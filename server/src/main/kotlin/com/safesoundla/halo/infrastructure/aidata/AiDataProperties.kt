package com.safesoundla.halo.infrastructure.aidata

import org.springframework.boot.context.properties.ConfigurationProperties

/**
 * File paths for the three AI-generated data files.
 *
 * Prefix with "classpath:" to load from the JAR (default, for committed placeholder/prod files).
 * Prefix with "file:" or use a bare filesystem path for externally mounted files.
 *
 * Configured via application.yml under `halo.ai-data`.
 */
@ConfigurationProperties(prefix = "halo.ai-data")
data class AiDataProperties(
    val segmentsPath: String = "classpath:ai-data/segments.geojson",
    val wsiScoresPath: String = "classpath:ai-data/wsi_scores.json",
    val safezonesPath: String = "classpath:ai-data/safezones.geojson",
)
