package com.safesoundla.halo.presentation.segment

import com.safesoundla.halo.application.segment.SegmentScoreService
import com.safesoundla.halo.domain.segment.SegmentScore
import com.safesoundla.halo.presentation.common.ApiResponse
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/v1/segments")
class SegmentScoreController(
    private val service: SegmentScoreService,
) {

    /**
     * GET /api/v1/segments/scores?lat=&lng=&radiusMeters=500
     *
     * Returns real WSI scores from the DB for segments near the given coordinate.
     */
    @GetMapping("/scores")
    fun getSegmentScores(
        @RequestParam lat: Double,
        @RequestParam lng: Double,
        @RequestParam(defaultValue = "500") radiusMeters: Int,
    ): ApiResponse<List<SegmentScoreResponse>> {
        val segments = service.findNearby(lat, lng, radiusMeters).map { it.toResponse() }
        return ApiResponse.ok(segments)
    }
}

// ── Response DTO ──────────────────────────────────────────────────────────────

data class SegmentScoreResponse(
    val segmentId: String,
    val wsiScore: Double,
    val confidence: Double,
    val colorBand: ColorBand,
    val startLat: Double,
    val startLng: Double,
    val endLat: Double,
    val endLng: Double,
)

enum class ColorBand {
    /** wsiScore >= 0.7 */
    GREEN,
    /** wsiScore 0.4–0.69 */
    YELLOW,
    /** wsiScore < 0.4 */
    RED,
}

private fun SegmentScore.toResponse() = SegmentScoreResponse(
    segmentId = segmentId,
    wsiScore = wsiScore,
    confidence = confidence,
    colorBand = when {
        wsiScore >= 0.7 -> ColorBand.GREEN
        wsiScore >= 0.4 -> ColorBand.YELLOW
        else -> ColorBand.RED
    },
    startLat = startLat,
    startLng = startLng,
    endLat = endLat,
    endLng = endLng,
)
