// Nota.swift
// ------------------------------------------------------------------
// Tu nota de triatleta de 0 a 100 en natación, bici y carrera, y la
// media de las tres. El 100 es el mejor del mundo de tu categoría de
// edad; el 0, el sofá.
//
// Carrera: "age grading" oficial (tablas de ruta de 2025 de Alan Jones,
// aprobadas por USATF). Nota = tiempo estándar de tu categoría en 10 km
// ÷ tu tiempo. Tu tiempo sale de la predicción de 10 km del reloj.
// Bici y natación no tienen tablas oficiales de edad: se comparan con
// el nivel mundial (FTP de 6,4 W/kg; 1500 m a 58 s por 100 m) y se les
// aplica el mismo factor de edad que a la carrera.
// ------------------------------------------------------------------

import Foundation

struct NotaDeporte: Identifiable {
    var id: String { deporte.rawValue }
    let deporte: Deporte
    let nota: Double?          // 0-100
    let marca: String          // "10 km en 59:49"
    let fuente: String         // de dónde sale
    let siguiente: String?     // qué haría falta para subir 10 puntos
}

struct NotaTriatleta {
    let deportes: [NotaDeporte]
    let edad: Int
    let categoria: String      // "M40 (40-44)"
    let factor: Double

    var global: Double? {
        let notas = deportes.compactMap(\.nota)
        return notas.isEmpty ? nil : notas.reduce(0, +) / Double(notas.count)
    }
}

enum Nota {
    /// Factores de edad para 10 km en ruta, hombres, de 30 a 85 años (tablas 2025).
    static let factores10k: [Double] = [
        1, 0.9996, 0.9985, 0.9967, 0.9942, 0.9909, 0.9869, 0.9822, 0.9767, 0.9705,
        0.9636, 0.9561, 0.9486, 0.9411, 0.9336, 0.9261, 0.9186, 0.9111, 0.9036, 0.8961,
        0.8886, 0.8811, 0.8736, 0.8661, 0.8586, 0.8511, 0.8436, 0.8361, 0.8286, 0.8211,
        0.8136, 0.8061, 0.7986, 0.7911, 0.7836, 0.7761, 0.7686, 0.7611, 0.7536, 0.7461,
        0.7386, 0.7308, 0.7223, 0.7131, 0.7033, 0.6928, 0.6816, 0.6697, 0.6572, 0.644,
        0.6301, 0.6156, 0.6004, 0.5845, 0.568, 0.5508
    ]
    /// Tiempo estándar absoluto en 10 km (segundos): 26:24.
    static let estandar10k = 1584.0
    static let wkgMundial = 6.4
    static let nadoMundial = 58.0      // segundos por 100 m

    static var nacimiento: Date {
        Calendario.fecha(UserDefaults.standard.string(forKey: "ref.nacimiento") ?? "1985-12-09") ?? Date()
    }

    static func edad(_ hoy: Date = Date()) -> Int {
        Calendar(identifier: .gregorian).dateComponents([.year], from: nacimiento, to: hoy).year ?? 40
    }

    /// Categoría de cinco años: M40 cubre de 40 a 44. Las tablas usan la edad de inicio
    /// de la categoría, así que solo cambian cuando subes de categoría.
    static func categoria(_ edad: Int) -> (nombre: String, edadTabla: Int) {
        guard edad >= 35 else { return ("Absoluta", 30) }
        let inicio = edad / 5 * 5
        return ("M\(inicio) (\(inicio)-\(inicio + 4))", inicio)
    }

    static func factor(edad: Int) -> Double {
        let i = min(max(edad - 30, 0), factores10k.count - 1)
        return factores10k[i]
    }

