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
    var sesiones: [SesionHecha] = []
    var eficiencia: [PuntoSerie] = []
    var zonas: [TiempoZona] = []
    var potencia: [MarcaPotencia] = []
    var ftpEstimado: Double?
    var natacion: [DiaValor] = []      // segundos por 100 m
    var peso: [DiaValor] = []          // kg
    var bateria: [DiaValor] = []       // Body Battery cargada cada día
    var pulsoReposo: Double?
    var pulsoReposo7: Double?
}

// MARK: - Series añadidas para rendimiento, cuerpo y constancia

/// Una sesión ya hecha, tal como viene de Garmin.
struct SesionHecha: Identifiable {
    let id: Int
    let dia: String        // yyyy-MM-dd
    let fecha: Date
    let deporte: String?   // Bici, Carrera, Agua, Fuerza
    let nombre: String
    let minutos: Double
    let metros: Double?
    let pulso: Double?
    let potencia: Double?
}

/// Un punto de una serie con nombre, para gráficas de varias líneas.
struct PuntoSerie: Identifiable {
    var id: String { "\(serie)-\(fecha.timeIntervalSince1970)" }
    let fecha: Date
    let serie: String
    let valor: Double
}

struct TiempoZona: Identifiable {
    var id: String { "\(semana.timeIntervalSince1970)-\(zona)" }
    let semana: Date
    let zona: String       // Z1 … Z5
    let horas: Double
}

struct MarcaPotencia: Identifiable {
    var id: String { "\(duracion)-\(periodo)" }
    let duracion: String   // 5 s, 1 min, 5 min, 20 min
    let periodo: String    // Últimos 28 días / 28 días anteriores
    let vatios: Double
}

struct DiaValor: Identifiable {
    var id: Date { fecha }
    let fecha: Date
    let valor: Double
}

extension Historico {
    /// Forma (fondo menos semana) y rampa (cuánto ha subido el fondo en 7 días).
    var formaYRampa: (forma: Double, rampa: Double)? {
        guard carga.count >= 8, let ultimo = carga.last else { return nil }
        return (ultimo.cronica - ultimo.aguda, ultimo.cronica - carga[carga.count - 8].cronica)
    }
}
