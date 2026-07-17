package com.safesoundla.halo.presentation.health

import com.safesoundla.halo.presentation.common.ApiResponse
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/health")
class HealthController {

    @GetMapping
    fun health(): ApiResponse<Map<String, String>> =
        ApiResponse.ok(mapOf("status" to "ok", "service" to "halo-server"))
}
