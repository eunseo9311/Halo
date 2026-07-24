package com.safesoundla.halo.application.segment

import com.safesoundla.halo.infrastructure.aidata.model.SlotDefinition
import org.junit.jupiter.api.Test
import java.time.DayOfWeek
import kotlin.test.assertEquals
import kotlin.test.assertNull

class SlotLookupTest {
    private val groups = listOf("weekday", "fri", "sat", "sun")
    private val slots = groups.flatMapIndexed { groupIndex, group ->
        (0 until 8).map { hourIndex ->
            SlotDefinition(
                index = groupIndex * 8 + hourIndex,
                dowGroup = group,
                hourStart = hourIndex * 3,
                hourEnd = hourIndex * 3 + 3,
            )
        }
    }

    @Test
    fun `days map to the four contracted groups`() {
        listOf(
            DayOfWeek.MONDAY,
            DayOfWeek.TUESDAY,
            DayOfWeek.WEDNESDAY,
            DayOfWeek.THURSDAY,
        ).forEach { assertEquals("weekday", dowGroupOf(it)) }
        assertEquals("fri", dowGroupOf(DayOfWeek.FRIDAY))
        assertEquals("sat", dowGroupOf(DayOfWeek.SATURDAY))
        assertEquals("sun", dowGroupOf(DayOfWeek.SUNDAY))
    }

    @Test
    fun `slot formula boundaries resolve from metadata`() {
        assertEquals(0, findSlotIndex(slots, DayOfWeek.MONDAY, 0))
        assertEquals(1, findSlotIndex(slots, DayOfWeek.THURSDAY, 3))
        assertEquals(7, findSlotIndex(slots, DayOfWeek.MONDAY, 21))
        assertEquals(8, findSlotIndex(slots, DayOfWeek.FRIDAY, 0))
        assertEquals(16, findSlotIndex(slots, DayOfWeek.SATURDAY, 0))
        assertEquals(31, findSlotIndex(slots, DayOfWeek.SUNDAY, 23))
    }

    @Test
    fun `24 is outside the valid hour domain`() {
        assertNull(findSlotIndex(slots, DayOfWeek.MONDAY, 24))
    }

    @Test
    fun `lookup uses slot metadata rather than list position`() {
        assertEquals(21, findSlotIndex(slots.reversed(), DayOfWeek.SATURDAY, 15))
    }
}
