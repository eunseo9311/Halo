package com.safesoundla.halo.application.segment

import com.safesoundla.halo.infrastructure.aidata.model.SlotDefinition
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import java.time.DayOfWeek
import kotlin.test.assertEquals
import kotlin.test.assertNull

/**
 * Unit tests for [findSlotIndex] and [dowGroupOf].
 *
 * Pure Kotlin — no Spring context, no DB.
 */
class SlotLookupTest {

    // 4-slot fixture that mirrors the placeholder wsi_scores.json
    private val slots = listOf(
        SlotDefinition(index = 0, dowGroup = "weekday",  hourStart = 0,  hourEnd = 12, label = "weekday_day"),
        SlotDefinition(index = 1, dowGroup = "weekday",  hourStart = 12, hourEnd = 24, label = "weekday_night"),
        SlotDefinition(index = 2, dowGroup = "saturday", hourStart = 0,  hourEnd = 12, label = "saturday_day"),
        SlotDefinition(index = 3, dowGroup = "saturday", hourStart = 12, hourEnd = 24, label = "saturday_night"),
    )

    // ── dowGroupOf ────────────────────────────────────────────────────────────

    @Test
    fun `weekdays map to weekday group`() {
        listOf(DayOfWeek.MONDAY, DayOfWeek.TUESDAY, DayOfWeek.WEDNESDAY,
               DayOfWeek.THURSDAY, DayOfWeek.FRIDAY).forEach { dow ->
            assertEquals("weekday", dowGroupOf(dow), "Expected weekday for $dow")
        }
    }

    @Test
    fun `saturday maps to saturday group`() {
        assertEquals("saturday", dowGroupOf(DayOfWeek.SATURDAY))
    }

    @Test
    fun `sunday maps to sunday group`() {
        assertEquals("sunday", dowGroupOf(DayOfWeek.SUNDAY))
    }

    // ── findSlotIndex — happy paths ───────────────────────────────────────────

    @Test
    fun `weekday morning hour resolves to slot 0`() {
        assertEquals(0, findSlotIndex(slots, DayOfWeek.MONDAY, 9))
    }

    @Test
    fun `weekday midnight (hour 0) resolves to slot 0`() {
        assertEquals(0, findSlotIndex(slots, DayOfWeek.FRIDAY, 0))
    }

    @Test
    fun `weekday noon (hour 12) resolves to slot 1`() {
        // hourEnd=12 is exclusive, so hour=12 falls into the night slot
        assertEquals(1, findSlotIndex(slots, DayOfWeek.WEDNESDAY, 12))
    }

    @Test
    fun `weekday hour 23 resolves to slot 1`() {
        assertEquals(1, findSlotIndex(slots, DayOfWeek.TUESDAY, 23))
    }

    @Test
    fun `saturday morning resolves to slot 2`() {
        assertEquals(2, findSlotIndex(slots, DayOfWeek.SATURDAY, 7))
    }

    @Test
    fun `saturday evening resolves to slot 3`() {
        assertEquals(3, findSlotIndex(slots, DayOfWeek.SATURDAY, 20))
    }

    // ── findSlotIndex — no match ──────────────────────────────────────────────

    @Test
    fun `returns null when no slot covers the combination`() {
        // Sunday is not covered by our 4-slot fixture
        assertNull(findSlotIndex(slots, DayOfWeek.SUNDAY, 10))
    }

    // ── No magic number arithmetic ────────────────────────────────────────────

    @Test
    fun `slot lookup works correctly after slot order is shuffled`() {
        // Reverses the list to prove we don't rely on array-position arithmetic
        val shuffled = slots.reversed()
        assertEquals(0, findSlotIndex(shuffled, DayOfWeek.MONDAY, 9))
        assertEquals(1, findSlotIndex(shuffled, DayOfWeek.MONDAY, 18))
        assertEquals(2, findSlotIndex(shuffled, DayOfWeek.SATURDAY, 5))
        assertEquals(3, findSlotIndex(shuffled, DayOfWeek.SATURDAY, 22))
    }

    @Test
    fun `slot lookup works with 32-slot schema (dense weekday coverage)`() {
        // Simulate 32 slots: 8 slots per dow_group × 3 groups + leftover sunday (8 slots)
        val thirtyTwo = (0 until 24 step 3).mapIndexed { i, h ->
            SlotDefinition(index = i, dowGroup = "weekday", hourStart = h,
                hourEnd = if (h + 3 >= 24) 24 else h + 3, label = "w$i")
        } // 8 weekday slots covering 0–24

        // hour=15 should be in slot covering [15,18)
        val result = findSlotIndex(thirtyTwo, DayOfWeek.TUESDAY, 15)
        assertEquals(5, result) // slot index 5 covers hours 15–17
    }
}
