package com.safesoundla.halo.presentation.routing

data class RouteResponse(
    /** A* route minimising WSI-weighted edge cost (safest pedestrian path). */
    val safestRoute: RouteInfo,
    /** A* route minimising physical distance only. */
    val shortestRoute: RouteInfo,
)

data class RouteInfo(
    val segments: List<RouteSegmentDto>,
    /** Total physical length of this route in metres. */
    val totalDistance: Double,
    /** Average WSI across all scored segments; null if no score data is available. */
    val avgWsi: Double?,
)

data class RouteSegmentDto(
    val segmentId: String,
    val startLat: Double,
    val startLng: Double,
    val endLat: Double,
    val endLng: Double,
    val lengthM: Double,
    /** WSI score for the resolved time slot (0.0–1.0); null if no score data. */
    val wsiScore: Double?,
    /** Tier label for the resolved time slot: "GREEN" | "YELLOW" | "RED" | null. */
    val colorBand: String?,
    /**
     * Factor codes for this segment at the resolved slot.
     * `high_incident` is NEVER present — filtered server-side before serialisation.
     */
    val factors: List<String>,
)
