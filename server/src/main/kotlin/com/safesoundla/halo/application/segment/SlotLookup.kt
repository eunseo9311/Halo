package com.safesoundla.halo.application.segment

import com.safesoundla.halo.infrastructure.aidata.model.SlotDefinition
import java.time.DayOfWeek

/**
 * Looks up the [SlotDefinition.index] that matches a given day-of-week + hour combination.
 *
 * ### Why a lookup function instead of arithmetic?
 * The AI/DS team may change the slot count, dow_group names, or hour boundaries at any time.
 * We must NOT bake in formulas like `dow_group_idx × 8 + hour_slot_idx`.
 * Instead, we search [slots] by matching the dow_group label and hour range.
 *
 * ### dow_group convention
 * [dowGroupOf] maps Java's [DayOfWeek] to the three dow_group string labels that the AI team
 * currently uses.  If the AI team adds a new grouping (e.g. "holiday"), only this mapping
 * needs updating — the rest of the code is unaffected.
 *
 * @param slots   The [SlotDefinition] list from the loaded wsi_scores.json meta.
 * @param dayOfWeek  Java DayOfWeek (MONDAY … SUNDAY).
 * @param hour    Hour of day in [0, 23].
 * @return        The matching slot index, or `null` if no slot covers this combination.
 */
fun findSlotIndex(slots: List<SlotDefinition>, dayOfWeek: DayOfWeek, hour: Int): Int? {
    val dowGroup = dowGroupOf(dayOfWeek)
    return slots.firstOrNull { slot ->
        slot.dowGroup == dowGroup && hour >= slot.hourStart && hour < slot.hourEnd
    }?.index
}

/**
 * Maps a Java [DayOfWeek] to the AI team's dow_group label.
 *
 * Current contract: "weekday" | "saturday" | "sunday".
 * Change only this function if the AI team redefines the groupings.
 */
fun dowGroupOf(dayOfWeek: DayOfWeek): String = when (dayOfWeek) {
    DayOfWeek.SATURDAY -> "saturday"
    DayOfWeek.SUNDAY   -> "sunday"
    else               -> "weekday"
}
