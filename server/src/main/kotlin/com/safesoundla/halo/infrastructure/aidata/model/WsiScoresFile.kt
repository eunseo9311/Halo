package com.safesoundla.halo.infrastructure.aidata.model

import com.fasterxml.jackson.annotation.JsonProperty

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
    val slots: List<SlotDefinition>,
)

data class BetaWeights(
    val risk: Double,
    val light: Double,
    val comfort: Double,
)

data class TierThresholds(
    val green: Double,
    val yellow: Double,
)

/**
 * One time-slot definition from meta.slots.
 *
 * [hourStart, hourEnd) is a half-open interval (hourEnd is exclusive).
 * e.g. hourStart=18, hourEnd=24 covers 18:00–23:59.
 *
 * [dowGroup] is a string label from the AI team (e.g. "weekday", "saturday", "sunday").
 * The mapping from Java DayOfWeek → dowGroup lives in [com.safesoundla.halo.application.segment.findSlotIndex].
 */
data class SlotDefinition(
    val index: Int,
    @JsonProperty("dow_group")  val dowGroup: String,
    @JsonProperty("hour_start") val hourStart: Int,
    @JsonProperty("hour_end")   val hourEnd: Int,
    val label: String,
)

/**
 * Per-segment score arrays.
 * All arrays have the same length as [WsiMeta.slots].
 * Index i corresponds to [SlotDefinition.index] == i.
 */
data class WsiScoreEntry(
    /** Overall WSI score per slot, 0.0–1.0 */
    val wsi: List<Double>,

    /** Tier label per slot: "GREEN" | "YELLOW" | "RED" */
    val tier: List<String>,

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
    val comfort: List<Double>,
)
