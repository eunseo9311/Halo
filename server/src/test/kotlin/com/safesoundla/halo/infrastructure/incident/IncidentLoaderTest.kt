package com.safesoundla.halo.infrastructure.incident

import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir
import java.nio.file.Path
import kotlin.io.path.writeText
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue

class IncidentLoaderTest {
    @TempDir
    lateinit var tempDir: Path

    @Test
    fun `loads validated array schema and accepts compact sample time`() {
        val file = fixture(
            """
            [
              {
                "area_name": "Central",
                "crime_code": 210,
                "crime_desc": "ROBBERY",
                "date": "2026-07-25",
                "time": 35,
                "lat": 34.0522,
                "lon": -118.2437,
                "premise": "SIDEWALK"
              },
              {
                "area_name": "West LA",
                "crime_code": 230,
                "crime_desc": "AGGRAVATED ASSAULT",
                "date": "2026-07-25",
                "time": "14:45",
                "lat": 34.05,
                "lon": -118.25,
                "premise": "PARKING LOT"
              }
            ]
            """,
        )

        val records = loader(file.toString()).load()

        assertEquals(2, records.size)
        assertEquals("00:35", records[0].occurredAt.toLocalTime().toString())
        assertEquals("14:45", records[1].occurredAt.toLocalTime().toString())
        assertNotEquals(records[0].incidentId, records[1].incidentId)
    }

    @Test
    fun `blank path returns empty without reading a file`() {
        assertTrue(loader("").load().isEmpty())
    }

    @Test
    fun `malformed schema or invalid coordinate rejects the whole file`() {
        val malformed = fixture("""[{"area_name":"Central"}]""")
        assertTrue(loader(malformed.toString()).load().isEmpty())

        val invalidRange = fixture(
            """
            [{
              "area_name":"Central","crime_code":210,"crime_desc":"ROBBERY",
              "date":"2026-07-25","time":"14:45","lat":91,"lon":-118.2,"premise":"STREET"
            }]
            """,
        )
        assertTrue(loader(invalidRange.toString()).load().isEmpty())
    }

    private fun loader(path: String) =
        IncidentLoader(IncidentStore(), IncidentProperties(path))

    private fun fixture(contents: String): Path =
        tempDir.resolve("incidents-${System.nanoTime()}.json").also { it.writeText(contents) }
}
