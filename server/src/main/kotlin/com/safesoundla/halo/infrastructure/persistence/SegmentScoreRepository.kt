package com.safesoundla.halo.infrastructure.persistence

import com.safesoundla.halo.domain.segment.SegmentScore
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import org.springframework.stereotype.Repository

@Repository
interface SegmentScoreRepository : JpaRepository<SegmentScore, Long> {

    fun findBySegmentId(segmentId: String): SegmentScore?

    /**
     * Return segments whose start coordinate falls within a bounding box.
     *
     * Simple lat/lng box approximation (MVP).
     * TODO: replace with ST_DWithin once hibernate-spatial + geometry column are added.
     */
    @Query("""
        SELECT s FROM SegmentScore s
        WHERE s.startLat BETWEEN :minLat AND :maxLat
          AND s.startLng BETWEEN :minLng AND :maxLng
        ORDER BY s.wsiScore ASC
    """)
    fun findByBoundingBox(
        @Param("minLat") minLat: Double,
        @Param("maxLat") maxLat: Double,
        @Param("minLng") minLng: Double,
        @Param("maxLng") maxLng: Double,
    ): List<SegmentScore>
}
