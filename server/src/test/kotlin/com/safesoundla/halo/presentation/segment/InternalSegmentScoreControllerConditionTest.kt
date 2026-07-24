package com.safesoundla.halo.presentation.segment

import com.safesoundla.halo.application.segment.AiSegmentService
import org.hamcrest.Matchers.containsString
import org.hamcrest.Matchers.not
import org.junit.jupiter.api.Test
import org.mockito.Mockito
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest
import org.springframework.test.context.bean.override.mockito.MockitoBean
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get

private const val SCORES_PATH = "/api/v1/segments/scores"
private const val INTERNAL_PATH = "/api/v1/segments/scores/internal"

@WebMvcTest(controllers = [SegmentScoreController::class, InternalSegmentScoreController::class])
class InternalSegmentScoreControllerDefaultOffTest {
    @Autowired lateinit var mvc: MockMvc
    @MockitoBean lateinit var service: AiSegmentService

    @Test
    fun `default configuration keeps public endpoint available and internal endpoint absent`() {
        Mockito.`when`(service.findNearbyPublic(34.0, -118.0, 200, null))
            .thenReturn(listOf(publicResponse()))

        mvc.get(SCORES_PATH) {
            param("lat", "34.0")
            param("lng", "-118.0")
        }.andExpect {
            status { isOk() }
            jsonPath("$.data[0].factors[0]") { value("low_light") }
            jsonPath("$.data[0].factors[1]") { doesNotExist() }
            content { string(not(containsString("high_incident"))) }
        }
        mvc.get(INTERNAL_PATH) {
            param("lat", "34.0")
            param("lng", "-118.0")
        }.andExpect { status { isNotFound() } }

        Mockito.verify(service, Mockito.never())
            .findNearbyInternal(34.0, -118.0, 200, null)
    }
}

@WebMvcTest(
    controllers = [SegmentScoreController::class, InternalSegmentScoreController::class],
    properties = ["halo.internal-api.segment-scores-enabled=false"],
)
class InternalSegmentScoreControllerExplicitOffTest {
    @Autowired lateinit var mvc: MockMvc
    @MockitoBean lateinit var service: AiSegmentService

    @Test
    fun `explicit false keeps public response filtered and internal mapping absent`() {
        Mockito.`when`(service.findNearbyPublic(34.0, -118.0, 200, null))
            .thenReturn(listOf(publicResponse()))

        mvc.get(SCORES_PATH) {
            param("lat", "34.0")
            param("lng", "-118.0")
        }.andExpect {
            status { isOk() }
            jsonPath("$.data[0].factors[0]") { value("low_light") }
            jsonPath("$.data[0].factors[1]") { doesNotExist() }
            content { string(not(containsString("high_incident"))) }
        }
        mvc.get(INTERNAL_PATH) {
            param("lat", "34.0")
            param("lng", "-118.0")
        }.andExpect { status { isNotFound() } }

        Mockito.verify(service, Mockito.never())
            .findNearbyInternal(34.0, -118.0, 200, null)
    }
}

@WebMvcTest(
    controllers = [SegmentScoreController::class, InternalSegmentScoreController::class],
    properties = ["halo.internal-api.segment-scores-enabled=true"],
)
class InternalSegmentScoreControllerEnabledTest {
    @Autowired lateinit var mvc: MockMvc
    @MockitoBean lateinit var service: AiSegmentService

    @Test
    fun `explicit true registers internal mapping while public response stays filtered`() {
        Mockito.`when`(service.findNearbyPublic(34.0, -118.0, 200, null))
            .thenReturn(listOf(publicResponse()))
        Mockito.`when`(service.findNearbyInternal(34.0, -118.0, 200, null))
            .thenReturn(listOf(internalResponse()))

        mvc.get(SCORES_PATH) {
            param("lat", "34.0")
            param("lng", "-118.0")
        }.andExpect {
            status { isOk() }
            jsonPath("$.data[0].factors[0]") { value("low_light") }
            jsonPath("$.data[0].factors[1]") { doesNotExist() }
            content { string(not(containsString("high_incident"))) }
        }
        mvc.get(INTERNAL_PATH) {
            param("lat", "34.0")
            param("lng", "-118.0")
        }.andExpect {
            status { isOk() }
            jsonPath("$.data[0].factors[0]") { value("high_incident") }
        }
    }
}

private fun publicResponse() = SegmentScoreResponse(
    segmentId = "fixture",
    wsiScore = 0.8,
    colorBand = "GREEN",
    startLat = 34.0,
    startLng = -118.0,
    endLat = 34.001,
    endLng = -118.001,
    components = ComponentScoresDto(risk = 0.8, light = 0.8, activity = 0.8, safezone = 0.8),
    factors = listOf("low_light"),
    slotIndex = 0,
)

private fun internalResponse() = SegmentScoreInternalResponse(
    segmentId = "fixture",
    wsiScore = 0.8,
    colorBand = "GREEN",
    startLat = 34.0,
    startLng = -118.0,
    endLat = 34.001,
    endLng = -118.001,
    components = ComponentScoresDto(risk = 0.8, light = 0.8, activity = 0.8, safezone = 0.8),
    factors = listOf("high_incident"),
    slotIndex = 0,
)
