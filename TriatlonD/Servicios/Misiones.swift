// Misiones.swift
// ------------------------------------------------------------------
// Misiones del día que premian también la recuperación, y comodines
// para salvar la racha un día justificado (uno cada 28 días).
// ------------------------------------------------------------------

import Foundation

struct Mision: Identifiable {
    let id: String
    let titulo: String
    let detalle: String
    let icono: String
    let puntos: Int
    let cumplida: Bool
}

enum Misiones {
    private static let clave = "misiones.v1"   // [dia: [idMision]]

    /// Las tres misiones de hoy, comprobadas con tus datos.
    static func deHoy(plan: [SesionPlan], historico h: Historico?, estado e: EstadoDia) -> [Mision] {
        let hoy = Calendario.texto(Date())
        let cruce = Analisis.cumplimiento(plan: plan, hechas: h?.sesiones ?? [], hoy: hoy)
        let deHoy = cruce.filter { $0.sesion.fecha == hoy }
        let entrenoHecho = !deHoy.isEmpty && deHoy.allSatisfy { $0.estado == .hecha || $0.estado == .aMedias }
        let descanso = deHoy.isEmpty
        let horas = e.sueno.horas ?? 0
        // Sensaciones del último entreno hecho (hoy o ayer)
        let ayer = Calendario.texto(Date().addingTimeInterval(-86400))
        let recientes = cruce.filter { ($0.sesion.fecha == hoy || $0.sesion.fecha == ayer) && ($0.estado == .hecha || $0.estado == .aMedias) }
        let apuntadas = !recientes.isEmpty && recientes.allSatisfy { c in
            let s = Sensaciones.de(dia: c.sesion.fecha, deporte: c.sesion.deporte)
            return s.esfuerzo != nil && s.animo != nil
        }

        var lista = [
            Mision(id: "sueno", titulo: "Dormir 7 h", detalle: String(format: "Anoche: %.1f h", horas),
                   icono: "moon.zzz.fill", puntos: 20, cumplida: horas >= 7),
            descanso
                ? Mision(id: "descanso", titulo: "Descansar de verdad", detalle: "Hoy no toca entrenar: recuperar también es entrenar",
                         icono: "leaf.fill", puntos: 20, cumplida: true)
                : Mision(id: "entreno", titulo: "Cumplir lo de hoy", detalle: deHoy.map(\.sesion.titulo).joined(separator: " + "),
                         icono: "flag.checkered", puntos: 20, cumplida: entrenoHecho)
        ]
        if !recientes.isEmpty {
            lista.append(Mision(id: "sensaciones", titulo: "Apuntar sensaciones", detalle: "Esfuerzo y ánimo en el parte del entreno",
                                icono: "square.and.pencil", puntos: 10, cumplida: apuntadas))
        }
        registrar(lista.filter(\.cumplida).map(\.id), dia: hoy)
        return lista
    }

    private static func registrar(_ ids: [String], dia: String) {
        var todas = UserDefaults.standard.dictionary(forKey: clave) as? [String: [String]] ?? [:]
        let previas = Set(todas[dia] ?? [])
        todas[dia] = Array(previas.union(ids)).sorted()
        UserDefaults.standard.set(todas, forKey: clave)
    }

    /// Puntos acumulados por misiones cumplidas.
    static var puntosTotales: Int {
        let todas = UserDefaults.standard.dictionary(forKey: clave) as? [String: [String]] ?? [:]
        let valor = ["sueno": 20, "descanso": 20, "entreno": 20, "sensaciones": 10]
        return todas.values.flatMap { $0 }.map { valor[$0] ?? 0 }.reduce(0, +)
    }
}

enum Comodines {
    private static let clave = "comodines.v1"

    static var usados: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: clave) ?? [])
    }

    /// Un comodín cada 28 días.
    static var disponible: Bool {
        let limite = Calendario.texto(Date().addingTimeInterval(-28 * 86400))
        return !usados.contains { $0 > limite }
    }

    static func usar(_ dia: String) {
        var lista = usados
        lista.insert(dia)
        UserDefaults.standard.set(Array(lista).sorted(), forKey: clave)
    }

    static func quitar(_ dia: String) {
        var lista = usados
        lista.remove(dia)
        UserDefaults.standard.set(Array(lista).sorted(), forKey: clave)
    }
}
