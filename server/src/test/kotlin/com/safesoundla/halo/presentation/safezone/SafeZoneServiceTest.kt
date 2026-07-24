package com.safesoundla.halo.presentation.safezone

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.module.kotlin.KotlinModule
import com.safesoundla.halo.application.safezone.SafeZoneService
import com.safesoundla.halo.infrastructure.aidata.AiDataSnapshot
import com.safesoundla.halo.infrastructure.aidata.AiDataStore
import com.safesoundla.halo.infrastructure.aidata.RouteGraph
import com.safesoundla.halo.infrastructure.aidata.model.*
import org.jgrapht.graph.DefaultWeightedEdge
import org.jgrapht.graph.DirectedWeightedMultigraph
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse

class SafeZoneServiceTest {
    private val categories = SafeZoneCategory.entries

    @Test
    fun `nearby query maps all categories without exposing influence segments or radius`() {
        val service = SafeZoneService(storeWithZones(categories.mapIndexed(::zone)))
        val result = service.findNearby(34.061, -118.300, 2_000)

        assertEquals(categories.map { it.code }.toSet(), result.map { it.category }.toSet())
        val json = ObjectMapper().registerModule(KotlinModule.Builder().build())
            .writeValueAsString(result)
        assertFalse(json.contains("nearbySegments"))
        assertFalse(json.contains("\"radius\""))
    }

    @Test
    fun `empty nearby segment list is valid and radius filters distant zones`() {
        val service = SafeZoneService(storeWithZones(listOf(zone(0, SafeZoneCategory.POLICE))))
        assertEquals(1, service.findNearby(34.061, -118.300, 100).size)
        assertEquals(0, service.findNearby(35.0, -118.300, 100).size)
    }

    @Test
    fun `invalid query is rejected explicitly`() {
        val service = SafeZoneService(storeWithZones(emptyList()))
        assertFailsWith<IllegalArgumentException> { service.findNearby(91.0, 0.0, 100) }
        assertFailsWith<IllegalArgumentException> { service.findNearby(0.0, 0.0, 0) }
    }

    private fun zone(index: Int, category: SafeZoneCategory) = SafeZoneFeature(
        type = "Feature",
        geometry = PointGeometry("Point", listOf(-118.300 + index * 0.0001, 34.061)),
        properties = SafeZoneProperties(
            poiId = "poi-$index",
            name = "Test ${category.code}",
            category = category,
            open24h = index % 2 == 0,
            nearbySegments = emptyList(),
        ),
    )

    private fun storeWithZones(zones: List<SafeZoneFeature>): AiDataStore {
        val store = AiDataStore()
        store.set(
            AiDataSnapshot(
                meta = WsiMeta(
                    wsiVersion = "test",
                    modelVersion = "test",
                    beta = BetaWeights(0.42, 0.31, 0.19, 0.08),
                    tierThresholds = TierThresholds(green = 0.67, yellow = 0.34),
                    slotCount = 32,
                    dataVintage = DataVintage.Dummy,
                    districtId = "REAL7KM",
                    sourcePeriod = "test",
                    slots = emptyList(),
                ),
                segments = emptyMap(),
                scores = emptyMap(),
                safeZones = zones,
                routeGraph = RouteGraph(
                    DirectedWeightedMultigraph<Long, DefaultWeightedEdge>(
                        DefaultWeightedEdge::class.java,
                    ),
                    emptyMap(),
                    emptyMap(),
                ),
            ),
        )
        return store
    }
}
