package com.safesoundla.halo.presentation.common

import com.fasterxml.jackson.annotation.JsonInclude

/**
 * Unified API response wrapper.
 *
 * Success: { "success": true, "data": {...} }
 * Error:   { "success": false, "error": { "code": "...", "message": "..." } }
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
data class ApiResponse<T>(
    val success: Boolean,
    val data: T? = null,
    val error: ErrorDetail? = null,
) {
    companion object {
        fun <T> ok(data: T): ApiResponse<T> = ApiResponse(success = true, data = data)
        fun <T> error(code: String, message: String): ApiResponse<T> =
            ApiResponse(success = false, error = ErrorDetail(code, message))
    }
}

data class ErrorDetail(
    val code: String,
    val message: String,
)

/**
 * Error codes — prefix with domain for clarity.
 * e.g. SEGMENT_NOT_FOUND, ROUTE_INVALID_COORDS
 */
object ErrorCode {
    const val INTERNAL_ERROR = "INTERNAL_ERROR"
    const val VALIDATION_ERROR = "VALIDATION_ERROR"
    const val NOT_FOUND = "NOT_FOUND"
    const val BAD_REQUEST = "BAD_REQUEST"
}
