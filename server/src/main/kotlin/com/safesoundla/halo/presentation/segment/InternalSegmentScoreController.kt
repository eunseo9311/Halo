package com.safesoundla.halo.presentation.segment

import com.safesoundla.halo.application.segment.AiSegmentService
import com.safesoundla.halo.presentation.common.ApiResponse
import org.slf4j.LoggerFactory
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController

/**
 * Sensitive factor endpoint. The controller bean does not exist unless an operator
 * explicitly opts in with `halo.internal-api.segment-scores-enabled=true`.
 *
 * Enabling this endpoint does not replace gateway authentication or a network allowlist.
 */
@RestController
@RequestMapping("/api/v1/segments")
@ConditionalOnProperty(
    prefix = "halo.internal-api",
    name = ["segment-scores-enabled"],
    havingValue = "true",
    matchIfMissing = false,
)
class InternalSegmentScoreController(
    private val service: AiSegmentService,
) {
    private val log = LoggerFactory.getLogger(InternalSegmentScoreController::class.java)

    init {
        log.warn(
            "[INTERNAL-API] Sensitive segment score endpoint is ENABLED; " +
                "restrict it with authentication and a network allowlist",
        )
    }

    @GetMapping("/scores/internal")
    fun getSegmentScoresInternal(
        @RequestParam lat: Double,
        @RequestParam lng: Double,
        @RequestParam(defaultValue = "200") radiusMeters: Int,
        @RequestParam(required = false) slotIndex: Int?,
    ): ApiResponse<List<SegmentScoreInternalResponse>> =
        ApiResponse.ok(service.findNearbyInternal(lat, lng, radiusMeters, slotIndex))
}

/**
 * Internal/B2G response DTO. Unlike [SegmentScoreResponse], factors are unfiltered.
 */
data class SegmentScoreInternalResponse(
    val segmentId: String,
    val wsiScore: Double,
    val colorBand: String,
    val startLat: Double,
    val startLng: Double,
    val endLat: Double,
    val endLng: Double,
    val coordinates: List<List<Double>>? = null,
    val components: ComponentScoresDto,
    /** Full factor list. This DTO must never be returned by a public controller. */
    val factors: List<String>,
    val slotIndex: Int,
)
