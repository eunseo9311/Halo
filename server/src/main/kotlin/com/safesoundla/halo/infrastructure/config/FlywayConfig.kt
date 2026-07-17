package com.safesoundla.halo.infrastructure.config

import org.flywaydb.core.Flyway
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import javax.sql.DataSource

/**
 * Explicit Flyway configuration — Spring Boot 4.x autoconfiguration does not reliably
 * pick up Flyway when the datasource is in a profile-specific yml.
 * Declaring the bean here guarantees migrations run during context refresh,
 * before any JPA repository tries to use the schema.
 *
 * The autoconfiguration backs off via @ConditionalOnMissingBean(Flyway::class).
 */
@Configuration
class FlywayConfig {

    @Bean(initMethod = "migrate")
    fun flyway(dataSource: DataSource): Flyway =
        Flyway.configure()
            .dataSource(dataSource)
            .locations("classpath:db/migration")
            .baselineOnMigrate(true)
            .load()
}
