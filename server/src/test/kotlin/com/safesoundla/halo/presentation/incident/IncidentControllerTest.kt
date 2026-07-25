package com.safesoundla.halo.presentation.incident

import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.safesoundla.halo.application.incident.IncidentService
import com.safesoundla.halo.infrastructure.incident.IncidentRecord
import com.safesoundla.halo.infrastructure.incident.IncidentStore
import com.safesoundla.halo.presentation.common.GlobalExceptionHandler
import org.hamcrest.Matchers.hasSize
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.setup.MockMvcBuilders
import java.time.LocalDateTime
import kotlin.test.assertFalse

class IncidentControllerTest {
    private lateinit var mockMvc: MockMvc

    @BeforeEach
    fun setUp() {
        val store = IncidentStore()
        store.set(
            listOf(
                IncidentRecord(
                    "opaque-id",
                    "ROBBERY",
                    "Central",
                    LocalDateTime.of(2026, 7, 25, 14, 45),
                    34.05221,
                    -118.24371,
                    "SIDEWALK",
                ),
            ),
        )
        mockMvc = MockMvcBuilders
            .standaloneSetup(IncidentController(IncidentService(store)))
            .setControllerAdvice(GlobalExceptionHandler())
            .build()
    }

    @Test
    fun `default radius returns public incident contract`() {
        val response = mockMvc.get("/api/v1/incidents") {
            param("lat", "34.0522")
            param("lng", "-118.2437")
        }
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data", hasSize<Any>(1))
                jsonPath("$.data[0].incidentId") { value("opaque-id") }
                jsonPath("$.data[0].latitude") { value(34.052) }
                jsonPath("$.data[0].longitude") { value(-118.244) }
            }
            .andReturn()
            .response
            .contentAsString

        val json = jacksonObjectMapper().readTree(response)["data"][0]
        setOf("crimeCode", "crimeDescription", "crime_desc", "premise", "path", "raw")
            .forEach { assertFalse(json.has(it), "forbidden public field: $it") }
    }

    @Test
    fun `rejects invalid radius`() {
        mockMvc.get("/api/v1/incidents") {
            param("lat", "34.0522")
            param("lng", "-118.2437")
            param("radiusMeters", "10001")
        }.andExpect {
            status { isBadRequest() }
            jsonPath("$.success") { value(false) }
        }
    }
}
