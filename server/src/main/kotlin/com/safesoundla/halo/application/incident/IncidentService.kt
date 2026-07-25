package com.safesoundla.halo.application.incident

import com.safesoundla.halo.infrastructure.incident.IncidentRecord
import com.safesoundla.halo.infrastructure.incident.IncidentStore
import com.safesoundla.halo.presentation.incident.IncidentResponse
import org.springframework.stereotype.Service
import java.time.ZoneId
import kotlin.math.*

private const val EARTH_RADIUS_METERS = 6_371_000.0
private const val MAX_RESULTS = 100
private const val MIN_QUERY_RADIUS_METERS = 500
private const val COORDINATE_GRID = 1_000.0
private val SAFE_TEXT = Regex("[^\\p{L}\\p{N} .,'&()/-]")
private val LOS_ANGELES = ZoneId.of("America/Los_Angeles")

@Service
class IncidentService(private val store: IncidentStore) {
    fun findNearby(latitude: Double, longitude: Double, radiusMeters: Int): List<IncidentResponse> {
        require(latitude.isFinite() && latitude in -90.0..90.0) { "lat must be within [-90, 90]" }
        require(longitude.isFinite() && longitude in -180.0..180.0) { "lng must be within [-180, 180]" }
        require(radiusMeters in MIN_QUERY_RADIUS_METERS..10_000) {
            "radiusMeters must be between $MIN_QUERY_RADIUS_METERS and 10000"
        }

        // Use the same coarse grid for membership and output so repeated public
        // queries cannot recover the source coordinate hidden behind rounding.
        val queryLatitude = privacyCoordinate(latitude)
        val queryLongitude = privacyCoordinate(longitude)

        return store.get()
            .asSequence()
            .map {
                it to distanceMeters(
                    queryLatitude,
                    queryLongitude,
                    privacyCoordinate(it.latitude),
                    privacyCoordinate(it.longitude),
                )
            }
            .filter { (_, distance) -> distance <= radiusMeters }
            .sortedWith(compareBy<Pair<IncidentRecord, Double>> { it.second }.thenBy { it.first.incidentId })
            .take(MAX_RESULTS)
            .map { (incident, _) -> incident.toResponse() }
            .toList()
    }

    private fun IncidentRecord.toResponse(): IncidentResponse {
        val mapping = IncidentCategory.from(crimeDescription)
        return IncidentResponse(
            incidentId = incidentId,
            category = mapping.category,
            emoji = mapping.emoji,
            title = mapping.title,
            description = mapping.description,
            locationType = sanitizeLocation(premise),
            areaName = sanitizeText(areaName, "Unknown area"),
            occurredAt = occurredAt
                .withHour(occurredAt.hour / 3 * 3)
                .withMinute(0)
                .withSecond(0)
                .withNano(0)
                .atZone(LOS_ANGELES)
                .toOffsetDateTime()
                .toString(),
            latitude = privacyCoordinate(latitude),
            longitude = privacyCoordinate(longitude),
        )
    }

    private fun sanitizeLocation(value: String): String {
        val normalized = value.trim().uppercase()
        return when {
            normalized.contains("STREET") || normalized.contains("SIDEWALK") -> "Street or sidewalk"
            normalized.contains("PARKING") || normalized.contains("GARAGE") -> "Parking area"
            normalized.contains("RESIDENCE") || normalized.contains("HOME") ||
                normalized.contains("APARTMENT") -> "Residence"
            normalized.contains("STORE") || normalized.contains("MARKET") ||
                normalized.contains("RESTAURANT") -> "Business"
            normalized.contains("PARK") || normalized.contains("RECREATION") -> "Park or recreation area"
            normalized.contains("TRANSIT") || normalized.contains("BUS") ||
                normalized.contains("METRO") -> "Transit area"
            else -> "Other location"
        }
    }

    private fun sanitizeText(value: String, fallback: String): String =
        value.replace(SAFE_TEXT, "").trim().take(80).ifBlank { fallback }

    private fun privacyCoordinate(value: Double): Double =
        round(value * COORDINATE_GRID) / COORDINATE_GRID

    private fun distanceMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val dLat = Math.toRadians(lat2 - lat1)
        val dLon = Math.toRadians(lon2 - lon1)
        val a = sin(dLat / 2).pow(2) +
            cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) * sin(dLon / 2).pow(2)
        return EARTH_RADIUS_METERS * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}

enum class IncidentCategory(
    val category: String,
    val emoji: String,
    val title: String,
    val description: String,
) {
    ROBBERY(
        "robbery",
        "🚨",
        "Robbery reported",
        "A robbery was reported in this area. Stay aware of your surroundings.",
    ),
    AGGRAVATED_ASSAULT(
        "aggravated_assault",
        "⚠️",
        "Aggravated assault reported",
        "An aggravated assault was reported in this area. Consider an alternate route.",
    ),
    OTHER(
        "other",
        "⚠️",
        "Incident reported",
        "An incident was reported in this area. Stay alert and use caution.",
    );

    companion object {
        fun from(rawDescription: String): IncidentCategory =
            when (rawDescription.trim().uppercase()) {
                "ROBBERY" -> ROBBERY
                "AGGRAVATED ASSAULT",
                "ASSAULT WITH DEADLY WEAPON, AGGRAVATED ASSAULT" -> AGGRAVATED_ASSAULT
                else -> OTHER
            }
    }
}