    static func calcular(historico h: Historico, pesoKg: Double?) -> NotaTriatleta {
        let edad = edad()
        let cat = categoria(edad)
        let f = factor(edad: cat.edadTabla)

        // Carrera
        let tiempo = h.prediccion10k ?? h.carreraEquivalente
        let carrera: NotaDeporte
        if let tiempo {
            let nota = min(100, estandar10k / f / tiempo * 100)
            let objetivo = estandar10k / f / ((nota + 10) / 100)
            carrera = NotaDeporte(
                deporte: .carrera, nota: nota, marca: "10 km en \(reloj(tiempo))",
                fuente: h.prediccion10k != nil ? "Predicción de tu reloj" : "Estimado con tu mejor carrera reciente",
                siguiente: nota < 90 ? "+10 puntos: 10 km en \(reloj(objetivo))" : nil)
        } else {
            carrera = NotaDeporte(deporte: .carrera, nota: nil, marca: "Sin datos",
                                  fuente: "Ni predicción del reloj ni carreras de 3 km o más", siguiente: nil)
        }

        // Bici
        let peso = pesoKg ?? h.peso.last?.valor ?? 88
        let wkg = Referencias.ftp / peso
        let notaBici = min(100, wkg / (wkgMundial * f) * 100)
        let bici = NotaDeporte(
            deporte: .bici, nota: notaBici,
            marca: "\(Int(Referencias.ftp)) W · \(String(format: "%.2f", wkg)) W/kg",
            fuente: "Tu FTP con \(String(format: "%.1f", peso)) kg",
            siguiente: notaBici < 90 ? "+10 puntos: \(Int((wkgMundial * f * (notaBici + 10) / 100 * peso).rounded())) W, o \(Int(Referencias.ftp)) W con \(String(format: "%.1f", Referencias.ftp / (wkgMundial * f * (notaBici + 10) / 100))) kg" : nil)

        // Natación: mejor ritmo de los últimos 60 días en sesiones de 1000 m o más
        let natacion: NotaDeporte
        if let mejor = h.nadoLargo.map(\.valor).min() {
            let nota = min(100, nadoMundial / f / mejor * 100)
            let objetivo = nadoMundial / f / ((nota + 10) / 100)
            natacion = NotaDeporte(
                deporte: .agua, nota: nota, marca: "\(reloj(mejor)) por 100 m",
                fuente: "Tu mejor sesión de 1000 m o más",
                siguiente: nota < 90 ? "+10 puntos: \(reloj(objetivo)) por 100 m" : nil)
        } else {
            natacion = NotaDeporte(deporte: .agua, nota: nil, marca: "Sin datos",
                                   fuente: "Sin sesiones de 1000 m o más en 60 días", siguiente: nil)
        }

        return NotaTriatleta(deportes: [natacion, bici, carrera], edad: edad, categoria: cat.nombre, factor: f)
    }

    static func reloj(_ segundos: Double) -> String {
        let total = Int(segundos.rounded())
        let h = total / 3600, m = total % 3600 / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    static func nivel(_ nota: Double) -> String {
        switch nota {
        case 90...: return "Clase mundial"
        case 80..<90: return "Nivel nacional"
        case 70..<80: return "Nivel regional"
        case 60..<70: return "Aficionado avanzado"
        case 45..<60: return "Aficionado"
        case 30..<45: return "En forma"
        default: return "Empezando"
        }
    }

    // MARK: - Historia, para ver si sube o baja

    private static let claveHistoria = "nota.historia.v1"

    /// Guarda la nota del día (una por día) y devuelve la de hace unos 30 días.
    static func registrar(_ n: NotaTriatleta) -> [String: Double] {
        var historia = (UserDefaults.standard.dictionary(forKey: claveHistoria) as? [String: [String: Double]]) ?? [:]
        var hoy: [String: Double] = [:]
        for d in n.deportes { if let nota = d.nota { hoy[d.deporte.rawValue] = nota } }
        if let g = n.global { hoy["Global"] = g }
        historia[Calendario.texto(Date())] = hoy
        let limite = Calendario.texto(Date().addingTimeInterval(-400 * 86400))
        historia = historia.filter { $0.key >= limite }
        UserDefaults.standard.set(historia, forKey: claveHistoria)
        let hace30 = Calendario.texto(Date().addingTimeInterval(-30 * 86400))
        let anteriores = historia.keys.filter { $0 <= hace30 }.sorted()
        if let clave = anteriores.last { return historia[clave] ?? [:] }
        return historia.keys.sorted().first.flatMap { $0 < Calendario.texto(Date()) ? historia[$0] : nil } ?? [:]
    }
}
