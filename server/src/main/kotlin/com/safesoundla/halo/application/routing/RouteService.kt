package com.safesoundla.halo.application.routing

import com.safesoundla.halo.application.segment.findSlotIndex
import com.safesoundla.halo.infrastructure.aidata.AiDataSnapshot
import com.safesoundla.halo.infrastructure.aidata.AiDataStore
import com.safesoundla.halo.infrastructure.aidata.RouteGraph
import com.safesoundla.halo.infrastructure.config.RoutingProperties
import com.safesoundla.halo.presentation.routing.RouteInfo
import com.safesoundla.halo.presentation.routing.RouteRequest
import com.safesoundla.halo.presentation.routing.RouteResponse
import com.safesoundla.halo.presentation.routing.RouteSegmentDto
import org.jgrapht.GraphPath
import org.jgrapht.alg.interfaces.AStarAdmissibleHeuristic
import org.jgrapht.alg.shortestpath.AStarShortestPath
import org.jgrapht.graph.AsWeightedGraph
import org.jgrapht.graph.DefaultWeightedEdge
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import java.time.DayOfWeek
import java.time.ZoneId
import java.time.ZonedDateTime
import kotlin.math.*

private const val HIGH_INCIDENT_FACTOR = "high_incident"
private val LA_ZONE = ZoneId.of("America/Los_Angeles")

