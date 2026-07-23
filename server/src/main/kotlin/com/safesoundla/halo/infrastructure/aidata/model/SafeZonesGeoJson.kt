package com.safesoundla.halo.infrastructure.aidata.model

import com.fasterxml.jackson.annotation.JsonProperty

/** Root object of safezones.geojson */
data class SafeZonesGeoJson(
    val type: String,
    val features: List<SafeZoneFeature>,
)

data class SafeZoneFeature(
    val type: String,
    val geometry: PointGeometry,
    val properties: SafeZoneProperties,
) {
    val lat: Double get() = geometry.coordinates[1]
    val lng: Double get() = geometry.coordinates[0]
}

data class PointGeometry(
    val type: String,
    /** GeoJSON order: [lng, lat] */
    val coordinates: List<Double>,
)

data class SafeZoneProperties(
    @JsonProperty("safezone_id")      val safezoneId: String,
    val name: String,
    val category: String,
    @JsonProperty("nearby_segments")  val nearbySegments: List<String>,
)
