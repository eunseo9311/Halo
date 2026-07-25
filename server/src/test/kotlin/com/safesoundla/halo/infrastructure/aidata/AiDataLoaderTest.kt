package com.safesoundla.halo.infrastructure.aidata

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.module.kotlin.KotlinModule
import com.fasterxml.jackson.module.kotlin.readValue
import com.safesoundla.halo.infrastructure.aidata.model.DataVintage
import com.safesoundla.halo.infrastructure.aidata.model.SegmentProperties
import com.safesoundla.halo.infrastructure.aidata.model.TierCode
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.junit.jupiter.api.io.TempDir
import org.springframework.boot.test.system.CapturedOutput
import org.springframework.boot.test.system.OutputCaptureExtension
import java.nio.file.Files
import java.nio.file.Path
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

@ExtendWith(OutputCaptureExtension::class)
class AiDataLoaderTest {

    @TempDir
    lateinit var tempDir: Path

    private val mapper = ObjectMapper().registerModule(KotlinModule.Builder().build())

    @Test
    fun `data_vintage parses exact object and legacy DUMMY sentinel`() {
        assertEquals(
            DataVintage.Sources(
                crime = "2026-01",
                poi = "2026-02",
                streetlightOutage = "2026-03",
            ),
            mapper.readValue<DataVintage>(resourceText("ai-data/data-vintage/actual.json")),
        )
        assertEquals(
            DataVintage.Dummy,
            mapper.readValue<DataVintage>(resourceText("ai-data/data-vintage/legacy-dummy.json")),
        )
    }

    @Test
    fun `data_vintage rejects non-DUMMY strings and malformed objects`() {
        listOf(
            "invalid-string.json",
            "missing-field.json",
            "wrong-type.json",
            "extra-field.json",
            "invalid-shape.json",
        ).forEach { fixture ->
            assertFailsWith<Exception>(fixture) {
                mapper.readValue<DataVintage>(resourceText("ai-data/data-vintage/$fixture"))
            }
        }
    }

    @Test
    fun `loads the committed 32-slot fixture and builds a directed Long graph`(output: CapturedOutput) {
        val snapshot = loader().load()

        assertEquals(setOf(TierCode.RED, TierCode.YELLOW, TierCode.GREEN),
            snapshot.scores.values.flatMap { it.tier }.toSet())
        assertEquals(emptyList(), snapshot.segments.getValue("111_222_0").properties.streetName)
        assertEquals(listOf("South Spring Street"),
            snapshot.segments.getValue("222_333_0").properties.streetName)
        assertEquals(listOf("East 1st Street", "South Main Street"),
            snapshot.segments.getValue("333_3000000000_0").properties.streetName)
        assertTrue(snapshot.routeGraph.graph.containsEdge(111L, 222L))
        assertTrue(!snapshot.routeGraph.graph.containsEdge(222L, 111L))
        assertTrue(snapshot.routeGraph.graph.containsVertex(3_000_000_000L))
        assertEquals(snapshot.segments.keys, snapshot.scores.keys)
        assertEquals(7, snapshot.safeZones.size)

        val selfLoop = snapshot.segments.getValue("3000000000_3000000000_0")
        assertEquals(3, selfLoop.geometry.coordinates.size)
        assertEquals(selfLoop.geometry.coordinates.first(), selfLoop.geometry.coordinates.last())
        val selfLoopEdges = snapshot.routeGraph.graph.getAllEdges(3_000_000_000L, 3_000_000_000L)
        assertEquals(1, selfLoopEdges.size)
        assertEquals(
            "3000000000_3000000000_0",
            snapshot.routeGraph.edgeToSegmentId.getValue(selfLoopEdges.single()),
        )
        assertTrue(output.out.contains("selfLoops=1"))
        assertTrue(!output.out.contains("3000000000_3000000000_0"))
    }

    @Test
    fun `street_name accepts null string and string array`() {
        fun parse(value: String): SegmentProperties = mapper.readValue(
            """{
                "segment_id":"1_2_0","connects":[1,2],"length_m":1.0,
                "district_id":null,"subarea_id":null,"street_name":$value
            }""",
        )

        assertEquals(emptyList(), parse("null").streetName)
        assertEquals(listOf("Main Street"), parse("\"Main Street\"").streetName)
        assertEquals(listOf("Main Street", "1st Street"), parse("""["Main Street","1st Street"]""").streetName)
    }

    @Test
    fun `street_name rejects other JSON shapes`() {
        assertFailsWith<Exception> {
            mapper.readValue<SegmentProperties>(
                """{
                    "segment_id":"1_2_0","connects":[1,2],"length_m":1.0,
                    "district_id":null,"subarea_id":null,"street_name":[1]
                }""",
            )
        }
    }

    @Test
    fun `unknown numeric tier code is rejected`() {
        val tier = mapper.readTree(resourceText("ai-data/invalid/unknown-tier.json")).get("tier")
        assertFailsWith<Exception> { mapper.treeToValue(tier, TierCode::class.java) }
    }

