package com.safesoundla.halo.infrastructure.incident

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties("halo.incidents")
data class IncidentProperties(
    val path: String = "",
)
