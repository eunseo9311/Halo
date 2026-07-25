package com.safesoundla.halo.presentation.routing

import com.safesoundla.halo.application.routing.RouteService
import com.safesoundla.halo.infrastructure.aidata.AiDataSnapshot
import com.safesoundla.halo.infrastructure.aidata.AiDataStore
import com.safesoundla.halo.infrastructure.aidata.RouteGraph
import com.safesoundla.halo.infrastructure.aidata.model.*
import com.safesoundla.halo.infrastructure.config.RoutingProperties
import org.jgrapht.graph.DefaultWeightedEdge
import org.jgrapht.graph.DirectedWeightedPseudograph
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import java.time.OffsetDateTime
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
        SlotDefinition(index = 0, dowGroup = "weekday", hourStart = 0, hourEnd = 24),
    )

    //  A=(34.0520, -118.2440)  B=(34.0525, -118.2430)  C=(34.0530, -118.2420)
    private val segAb = buildSeg(
        segId = "A_B_0", from = 1L, to = 2L,
        sLat = 34.0520, sLng = -118.2440, eLat = 34.0525, eLng = -118.2430,
        lengthM = 110.0, wsi = 0.8,
        factors = listOf("low_light", "high_incident"),
    )
    private val segBc = buildSeg(
        segId = "B_C_0", from = 2L, to = 3L,
        sLat = 34.0525, sLng = -118.2430, eLat = 34.0530, eLng = -118.2420,
        lengthM = 120.0, wsi = 0.7,
        factors = listOf("high_incident", "low_activity"),
    )

    @BeforeEach
    fun setUp() {
        val graph = DirectedWeightedPseudograph<Long, DefaultWeightedEdge>(DefaultWeightedEdge::class.java)
        val edgeToSegId = HashMap<DefaultWeightedEdge, String>()
        val nodeCoords = HashMap<Long, DoubleArray>()

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
                    beta = BetaWeights(risk = 0.42, light = 0.31, activity = 0.19, safezone = 0.08),
                    tierThresholds = TierThresholds(green = 0.7, yellow = 0.4),
                    slotCount = 1,
                    dataVintage = DataVintage.Dummy,
                    districtId = "test",
                    sourcePeriod = "test",
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
        assertTrue(allFactors.contains("low_light"), "low_light must be retained in safest route")
        assertTrue(allFactors.contains("low_activity"), "low_activity must be retained in safest route")
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

    @Test
    fun `response exposes resolved slot departure time and full coordinates`() {
        val response = service.findRoutes(fromAtoC())

        assertEquals(0, response.slotIndex)
        assertEquals("2026-07-20T12:00-07:00[America/Los_Angeles]", response.departureTime)
        assertEquals(2, response.safestRoute.segments.first().coordinates?.size)
        assertEquals("GREEN", response.safestRoute.segments.first().colorBand)
        assertEquals(0, response.safestRoute.segments.first().slotIndex)
    }

    @Test
    fun `departure timestamps use LA daylight and standard offsets`() {
        val summer = service.findRoutes(
            fromAtoC().copy(departureTime = OffsetDateTime.parse("2026-07-20T19:00:00Z")),
        )
        val winter = service.findRoutes(
            fromAtoC().copy(departureTime = OffsetDateTime.parse("2026-01-19T20:00:00Z")),
        )

        assertTrue(summer.departureTime!!.contains("-07:00[America/Los_Angeles]"))
        assertTrue(winter.departureTime!!.contains("-08:00[America/Los_Angeles]"))
    }

    @Test
    fun `unknown day is rejected instead of silently using current LA day`() {
        assertThrows<IllegalArgumentException> {
            service.findRoutes(fromAtoC().copy(departureTime = null, dayOfWeek = "holiday", hour = 12))
        }
    }

    @Test
    fun `departure timestamp cannot be combined with legacy slot fields`() {
        assertThrows<IllegalArgumentException> {
            service.findRoutes(fromAtoC().copy(hour = 12))
        }
    }

    @Test
    fun `missing slot WSI is rejected instead of using a neutral score`() {
        val broken = segAb.score.copy(wsi = emptyList())
        val snapshot = store.get()
        store.set(snapshot.copy(scores = snapshot.scores + (segAb.segId to broken)))

        assertThrows<IllegalStateException> { service.findRoutes(fromAtoC()) }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun fromAtoC() = RouteRequest(
        fromLat = 34.0520, fromLng = -118.2440,
        toLat   = 34.0530, toLng   = -118.2420,
        departureTime = OffsetDateTime.parse("2026-07-20T12:00:00-07:00"),
    )

    private data class SegData(
        val segId: String, val nodeA: Long, val nodeB: Long,
        val sLat: Double, val sLng: Double, val eLat: Double, val eLng: Double,
        val lengthM: Double,
        val feature: SegmentFeature,
        val score: WsiScoreEntry,
    )

    private fun buildSeg(
        segId: String, from: Long, to: Long,
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
                streetName = emptyList(),
            ),
        ),
        score = WsiScoreEntry(
            wsi        = listOf(wsi),
            tier = listOf(TierCode.GREEN),
            components = ComponentScores(
                risk = listOf(0.5),
                light = listOf(0.5),
                activity = listOf(0.5),
                safezone = listOf(0.5),
            ),
            factors    = listOf(factors),
        ),
    )
}