@Service
class RouteService(
    private val store: AiDataStore,
    private val routingProps: RoutingProperties,
) {
    private val log = LoggerFactory.getLogger(RouteService::class.java)

    fun findRoutes(request: RouteRequest): RouteResponse {
        val snapshot   = store.get()
        val slotIndex  = resolveSlotIndex(snapshot, request.dayOfWeek, request.hour)
        val rg         = snapshot.routeGraph

        val fromNode = nearestNode(rg, request.fromLat, request.fromLng)
            ?: throw NoSuchElementException("No graph node found near from-coordinate")
        val toNode   = nearestNode(rg, request.toLat, request.toLng)
            ?: throw NoSuchElementException("No graph node found near to-coordinate")

        if (fromNode == toNode) {
            throw IllegalArgumentException(
                "Start and destination resolve to the same graph node — provide coordinates further apart"
            )
        }

        // A* Euclidean heuristic using pre-computed node coordinates
        val heuristic = AStarAdmissibleHeuristic<String> { u, t ->
            val uC = rg.nodeCoords[u] ?: return@AStarAdmissibleHeuristic 0.0
            val tC = rg.nodeCoords[t] ?: return@AStarAdmissibleHeuristic 0.0
            haversineMeters(uC[0], uC[1], tC[0], tC[1])
        }

        // Safest route: pre-compute WSI-weighted costs for this slot (O(E), negligible),
        // then pass as a Map to AsWeightedGraph (JGraphT 1.5.x only has Map constructor).
        val safetyWeights: Map<DefaultWeightedEdge, Double> =
            rg.edgeToSegmentId.mapValues { (edge, segId) ->
                val length = rg.graph.getEdgeWeight(edge)
                val wsi    = snapshot.scores[segId]?.wsi?.getOrNull(slotIndex) ?: 0.5
                length * (1.0 + (1.0 - wsi) * routingProps.safetyWeight)
            }
        val safetyWeighted = AsWeightedGraph(rg.graph, safetyWeights)
        val safestPath = AStarShortestPath(safetyWeighted, heuristic).getPath(fromNode, toNode)
            ?: throw NoSuchElementException("No route found between the given coordinates")

        // Shortest route: edge cost = physical length_m only
        val shortestPath = AStarShortestPath(rg.graph, heuristic).getPath(fromNode, toNode)
            ?: throw NoSuchElementException("No route found between the given coordinates")

        return RouteResponse(
            safestRoute   = toRouteInfo(safestPath, snapshot, slotIndex, rg),
            shortestRoute = toRouteInfo(shortestPath, snapshot, slotIndex, rg),
        )
    }

    // ── Path → DTO ────────────────────────────────────────────────────────────

    private fun toRouteInfo(
        path: GraphPath<String, DefaultWeightedEdge>,
        snapshot: AiDataSnapshot,
        slotIndex: Int,
        rg: RouteGraph,
    ): RouteInfo {
        val dtos = path.edgeList.mapNotNull { edge ->
            val segId = rg.edgeToSegmentId[edge] ?: return@mapNotNull null
            val seg   = snapshot.segments[segId]   ?: return@mapNotNull null
            val score = snapshot.scores[segId]
            RouteSegmentDto(
                segmentId = segId,
                startLat  = seg.startLat,
                startLng  = seg.startLng,
                endLat    = seg.endLat,
                endLng    = seg.endLng,
                lengthM   = seg.properties.lengthM,
                wsiScore  = score?.wsi?.getOrNull(slotIndex),
                colorBand = score?.tier?.getOrNull(slotIndex),
                // high_incident filtered here — same rule as public segments API
                factors   = score?.factors?.getOrNull(slotIndex)
                                ?.filter { it != HIGH_INCIDENT_FACTOR }
                            ?: emptyList(),
            )
        }
        val wsiValues = dtos.mapNotNull { it.wsiScore }
        return RouteInfo(
            segments      = dtos,
            totalDistance = dtos.sumOf { it.lengthM },
            avgWsi        = if (wsiValues.isNotEmpty()) wsiValues.average() else null,
        )
    }

    // ── Nearest-node snap ─────────────────────────────────────────────────────

    /**
     * Finds the graph node closest to the given coordinate.
     *
     * Uses squared Euclidean distance in degree-space (no sqrt, no haversine needed for
     * comparison-only nearest-neighbour search over short urban distances).
     */
    private fun nearestNode(rg: RouteGraph, lat: Double, lng: Double): String? {
        var bestId   : String? = null
        var bestDist           = Double.MAX_VALUE
        for ((id, coords) in rg.nodeCoords) {
            val dLat = coords[0] - lat
            val dLng = coords[1] - lng
            val d    = dLat * dLat + dLng * dLng
            if (d < bestDist) { bestDist = d; bestId = id }
        }
        return bestId
    }

    // ── Slot resolution ───────────────────────────────────────────────────────

    private fun resolveSlotIndex(
        snapshot: AiDataSnapshot,
        dayOfWeekParam: String?,
        hourParam: Int?,
    ): Int {
        val now  = ZonedDateTime.now(LA_ZONE)
        val dow  = if (dayOfWeekParam != null) parseDayOfWeek(dayOfWeekParam) else now.dayOfWeek
        val hour = hourParam ?: now.hour
        return findSlotIndex(snapshot.meta.slots, dow, hour) ?: run {
            log.warn("[ROUTE] No slot matched for dow={} hour={} — defaulting to slot 0", dow, hour)
            0
        }
    }

    private fun parseDayOfWeek(value: String): DayOfWeek = when (value.lowercase()) {
        "mon", "monday"    -> DayOfWeek.MONDAY
        "tue", "tuesday"   -> DayOfWeek.TUESDAY
        "wed", "wednesday" -> DayOfWeek.WEDNESDAY
        "thu", "thursday"  -> DayOfWeek.THURSDAY
        "fri", "friday"    -> DayOfWeek.FRIDAY
        "sat", "saturday"  -> DayOfWeek.SATURDAY
        "sun", "sunday"    -> DayOfWeek.SUNDAY
        else               -> {
            log.warn("[ROUTE] Unrecognised dayOfWeek='{}' — using current LA day", value)
            ZonedDateTime.now(LA_ZONE).dayOfWeek
        }
    }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

private fun haversineMeters(lat1: Double, lng1: Double, lat2: Double, lng2: Double): Double {
    val r    = 6_371_000.0
    val dLat = Math.toRadians(lat2 - lat1)
    val dLng = Math.toRadians(lng2 - lng1)
    val a    = sin(dLat / 2).pow(2) +
               cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) * sin(dLng / 2).pow(2)
    return r * 2.0 * asin(sqrt(a))
}
