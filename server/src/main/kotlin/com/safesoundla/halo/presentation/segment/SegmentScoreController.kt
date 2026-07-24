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
    /** Full GeoJSON LineString coordinates in [longitude, latitude] order. */
    val coordinates: List<List<Double>>? = null,
    val components: ComponentScoresDto,
    /** Factor codes for this slot — `high_incident` is NEVER present. */
    val factors: List<String>,
    val slotIndex: Int,
)

data class ComponentScoresDto(
    val risk: Double,
    val light: Double,
    val activity: Double,
    val safezone: Double,
)
