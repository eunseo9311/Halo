package com.safesoundla.halo.infrastructure.incident

import java.time.LocalDateTime

data class IncidentRecord(
    val incidentId: String,
    val crimeDescription: String,
    val areaName: String,
    val occurredAt: LocalDateTime,
    val latitude: Double,
    val longitude: Double,
    val premise: String,
)
