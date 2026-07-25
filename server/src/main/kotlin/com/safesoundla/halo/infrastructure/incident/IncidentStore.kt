package com.safesoundla.halo.infrastructure.incident

import org.springframework.stereotype.Component
import java.util.concurrent.atomic.AtomicReference

@Component
class IncidentStore {
    private val incidents = AtomicReference<List<IncidentRecord>>(emptyList())

    fun get(): List<IncidentRecord> = incidents.get()

    fun set(records: List<IncidentRecord>) {
        incidents.set(records.toList())
    }
}
