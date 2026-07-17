package com.safesoundla.halo.application.segment

import com.safesoundla.halo.domain.segment.SegmentScore
import com.safesoundla.halo.infrastructure.persistence.SegmentScoreRepository
import org.springframework.stereotype.Service

@Service
class SegmentScoreService(
    private val repository: SegmentScoreRepository,
) {
    fun findById(id: Long): SegmentScore =
        repository.findById(id).orElseThrow { NoSuchElementException("Segment $id not found") }

    fun findBySegmentId(segmentId: String): SegmentScore =
        repository.findBySegmentId(segmentId)
            ?: throw NoSuchElementException("Segment '$segmentId' not found")
}
