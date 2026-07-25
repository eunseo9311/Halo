package com.safesoundla.halo.application.incident

import com.safesoundla.halo.infrastructure.incident.IncidentRecord
import com.safesoundla.halo.infrastructure.incident.IncidentStore
import org.junit.jupiter.api.Test
import java.time.LocalDateTime
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class IncidentServiceTest {
    @Test
    fun `filters sorts limits and applies privacy-safe mapping`() {
        val store = IncidentStore()
        val records = (0..100).map { index ->
            incident(
                id = "incident-${index.toString().padStart(3, '0')}",
                description = if (index == 0) {
                    "ROBBERY"
                } else {
                    "ASSAULT WITH DEADLY WEAPON, AGGRAVATED ASSAULT"
                },
                latitude = 34.0 + index * 0.00001,
                longitude = -118.0,
            )
        } + incident("outside", "SECRET RAW DESCRIPTION", 35.0, -118.0)
        store.set(records)

        val results = IncidentService(store).findNearby(34.0, -118.0, 1_500)

        assertEquals(100, results.size)
        assertEquals("incident-000", results.first().incidentId)
        assertEquals("robbery", results.first().category)
        assertEquals("Street or sidewalk", results.first().locationType)
        assertEquals(34.0, results.first().latitude)
        assertFalse(results.any { it.incidentId == "outside" })
    }

    @Test
    fun `unknown descriptions use generic canned content and sanitized labels`() {
        val store = IncidentStore()
        store.set(
            listOf(
                incident(
                    "unknown",
                    "PRIVATE SOURCE NARRATIVE",
                    34.12349,
                    -118.98751,
                    areaName = "Central<script>\u0000",
                    premise = "unlisted private place",
                ),
            ),
        )

        val result = IncidentService(store).findNearby(34.12349, -118.98751, 500).single()

        assertEquals("other", result.category)
        assertEquals("⚠️", result.emoji)
        assertFalse(result.description.contains("PRIVATE"))
        assertEquals("Other location", result.locationType)
        assertEquals("Centralscript", result.areaName)
        assertEquals(34.123, result.latitude)
        assertEquals(-118.988, result.longitude)
        assertEquals("2026-07-25T12:00-07:00", result.occurredAt)
    }

    @Test
    fun `validates query ranges`() {
        val service = IncidentService(IncidentStore())
        assertTrue(runCatching { service.findNearby(91.0, 0.0, 1_500) }.isFailure)
        assertTrue(runCatching { service.findNearby(0.0, 181.0, 1_500) }.isFailure)
        assertTrue(runCatching { service.findNearby(0.0, 0.0, 499) }.isFailure)
        assertTrue(runCatching { service.findNearby(0.0, 0.0, 10_001) }.isFailure)
    }

    @Test
    fun `sub-grid query changes cannot reveal a more precise incident location`() {
        val store = IncidentStore()
        store.set(listOf(incident("opaque", "ROBBERY", 34.12349, -118.98751)))
        val service = IncidentService(store)

        val first = service.findNearby(34.12301, -118.98701, 500)
        val second = service.findNearby(34.12349, -118.98749, 500)

        assertEquals(first.map { it.incidentId }, second.map { it.incidentId })
    }

    private fun incident(
        id: String,
        description: String,
        latitude: Double,
        longitude: Double,
        areaName: String = "Central",
        premise: String = "SIDEWALK",
    ) = IncidentRecord(
        incidentId = id,
        crimeDescription = description,
        areaName = areaName,
        occurredAt = LocalDateTime.of(2026, 7, 25, 14, 45),
        latitude = latitude,
        longitude = longitude,
        premise = premise,
    )
}
