package com.safesoundla.halo.application.routing

import com.safesoundla.halo.application.segment.findSlotIndex
import com.safesoundla.halo.infrastructure.aidata.AiDataSnapshot
import com.safesoundla.halo.infrastructure.aidata.AiDataStore
import com.safesoundla.halo.infrastructure.aidata.RouteGraph
import com.safesoundla.halo.infrastructure.config.RoutingProperties
import com.safesoundla.halo.presentation.routing.RouteInfo
import com.safesoundla.halo.presentation.routing.RouteCoordinateDto
import com.safesoundla.halo.presentation.routing.RouteRequest
import com.safesoundla.halo.presentation.routing.RouteResponse
import com.safesoundla.halo.presentation.routing.RouteSegmentDto
import org.jgrapht.GraphPath
import org.jgrapht.alg.interfaces.AStarAdmissibleHeuristic
import org.jgrapht.alg.shortestpath.AStarShortestPath
import org.jgrapht.graph.AsWeightedGraph
import org.jgrapht.graph.DefaultWeightedEdge
import org.springframework.stereotype.Service
import java.time.DayOfWeek
import java.time.ZoneId
import java.time.ZonedDateTime
import kotlin.math.*

private val PUBLIC_FACTORS = setOf("low_light", "outage_reported", "low_activity", "no_safezone")
private val LA_ZONE = ZoneId.of("America/Los_Angeles")

@Service
class RouteService(
    private val store: AiDataStore,
    private val routingProps: RoutingProperties,
) {
    fun findRoutes(request: RouteRequest): RouteResponse {
        val snapshot   = store.get()
        val departure = resolveDeparture(request)
        val slotIndex = resolveSlotIndex(snapshot, departure)
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
        val heuristic = AStarAdmissibleHeuristic<Long> { u, t ->
            val uC = rg.nodeCoords[u] ?: return@AStarAdmissibleHeuristic 0.0
            val tC = rg.nodeCoords[t] ?: return@AStarAdmissibleHeuristic 0.0
            haversineMeters(uC[0], uC[1], tC[0], tC[1])
        }

        // Safest route: pre-compute WSI-weighted costs for this slot, then pass them
        // to AsWeightedGraph. This is intentionally unconstrained: enforcing a 30%
        // distance budget requires a resource-constrained label-setting algorithm,
        // not a post-hoc truncation of this A* result.
        val safetyWeights: Map<DefaultWeightedEdge, Double> =
            rg.edgeToSegmentId.mapValues { (edge, segId) ->
                val length = rg.graph.getEdgeWeight(edge)
                val score = checkNotNull(snapshot.scores[segId]) {
                    "Routing segment '$segId' has no joined WSI score"
                }
                val wsi = checkNotNull(score.wsi.getOrNull(slotIndex)) {
                    "Routing segment '$segId' has no WSI value for slot $slotIndex"
                }
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
            slotIndex = slotIndex,
            departureTime = departure.toString(),
        )
    }

    // ── Path → DTO ────────────────────────────────────────────────────────────

    private fun toRouteInfo(
        path: GraphPath<Long, DefaultWeightedEdge>,
        snapshot: AiDataSnapshot,
        slotIndex: Int,
        rg: RouteGraph,
    ): RouteInfo {
        val dtos = path.edgeList.map { edge ->
            val segId = checkNotNull(rg.edgeToSegmentId[edge]) {
                "Routing edge is missing its segment ID"
            }
            val seg = checkNotNull(snapshot.segments[segId]) {
                "Routing segment '$segId' is missing from the loaded snapshot"
            }
            val score = checkNotNull(snapshot.scores[segId]) {
                "Routing segment '$segId' has no joined WSI score"
            }
            val wsi = checkNotNull(score.wsi.getOrNull(slotIndex)) {
                "Routing segment '$segId' has no WSI value for slot $slotIndex"
            }
            val factors = checkNotNull(score.factors.getOrNull(slotIndex)) {
                "Routing segment '$segId' has no factor list for slot $slotIndex"
            }
            val tier = checkNotNull(score.tier.getOrNull(slotIndex)) {
                "Routing segment '$segId' has no tier code for slot $slotIndex"
            }
            RouteSegmentDto(
                segmentId = segId,
                startLat  = seg.startLat,
                startLng  = seg.startLng,
                endLat    = seg.endLat,
                endLng    = seg.endLng,
                coordinates = seg.geometry.coordinates.map { coordinate ->
                    RouteCoordinateDto(latitude = coordinate[1], longitude = coordinate[0])
                },
                lengthM   = seg.properties.lengthM,
                wsiScore  = wsi,
                colorBand = tier.name,
                slotIndex = slotIndex,
                // Defence in depth: sensitive and unknown codes never cross the public DTO.
                factors   = factors.filter { it in PUBLIC_FACTORS },
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
    private fun nearestNode(rg: RouteGraph, lat: Double, lng: Double): Long? {
        var bestId: Long? = null
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

    private fun resolveDeparture(request: RouteRequest): ZonedDateTime {
        require(request.departureTime == null || (request.dayOfWeek == null && request.hour == null)) {
            "departureTime cannot be combined with dayOfWeek or hour"
        }
        request.departureTime?.let { return it.atZoneSameInstant(LA_ZONE) }

        val now = ZonedDateTime.now(LA_ZONE)
        val day = request.dayOfWeek?.let(::parseDayOfWeek) ?: now.dayOfWeek
        val hour = request.hour ?: now.hour
        return now.with(java.time.temporal.TemporalAdjusters.previousOrSame(day))
            .withHour(hour)
            .withMinute(0)
            .withSecond(0)
            .withNano(0)
    }

    private fun resolveSlotIndex(
        snapshot: AiDataSnapshot,
        departure: ZonedDateTime,
    ): Int {
        return requireNotNull(findSlotIndex(snapshot.meta.slots, departure.dayOfWeek, departure.hour)) {
            "No AI slot matches LA departure time dayOfWeek=${departure.dayOfWeek} hour=${departure.hour}"
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
        else -> throw IllegalArgumentException("Unrecognised dayOfWeek='$value'")
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
