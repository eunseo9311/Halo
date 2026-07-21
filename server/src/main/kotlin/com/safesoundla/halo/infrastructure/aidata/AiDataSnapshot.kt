package com.safesoundla.halo.infrastructure.aidata

import com.safesoundla.halo.infrastructure.aidata.model.SafeZoneFeature
import com.safesoundla.halo.infrastructure.aidata.model.SegmentFeature
import com.safesoundla.halo.infrastructure.aidata.model.WsiMeta
import com.safesoundla.halo.infrastructure.aidata.model.WsiScoreEntry

/**
 * Immutable in-memory snapshot of all three AI data files plus the pre-built routing graph.
 *
 * Replaced atomically on /admin/reload — readers always see a fully-consistent version
 * where [segments], [scores], and [routeGraph] are all from the same load cycle.
 *
 * @param meta       Parsed meta block from wsi_scores.json (beta, thresholds, slots, version).
 * @param segments   segmentId → SegmentFeature (geometry + properties).
 * @param scores     segmentId → WsiScoreEntry (wsi/tier/components/factors arrays).
 * @param safeZones  All safe-zone POIs.
 * @param routeGraph JGraphT graph built from [segments] at load time; always the same version.
 */
data class AiDataSnapshot(
    val meta: WsiMeta,
    val segments: Map<String, SegmentFeature>,
    val scores: Map<String, WsiScoreEntry>,
    val safeZones: List<SafeZoneFeature>,
    val routeGraph: RouteGraph,
)
