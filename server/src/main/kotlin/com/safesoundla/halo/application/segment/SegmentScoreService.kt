package com.safesoundla.halo.application.segment

import com.safesoundla.halo.domain.segment.SegmentScore
import com.safesoundla.halo.infrastructure.persistence.SegmentScoreRepository
import org.springframework.stereotype.Service
import kotlin.math.cos
import kotlin.math.PI

@Service
class SegmentScoreService(
    private val repository: SegmentScoreRepository,
) {

    fun findById(id: Long): SegmentScore =
        repository.findById(id).orElseThrow { NoSuchElementException("Segment $id not found") }

    fun findBySegmentId(segmentId: String): SegmentScore =
        repository.findBySegmentId(segmentId)
            ?: throw NoSuchElementException("Segment '$segmentId' not found")

    /**
     * Find segments within [radiusMeters] of the given coordinate.
     *
     * Uses a bounding-box approximation:
     *   1° latitude  ≈ 111 km  (constant)
     *   1° longitude ≈ 111 km × cos(lat)
     *
     * Results are capped at 500 to avoid overloading the Flutter client.
     */
    fun findNearby(lat: Double, lng: Double, radiusMeters: Int): List<SegmentScore> {
        val latDelta = radiusMeters / 111_000.0
        val lngDelta = radiusMeters / (111_000.0 * cos(lat * PI / 180.0))
        return repository.findByBoundingBox(
            minLat = lat - latDelta,
            maxLat = lat + latDelta,
            minLng = lng - lngDelta,
            maxLng = lng + lngDelta,
        ).take(500)
    }
}
