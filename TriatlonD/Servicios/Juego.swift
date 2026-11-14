// Juego.swift
// ------------------------------------------------------------------
// Reglas del juego: cómo salen los atributos del personaje de los
// datos reales. Primera versión, pendiente de ajustar.
// ------------------------------------------------------------------

import Foundation

enum Juego {
    /// Energía del día (0-100): 40 % readiness, 30 % sueño, 30 % VFC frente a su media.
    /// Si falta algún dato, se reparte el peso entre los que sí hay.
    static func energia(_ e: EstadoDia) -> Double? {
        var suma = 0.0
        var peso = 0.0
        if let r = e.readiness.puntuacion { suma += 0.4 * r; peso += 0.4 }
        if let s = e.sueno.puntuacion { suma += 0.3 * s; peso += 0.3 }
        if let anoche = e.vfc.anocheMs, let media = e.vfc.mediaSemanalMs, media > 0 {
            suma += 0.3 * min(100, anoche / media * 100)
            peso += 0.3
        }
        return peso > 0 ? (suma / peso).rounded() : nil
    }

    /// Texto llano para la relación entre carga aguda y crónica.
    static func lecturaCarga(_ c: Carga) -> String {
        guard let r = c.relacion else { return "Sin datos de carga todavía." }
        if r < 0.8 { return "Has hecho menos de lo que tu cuerpo ya aguanta. Hay margen para subir." }
        if r <= 1.3 { return "Carga en su punto: estás construyendo sin pasarte." }
        if r <= 1.5 { return "Vas justo por encima de lo ideal. Vigila el descanso." }
        return "Carga demasiado alta para tu fondo. Toca aflojar."
    }
}

/// Cruces de datos en lenguaje llano, a partir de las series de las últimas semanas.
enum Lecturas {
    private static let formato: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "d 'de' MMMM"
        return f
    }()

    static func todas(_ h: Historico) -> [String] {
        var frases: [String] = []

        if let ultimo = h.carga.last, ultimo.cronica > 0 {
            let relacion = ultimo.aguda / ultimo.cronica
            let pico = h.carga.max { $0.aguda < $1.aguda }
            var frase = "Carga: llevas \(Int(ultimo.aguda)) esta semana sobre un fondo de \(Int(ultimo.cronica)), relación \(String(format: "%.1f", relacion))."
            if let pico, pico.aguda > ultimo.aguda * 1.3 {
                frase += " Tu pico del mes fue \(Int(pico.aguda)) el \(formato.string(from: pico.fecha))."
            }
            frases.append(frase)
        }

        if let peor = h.sueno.min(by: { $0.horas < $1.horas }), peor.horas < 6 {
            var frase = "Tu peor noche fue la del \(formato.string(from: peor.fecha)): \(String(format: "%.1f", peor.horas)) h."
            if let vfc = h.vfc.first(where: { Calendar.current.isDate($0.fecha, inSameDayAs: peor.fecha) }) {
                frase += " Esa noche tu VFC fue \(Int(vfc.anoche)) ms"
                if let media = vfc.media { frase += " frente a una media de \(Int(media))" }
                frase += "."
            }
            frases.append(frase)
        }

        if !h.sueno.isEmpty {
            let cortas = h.sueno.filter { $0.horas < 7 }.count
            let media = h.sueno.map(\.horas).reduce(0, +) / Double(h.sueno.count)
            frases.append("Sueño: media de \(String(format: "%.1f", media)) h en \(h.sueno.count) noches; \(cortas) por debajo de 7 h.")
        }

        if h.vfc.count >= 14 {
            let reciente = h.vfc.suffix(7).map(\.anoche).reduce(0, +) / 7
            let anterior = h.vfc.dropLast(7).suffix(7).map(\.anoche).reduce(0, +) / 7
            let diferencia = reciente - anterior
            let sentido = abs(diferencia) < 3 ? "estable" : (diferencia > 0 ? "al alza" : "a la baja")
            frases.append("VFC: \(Int(reciente)) ms de media esta semana frente a \(Int(anterior)) la anterior, \(sentido).")
        }

        let semanas = Dictionary(grouping: h.volumen, by: \.inicio).mapValues { $0.map(\.horas).reduce(0, +) }
        let ordenadas = semanas.keys.sorted()
        if ordenadas.count >= 2, let actual = semanas[ordenadas[ordenadas.count - 1]],
           let previa = semanas[ordenadas[ordenadas.count - 2]], previa > 0 {
            let cambio = (actual - previa) / previa * 100
            frases.append("Volumen: \(String(format: "%.1f", actual)) h esta semana frente a \(String(format: "%.1f", previa)) h la pasada (\(cambio >= 0 ? "+" : "")\(Int(cambio)) %).")
        }
        return frases
    }
}

/// Datos reales del 13 de noviembre de 2026, guardados en la app
/// hasta que se conecte con el servidor del portátil.
enum DatosEjemplo {
    static let hoy = EstadoDia(
        dia: "2026-11-13",
        carga: Carga(aguda: 216, cronica: 356, relacion: 0.6, estadoRelacion: "LOW"),
        vfc: VFC(anocheMs: 71, mediaSemanalMs: 79, estado: "BALANCED"),
        sueno: Sueno(horas: 6.58, puntuacion: 59),
        readiness: Readiness(puntuacion: 53, nivel: "MODERATE"),
        pesoKg: 88.4,
        actividades: [
            Actividad(id: 25050781159, nombre: "S10 D4: B2 45' Z2 130W", tipo: "virtual_ride",
                      inicio: "2026-11-12 06:13:32", minutos: 45, metros: 19943, pulsoMedio: 117),
            Actividad(id: 25039157563, nombre: "Mataró Carrera", tipo: "running",
                      inicio: "2026-11-11 06:56:20", minutos: 30, metros: 4492, pulsoMedio: 141),
            Actividad(id: 25038897094, nombre: "S10 D2: B1 45' Z2 130W", tipo: "virtual_ride",
                      inicio: "2026-11-11 06:01:51", minutos: 45, metros: 19997, pulsoMedio: 115)
        ]
    )
}
