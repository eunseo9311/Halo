package com.safesoundla.halo.presentation.safezone

import com.safesoundla.halo.application.safezone.SafeZoneService
import com.safesoundla.halo.presentation.common.ApiResponse
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1/safezones")
class SafeZoneController(private val service: SafeZoneService) {
    @GetMapping
    fun getNearby(
        @RequestParam lat: Double,
        @RequestParam lng: Double,
        @RequestParam(defaultValue = "1000") radiusMeters: Int,
    ): ApiResponse<List<SafeZoneResponse>> =
        ApiResponse.ok(service.findNearby(lat, lng, radiusMeters))
}

/**
 * Public safe-zone contract. Influence segment IDs remain internal to the ingest snapshot.
 * No radius is exposed because the source data does not define one.
 */
data class SafeZoneResponse(
    val poiId: String,
    val category: String,
    val name: String,
    val latitude: Double,
    val longitude: Double,
    val open24h: Boolean,
)