    @Test
    fun `fractional and string tiers are rejected without numeric coercion`() {
        assertFailsWith<Exception> { mapper.readValue<TierCode>("1.5") }
        assertFailsWith<Exception> { mapper.readValue<TierCode>("\"1\"") }
    }

    @Test
    fun `numeric tier codes map at the single contract boundary`() {
        assertEquals(TierCode.RED, mapper.readValue<TierCode>("0"))
        assertEquals(TierCode.YELLOW, mapper.readValue<TierCode>("1"))
        assertEquals(TierCode.GREEN, mapper.readValue<TierCode>("2"))
    }

    @Test
    fun `slot arrays must contain exactly 32 entries`() {
        val invalidWsi = resourceText("ai-data/wsi_scores.json").replaceFirst(
            "0.8,0.8,0.8,0.8,0.8,0.8,0.8,0.8,0.8,0.8,0.8,0.8,0.8,0.8,0.8,0.8,0.8,0.8,0.8,0.8,0.8,0.8,0.8,0.8,0.8,0.8,0.8,0.8,0.8,0.8,0.8,0.8",
            "0.8",
        )

        val error = assertFailsWith<IllegalArgumentException> {
            loader(wsi = invalidWsi).load()
        }
        assertTrue(error.message.orEmpty().contains("exactly 32 slots"))
    }

    @Test
    fun `unknown factor is rejected`() {
        val invalidWsi = resourceText("ai-data/wsi_scores.json")
            .replaceFirst(
                "\"low_light\"",
                "\"${invalidTextValue("ai-data/invalid/unknown-factor.json", "factor")}\"",
            )

        val error = assertFailsWith<IllegalArgumentException> {
            loader(wsi = invalidWsi).load()
        }
        assertTrue(error.message.orEmpty().contains("unknown factor"))
    }

    @Test
    fun `invalid safe-zone category is rejected`() {
        val invalidSafeZones = resourceText("ai-data/safezones.geojson")
            .replaceFirst(
                "\"police\"",
                "\"${invalidTextValue("ai-data/invalid/unknown-category.json", "category")}\"",
            )

        assertFailsWith<Exception> { loader(safeZones = invalidSafeZones).load() }
    }

    @Test
    fun `orphan nearby segment is retained under aggregate warning policy`() {
        val orphan = invalidTextValue("ai-data/invalid/orphan-nearby-segment.json", "nearby_segment")
        val invalidSafeZones = resourceText("ai-data/safezones.geojson")
            .replaceFirst("\"nearby_segments\":[]", "\"nearby_segments\":[\"$orphan\"]")

        val snapshot = loader(safeZones = invalidSafeZones).load()

        assertEquals(7, snapshot.safeZones.size)
        assertEquals(listOf(orphan), snapshot.safeZones.last().properties.nearbySegments)
    }

    @Test
    fun `every LineString coordinate is range validated`() {
        val invalidSegments = resourceText("ai-data/segments.geojson")
            .replaceFirst("[-118.2434, 34.0525]", "[-118.2434, 134.0525]")

        val error = assertFailsWith<IllegalArgumentException> {
            loader(segments = invalidSegments).load()
        }
        assertTrue(error.message.orEmpty().contains("coordinate[1] is out of range"))
    }

    @Test
    fun `connects must contain exactly two Long node IDs`() {
        val invalidSegments = resourceText("ai-data/segments.geojson")
            .replaceFirst("\"connects\": [111, 222]", "\"connects\": [111]")

        val error = assertFailsWith<IllegalArgumentException> {
            loader(segments = invalidSegments).load()
        }
        assertTrue(error.message.orEmpty().contains("exactly two node IDs"))
    }

    private fun loader(
        segments: String = resourceText("ai-data/segments.geojson"),
        wsi: String = resourceText("ai-data/wsi_scores.json"),
        safeZones: String = resourceText("ai-data/safezones.geojson"),
    ): AiDataLoader {
        val segmentsPath = tempDir.resolve("segments-${System.nanoTime()}.geojson")
        val wsiPath = tempDir.resolve("wsi-${System.nanoTime()}.json")
        val safeZonesPath = tempDir.resolve("safezones-${System.nanoTime()}.geojson")
        Files.writeString(segmentsPath, segments)
        Files.writeString(wsiPath, wsi)
        Files.writeString(safeZonesPath, safeZones)
        return AiDataLoader(
            AiDataStore(),
            AiDataProperties(
                segmentsPath = segmentsPath.toString(),
                wsiScoresPath = wsiPath.toString(),
                safezonesPath = safeZonesPath.toString(),
            ),
        )
    }

    private fun resourceText(path: String): String =
        checkNotNull(javaClass.classLoader.getResource(path)).readText()

    private fun invalidTextValue(path: String, field: String): String =
        mapper.readTree(resourceText(path)).get(field).textValue()
}
