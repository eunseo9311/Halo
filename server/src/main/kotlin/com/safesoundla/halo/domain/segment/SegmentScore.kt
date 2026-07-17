package com.safesoundla.halo.domain.segment

import jakarta.persistence.*

/**
 * Represents a scored street segment.
 *
 * WSI (Walkability/Safety Index): 0.0–1.0
 *   - Higher = better environment (well-lit, low incident history, etc.)
 *   - Displayed as green (≥0.7) / yellow (0.4–0.7) / red (<0.4)
 *
 * TODO: Replace lat/lng pairs with PostGIS geometry(LineString, 4326) once
 *       hibernate-spatial is added. The DB column is already geometry type
 *       (see migration V1). For now, we store start/end coordinates only.
 */
@Entity
@Table(name = "street_segments")
class SegmentScore(

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0,

    @Column(nullable = false)
    val segmentId: String,

    /** WSI score: 0.0 (worst) – 1.0 (best) */
    @Column(nullable = false)
    val wsiScore: Double,

    /** Data confidence: 0.0 – 1.0 (how much data backs this score) */
    @Column(nullable = false)
    val confidence: Double = 0.0,

    // Bounding coordinates (simplified; use PostGIS geometry for real geo queries)
    @Column(nullable = false) val startLat: Double,
    @Column(nullable = false) val startLng: Double,
    @Column(nullable = false) val endLat: Double,
    @Column(nullable = false) val endLng: Double,

    /** ISO-8601 hour of day the score applies to (0–23), null = all-day average */
    @Column val hourOfDay: Int? = null,
)
