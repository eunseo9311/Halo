package com.safesoundla.halo.infrastructure.aidata

import com.fasterxml.jackson.databind.DeserializationFeature
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.module.kotlin.KotlinModule
import com.fasterxml.jackson.module.kotlin.readValue
import com.safesoundla.halo.infrastructure.aidata.model.SafeZoneFeature
import com.safesoundla.halo.infrastructure.aidata.model.SafeZonesGeoJson
import com.safesoundla.halo.infrastructure.aidata.model.SegmentFeature
import com.safesoundla.halo.infrastructure.aidata.model.SegmentsGeoJson
import com.safesoundla.halo.infrastructure.aidata.model.WsiScoresFile
import org.jgrapht.graph.DefaultWeightedEdge
import org.jgrapht.graph.DirectedWeightedMultigraph
import org.slf4j.LoggerFactory
import org.springframework.boot.context.event.ApplicationReadyEvent
import org.springframework.context.event.EventListener
import org.springframework.core.io.ClassPathResource
import org.springframework.core.io.FileSystemResource
import org.springframework.core.io.Resource
import org.springframework.stereotype.Component
import java.io.InputStream
import kotlin.system.measureTimeMillis

private const val EXPECTED_SLOT_COUNT = 32
private const val BETA_SUM_TOLERANCE = 1e-6
private const val NODE_COORD_TOLERANCE = 1e-7
private val PUBLIC_FACTORS = setOf("low_light", "outage_reported", "low_activity", "no_safezone")
private const val INTERNAL_FACTOR = "high_incident"
private val EXPECTED_DOW_GROUPS = listOf("weekday", "fri", "sat", "sun")

/**
 * Loads the three AI-generated data files into [AiDataStore] at startup.
 *
 * Also called by [com.safesoundla.halo.presentation.admin.AdminController] for manual hot-reload.
 *
 * ### Validation (Requirement 5)
 * - WSI scores whose segment_id is absent from segments.geojson → WARNING log + skip.
 * - Safe-zone nearby_segments that reference an absent segment_id → WARNING log + count only.
 * - Server does NOT hard-fail on mismatch; prototype resilience > strict gate.
 *   Rationale: AI team may deliver files at slightly different times; a warning is actionable
 *   without taking down the server. Re-evaluate when moving to production.
 */
