package com.safesoundla.halo.presentation.routing

import com.safesoundla.halo.application.routing.RouteService
import com.safesoundla.halo.infrastructure.aidata.AiDataSnapshot
import com.safesoundla.halo.infrastructure.aidata.AiDataStore
import com.safesoundla.halo.infrastructure.aidata.RouteGraph
import com.safesoundla.halo.infrastructure.aidata.model.*
import com.safesoundla.halo.infrastructure.config.RoutingProperties
import org.jgrapht.graph.DefaultWeightedEdge
import org.jgrapht.graph.WeightedMultigraph
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Verifies that `high_incident` is NEVER present in route segment factors
 * for either the safest or shortest route.
 *
 * Mirrors the contract from [com.safesoundla.halo.presentation.segment.HighIncidentFilterTest]
 * but applied to the routing API.
 *
 * Test graph:  A ──(AB)──► B ──(BC)──► C  (linear path, no branches)
 *
 * Pure unit test — no Spring context, no DB, no file I/O.
 */
class RouteHighIncidentFilterTest {

    private lateinit var store: AiDataStore
    private lateinit var service: RouteService

    // ── Fixture ───────────────────────────────────────────────────────────────

    private val slots = listOf(
        SlotDefinition(index = 0, dowGroup = "weekday", hourStart = 0, hourEnd = 24, label = "all_day"),
    )

    //  A=(34.0520, -118.2440)  B=(34.0525, -118.2430)  C=(34.0530, -118.2420)
    private val segAb = buildSeg(
        segId = "A_B_0", from = "A", to = "B",
        sLat = 34.0520, sLng = -118.2440, eLat = 34.0525, eLng = -118.2430,
        lengthM = 110.0, wsi = 0.8,
        factors = listOf("well_lit", "high_incident"),
    )
    private val segBc = buildSeg(
        segId = "B_C_0", from = "B", to = "C",
        sLat = 34.0525, sLng = -118.2430, eLat = 34.0530, eLng = -118.2420,
        lengthM = 120.0, wsi = 0.7,
        factors = listOf("high_incident", "low_traffic"),
    )

    @BeforeEach
    fun setUp() {
        val graph       = WeightedMultigraph<String, DefaultWeightedEdge>(DefaultWeightedEdge::class.java)
        val edgeToSegId = HashMap<DefaultWeightedEdge, String>()
        val nodeCoords  = HashMap<String, DoubleArray>()

        listOf(segAb, segBc).forEach { s ->
            graph.addVertex(s.nodeA); graph.addVertex(s.nodeB)
            nodeCoords[s.nodeA] = doubleArrayOf(s.sLat, s.sLng)
            nodeCoords[s.nodeB] = doubleArrayOf(s.eLat, s.eLng)
            val edge = graph.addEdge(s.nodeA, s.nodeB)
            graph.setEdgeWeight(edge, s.lengthM)
            edgeToSegId[edge] = s.segId
        }

        store = AiDataStore()
        store.set(
            AiDataSnapshot(
                meta = WsiMeta(
                    wsiVersion     = "test",
                    modelVersion   = "v0",
                    beta           = BetaWeights(risk = 0.5, light = 0.3, comfort = 0.2),
                    tierThresholds = TierThresholds(green = 0.7, yellow = 0.4),
                    slots          = slots,
                ),
                segments   = mapOf(segAb.segId to segAb.feature, segBc.segId to segBc.feature),
                scores     = mapOf(segAb.segId to segAb.score,   segBc.segId to segBc.score),
                safeZones  = emptyList(),
                routeGraph = RouteGraph(graph, edgeToSegId, nodeCoords),
            )
        )
        service = RouteService(store, RoutingProperties(safetyWeight = 1.0))
    }

    // ── high_incident filter tests ────────────────────────────────────────────

    @Test
    fun `safest route never contains high_incident in any segment factors`() {
        val response = service.findRoutes(fromAtoC())
        response.safestRoute.segments.forEach { seg ->
            assertFalse(
                seg.factors.contains("high_incident"),
                "high_incident must not appear in safest route — segment=${seg.segmentId} factors=${seg.factors}"
            )
        }
    }

    @Test
    fun `shortest route never contains high_incident in any segment factors`() {
        val response = service.findRoutes(fromAtoC())
        response.shortestRoute.segments.forEach { seg ->
            assertFalse(
                seg.factors.contains("high_incident"),
                "high_incident must not appear in shortest route — segment=${seg.segmentId} factors=${seg.factors}"
            )
        }
    }

    @Test
    fun `other factors are preserved after filtering`() {
        val response   = service.findRoutes(fromAtoC())
        val allFactors = response.safestRoute.segments.flatMap { it.factors }
        assertTrue(allFactors.contains("well_lit"),    "well_lit must be retained in safest route")
        assertTrue(allFactors.contains("low_traffic"), "low_traffic must be retained in safest route")
    }

    @Test
    fun `route traverses both segments A-B and B-C`() {
        val response = service.findRoutes(fromAtoC())
        val segIds   = response.safestRoute.segments.map { it.segmentId }
        assertTrue(segIds.contains("A_B_0"), "safest route must include A_B_0")
        assertTrue(segIds.contains("B_C_0"), "safest route must include B_C_0")
    }

    @Test
    fun `route response contains totalDistance and avgWsi`() {
        val response = service.findRoutes(fromAtoC())
        assertEquals(110.0 + 120.0, response.safestRoute.totalDistance, "totalDistance mismatch")
        val avgWsi = response.safestRoute.avgWsi
        assertTrue(avgWsi != null && avgWsi > 0.0, "avgWsi should be populated")
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun fromAtoC() = RouteRequest(
        fromLat = 34.0520, fromLng = -118.2440,
        toLat   = 34.0530, toLng   = -118.2420,
    )

    private data class SegData(
        val segId: String, val nodeA: String, val nodeB: String,
        val sLat: Double, val sLng: Double, val eLat: Double, val eLng: Double,
        val lengthM: Double,
        val feature: SegmentFeature,
        val score: WsiScoreEntry,
    )

    private fun buildSeg(
        segId: String, from: String, to: String,
        sLat: Double, sLng: Double, eLat: Double, eLng: Double,
        lengthM: Double, wsi: Double, factors: List<String>,
    ) = SegData(
        segId   = segId, nodeA = from, nodeB = to,
        sLat    = sLat,  sLng  = sLng, eLat  = eLat, eLng = eLng,
        lengthM = lengthM,
        feature = SegmentFeature(
            type     = "Feature",
            geometry = LineStringGeometry(
                type        = "LineString",
                coordinates = listOf(listOf(sLng, sLat), listOf(eLng, eLat)),
            ),
            properties = SegmentProperties(
                segmentId  = segId,
                connects   = listOf(from, to),
                lengthM    = lengthM,
                districtId = null,
                subareaId  = null,
            ),
        ),
        score = WsiScoreEntry(
            wsi        = listOf(wsi),
            tier       = listOf(if (wsi >= 0.7) "GREEN" else if (wsi >= 0.4) "YELLOW" else "RED"),
            components = ComponentScores(risk = listOf(0.5), light = listOf(0.5), comfort = listOf(0.5)),
            factors    = listOf(factors),
        ),
    )
}
