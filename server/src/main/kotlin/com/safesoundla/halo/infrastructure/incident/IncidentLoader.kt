package com.safesoundla.halo.infrastructure.incident

import com.fasterxml.jackson.databind.JsonNode
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.module.kotlin.KotlinModule
import org.slf4j.LoggerFactory
import org.springframework.boot.context.event.ApplicationReadyEvent
import org.springframework.context.event.EventListener
import org.springframework.stereotype.Component
import java.nio.file.Files
import java.nio.file.Path
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException
import java.util.UUID

private val REQUIRED_FIELDS = setOf(
    "area_name", "crime_code", "crime_desc", "date", "time", "lat", "lon", "premise",
)
private val COMPACT_TIME = DateTimeFormatter.ofPattern("HHmm")

@Component
class IncidentLoader(
    private val store: IncidentStore,
    private val properties: IncidentProperties,
) {
    private val log = LoggerFactory.getLogger(IncidentLoader::class.java)
    private val objectMapper = ObjectMapper().registerModule(KotlinModule.Builder().build())

    @EventListener(ApplicationReadyEvent::class)
    fun onReady() {
        store.set(load())
    }

    fun load(): List<IncidentRecord> {
        if (properties.path.isBlank()) {
            log.info("[INCIDENTS] No external incident file configured; store remains empty")
            return emptyList()
        }

        return try {
            val root = Files.newInputStream(Path.of(properties.path)).use(objectMapper::readTree)
            require(root.isArray) { "root must be a JSON array" }
            root.mapIndexed(::parseRecord).also {
                log.info("[INCIDENTS] Loaded {} validated incidents", it.size)
            }
        } catch (ex: Exception) {
            log.error(
                "[INCIDENTS] External incident file rejected; store remains empty ({})",
                ex.javaClass.simpleName,
            )
            emptyList()
        }
    }

    private fun parseRecord(index: Int, node: JsonNode): IncidentRecord {
        require(node.isObject) { "record $index must be an object" }
        require(node.fieldNames().asSequence().toSet() == REQUIRED_FIELDS) {
            "record $index has an invalid schema"
        }

        val areaName = requiredText(node, "area_name", index)
        val crimeDescription = requiredText(node, "crime_desc", index)
        val premise = requiredText(node, "premise", index)
        val crimeCodeNode = node["crime_code"]
        require(crimeCodeNode.isIntegralNumber && crimeCodeNode.canConvertToInt()) {
            "record $index crime_code must be an integer"
        }
        val crimeCode = crimeCodeNode.intValue()
        val date = parseDate(requiredText(node, "date", index), index)
        val time = parseTime(node["time"], index)
        val latitude = requiredCoordinate(node, "lat", index, -90.0, 90.0)
        val longitude = requiredCoordinate(node, "lon", index, -180.0, 180.0)
        val occurredAt = LocalDateTime.of(date, time)

        return IncidentRecord(
            // Public IDs must not be derivable from the source record.
            incidentId = UUID.randomUUID().toString(),
            crimeDescription = crimeDescription,
            areaName = areaName,
            occurredAt = occurredAt,
            latitude = latitude,
            longitude = longitude,
            premise = premise,
        )
    }

    private fun requiredText(node: JsonNode, field: String, index: Int): String {
        val value = node[field]
        require(value?.isTextual == true && value.textValue().isNotBlank()) {
            "record $index $field must be a non-blank string"
        }
        return value.textValue()
    }

    private fun parseDate(value: String, index: Int): LocalDate =
        try {
            LocalDate.parse(value, DateTimeFormatter.ISO_LOCAL_DATE)
        } catch (_: DateTimeParseException) {
            throw IllegalArgumentException("record $index date must be ISO-8601")
        }

    private fun parseTime(node: JsonNode?, index: Int): LocalTime {
        require(node != null && (node.isTextual || node.isIntegralNumber)) {
            "record $index time must be HH:mm or HHmm"
        }
        val raw = if (node.isTextual) node.textValue() else node.intValue().toString().padStart(4, '0')
        val formatter = if (raw.contains(':')) DateTimeFormatter.ofPattern("HH:mm") else COMPACT_TIME
        return try {
            LocalTime.parse(raw, formatter)
        } catch (_: DateTimeParseException) {
            throw IllegalArgumentException("record $index time must be HH:mm or HHmm")
        }
    }

    private fun requiredCoordinate(
        node: JsonNode,
        field: String,
        index: Int,
        minimum: Double,
        maximum: Double,
    ): Double {
        val value = node[field]
        require(value?.isNumber == true) { "record $index $field must be numeric" }
        val coordinate = value.doubleValue()
        require(coordinate.isFinite() && coordinate in minimum..maximum) {
            "record $index $field is outside the valid range"
        }
        return coordinate
    }

}
