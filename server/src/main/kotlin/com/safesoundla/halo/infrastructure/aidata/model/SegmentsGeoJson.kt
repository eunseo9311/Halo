package com.safesoundla.halo.infrastructure.aidata.model

import com.fasterxml.jackson.core.JsonParser
import com.fasterxml.jackson.databind.DeserializationContext
import com.fasterxml.jackson.databind.JsonDeserializer
import com.fasterxml.jackson.databind.JsonNode
import com.fasterxml.jackson.annotation.JsonProperty
import com.fasterxml.jackson.databind.annotation.JsonDeserialize

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
    val connects: List<Long>,
    @JsonProperty("length_m")    val lengthM: Double,
    @JsonProperty("district_id") val districtId: String?,
    @JsonProperty("subarea_id")  val subareaId: String?,
    @JsonProperty("street_name")
    @JsonDeserialize(using = StreetNamesDeserializer::class)
    val streetName: List<String>,
)

class StreetNamesDeserializer : JsonDeserializer<List<String>>() {
    override fun deserialize(parser: JsonParser, context: DeserializationContext): List<String> {
        val node = parser.codec.readTree<JsonNode>(parser)
        return when {
            node.isTextual -> listOf(node.textValue())
            node.isArray && node.all(JsonNode::isTextual) -> node.map(JsonNode::textValue)
            else -> context.reportInputMismatch(
                List::class.java,
                "street_name must be null, a string, or an array of strings",
            )
        }
    }

    override fun getNullValue(context: DeserializationContext): List<String> = emptyList()
}
