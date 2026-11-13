// EstadoDia.swift
// ------------------------------------------------------------------
// Los datos del día tal como los entrega el servidor del portátil
// en /estado. Casi todo es opcional: si Garmin no da un dato, llega nulo.
// ------------------------------------------------------------------

import Foundation

struct EstadoDia: Codable {
    var dia: String
    var carga: Carga
    var vfc: VFC
    var sueno: Sueno
    var readiness: Readiness
    var pesoKg: Double?
    var actividades: [Actividad]

    enum CodingKeys: String, CodingKey {
        case dia, carga, vfc, sueno, readiness, actividades
        case pesoKg = "peso_kg"
    }
}

struct Carga: Codable {
    var aguda: Double?
    var cronica: Double?
    var relacion: Double?
    var estadoRelacion: String?

    enum CodingKeys: String, CodingKey {
        case aguda, cronica, relacion
        case estadoRelacion = "estado_relacion"
    }
}

struct VFC: Codable {
    var anocheMs: Double?
    var mediaSemanalMs: Double?
    var estado: String?

    enum CodingKeys: String, CodingKey {
        case estado
        case anocheMs = "anoche_ms"
        case mediaSemanalMs = "media_semanal_ms"
    }
}

struct Sueno: Codable {
    var horas: Double?
    var puntuacion: Double?
}

struct Readiness: Codable {
    var puntuacion: Double?
    var nivel: String?
}

struct Actividad: Codable, Identifiable {
    var id: Int
    var nombre: String?
    var tipo: String?
    var inicio: String?
    var minutos: Double?
    var metros: Double?
    var pulsoMedio: Double?

    enum CodingKeys: String, CodingKey {
        case id, nombre, tipo, inicio, minutos, metros
        case pulsoMedio = "pulso_medio"
    }
}
