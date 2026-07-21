package com.safesoundla.halo.presentation.segment

import com.safesoundla.halo.application.segment.AiSegmentService
import com.safesoundla.halo.infrastructure.aidata.AiDataSnapshot
import com.safesoundla.halo.infrastructure.aidata.AiDataStore
import com.safesoundla.halo.infrastructure.aidata.model.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Verifies that `high_incident` is NEVER present in the public API response,
 * and IS present in the internal response.
 *
 * Pure unit test — no Spring context, no DB, no file I/O.
 */
class HighIncidentFilterTest {

    private lateinit var store: AiDataStore
    private lateinit var service: AiSegmentService

    // ── Fixture ───────────────────────────────────────────────────────────────

    private val slots = listOf(
        SlotDefinition(index = 0, dowGroup = "weekday", hourStart = 0, hourEnd = 24, label = "all_day"),
    )

    private val segmentId = "111_222_0"

    // Factor list for slot 0: contains high_incident alongside other codes
    private val factorsWithHighIncident = listOf(listOf("well_lit", "high_incident", "low_traffic"))

    private val segment = SegmentFeature(
        type = "Feature",
        geometry = LineStringGeometry(
            type = "LineString",
            coordinates = listOf(listOf(-118.2437, 34.0522), listOf(-118.2430, 34.0528)),
        ),
        properties = SegmentProperties(
            segmentId  = segmentId,
            connects   = listOf("111", "222"),
            lengthM    = 87.5,
            districtId = null,
            subareaId  = null,
        ),
    )

    private val scoreEntry = WsiScoreEntry(
        wsi        = listOf(0.82),
        tier       = listOf("GREEN"),
        components = ComponentScores(
            risk    = listOf(0.15),
            light   = listOf(0.90),
            comfort = listOf(0.75),
        ),
        factors    = factorsWithHighIncident,
    )

    private val meta = WsiMeta(
        wsiVersion       = "2026-07-22T00:00:00Z",
        modelVersion     = "v0.1-test",
        beta             = BetaWeights(risk = 0.6, light = 0.3, comfort = 0.1),
        tierThresholds   = TierThresholds(green = 0.7, yellow = 0.4),
        slots            = slots,
    )

    @BeforeEach
    fun setUp() {
        store = AiDataStore()
        store.set(AiDataSnapshot(
            meta       = meta,
            segments   = mapOf(segmentId to segment),
            scores     = mapOf(segmentId to scoreEntry),
            safeZones  = emptyList(),
        ))
        service = AiSegmentService(store)
    }

    // ── Public response tests ─────────────────────────────────────────────────

    @Test
    fun `public response never contains high_incident`() {
        val responses = service.findNearbyPublic(
            lat = 34.0522, lng = -118.2437, radiusMeters = 500, slotIndex = 0
        )
        assertTrue(responses.isNotEmpty(), "Expected at least one segment in response")
        responses.forEach { r ->
            assertFalse(
                r.factors.contains("high_incident"),
                "high_incident must not appear in public response factors, got: ${r.factors}"
            )
        }
    }

    @Test
    fun `public response retains other factors after filtering`() {
        val responses = service.findNearbyPublic(
            lat = 34.0522, lng = -118.2437, radiusMeters = 500, slotIndex = 0
        )
        val factors = responses.first().factors
        assertTrue(factors.contains("well_lit"),    "well_lit should be kept")
        assertTrue(factors.contains("low_traffic"), "low_traffic should be kept")
        assertEquals(2, factors.size, "Exactly 2 factors should remain after filtering high_incident")
    }

    @Test
    fun `public response is empty factors list when all factors are high_incident`() {
        val onlyHighIncident = scoreEntry.copy(factors = listOf(listOf("high_incident")))
        store.set(AiDataSnapshot(
            meta      = meta,
            segments  = mapOf(segmentId to segment),
            scores    = mapOf(segmentId to onlyHighIncident),
            safeZones = emptyList(),
        ))
        val responses = service.findNearbyPublic(
            lat = 34.0522, lng = -118.2437, radiusMeters = 500, slotIndex = 0
        )
        val factors = responses.first().factors
        assertTrue(factors.isEmpty(), "Factors list should be empty when only high_incident was present")
    }

    // ── Internal response tests ───────────────────────────────────────────────

    @Test
    fun `internal response contains high_incident`() {
        val responses = service.findNearbyInternal(
            lat = 34.0522, lng = -118.2437, radiusMeters = 500, slotIndex = 0
        )
        assertTrue(responses.isNotEmpty(), "Expected at least one segment in response")
        val factors = responses.first().factors
        assertTrue(
            factors.contains("high_incident"),
            "high_incident must be present in internal response, got: $factors"
        )
    }

    @Test
    fun `internal response returns all three original factors unmodified`() {
        val responses = service.findNearbyInternal(
            lat = 34.0522, lng = -118.2437, radiusMeters = 500, slotIndex = 0
        )
        val factors = responses.first().factors
        assertEquals(
            listOf("well_lit", "high_incident", "low_traffic"),
            factors,
            "Internal response must return factors exactly as stored"
        )
    }

    // ── DTO isolation test ────────────────────────────────────────────────────

    @Test
    fun `SegmentScoreResponse and SegmentScoreInternalResponse are distinct types`() {
        // Compile-time guarantee: these are separate classes, not the same DTO
        val publicType = SegmentScoreResponse::class
        val internalType = SegmentScoreInternalResponse::class
        assertTrue(publicType != internalType,
            "Public and internal DTOs must be distinct Kotlin classes")
    }
}
