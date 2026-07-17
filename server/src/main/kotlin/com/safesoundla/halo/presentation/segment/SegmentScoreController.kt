package com.safesoundla.halo.presentation.segment

import com.safesoundla.halo.presentation.common.ApiResponse
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/v1/segments")
class SegmentScoreController {

    /**
     * GET /api/v1/segments/scores?lat=...&lng=...&radius=500
     *
     * Returns dummy WSI scores for street segments near a coordinate.
     * Replace dummy data with real DB queries once Python pipeline writes scores.
     */
    @GetMapping("/scores")
    fun getSegmentScores(
        @RequestParam lat: Double,
        @RequestParam lng: Double,
        @RequestParam(defaultValue = "500") radiusMeters: Int,
    ): ApiResponse<List<SegmentScoreResponse>> {
        // TODO: replace with real repository query
        val dummySegments = listOf(
            SegmentScoreResponse(
                segmentId = "seg-001",
                wsiScore = 0.82,
                confidence = 0.9,
                colorBand = ColorBand.GREEN,
                startLat = lat + 0.001, startLng = lng,
                endLat = lat + 0.002, endLng = lng + 0.001,
            ),
            SegmentScoreResponse(
                segmentId = "seg-002",
                wsiScore = 0.45,
                confidence = 0.6,
                colorBand = ColorBand.YELLOW,
                startLat = lat + 0.002, startLng = lng + 0.001,
                endLat = lat + 0.003, endLng = lng + 0.002,
            ),
            SegmentScoreResponse(
                segmentId = "seg-003",
                wsiScore = 0.21,
                confidence = 0.4,
                colorBand = ColorBand.RED,
                startLat = lat + 0.003, startLng = lng + 0.002,
                endLat = lat + 0.004, endLng = lng + 0.003,
            ),
        )
        return ApiResponse.ok(dummySegments)
    }
}

data class SegmentScoreResponse(
    val segmentId: String,
    /** WSI score 0.0–1.0 */
    val wsiScore: Double,
    /** Data confidence 0.0–1.0 */
    val confidence: Double,
    /** Visual color band derived from wsiScore */
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
