// Logros.swift
// ------------------------------------------------------------------
// Hitos que se desbloquean solos con tus datos reales. La fecha en que
// se consigue cada uno queda guardada.
// ------------------------------------------------------------------

import Foundation

struct Logro: Identifiable {
    let id: String
    let titulo: String
    let detalle: String
    let icono: String
    var conseguido: Bool
    var fecha: String?
    var categoria = "Constancia"
}

enum Logros {
    private static let clave = "logros.v1"

    static func calcular(plan: [SesionPlan], historico h: Historico?, pesoKg: Double?) -> [Logro] {
        let hechas = h?.sesiones ?? []
        let cruce = Analisis.cumplimiento(plan: plan, hechas: hechas, hoy: Calendario.texto(Date()))
        let cumplidas = cruce.filter { $0.estado == .hecha }.count
        let racha = Analisis.constancia(hechas, hoy: Date(), plan: plan).mejorRacha
        let pesos = (h?.peso.map(\.valor) ?? []) + [pesoKg].compactMap { $0 }
        let minimo = pesos.min() ?? 99
        let escalera = Escalera.calcular(plan: plan, hechas: hechas)
        func peldano(_ m: Int) -> Bool { escalera.peldanos.first { $0.minutos == m }?.estado == 2 }
        let porSemana = Dictionary(grouping: cruce) { c in Calendario.fecha(c.sesion.fecha).map(Calendario.semanaTemporada) ?? 0 }
        let tresEstrellas = porSemana.values.contains { lista in
            !lista.contains { $0.estado == .pendiente } && Travesia.estrellas(Analisis.porcentaje(lista)) == 3
        }
        let jefe = cruce.contains { $0.sesion.nombre.localizedCaseInsensitiveContains("test") && $0.estado == .hecha }
        let nota = h.map { Nota.calcular(historico: $0, pesoKg: pesoKg).global ?? 0 } ?? 0

        var lista = [
            Logro(id: "plan10", titulo: "10 sesiones", detalle: "Cumple 10 sesiones del plan", icono: "checkmark.seal.fill", conseguido: cumplidas >= 10),
            Logro(id: "plan25", titulo: "25 sesiones", detalle: "Cumple 25 sesiones del plan", icono: "checkmark.seal.fill", conseguido: cumplidas >= 25),
            Logro(id: "plan50", titulo: "50 sesiones", detalle: "Cumple 50 sesiones del plan", icono: "rosette", conseguido: cumplidas >= 50),
            Logro(id: "estrellas", titulo: "Semana perfecta", detalle: "Una etapa con tres estrellas", icono: "star.fill", conseguido: tresEstrellas),
            Logro(id: "racha7", titulo: "Racha de 7", detalle: "7 días seguidos entrenando", icono: "flame.fill", conseguido: racha >= 7),
            Logro(id: "racha14", titulo: "Racha de 14", detalle: "14 días seguidos entrenando", icono: "flame.fill", conseguido: racha >= 14),
            Logro(id: "tramo6",  titulo: "Tramos de 6'", detalle: "Abre el peldaño de 6' sin dolor", icono: "figure.run", conseguido: peldano(6)),
            Logro(id: "tramo10",  titulo: "Tramos de 10'", detalle: "Abre el peldaño de 10' sin dolor", icono: "figure.run", conseguido: peldano(10)),
            Logro(id: "venda",  titulo: "Fuera la venda", detalle: "20' seguidos corriendo sin dolor", icono: "bandage", conseguido: peldano(20)),
            Logro(id: "peso88",  titulo: "Bajo 88 kg", detalle: "Pésate por debajo de 88 kg", icono: "scalemass.fill", conseguido: minimo < 88),
            Logro(id: "peso85",  titulo: "Bajo 85 kg", detalle: "Pésate por debajo de 85 kg", icono: "scalemass.fill", conseguido: minimo < 85),
            Logro(id: "peso82",  titulo: "Objetivo de peso", detalle: "Llega a \(Int(Referencias.pesoObjetivo)) kg", icono: "trophy.fill", conseguido: minimo <= Referencias.pesoObjetivo),
            Logro(id: "jefe",  titulo: "Jefe superado", detalle: "Haz un test de FTP del plan", icono: "crown.fill", conseguido: jefe),
            Logro(id: "ftp210",  titulo: "210 W", detalle: "FTP de 210 W o más", icono: "bolt.fill", conseguido: Referencias.ftp >= 210),
            Logro(id: "ftp230",  titulo: "230 W", detalle: "FTP de 230 W o más", icono: "bolt.fill", conseguido: Referencias.ftp >= 230),
            Logro(id: "nota45",  titulo: "Nota 45", detalle: "Nota global de triatleta de 45", icono: "chart.line.uptrend.xyaxis", conseguido: nota >= 45),
            Logro(id: "nota50",  titulo: "Nota 50", detalle: "Nota global de triatleta de 50", icono: "chart.line.uptrend.xyaxis", conseguido: nota >= 50)
        ]

        lista += deportes(hechas)

        for i in lista.indices where lista[i].categoria == "Constancia" { lista[i].categoria = categoria(lista[i].id) }

        // Guarda la fecha de cada logro la primera vez que se consigue.
        let guardadas = UserDefaults.standard.dictionary(forKey: clave) as? [String: String]
        var fechas = guardadas ?? [:]
        // Lo conseguido una vez no se pierde aunque el entreno salga de los 60 días que lee la app.
        for i in lista.indices where fechas[lista[i].id] != nil { lista[i].conseguido = true }
        for i in lista.indices where lista[i].conseguido {
            // La primera vez que se abre esta versión, lo ya conseguido no cuenta como nuevo.
            if fechas[lista[i].id] == nil { fechas[lista[i].id] = guardadas == nil ? "antes" : Calendario.texto(Date()) }
            lista[i].fecha = fechas[lista[i].id]
        }
        UserDefaults.standard.set(fechas, forKey: clave)
        return lista
    }

