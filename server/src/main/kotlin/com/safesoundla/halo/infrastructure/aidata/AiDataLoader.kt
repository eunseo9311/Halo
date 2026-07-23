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
import org.slf4j.LoggerFactory
import org.springframework.boot.context.event.ApplicationReadyEvent
import org.springframework.context.event.EventListener
import org.springframework.core.io.ClassPathResource
import org.springframework.core.io.FileSystemResource
import org.springframework.core.io.Resource
import org.springframework.stereotype.Component
import java.io.InputStream
import kotlin.system.measureTimeMillis

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
     * Performance note: files are read sequentially.
     * With real data (~30k segments, ~5–10 MB), expect 200–600 ms on first cold load.
     * Subsequent reloads will be similar (no caching of raw bytes by design).
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

        return AiDataSnapshot(
            meta = wsiFile.meta,
            segments = segmentMap,
            scores = validScores,
            safeZones = validSafeZones,
        )
    }

    // ── Validation helpers ────────────────────────────────────────────────────

    /**
     * Drops score entries whose segment_id is not in [segmentMap].
     * Logs one warning per orphaned ID (or a summary if count is large).
     */
    private fun validateScores(
        wsiFile: WsiScoresFile,
        segmentMap: Map<String, SegmentFeature>,
    ): Map<String, com.safesoundla.halo.infrastructure.aidata.model.WsiScoreEntry> {
        val orphaned = wsiFile.scores.keys.filter { it !in segmentMap }
        if (orphaned.isNotEmpty()) {
            if (orphaned.size <= 10) {
                orphaned.forEach { id ->
                    log.warn("[AI-DATA] wsi_scores has segment_id='$id' not found in segments.geojson — skipped")
                }
            } else {
                log.warn("[AI-DATA] wsi_scores has ${orphaned.size} segment_ids not found in segments.geojson — all skipped. First 5: ${orphaned.take(5)}")
            }
        }
        return wsiFile.scores.filterKeys { it in segmentMap }
    }

    /**
     * Logs warnings for safe-zone nearby_segments that reference unknown segment IDs.
     * The safe-zone itself is kept (bad nearby refs are just a data quality issue).
     */
    private fun validateSafeZones(
        safeZonesFile: SafeZonesGeoJson,
        segmentMap: Map<String, SegmentFeature>,
    ): List<SafeZoneFeature> {
        var totalOrphaned = 0
        safeZonesFile.features.forEach { zone ->
            val bad = zone.properties.nearbySegments.filter { it !in segmentMap }
            if (bad.isNotEmpty()) {
                totalOrphaned += bad.size
                log.warn("[AI-DATA] SafeZone '${zone.properties.safezoneId}' " +
                    "references ${bad.size} unknown nearby_segment(s): $bad")
            }
        }
        if (totalOrphaned > 0) {
            log.warn("[AI-DATA] Total orphaned nearby_segment references: $totalOrphaned")
        }
        return safeZonesFile.features
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
