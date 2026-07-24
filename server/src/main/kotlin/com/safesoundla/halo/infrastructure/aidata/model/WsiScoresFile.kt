package com.safesoundla.halo.infrastructure.aidata.model

import com.fasterxml.jackson.annotation.JsonProperty
import com.fasterxml.jackson.core.JsonParser
import com.fasterxml.jackson.databind.DeserializationContext
import com.fasterxml.jackson.databind.JsonDeserializer
import com.fasterxml.jackson.databind.JsonNode
import com.fasterxml.jackson.databind.annotation.JsonDeserialize

/** Root object of wsi_scores.json */
data class WsiScoresFile(
    val meta: WsiMeta,
    val scores: Map<String, WsiScoreEntry>,
)

data class WsiMeta(
    @JsonProperty("wsi_version")    val wsiVersion: String,
    @JsonProperty("model_version")  val modelVersion: String,
    val beta: BetaWeights,
    @JsonProperty("tier_thresholds") val tierThresholds: TierThresholds,
    @JsonProperty("slot_count") val slotCount: Int,
    @JsonProperty("data_vintage") val dataVintage: String,
    @JsonProperty("district_id") val districtId: String,
    @JsonProperty("source_period") val sourcePeriod: String,
    val slots: List<SlotDefinition>,
)

data class BetaWeights(
    val risk: Double,
    val light: Double,
    val activity: Double,
    val safezone: Double,
)

@JsonDeserialize(using = TierThresholdsDeserializer::class)
data class TierThresholds(
    val green: Double,
    val yellow: Double,
)

class TierThresholdsDeserializer : JsonDeserializer<TierThresholds>() {
    override fun deserialize(parser: JsonParser, context: DeserializationContext): TierThresholds {
        val node = parser.codec.readTree<JsonNode>(parser)
        if (!node.isArray || node.size() != 2 || !node.all(JsonNode::isNumber)) {
            return context.reportInputMismatch(
                TierThresholds::class.java,
                "tier_thresholds must be a two-number array [yellow, green]",
            )
        }
        return TierThresholds(yellow = node[0].doubleValue(), green = node[1].doubleValue())
    }
}

/**
 * One time-slot definition from meta.slots.
 *
 * [hourStart, hourEnd) is a half-open interval (hourEnd is exclusive).
 * e.g. hourStart=18, hourEnd=24 covers 18:00–23:59.
 *
 * [dowGroup] is one of "weekday", "fri", "sat", or "sun".
 * The mapping from Java DayOfWeek → dowGroup lives in [com.safesoundla.halo.application.segment.findSlotIndex].
 */
data class SlotDefinition(
    val index: Int,
    @JsonProperty("dow_group")  val dowGroup: String,
    @JsonProperty("hour_start") val hourStart: Int,
    @JsonProperty("hour_end")   val hourEnd: Int,
)

/**
 * Per-segment score arrays.
 * All arrays have the same length as [WsiMeta.slots].
 * Index i corresponds to [SlotDefinition.index] == i.
 */
data class WsiScoreEntry(
    /** Overall WSI score per slot, 0.0–1.0 */
    val wsi: List<Double>,

    /** Numeric tier code per slot: 0=RED, 1=YELLOW, 2=GREEN. */
    val tier: List<TierCode>,

    val components: ComponentScores,

    /**
     * Factor codes per slot.
     * Contains "high_incident" among others — MUST be filtered before public serialization.
     */
    val factors: List<List<String>>,
)

data class ComponentScores(
    val risk: List<Double>,
    val light: List<Double>,
    val activity: List<Double>,
    val safezone: List<Double>,
)

@JsonDeserialize(using = TierCodeDeserializer::class)
enum class TierCode {
    RED,
    YELLOW,
    GREEN;

    companion object {
        @JvmStatic
        fun fromCode(code: Int): TierCode = when (code) {
            0 -> RED
            1 -> YELLOW
            2 -> GREEN
            else -> throw IllegalArgumentException("Unknown tier code: $code")
        }
    }
}

class TierCodeDeserializer : JsonDeserializer<TierCode>() {
    override fun deserialize(parser: JsonParser, context: DeserializationContext): TierCode {
        val node = parser.codec.readTree<JsonNode>(parser)
        if (!node.isIntegralNumber || !node.canConvertToInt()) {
            return context.reportInputMismatch(
                TierCode::class.java,
                "tier must be an integer code 0, 1, or 2",
            )
        }
        return try {
            TierCode.fromCode(node.intValue())
        } catch (error: IllegalArgumentException) {
            context.reportInputMismatch(
                TierCode::class.java,
                error.message ?: "Unknown tier code",
            )
        }
    }
}
