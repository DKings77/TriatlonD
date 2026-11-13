// SesionPlan.swift
// ------------------------------------------------------------------
// Una sesión del plan. El plan vive en el iPhone (no en el código):
// se puede mover de día y la app lo deja igual en intervals.icu.
// ------------------------------------------------------------------

import SwiftUI

enum Deporte: String {
    case bici = "Bici"
    case agua = "Agua"
    case carrera = "Carrera"
    case fuerza = "Fuerza"

    var color: Color {
        switch self {
        case .bici: return Tema.bici
        case .agua: return Tema.natacion
        case .carrera: return Tema.carrera
        case .fuerza: return Tema.fuerza
        }
    }
}

struct SesionPlan: Codable, Identifiable, Equatable {
    var id: String            // estable, p. ej. "S11-C1"
    var fecha: String         // yyyy-MM-dd
    var tipo: String          // tipo de intervals.icu: Ride, Run, WeightTraining, Swim
    var interior: Bool
    var nombre: String        // "S11 D1: C1 35' Z2 2/2 | estructura"
    var pasos: String         // formato de intervals.icu, o texto libre si no se envía
    var seEnvia: Bool         // false: natación y test, que no pasan por intervals.icu
    var xp: Int
    var eventoId: Int?        // id en intervals.icu una vez enviada

    var deporte: Deporte {
        switch tipo {
        case "Ride": return .bici
        case "Run": return .carrera
        case "Swim": return .agua
        default: return .fuerza
        }
    }

    /// Parte del nombre antes de la barra: "S11 D1: C1 35' Z2 2/2".
    var titulo: String {
        nombre.components(separatedBy: " | ").first ?? nombre
    }

    /// Parte del nombre tras la barra: la estructura de series.
    var estructura: String? {
        let partes = nombre.components(separatedBy: " | ")
        return partes.count > 1 ? partes[1] : nil
    }

    /// Cambia de día y ajusta el "S11 D4" del nombre a la semana y día nuevos.
    mutating func mover(a nueva: Date) {
        fecha = Calendario.texto(nueva)
        let prefijo = "S\(Calendario.semanaTemporada(nueva)) D\(Calendario.diaSemana(nueva))"
        if let rango = nombre.range(of: #"^S\d+ D\d"#, options: .regularExpression) {
            nombre.replaceSubrange(rango, with: prefijo)
        }
    }

    /// Los pasos explicados con vatios y pulsaciones reales.
    func pasosLegibles() -> [PasoLegible] {
        pasos.split(separator: "\n", omittingEmptySubsequences: true).map { linea in
            let texto = linea.trimmingCharacters(in: .whitespaces)
            guard texto.hasPrefix("- ") else {
                if texto.hasSuffix("x"), let veces = Int(texto.dropLast()) {
                    return PasoLegible(texto: "Repetir \(veces) veces", detalle: nil, esCabecera: true)
                }
                return PasoLegible(texto: texto, detalle: nil, esCabecera: true)
            }
            let partes = texto.dropFirst(2).split(separator: " ").map(String.init)
            var duracion = partes.first ?? ""
            if duracion.hasSuffix("m"), let minutos = Int(duracion.dropLast()) {
                duracion = "\(minutos)'"
            }
            var detalle: String?
            if partes.count >= 2 {
                let objetivo = partes[1]
                if objetivo.hasSuffix("%"), let porcentaje = Double(objetivo.dropLast()) {
                    let vatios = Int((porcentaje * Referencias.ftp / 100).rounded())
                    detalle = "\(Int(porcentaje)) % del FTP · \(vatios) W"
                } else if objetivo.hasPrefix("Z"), let zona = Int(objetivo.dropFirst()),
                          let rango = Referencias.zonasPulso[zona] {
                    detalle = "Zona \(zona) · \(rango)"
                } else {
                    detalle = partes.dropFirst().joined(separator: " ")
                }
            }
            return PasoLegible(texto: duracion, detalle: detalle, esCabecera: false)
        }
    }
}

struct PasoLegible: Identifiable {
    let id = UUID()
    let texto: String
    let detalle: String?
    let esCabecera: Bool
}

/// Tus referencias, iguales que en Garmin e intervals.icu.
enum Referencias {
    static let ftp = 200.0
    static let zonasPulso: [Int: String] = [
        1: "108-135 ppm",
        2: "136-150 ppm",
        3: "151-159 ppm",
        4: "160-170 ppm",
        5: "171-187 ppm"
    ]
}

enum Calendario {
    private static let gregoriano = Calendar(identifier: .gregorian)

    private static let formato: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let nombresDia = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]

    static func fecha(_ texto: String) -> Date? { formato.date(from: texto) }
    static func texto(_ fecha: Date) -> String { formato.string(from: fecha) }

    /// Lunes = 1 … domingo = 7.
    static func diaSemana(_ fecha: Date) -> Int {
        let dia = gregoriano.component(.weekday, from: fecha)
        return dia == 1 ? 7 : dia - 1
    }

    /// La semana del 19 de octubre de 2026 es la S7.
    static func semanaTemporada(_ fecha: Date) -> Int {
        guard let inicio = Calendario.fecha("2026-10-19") else { return 0 }
        let dias = gregoriano.dateComponents([.day], from: inicio, to: fecha).day ?? 0
        return 7 + Int((Double(dias) / 7).rounded(.down))
    }

    /// "Lun 16"
    static func etiqueta(_ texto: String) -> String {
        guard let dia = fecha(texto) else { return texto }
        return "\(nombresDia[diaSemana(dia) - 1]) \(gregoriano.component(.day, from: dia))"
    }
}

