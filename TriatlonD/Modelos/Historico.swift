// Historico.swift
// ------------------------------------------------------------------
// Las series de las últimas semanas que pintan las gráficas de Datos:
// carga, variabilidad del pulso, sueño y volumen por deporte.
// ------------------------------------------------------------------

import Foundation

struct DiaCarga: Identifiable {
    var id: Date { fecha }
    let fecha: Date
    let aguda: Double      // suma de los 7 días anteriores
    let cronica: Double    // media semanal de los 28 días anteriores
}

struct NocheVFC: Identifiable {
    var id: Date { fecha }
    let fecha: Date
    let anoche: Double
    let media: Double?
}

struct NocheSueno: Identifiable {
    var id: Date { fecha }
    let fecha: Date
    let horas: Double
    let nota: Double?
}

struct VolumenSemana: Identifiable {
    var id: String { "\(inicio.timeIntervalSince1970)-\(deporte)" }
    let inicio: Date       // lunes de esa semana
    let deporte: String    // Bici, Carrera, Agua, Fuerza
    let horas: Double
}

struct Historico {
    var carga: [DiaCarga] = []
    var vfc: [NocheVFC] = []
    var sueno: [NocheSueno] = []
    var volumen: [VolumenSemana] = []
}
