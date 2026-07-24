package com.safesoundla.halo.infrastructure.aidata

import org.jgrapht.alg.shortestpath.DijkstraShortestPath
import org.jgrapht.graph.DefaultWeightedEdge
import org.jgrapht.graph.DirectedWeightedMultigraph
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class RouteGraphContractTest {

    @Test
    fun `connects order is directed and reverse traversal is unavailable`() {
        val graph = DirectedWeightedMultigraph<Long, DefaultWeightedEdge>(DefaultWeightedEdge::class.java)
        graph.addVertex(10L)
        graph.addVertex(20L)
        graph.addEdge(10L, 20L)

        assertEquals(1, DijkstraShortestPath(graph).getPath(10L, 20L).length)
        assertNull(DijkstraShortestPath(graph).getPath(20L, 10L))
    }

    @Test
    fun `parallel directed segments are retained`() {
        val graph = DirectedWeightedMultigraph<Long, DefaultWeightedEdge>(DefaultWeightedEdge::class.java)
        graph.addVertex(10L)
        graph.addVertex(20L)
        graph.addEdge(10L, 20L)
        graph.addEdge(10L, 20L)

        assertEquals(2, graph.getAllEdges(10L, 20L).size)
    }

    @Test
    fun `node IDs retain values beyond signed 32 bit range`() {
        val source = 4_294_967_296L
        val target = Long.MAX_VALUE - 1
        val graph = DirectedWeightedMultigraph<Long, DefaultWeightedEdge>(DefaultWeightedEdge::class.java)
        graph.addVertex(source)
        graph.addVertex(target)
        graph.addEdge(source, target)

        assertEquals(setOf(source, target), graph.vertexSet())
    }
}
