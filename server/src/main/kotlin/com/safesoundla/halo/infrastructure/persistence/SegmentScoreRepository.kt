package com.safesoundla.halo.infrastructure.persistence

import com.safesoundla.halo.domain.segment.SegmentScore
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository

@Repository
interface SegmentScoreRepository : JpaRepository<SegmentScore, Long> {
    fun findBySegmentId(segmentId: String): SegmentScore?

    // TODO: replace with PostGIS spatial query once hibernate-spatial is added
    // Example future method:
    // @Query("SELECT s FROM SegmentScore s WHERE ST_DWithin(s.geometry, :point, :radiusMeters)")
    // fun findNearby(point: Point, radiusMeters: Double): List<SegmentScore>
}
