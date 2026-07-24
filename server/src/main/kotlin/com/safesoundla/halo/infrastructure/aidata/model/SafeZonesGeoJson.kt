package com.safesoundla.halo.infrastructure.aidata.model

import com.fasterxml.jackson.annotation.JsonCreator
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
    @JsonProperty("poi_id")           val poiId: String,
    val name: String,
    val category: SafeZoneCategory,
    @JsonProperty("open_24h")         val open24h: Boolean,
    @JsonProperty("nearby_segments")  val nearbySegments: List<String>,
)

enum class SafeZoneCategory(val code: String) {
    POLICE("police"),
    FIRE_STATION("fire_station"),
    SCHOOL("school"),
    HOSPITAL_ER("hospital_er"),
    CONVENIENCE_24H("convenience_24h"),
    GAS_STATION("gas_station"),
    TRANSIT_STATION("transit_station");

    companion object {
        @JvmStatic
        @JsonCreator(mode = JsonCreator.Mode.DELEGATING)
        fun fromCode(code: String): SafeZoneCategory =
            entries.firstOrNull { it.code == code }
                ?: throw IllegalArgumentException("Unknown safe-zone category: $code")
    }
}
