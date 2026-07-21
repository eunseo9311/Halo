package com.safesoundla.halo.presentation.segment

import com.safesoundla.halo.application.segment.AiSegmentService
import com.safesoundla.halo.presentation.common.ApiResponse
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/v1/segments")
class SegmentScoreController(
    private val service: AiSegmentService,
) {

    /**
     * GET /api/v1/segments/scores?lat=&lng=&radiusMeters=&slotIndex=
     *
     * Returns AI-scored segments near the given coordinate for the current (or specified) time slot.
     * Response uses [SegmentScoreResponse] — [high_incident] factor is NEVER included.
     *
     * [slotIndex] is optional; omit to auto-resolve from current LA local time.
     */
    @GetMapping("/scores")
    fun getSegmentScores(
        @RequestParam lat: Double,
        @RequestParam lng: Double,
        @RequestParam(defaultValue = "200") radiusMeters: Int,
        @RequestParam(required = false) slotIndex: Int?,
    ): ApiResponse<List<SegmentScoreResponse>> =
        ApiResponse.ok(service.findNearbyPublic(lat, lng, radiusMeters, slotIndex))

    /**
     * GET /api/v1/segments/scores/internal?lat=&lng=&radiusMeters=&slotIndex=
     *
     * Internal/B2G endpoint — response includes the full [factors] array (with high_incident).
     * DO NOT expose this path via the public API gateway.
     *
     * TODO: Protect with an internal auth header or network policy before external deployment.
     */
    @GetMapping("/scores/internal")
    fun getSegmentScoresInternal(
        @RequestParam lat: Double,
        @RequestParam lng: Double,
        @RequestParam(defaultValue = "200") radiusMeters: Int,
        @RequestParam(required = false) slotIndex: Int?,
    ): ApiResponse<List<SegmentScoreInternalResponse>> =
        ApiResponse.ok(service.findNearbyInternal(lat, lng, radiusMeters, slotIndex))
}

// ── DTOs ─────────────────────────────────────────────────────────────────────

/**
 * Public-facing response DTO.
 *
 * [factors] has `high_incident` pre-removed by [AiSegmentService.toPublicResponse].
 * Field names [wsiScore] and [colorBand] kept for Flutter backward compatibility.
 */
data class SegmentScoreResponse(
    val segmentId: String,
    /** WSI score for [slotIndex], 0.0–1.0. */
    val wsiScore: Double,
    /** Tier label: "GREEN" | "YELLOW" | "RED". */
    val colorBand: String,
    val startLat: Double,
    val startLng: Double,
    val endLat: Double,
    val endLng: Double,
    val components: ComponentScoresDto,
    /** Factor codes for this slot — `high_incident` is NEVER present. */
    val factors: List<String>,
    val slotIndex: Int,
)

/**
 * Internal/B2G response DTO — identical to [SegmentScoreResponse] but [factors] is UNFILTERED.
 * Includes `high_incident` and any other sensitive codes.
 * Must only be served via the /internal endpoint, never through the public gateway.
 */
data class SegmentScoreInternalResponse(
    val segmentId: String,
    val wsiScore: Double,
    val colorBand: String,
    val startLat: Double,
    val startLng: Double,
    val endLat: Double,
    val endLng: Double,
    val components: ComponentScoresDto,
    /** Full, unfiltered factor list — includes high_incident. */
    val factors: List<String>,
    val slotIndex: Int,
)

data class ComponentScoresDto(
    val risk: Double,
    val light: Double,
    val comfort: Double,
)