/// El plan con el que arranca la app: fin de semana de la S10 y la S11 entera.
enum PlanInicial {
    private static let carrera4 = "Calentamiento\n- 5m Z1 HR\n\n5x\n- 4m Z2 HR\n- 1m Z1 HR\n\nEnfriamiento\n- 5m Z1 HR"
    private static let carrera6 = "Calentamiento\n- 5m Z1 HR\n\n4x\n- 6m Z2 HR\n- 1m Z1 HR\n\nEnfriamiento\n- 5m Z1 HR"
    private static let bici60 = "- 10m 60%\n- 40m 70%\n- 10m 55%"

    static let sesiones: [SesionPlan] = [
        SesionPlan(id: "S10-C2", fecha: "2026-11-14", tipo: "Run", interior: false,
                   nombre: "S10 D6: C2 35' Z2 | 5' cal + 5 x (4' Z2 + 1' caminar) + 5' enf",
                   pasos: carrera4, seEnvia: true, xp: 100),
        SesionPlan(id: "S10-B3", fecha: "2026-11-15", tipo: "Ride", interior: true,
                   nombre: "S10 D7: B3 60' Z2 140W | 10' cal + 40' Z2 140W + 10' enf",
                   pasos: bici60, seEnvia: true, xp: 100),
        SesionPlan(id: "S11-F1", fecha: "2026-11-16", tipo: "WeightTraining", interior: true,
                   nombre: "S11 D1: F1 50' 1/2", pasos: "- 50m", seEnvia: true, xp: 100),
        SesionPlan(id: "S11-C1", fecha: "2026-11-16", tipo: "Run", interior: false,
                   nombre: "S11 D1: C1 35' Z2 2/2 | 5' cal + 5 x (4' Z2 + 1' caminar) + 5' enf",
                   pasos: carrera4, seEnvia: true, xp: 100),
        SesionPlan(id: "S11-B1", fecha: "2026-11-17", tipo: "Ride", interior: true,
                   nombre: "S11 D2: B1 60' Z2 140W | 10' cal + 40' Z2 140W + 10' enf",
                   pasos: bici60, seEnvia: true, xp: 100),
        SesionPlan(id: "S11-F2", fecha: "2026-11-18", tipo: "WeightTraining", interior: true,
                   nombre: "S11 D3: F2 35' 1/2", pasos: "- 35m", seEnvia: true, xp: 100),
        SesionPlan(id: "S11-N1", fecha: "2026-11-18", tipo: "Swim", interior: true,
                   nombre: "S11 D3: N1 1700m Z2 2/2 | 300 suave + 8 x 50 técnica + 3 x 300 aeróbico + 100 suave",
                   pasos: "300 m suave\n8 x 50 m técnica, 20'' de descanso\n3 x 300 m aeróbico a 2:15-2:25, 30'' de descanso\n100 m suave",
                   seEnvia: false, xp: 100),
        SesionPlan(id: "S11-B2", fecha: "2026-11-19", tipo: "Ride", interior: true,
                   nombre: "S11 D4: B2 55' Z2 | 10' cal + 20' Z2 140W + 3 x (3' 172W + 3' rec) + 7' enf",
                   pasos: "- 10m 60%\n- 20m 70%\n- 3m 86%\n- 3m 60%\n- 3m 86%\n- 3m 60%\n- 3m 86%\n- 3m 60%\n- 7m 55%",
                   seEnvia: true, xp: 100),
        SesionPlan(id: "S11-F3", fecha: "2026-11-20", tipo: "WeightTraining", interior: true,
                   nombre: "S11 D5: F3 35' 1/2", pasos: "- 35m", seEnvia: true, xp: 100),
        SesionPlan(id: "S11-N2", fecha: "2026-11-20", tipo: "Swim", interior: true,
                   nombre: "S11 D5: N2 1900m Z2 2/2 | 300 suave + 8 x 50 técnica + 4 x 250 aeróbico + 200 suave",
                   pasos: "300 m suave\n8 x 50 m técnica, 20'' de descanso\n4 x 250 m aeróbico a 2:15-2:25, 30'' de descanso\n200 m suave",
                   seEnvia: false, xp: 100),
        SesionPlan(id: "S11-TEST", fecha: "2026-11-21", tipo: "Ride", interior: true,
                   nombre: "S11 D6: B3 Test de FTP 1/2 | test de rampa de Rouvy",
                   pasos: "Se hace con el test de rampa propio de Rouvy.\nEs el jefe de la región: supera tus 200 W.",
                   seEnvia: false, xp: 100),
        SesionPlan(id: "S11-C2", fecha: "2026-11-21", tipo: "Run", interior: false,
                   nombre: "S11 D6: C2 38' Z2 2/2 | 5' cal + 4 x (6' Z2 + 1' caminar) + 5' enf",
                   pasos: carrera6, seEnvia: true, xp: 100)
    ]
}
