package com.safesoundla.halo

import com.safesoundla.halo.infrastructure.aidata.AiDataProperties
import com.safesoundla.halo.infrastructure.config.RoutingProperties
import com.safesoundla.halo.infrastructure.incident.IncidentProperties
import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.context.properties.EnableConfigurationProperties
import org.springframework.boot.runApplication

@SpringBootApplication
@EnableConfigurationProperties(AiDataProperties::class, RoutingProperties::class, IncidentProperties::class)
class HaloApplication

fun main(args: Array<String>) {
    runApplication<HaloApplication>(*args)
}
