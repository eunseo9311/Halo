package com.safesoundla.halo.presentation.routing

import com.safesoundla.halo.application.routing.RouteService
import com.safesoundla.halo.presentation.common.ApiResponse
import jakarta.validation.Valid
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1")
class RouteController(private val routeService: RouteService) {

    /**
     * Find safest and shortest pedestrian routes between two coordinates.
     *
     * Both routes use A* on the in-memory JGraphT graph built from segments.geojson:
     * - **safestRoute**: edge cost = `length_m × (1 + (1 − wsi[slot]) × safetyWeight)`
     * - **shortestRoute**: edge cost = `length_m` (pure physical distance)
     *
     * The time slot is resolved from the optional [dayOfWeek]/[hour] request fields,
     * or from the current LA local time if both are absent.
     *
     * `high_incident` is never present in response segment factors.
     */
    @PostMapping("/route")
    fun route(@Valid @RequestBody request: RouteRequest): ApiResponse<RouteResponse> =
        ApiResponse.ok(routeService.findRoutes(request))
}
