package com.safesoundla.halo.infrastructure.config

import org.springframework.boot.context.properties.ConfigurationProperties

/**
 * Tuning parameters for the in-memory A* routing engine.
 *
 * [safetyWeight] controls the penalty applied to low-WSI edges relative to physical length:
 *
 *   edgeCost = length_m × (1 + (1 − wsi[slot]) × safetyWeight)
 *
 * | safetyWeight | Behaviour |
 * |---|---|
 * | 0.0 | Pure shortest-path; WSI ignored |
 * | 1.0 | Default; wsi=0 edge costs 2× a wsi=1 edge of equal length |
 * | 2.0 | Strongly safety-biased; will accept longer detours for safer paths |
 *
 * Adjust in application.yml without any model retraining:
 *   halo.routing.safety-weight: 1.5
 */
@ConfigurationProperties(prefix = "halo.routing")
data class RoutingProperties(
    val safetyWeight: Double = 1.0,
)