    static let categorias = ["Constancia", "Bici", "Carrera", "Natación", "Cuerpo", "Nota"]

    /// Categoría de los logros fijos.
    private static func categoria(_ id: String) -> String {
        if ["tramo6", "tramo10", "venda"].contains(id) { return "Carrera" }
        if ["peso88", "peso85", "peso82"].contains(id) { return "Cuerpo" }
        if ["jefe", "ftp210", "ftp230"].contains(id) { return "Bici" }
        if ["nota45", "nota50"].contains(id) { return "Nota" }
        return "Constancia"
    }

    /// Hitos de duración y de marcas, sacados de tus actividades de Garmin.
    private static func deportes(_ hechas: [SesionHecha]) -> [Logro] {
        let bicis = hechas.filter { $0.deporte == "Bici" }
        let carreras = hechas.filter { $0.deporte == "Carrera" }
        let nados = hechas.filter { $0.deporte == "Agua" }
        let biciMax = bicis.map(\.minutos).max() ?? 0
        let carreraMax = carreras.map(\.minutos).max() ?? 0
        let nadoMax = nados.compactMap(\.metros).max() ?? 0
        // Mejor tiempo en 5 y 10 km: ritmo medio de carreras de esa distancia o más.
        func mejor(_ metros: Double) -> Double? {
            carreras.compactMap { c in
                guard let m = c.metros, m >= metros * 0.99, c.minutos > 0 else { return nil }
                return c.minutos * metros / m
            }.min()
        }
        let mejor5 = mejor(5000) ?? .infinity
        let mejor10 = mejor(10000) ?? .infinity
        let mejorNado = nados.compactMap { n -> Double? in
            guard let m = n.metros, m >= 1000 else { return nil }
            return n.minutos * 60 / (m / 100)
        }.min() ?? .infinity

        var lista: [Logro] = []
        for (min, texto) in [(90, "1 h 30"), (120, "2 h"), (135, "2 h 15"), (150, "2 h 30"), (180, "3 h"), (240, "4 h")] {
            lista.append(Logro(id: "bici\(min)", titulo: "Bici de \(texto)", detalle: "Una sesión de bici de \(texto) o más",
                               icono: "bicycle", conseguido: biciMax >= Double(min) - 1, categoria: "Bici"))
        }
        for (min, texto) in [(30, "30'"), (45, "45'"), (60, "1 h"), (90, "1 h 30"), (120, "2 h")] {
            lista.append(Logro(id: "correr\(min)", titulo: "Correr \(texto)", detalle: "Una carrera de \(texto) o más",
                               icono: "figure.run", conseguido: carreraMax >= Double(min) - 1, categoria: "Carrera"))
        }
        for (min, texto) in [(25, "25'"), (22, "22'"), (20, "20'")] {
            lista.append(Logro(id: "5k\(min)", titulo: "5 km en menos de \(texto)", detalle: "Correr 5 km por debajo de \(texto)",
                               icono: "stopwatch.fill", conseguido: mejor5 < Double(min), categoria: "Carrera"))
        }
        for (min, texto) in [(50, "50'"), (47, "47'"), (45, "45'"), (43, "43'"), (40, "40'")] {
            lista.append(Logro(id: "10k\(min)", titulo: "10 km en menos de \(texto)", detalle: "Correr 10 km por debajo de \(texto)",
                               icono: "stopwatch.fill", conseguido: mejor10 < Double(min), categoria: "Carrera"))
        }
        for (m, texto) in [(2000, "2 km"), (2500, "2,5 km"), (3000, "3 km"), (4000, "4 km")] {
            lista.append(Logro(id: "nado\(m)", titulo: "Nadar \(texto)", detalle: "Una sesión de \(texto) o más",
                               icono: "figure.pool.swim", conseguido: nadoMax >= Double(m), categoria: "Natación"))
        }
        for (seg, texto) in [(130, "2:10"), (120, "2:00"), (110, "1:50"), (100, "1:40")] {
            lista.append(Logro(id: "ritmo\(seg)", titulo: "Bajar de \(texto)", detalle: "Ritmo medio por debajo de \(texto) por 100 m en 1000 m o más",
                               icono: "drop.fill", conseguido: mejorNado < Double(seg), categoria: "Natación"))
        }
        return lista
    }

    /// Logros conseguidos hoy, para celebrarlos.
    static func nuevos(_ lista: [Logro]) -> [Logro] {
        lista.filter { $0.fecha == Calendario.texto(Date()) }
    }
}
