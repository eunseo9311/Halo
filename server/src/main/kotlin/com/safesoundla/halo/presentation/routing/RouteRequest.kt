package com.safesoundla.halo.presentation.routing

import jakarta.validation.constraints.DecimalMax
import jakarta.validation.constraints.DecimalMin
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import java.time.OffsetDateTime

data class RouteRequest(
    @field:DecimalMin("-90.0") @field:DecimalMax("90.0")
    val fromLat: Double,

    @field:DecimalMin("-180.0") @field:DecimalMax("180.0")
    val fromLng: Double,

    @field:DecimalMin("-90.0") @field:DecimalMax("90.0")
    val toLat: Double,

    @field:DecimalMin("-180.0") @field:DecimalMax("180.0")
    val toLng: Double,

    /**
     * Optional day-of-week for slot resolution.
     * Accepted values (case-insensitive): "mon"/"monday", "tue"/"tuesday",
     * "wed"/"wednesday", "thu"/"thursday", "fri"/"friday", "sat"/"saturday", "sun"/"sunday".
     * Defaults to current LA local time day when absent.
     */
    val dayOfWeek: String? = null,

    /**
     * Optional hour (0–23) for slot resolution.
     * Defaults to current LA local time hour when absent.
     * When supplied without [dayOfWeek], the current LA day is used.
     */
    @field:Min(0) @field:Max(23)
    val hour: Int? = null,

    /**
     * Optional ISO-8601 departure instant. It is converted to Los Angeles local time
     * before slot lookup. Do not combine this with the legacy [dayOfWeek]/[hour] fields.
     */
    val departureTime: OffsetDateTime? = null,
)
