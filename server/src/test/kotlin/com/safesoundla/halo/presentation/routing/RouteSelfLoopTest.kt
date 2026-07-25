package com.safesoundla.halo.presentation.routing

import com.safesoundla.halo.application.routing.RouteService
import com.safesoundla.halo.infrastructure.aidata.AiDataSnapshot
import com.safesoundla.halo.infrastructure.aidata.AiDataStore
import com.safesoundla.halo.infrastructure.aidata.RouteGraph
import com.safesoundla.halo.infrastructure.aidata.model.BetaWeights
import com.safesoundla.halo.infrastructure.aidata.model.ComponentScores
import com.safesoundla.halo.infrastructure.aidata.model.DataVintage
import com.safesoundla.halo.infrastructure.aidata.model.LineStringGeometry
import com.safesoundla.halo.infrastructure.aidata.model.SegmentFeature
import com.safesoundla.halo.infrastructure.aidata.model.SegmentProperties
import com.safesoundla.halo.infrastructure.aidata.model.SlotDefinition
import com.safesoundla.halo.infrastructure.aidata.model.TierCode
import com.safesoundla.halo.infrastructure.aidata.model.TierThresholds
import com.safesoundla.halo.infrastructure.aidata.model.WsiMeta
import com.safesoundla.halo.infrastructure.aidata.model.WsiScoreEntry
import com.safesoundla.halo.infrastructure.config.RoutingProperties
import org.jgrapht.graph.DefaultWeightedEdge
import org.jgrapht.graph.DirectedWeightedPseudograph
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import java.time.OffsetDateTime
import kotlin.test.assertEquals
import kotlin.test.assertFalse

/**
 * Positive-cost self-loops are valid ingest edges but must never be inserted into a
 * simple route when they do not advance toward the destination.
 *
 * TODO(Yen): if route alternatives use Yen's algorithm, preserve this loopless response
 * contract and reject candidate paths that repeat a vertex or segment.
 */
class RouteSelfLoopTest {
    private lateinit var service: RouteService

    @BeforeEach
    fun setUp() {
        val loop = segment("SELF", 1L, 1L, 34.0000, -118.0000, 34.0000, -118.0000, 10.0)
        val first = segment("ONE_TWO", 1L, 2L, 34.0000, -118.0000, 34.0010, -118.0000, 120.0)
        val second = segment("TWO_THREE", 2L, 3L, 34.0010, -118.0000, 34.0020, -118.0000, 120.0)
        val segments = listOf(loop, first, second)

        val graph = DirectedWeightedPseudograph<Long, DefaultWeightedEdge>(DefaultWeightedEdge::class.java)
        val edgeToSegmentId = mutableMapOf<DefaultWeightedEdge, String>()
        val nodeCoords = mutableMapOf<Long, DoubleArray>()
        segments.forEach { fixture ->
            graph.addVertex(fixture.from)
            graph.addVertex(fixture.to)
            nodeCoords[fixture.from] = doubleArrayOf(fixture.feature.startLat, fixture.feature.startLng)
            nodeCoords[fixture.to] = doubleArrayOf(fixture.feature.endLat, fixture.feature.endLng)
            val edge = graph.addEdge(fixture.from, fixture.to)
            graph.setEdgeWeight(edge, fixture.feature.properties.lengthM)
            edgeToSegmentId[edge] = fixture.feature.properties.segmentId
        }

        val store = AiDataStore()
        store.set(
            AiDataSnapshot(
                meta = meta(),
                segments = segments.associate { it.feature.properties.segmentId to it.feature },
                scores = segments.associate { it.feature.properties.segmentId to score() },
                safeZones = emptyList(),
                routeGraph = RouteGraph(graph, edgeToSegmentId, nodeCoords),
            ),
        )
        service = RouteService(store, RoutingProperties(safetyWeight = 1.0))
    }

    @Test
    fun `shortest and safest routes skip positive self-loop and never repeat segments`() {
        val response = service.findRoutes(request(fromLat = 34.0000, toLat = 34.0020))

        listOf(response.shortestRoute, response.safestRoute).forEach { route ->
            val ids = route.segments.map { it.segmentId }
            assertEquals(listOf("ONE_TWO", "TWO_THREE"), ids)
            assertEquals(ids.distinct().size, ids.size)
            assertFalse("SELF" in ids)
        }
    }

    @Test
    fun `directed path remains unavailable in reverse despite self-loop`() {
        assertThrows<NoSuchElementException> {
            service.findRoutes(request(fromLat = 34.0020, toLat = 34.0000))
        }
    }

    private fun request(fromLat: Double, toLat: Double) = RouteRequest(
        fromLat = fromLat,
        fromLng = -118.0000,
        toLat = toLat,
        toLng = -118.0000,
        departureTime = OffsetDateTime.parse("2026-07-20T12:00:00-07:00"),
    )

    private fun meta() = WsiMeta(
        wsiVersion = "test",
        modelVersion = "test",
        beta = BetaWeights(risk = 0.42, light = 0.31, activity = 0.19, safezone = 0.08),
        tierThresholds = TierThresholds(yellow = 0.4, green = 0.7),
        slotCount = 1,
        dataVintage = DataVintage.Dummy,
        districtId = "test",
        sourcePeriod = "test",
        slots = listOf(SlotDefinition(index = 0, dowGroup = "weekday", hourStart = 0, hourEnd = 24)),
    )

    private fun score() = WsiScoreEntry(
        wsi = listOf(0.8),
        tier = listOf(TierCode.GREEN),
        components = ComponentScores(
            risk = listOf(0.8),
            light = listOf(0.8),
            activity = listOf(0.8),
            safezone = listOf(0.8),
        ),
        factors = listOf(emptyList()),
    )

    private fun segment(
        id: String,
        from: Long,
        to: Long,
        startLat: Double,
        startLng: Double,
        endLat: Double,
        endLng: Double,
        lengthM: Double,
    ) = SegmentFixture(
        from = from,
        to = to,
        feature = SegmentFeature(
            type = "Feature",
            geometry = LineStringGeometry(
                type = "LineString",
                coordinates = listOf(listOf(startLng, startLat), listOf(endLng, endLat)),
            ),
            properties = SegmentProperties(
                segmentId = id,
                connects = listOf(from, to),
                lengthM = lengthM,
                districtId = null,
                subareaId = null,
                streetName = emptyList(),
            ),
        ),
    )

    private data class SegmentFixture(
        val from: Long,
        val to: Long,
        val feature: SegmentFeature,
    )
}
