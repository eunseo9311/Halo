package com.safesoundla.halo

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication

@SpringBootApplication
class HaloApplication

fun main(args: Array<String>) {
    runApplication<HaloApplication>(*args)
}
