package com.safesoundla.halo.presentation.admin

import com.safesoundla.halo.infrastructure.aidata.AiDataLoader
import com.safesoundla.halo.infrastructure.aidata.AiDataStore
import com.safesoundla.halo.presentation.common.ApiResponse
import org.slf4j.LoggerFactory
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import kotlin.system.measureTimeMillis

/**
 * Admin endpoints — must be protected by network policy or auth before external deployment.
 *
 * ### Hot-reload strategy (Requirement 4)
 * This project uses **(a) restart-only** as the default reload mechanism: the AI batch
 * pipeline deploys new files and the service is restarted (e.g. via Docker or systemd).
 *
 * This endpoint provides **(c) manual reload** as an optional convenience for dev/ops:
 * - Useful during development when the AI team pushes new scores frequently.
 * - Does NOT require a restart; swaps the in-memory snapshot atomically.
 * - Safe to call mid-traffic — [AiDataStore] uses [AtomicReference] internally.
 *
 * The [wsi_version] field in the response lets callers verify which data is now live.
 *
 * TODO: Before production, add authentication (e.g. Bearer token or IP allowlist).
 */
@RestController
@RequestMapping("/admin")
class AdminController(
    private val loader: AiDataLoader,
    private val store: AiDataStore,
) {

    private val log = LoggerFactory.getLogger(AdminController::class.java)

    @PostMapping("/reload")
    fun reload(): ApiResponse<ReloadResult> {
        log.info("[ADMIN] Manual AI data reload triggered")
        val snapshot = loader.load()
        store.set(snapshot)
        val result = ReloadResult(
            wsiVersion     = snapshot.meta.wsiVersion,
            modelVersion   = snapshot.meta.modelVersion,
            segmentsLoaded = snapshot.segments.size,
            scoresLoaded   = snapshot.scores.size,
            safeZonesLoaded = snapshot.safeZones.size,
            slotCount      = snapshot.meta.slots.size,
        )
        log.info("[ADMIN] Reload complete — $result")
        return ApiResponse.ok(result)
    }
}

data class ReloadResult(
    val wsiVersion: String,
    val modelVersion: String,
    val segmentsLoaded: Int,
    val scoresLoaded: Int,
    val safeZonesLoaded: Int,
    val slotCount: Int,
)