@Component
class AiDataLoader(
    private val store: AiDataStore,
    private val props: AiDataProperties,
) {

    private val log = LoggerFactory.getLogger(AiDataLoader::class.java)

    // Dedicated ObjectMapper — FAIL_ON_UNKNOWN_PROPERTIES=false so unknown fields
    // (e.g. the _comment field in placeholder JSON) are silently ignored.
    private val mapper: ObjectMapper = ObjectMapper()
        .registerModule(KotlinModule.Builder().build())
        .configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false)

    // ── Startup ──────────────────────────────────────────────────────────────

    @EventListener(ApplicationReadyEvent::class)
    fun onReady() {
        val elapsed = measureTimeMillis { store.set(load()) }
        log.info("[AI-DATA] Bootstrap complete in ${elapsed}ms")
    }

    // ── Public (also used by /admin/reload) ──────────────────────────────────

    /**
     * Reads all three files, validates cross-file segment ID consistency,
     * and returns a new [AiDataSnapshot].
     *
     * Files are read sequentially and raw bytes are not cached.
     */
    fun load(): AiDataSnapshot {
        log.info("[AI-DATA] Loading from: segments={}, wsi_scores={}, safezones={}",
            props.segmentsPath, props.wsiScoresPath, props.safezonesPath)

        val segmentsFile: SegmentsGeoJson
        val wsiFile: WsiScoresFile
        val safeZonesFile: SafeZonesGeoJson

        val parseMs = measureTimeMillis {
            segmentsFile = openResource(props.segmentsPath).use { mapper.readValue(it) }
            wsiFile      = openResource(props.wsiScoresPath).use { mapper.readValue(it) }
            safeZonesFile = openResource(props.safezonesPath).use { mapper.readValue(it) }
        }

        validateSchema(segmentsFile, wsiFile, safeZonesFile)

        log.info("[AI-DATA] Parsed in ${parseMs}ms — " +
            "segments=${segmentsFile.features.size}, " +
            "score_entries=${wsiFile.scores.size}, " +
            "safezones=${safeZonesFile.features.size}")
        log.info("[AI-DATA] wsi_version=${wsiFile.meta.wsiVersion}, " +
            "model_version=${wsiFile.meta.modelVersion}, " +
            "slot_count=${wsiFile.meta.slots.size}")

        // Index segments by ID for O(1) lookup and validation
        val segmentMap: Map<String, SegmentFeature> =
            segmentsFile.features.associateBy { it.properties.segmentId }

        // ── Requirement 5: Cross-file validation ─────────────────────────────

        val validScores = validateScores(wsiFile, segmentMap)
        val validSafeZones = validateSafeZones(safeZonesFile, segmentMap)

        val routeGraph = buildRouteGraph(segmentMap)

        return AiDataSnapshot(
            meta       = wsiFile.meta,
            segments   = segmentMap,
            scores     = validScores,
            safeZones  = validSafeZones,
            routeGraph = routeGraph,
        )
    }

    // ── Validation helpers ────────────────────────────────────────────────────

    private fun validateSchema(
        segmentsFile: SegmentsGeoJson,
        wsiFile: WsiScoresFile,
        safeZonesFile: SafeZonesGeoJson,
    ) {
        require(segmentsFile.type == "FeatureCollection") {
            "segments.geojson type must be FeatureCollection"
        }
        require(safeZonesFile.type == "FeatureCollection") {
            "safezones.geojson type must be FeatureCollection"
        }
        require(segmentsFile.features.map { it.properties.segmentId }.toSet().size == segmentsFile.features.size) {
            "segments.geojson contains duplicate segment_id values"
        }
        require(safeZonesFile.features.map { it.properties.poiId }.toSet().size == safeZonesFile.features.size) {
            "safezones.geojson contains duplicate poi_id values"
        }

        segmentsFile.features.forEach(::validateSegment)
        safeZonesFile.features.forEach(::validateSafeZone)
        validateMeta(wsiFile)
        wsiFile.scores.forEach { (segmentId, score) ->
            require(segmentId.isNotBlank()) { "wsi_scores contains a blank segment_id" }
            val arrays = listOf(
                "wsi" to score.wsi,
                "tier" to score.tier,
                "components.risk" to score.components.risk,
                "components.light" to score.components.light,
                "components.activity" to score.components.activity,
                "components.safezone" to score.components.safezone,
                "factors" to score.factors,
            )
            arrays.forEach { (name, values) ->
                require(values.size == EXPECTED_SLOT_COUNT) {
                    "scores[$segmentId].$name must contain exactly $EXPECTED_SLOT_COUNT slots"
                }
            }
            listOf(
                "wsi" to score.wsi,
                "components.risk" to score.components.risk,
                "components.light" to score.components.light,
                "components.activity" to score.components.activity,
                "components.safezone" to score.components.safezone,
            ).forEach { (name, values) ->
                require(values.all { it.isFinite() && it in 0.0..1.0 }) {
                    "scores[$segmentId].$name values must be finite and within [0, 1]"
                }
            }
            score.factors.flatten().forEach { factor ->
                require(factor in PUBLIC_FACTORS || factor == INTERNAL_FACTOR) {
                    "scores[$segmentId] contains unknown factor: $factor"
                }
            }
        }
    }

    private fun validateMeta(wsiFile: WsiScoresFile) {
        val meta = wsiFile.meta
        val beta = meta.beta
        val weights = listOf(beta.risk, beta.light, beta.activity, beta.safezone)
        require(weights.all { it.isFinite() && it in 0.0..1.0 }) {
            "meta.beta weights must be finite and within [0, 1]"
        }
        require(kotlin.math.abs(weights.sum() - 1.0) <= BETA_SUM_TOLERANCE) {
            "meta.beta weights must sum to 1.0"
        }
        require(meta.tierThresholds.green.isFinite() && meta.tierThresholds.yellow.isFinite()) {
            "meta.tier_thresholds must be finite"
        }
        require(meta.tierThresholds.green in 0.0..1.0 &&
            meta.tierThresholds.yellow in 0.0..1.0 &&
            meta.tierThresholds.yellow < meta.tierThresholds.green
        ) {
            "meta.tier_thresholds must satisfy 0 <= yellow < green <= 1"
        }
        require(meta.slots.size == EXPECTED_SLOT_COUNT) {
            "meta.slots must contain exactly $EXPECTED_SLOT_COUNT slots"
        }
        require(meta.slotCount == EXPECTED_SLOT_COUNT && meta.slotCount == meta.slots.size) {
            "meta.slot_count must equal $EXPECTED_SLOT_COUNT and match meta.slots"
        }
        meta.slots.forEachIndexed { index, slot ->
            val expectedGroup = EXPECTED_DOW_GROUPS[index / 8]
            val expectedStart = (index % 8) * 3
            require(slot.index == index) { "meta.slots[$index].index must equal $index" }
            require(slot.dowGroup == expectedGroup) {
                "meta.slots[$index].dow_group must be $expectedGroup"
            }
            require(slot.hourStart == expectedStart && slot.hourEnd == expectedStart + 3) {
                "meta.slots[$index] must cover [$expectedStart, ${expectedStart + 3})"
            }
        }
    }

    private fun validateSegment(segment: SegmentFeature) {
        require(segment.type == "Feature") { "Segment feature type must be Feature" }
        require(segment.geometry.type == "LineString") {
            "Segment '${segment.properties.segmentId}' geometry type must be LineString"
        }
        require(segment.geometry.coordinates.size >= 2) {
            "Segment '${segment.properties.segmentId}' LineString must contain at least two coordinates"
        }
        segment.geometry.coordinates.forEachIndexed { index, coordinate ->
            require(coordinate.size == 2) {
                "Segment '${segment.properties.segmentId}' coordinate[$index] must be [longitude, latitude]"
            }
            val (lng, lat) = coordinate
            require(lng.isFinite() && lng in -180.0..180.0 && lat.isFinite() && lat in -90.0..90.0) {
                "Segment '${segment.properties.segmentId}' coordinate[$index] is out of range"
            }
        }
        require(segment.properties.segmentId.isNotBlank()) { "segment_id must not be blank" }
        require(segment.properties.connects.size == 2) {
            "Segment '${segment.properties.segmentId}' connects must contain exactly two node IDs"
        }
        require(segment.properties.connects[0] != segment.properties.connects[1]) {
            "Segment '${segment.properties.segmentId}' connects must reference distinct node IDs"
        }
        require(segment.properties.lengthM.isFinite() && segment.properties.lengthM > 0.0) {
            "Segment '${segment.properties.segmentId}' length_m must be positive and finite"
        }
        require(segment.properties.streetName.all { it.isNotBlank() }) {
            "Segment '${segment.properties.segmentId}' street_name values must not be blank"
        }
    }

    private fun validateSafeZone(zone: SafeZoneFeature) {
        require(zone.type == "Feature") { "Safe-zone feature type must be Feature" }
        require(zone.geometry.type == "Point") {
            "SafeZone '${zone.properties.poiId}' geometry type must be Point"
        }
        require(zone.geometry.coordinates.size == 2) {
            "SafeZone '${zone.properties.poiId}' coordinate must be [longitude, latitude]"
        }
        val (lng, lat) = zone.geometry.coordinates
        require(lng.isFinite() && lng in -180.0..180.0 && lat.isFinite() && lat in -90.0..90.0) {
            "SafeZone '${zone.properties.poiId}' coordinate is out of range"
        }
        require(zone.properties.poiId.isNotBlank()) { "poi_id must not be blank" }
        require(zone.properties.name.isNotBlank()) {
            "SafeZone '${zone.properties.poiId}' name must not be blank"
        }
        require(zone.properties.nearbySegments.distinct().size == zone.properties.nearbySegments.size) {
            "SafeZone '${zone.properties.poiId}' nearby_segments must not contain duplicates"
        }
    }

    /**
     * Drops score entries whose segment_id is not in [segmentMap].
     * Logs only an aggregate count; source identifiers are never emitted.
     */
    private fun validateScores(
        wsiFile: WsiScoresFile,
        segmentMap: Map<String, SegmentFeature>,
    ): Map<String, com.safesoundla.halo.infrastructure.aidata.model.WsiScoreEntry> {
        val orphaned = wsiFile.scores.keys.filter { it !in segmentMap }
        val missing = segmentMap.keys.count { it !in wsiFile.scores }
        if (orphaned.isNotEmpty()) {
            log.warn(
                "[AI-DATA] wsi_scores contains {} segment_ids not found in segments.geojson — skipped",
                orphaned.size,
            )
        }
        if (missing > 0) {
            log.warn(
                "[AI-DATA] segments.geojson contains {} segment_ids without a WSI score",
                missing,
            )
        }
        return wsiFile.scores.filterKeys { it in segmentMap }
    }

    /**
     * Logs one aggregate warning for safe-zone nearby_segments that reference unknown segment IDs.
     * Safe zones are retained because orphan references are a cross-file delivery mismatch.
     */
    private fun validateSafeZones(
        safeZonesFile: SafeZonesGeoJson,
        segmentMap: Map<String, SegmentFeature>,
    ): List<SafeZoneFeature> {
        val orphaned = safeZonesFile.features.flatMap { zone ->
            zone.properties.nearbySegments
                .filter { it !in segmentMap }
                .map { zone.properties.poiId to it }
        }
        if (orphaned.isNotEmpty()) {
            log.warn(
                "[AI-DATA] Safe zones contain {} orphaned nearby_segment references across {} zones",
                orphaned.size,
                orphaned.map { it.first }.distinct().size,
            )
        }
        return safeZonesFile.features
    }

    // ── Route graph construction ──────────────────────────────────────────────

    /**
     * Builds a [RouteGraph] from the validated segment map.
     *
     * - Vertices = node IDs from connects[].
     * - Edges = one per segment, base weight = length_m (used for shortest-path queries).
     * - [RouteGraph.edgeToSegmentId] enables dynamic per-slot WSI cost at query time.
     * - [RouteGraph.nodeCoords] stores (lat, lng) for the A* Euclidean heuristic.
     *
     * Uses [DirectedWeightedMultigraph] to support parallel directed segments between two nodes
     * (e.g. segment_id "111_222_0" and "111_222_1").
     */
    private fun buildRouteGraph(segments: Map<String, SegmentFeature>): RouteGraph {
        val graph = DirectedWeightedMultigraph<Long, DefaultWeightedEdge>(DefaultWeightedEdge::class.java)
        val edgeToSegmentId = HashMap<DefaultWeightedEdge, String>(segments.size)
        val nodeCoords = HashMap<Long, DoubleArray>(segments.size * 2)

        for (segment in segments.values) {
            val props = segment.properties
            val nodeA = props.connects[0]
            val nodeB = props.connects[1]

            graph.addVertex(nodeA)
            graph.addVertex(nodeB)
            putNodeCoords(nodeCoords, nodeA, segment.startLat, segment.startLng, props.segmentId)
            putNodeCoords(nodeCoords, nodeB, segment.endLat, segment.endLng, props.segmentId)

            val edge = checkNotNull(graph.addEdge(nodeA, nodeB)) {
                "Unable to add graph edge for segment '${props.segmentId}'"
            }
            graph.setEdgeWeight(edge, props.lengthM)
            check(edgeToSegmentId.put(edge, props.segmentId) == null) {
                "Duplicate graph edge mapping for segment '${props.segmentId}'"
            }
        }

        check(graph.edgeSet().size == edgeToSegmentId.size) {
            "Route graph edge count does not match segment mapping count"
        }
        log.info("[AI-DATA] Route graph: vertices=${graph.vertexSet().size}, " +
            "edges=${graph.edgeSet().size}")
        return RouteGraph(graph, edgeToSegmentId, nodeCoords)
    }

    private fun putNodeCoords(
        nodeCoords: MutableMap<Long, DoubleArray>,
        nodeId: Long,
        lat: Double,
        lng: Double,
        segmentId: String,
    ) {
        val coordinates = doubleArrayOf(lat, lng)
        val existing = nodeCoords.putIfAbsent(nodeId, coordinates) ?: return
        check(
            kotlin.math.abs(existing[0] - lat) <= NODE_COORD_TOLERANCE &&
                kotlin.math.abs(existing[1] - lng) <= NODE_COORD_TOLERANCE,
        ) {
            "Node $nodeId has inconsistent coordinates at segment '$segmentId'"
        }
    }

    // ── Resource resolution ───────────────────────────────────────────────────

    private fun openResource(path: String): InputStream {
        val resource: Resource = when {
            path.startsWith("classpath:") -> ClassPathResource(path.removePrefix("classpath:"))
            path.startsWith("file:")      -> FileSystemResource(path.removePrefix("file:"))
            else                          -> FileSystemResource(path)
        }
        check(resource.exists()) { "AI data file not found: $path" }
        return resource.inputStream
    }
}
