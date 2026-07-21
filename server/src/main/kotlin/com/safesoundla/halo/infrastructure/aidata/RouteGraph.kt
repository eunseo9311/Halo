package com.safesoundla.halo.infrastructure.aidata

import org.jgrapht.graph.DefaultWeightedEdge
import org.jgrapht.graph.WeightedMultigraph

/**
 * Pre-built routing graph derived from segments.geojson at snapshot load time.
 *
 * - **Vertices**: node IDs from `connects[]` arrays (e.g. "111", "222").
 * - **Edges**: one [DefaultWeightedEdge] per segment, base weight = `length_m`.
 * - **[edgeToSegmentId]**: reverse-lookup enabling dynamic per-slot WSI cost via `AsWeightedGraph`.
 * - **[nodeCoords]**: `DoubleArray(lat, lng)` per node, used by the A* Euclidean heuristic.
 *
 * This object is immutable after construction and replaced atomically together with
 * the rest of [AiDataSnapshot] on each data reload.
 */
class RouteGraph(
    val graph: WeightedMultigraph<String, DefaultWeightedEdge>,
    /** edge → segment_id for all edges in [graph]. */
    val edgeToSegmentId: Map<DefaultWeightedEdge, String>,
    /** node_id → [lat, lng] in degrees. */
    val nodeCoords: Map<String, DoubleArray>,
)
