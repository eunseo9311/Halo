package com.safesoundla.halo.presentation.incident

import com.safesoundla.halo.application.incident.IncidentService
import com.safesoundla.halo.presentation.common.ApiResponse
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1/incidents")
class IncidentController(private val service: IncidentService) {
    @GetMapping
    fun getNearby(
        @RequestParam lat: Double,
        @RequestParam lng: Double,
        @RequestParam(defaultValue = "1500") radiusMeters: Int,
    ): ApiResponse<List<IncidentResponse>> =
        ApiResponse.ok(service.findNearby(lat, lng, radiusMeters))
}

data class IncidentResponse(
    val incidentId: String,
    val category: String,
    val emoji: String,
    val title: String,
    val description: String,
    val locationType: String,
    val areaName: String,
    val occurredAt: String,
    val latitude: Double,
    val longitude: Double,
)
