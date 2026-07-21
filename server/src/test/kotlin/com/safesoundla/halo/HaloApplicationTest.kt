package com.safesoundla.halo

import org.junit.jupiter.api.Test
import org.springframework.boot.test.context.SpringBootTest

/**
 * Smoke test: verifies the Spring context loads without a database connection.
 *
 * The server is designed to run without PostgreSQL (halo.db.enabled=false by default).
 * The property below explicitly mirrors the !db profile's autoconfigure.exclude list so
 * this test is independent of profile-conditional property evaluation order.
 */
@SpringBootTest(properties = [
    "spring.autoconfigure.exclude=" +
        "org.springframework.boot.jdbc.autoconfigure.DataSourceAutoConfiguration," +
        "org.springframework.boot.hibernate.autoconfigure.HibernateJpaAutoConfiguration," +
        "org.springframework.boot.data.jpa.autoconfigure.DataJpaRepositoriesAutoConfiguration," +
        "org.springframework.boot.jdbc.autoconfigure.DataSourceTransactionManagerAutoConfiguration"
])
class HaloApplicationTest {

    @Test
    fun contextLoads() {
    }
}
