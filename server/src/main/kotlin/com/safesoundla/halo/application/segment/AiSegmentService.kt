package com.safesoundla.halo.application.segment

import com.safesoundla.halo.infrastructure.aidata.AiDataSnapshot
import com.safesoundla.halo.infrastructure.aidata.AiDataStore
import com.safesoundla.halo.infrastructure.aidata.model.SegmentFeature
import com.safesoundla.halo.infrastructure.aidata.model.WsiScoreEntry
import com.safesoundla.halo.presentation.segment.ComponentScoresDto
import com.safesoundla.halo.presentation.segment.SegmentScoreInternalResponse
import com.safesoundla.halo.presentation.segment.SegmentScoreResponse
import org.springframework.stereotype.Service
import java.time.DayOfWeek
import java.time.ZoneId
import java.time.ZonedDateTime
import kotlin.math.cos
import kotlin.math.PI

private const val METERS_PER_DEGREE_LAT = 111_000.0
private const val MAX_SEGMENTS_PER_RESPONSE = 200
private const val HIGH_INCIDENT_FACTOR = "high_incident"
private val PUBLIC_FACTORS = setOf("low_light", "outage_reported", "low_activity", "no_safezone")
private val LA_ZONE = ZoneId.of("America/Los_Angeles")

@Service
class AiSegmentService(
    private val store: AiDataStore,
) {

    // ── Public API (used by SegmentScoreController) ───────────────────────────

    /**
     * Returns up to [MAX_SEGMENTS_PER_RESPONSE] segments near [lat]/[lng].
     *
     * Uses a bounding-box filter on the in-memory segment store (same approximation as the
     * DB-based service, but now reading from the AI snapshot instead of PostgreSQL).
     *
     * [slotIndex] defaults to the slot matching the current LA time if not supplied.
     * Beta weights and tier thresholds are read from [AiDataSnapshot.meta] — never hardcoded.
     */
    fun findNearbyPublic(
        lat: Double,
        lng: Double,
        radiusMeters: Int,
        slotIndex: Int? = null,
    ): List<SegmentScoreResponse> {
        val snapshot = store.get()
        val idx = slotIndex ?: currentSlotIndex(snapshot)
        return nearbySegments(snapshot, lat, lng, radiusMeters)
            .map { (seg, score) -> toPublicResponse(seg, score, idx) }
    }

    /**
     * Same as [findNearbyPublic] but returns the INTERNAL DTO — factors are unfiltered
     * (includes [HIGH_INCIDENT_FACTOR]).  Must only be exposed to internal/B2G endpoints.
     */
    fun findNearbyInternal(
        lat: Double,
        lng: Double,
        radiusMeters: Int,
        slotIndex: Int? = null,
    ): List<SegmentScoreInternalResponse> {
        val snapshot = store.get()
        val idx = slotIndex ?: currentSlotIndex(snapshot)
        return nearbySegments(snapshot, lat, lng, radiusMeters)
            .map { (seg, score) -> toInternalResponse(seg, score, idx) }
    }

    // ── Mapping ───────────────────────────────────────────────────────────────

    /**
     * Public response: [HIGH_INCIDENT_FACTOR] is EXPLICITLY removed at this mapping step.
     *
     * This is a server-side concern — callers must never receive this factor code.
     */
    private fun toPublicResponse(
        seg: SegmentFeature,
        score: WsiScoreEntry,
        slotIndex: Int,
    ) = SegmentScoreResponse(
        segmentId  = seg.properties.segmentId,
        wsiScore   = score.wsi.requiredAt(slotIndex, "wsi"),
        colorBand  = score.tier.requiredAt(slotIndex, "tier").name,
        startLat   = seg.startLat,
        startLng   = seg.startLng,
        endLat     = seg.endLat,
        endLng     = seg.endLng,
        coordinates = seg.geometry.coordinates,
        components = toComponentsDto(score, slotIndex),
        // Defence in depth: only explicitly public factor codes cross this DTO.
        factors    = score.factors.requiredAt(slotIndex, "factors")
                         .filter { it in PUBLIC_FACTORS },
        slotIndex  = slotIndex,
    )

    /** Internal response: all factors intact, no filtering. */
    private fun toInternalResponse(
        seg: SegmentFeature,
        score: WsiScoreEntry,
        slotIndex: Int,
    ) = SegmentScoreInternalResponse(
        segmentId  = seg.properties.segmentId,
        wsiScore   = score.wsi.requiredAt(slotIndex, "wsi"),
        colorBand  = score.tier.requiredAt(slotIndex, "tier").name,
        startLat   = seg.startLat,
        startLng   = seg.startLng,
        endLat     = seg.endLat,
        endLng     = seg.endLng,
        coordinates = seg.geometry.coordinates,
        components = toComponentsDto(score, slotIndex),
        factors    = score.factors.requiredAt(slotIndex, "factors"),
        slotIndex  = slotIndex,
    )

    private fun toComponentsDto(score: WsiScoreEntry, slotIndex: Int) = ComponentScoresDto(
        risk     = score.components.risk.requiredAt(slotIndex, "components.risk"),
        light    = score.components.light.requiredAt(slotIndex, "components.light"),
        activity = score.components.activity.requiredAt(slotIndex, "components.activity"),
        safezone = score.components.safezone.requiredAt(slotIndex, "components.safezone"),
    )

    // ── Bounding-box filter ───────────────────────────────────────────────────

    private fun nearbySegments(
        snapshot: AiDataSnapshot,
        lat: Double,
        lng: Double,
        radiusMeters: Int,
    ): List<Pair<SegmentFeature, WsiScoreEntry>> {
        val latDelta = radiusMeters / METERS_PER_DEGREE_LAT
        val lngDelta = radiusMeters / (METERS_PER_DEGREE_LAT * cos(lat * PI / 180.0))

        val minLat = lat - latDelta; val maxLat = lat + latDelta
        val minLng = lng - lngDelta; val maxLng = lng + lngDelta

        return snapshot.segments.values
            .asSequence()
            .filter { seg ->
                seg.startLat in minLat..maxLat && seg.startLng in minLng..maxLng
            }
            .map { seg ->
                val score = requireNotNull(snapshot.scores[seg.properties.segmentId]) {
                    "Missing WSI score for segment '${seg.properties.segmentId}'"
                }
                seg to score
            }
            .take(MAX_SEGMENTS_PER_RESPONSE)
            .toList()
    }

    // ── Slot resolution ───────────────────────────────────────────────────────

    /**
     * Derives the current slot index from LA local time and [AiDataSnapshot.meta.slots].
     *
     * Beta weights and tier thresholds live in [snapshot.meta] — read at call time,
     * never as compile-time constants.
     */
    private fun currentSlotIndex(snapshot: AiDataSnapshot): Int {
        val now = ZonedDateTime.now(LA_ZONE)
        return requireNotNull(findSlotIndex(snapshot.meta.slots, now.dayOfWeek, now.hour)) {
            "No AI slot matches current America/Los_Angeles time"
        }
    }
}

private fun <T> List<T>.requiredAt(slotIndex: Int, field: String): T {
    require(slotIndex in indices) { "$field has no value for slotIndex=$slotIndex" }
    return this[slotIndex]
}
