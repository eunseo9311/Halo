package com.safesoundla.halo.infrastructure.aidata.model

import com.fasterxml.jackson.annotation.JsonProperty

/** Root object of segments.geojson */
data class SegmentsGeoJson(
    val type: String,
    val features: List<SegmentFeature>,
)

data class SegmentFeature(
    val type: String,
    val geometry: LineStringGeometry,
    val properties: SegmentProperties,
) {
    /** First coordinate [lng, lat] → lat */
    val startLat: Double get() = geometry.coordinates.first()[1]

    /** First coordinate [lng, lat] → lng */
    val startLng: Double get() = geometry.coordinates.first()[0]

    /** Last coordinate [lng, lat] → lat */
    val endLat: Double get() = geometry.coordinates.last()[1]

    /** Last coordinate [lng, lat] → lng */
    val endLng: Double get() = geometry.coordinates.last()[0]
}

data class LineStringGeometry(
    val type: String,
    /** GeoJSON order: [[lng, lat], [lng, lat], …] */
    val coordinates: List<List<Double>>,
)

data class SegmentProperties(
    @JsonProperty("segment_id")  val segmentId: String,
    val connects: List<String>,
    @JsonProperty("length_m")    val lengthM: Double,
    @JsonProperty("district_id") val districtId: String?,
    @JsonProperty("subarea_id")  val subareaId: String?,
)
