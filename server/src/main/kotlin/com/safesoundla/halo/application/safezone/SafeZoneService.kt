package com.safesoundla.halo.application.safezone

import com.safesoundla.halo.infrastructure.aidata.AiDataStore
import com.safesoundla.halo.presentation.safezone.SafeZoneResponse
import org.springframework.stereotype.Service
import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

private const val EARTH_RADIUS_METERS = 6_371_000.0
private const val MAX_SAFEZONES_PER_RESPONSE = 200

@Service
class SafeZoneService(private val store: AiDataStore) {
    fun findNearby(lat: Double, lng: Double, radiusMeters: Int): List<SafeZoneResponse> {
        require(lat.isFinite() && lat in -90.0..90.0) { "lat must be finite and within [-90, 90]" }
        require(lng.isFinite() && lng in -180.0..180.0) { "lng must be finite and within [-180, 180]" }
        require(radiusMeters in 1..50_000) { "radiusMeters must be within [1, 50000]" }

        return store.get().safeZones.asSequence()
            .map { zone ->
                zone to haversineMeters(lat, lng, zone.lat, zone.lng)
            }
            .filter { (_, distance) -> distance <= radiusMeters }
            .sortedBy { (_, distance) -> distance }
            .take(MAX_SAFEZONES_PER_RESPONSE)
            .map { (zone, _) ->
                SafeZoneResponse(
                    poiId = zone.properties.poiId,
                    category = zone.properties.category.code,
                    name = zone.properties.name,
                    latitude = zone.lat,
                    longitude = zone.lng,
                    open24h = zone.properties.open24h,
                )
            }
            .toList()
    }
}

private fun haversineMeters(lat1: Double, lng1: Double, lat2: Double, lng2: Double): Double {
    val dLat = Math.toRadians(lat2 - lat1)
    val dLng = Math.toRadians(lng2 - lng1)
    val a = sin(dLat / 2).pow(2) +
        cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) * sin(dLng / 2).pow(2)
    return EARTH_RADIUS_METERS * 2 * asin(sqrt(a))
}
