package com.safesoundla.halo.infrastructure.aidata

import org.springframework.stereotype.Component
import java.util.concurrent.atomic.AtomicReference

/**
 * Thread-safe holder for the current [AiDataSnapshot].
 *
 * Uses [AtomicReference] so that /admin/reload can swap in a new snapshot
 * without locking read-path callers.
 */
@Component
class AiDataStore {

    private val ref = AtomicReference<AiDataSnapshot>()

    /** Returns the current snapshot, or throws if not yet loaded. */
    fun get(): AiDataSnapshot =
        ref.get() ?: error("AI data not loaded yet — server may still be starting up")

    /** Atomically replaces the current snapshot. */
    fun set(snapshot: AiDataSnapshot) {
        ref.set(snapshot)
    }
}
