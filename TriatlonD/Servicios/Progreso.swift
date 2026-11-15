// Progreso.swift
// ------------------------------------------------------------------
// Cálculos del bloque 1: horas previstas por semana, el parte de cada
// entreno (previsto frente a hecho), el diario de dolor y la escalera
// de vuelta a correr calculada con tus carreras reales.
// ------------------------------------------------------------------

import Foundation

// MARK: - Horas previstas

struct TotalSemana {
    var semana: Int
    var minutos: [Deporte: Double]
    var total: Double { minutos.values.reduce(0, +) }
}

enum Totales {
    /// Minutos de una sesión: por sus pasos; la natación por sus metros
    /// (a unos 2:20 por 100 m, con descansos) y el test de FTP, 45'.
    static func minutos(_ sesion: SesionPlan) -> Double {
        if let m = Analisis.minutosPlan(sesion) { return m }
        if sesion.tipo == "Swim",
           let rango = sesion.nombre.range(of: #"\d{3,4}m"#, options: .regularExpression),
           let metros = Double(sesion.nombre[rango].dropLast()) {
            return (metros / 100 * 2.6).rounded()
        }
        if sesion.nombre.localizedCaseInsensitiveContains("test") { return 45 }
        if let rango = sesion.nombre.range(of: #"\d+'"#, options: .regularExpression),
           let m = Double(sesion.nombre[rango].dropLast()) {
            return m
        }
        return 0
    }

    static func porSemana(_ sesiones: [SesionPlan]) -> [TotalSemana] {
        var mapa: [Int: [Deporte: Double]] = [:]
        for s in sesiones {
            guard let fecha = Calendario.fecha(s.fecha) else { continue }
            let semana = Calendario.semanaTemporada(fecha)
            mapa[semana, default: [:]][s.deporte, default: 0] += minutos(s)
        }
        return mapa.keys.sorted().map { TotalSemana(semana: $0, minutos: mapa[$0] ?? [:]) }
    }

    /// Media de horas reales de las últimas cuatro semanas terminadas.
    static func mediaReciente(_ h: Historico?) -> Double? {
        guard let h else { return nil }
        let lunesActual = Calendario.fecha(Calendario.texto(Date())).map { hoy in
            hoy.addingTimeInterval(-Double(Calendario.diaSemana(hoy) - 1) * 86400)
        } ?? Date()
        let grupos = Dictionary(grouping: h.volumen.filter { $0.inicio < lunesActual.addingTimeInterval(-3600) }, by: \.inicio)
        let semanas = grupos.keys.sorted().suffix(4)
        guard !semanas.isEmpty else { return nil }
        let horas = semanas.map { grupos[$0]!.map(\.horas).reduce(0, +) }
        return horas.reduce(0, +) / Double(horas.count)
    }

    static func texto(_ minutos: Double) -> String {
        let h = Int(minutos) / 60, m = Int(minutos) % 60
        return h > 0 ? "\(h) h \(String(format: "%02d", m))'" : "\(m)'"
    }
}

// MARK: - Parte de un entreno

struct Parte {
    let sesion: SesionPlan
    let estado: EstadoSesion
    let minutosPrevistos: Double?
    let minutosHechos: Double
    let pulsoMedio: Double?
    let objetivoPulso: (desde: Int, hasta: Int)?
    let potenciaMedia: Double?
    let objetivoPotencia: Double?
    let puntos: Int
}

enum Partes {
    /// Zona de pulso que más minutos ocupa en los pasos ("- 4m Z2 HR").
    static func zonaPrincipal(_ sesion: SesionPlan) -> Int? {
        var minutos: [Int: Double] = [:]
        recorrer(sesion) { m, objetivo in
            if objetivo.hasPrefix("Z"), let z = Int(objetivo.dropFirst()) { minutos[z, default: 0] += m }
        }
        return minutos.max { $0.value < $1.value }?.key
    }

    /// Vatios medios previstos según los porcentajes de FTP de los pasos.
    static func potenciaPrevista(_ sesion: SesionPlan) -> Double? {
        var suma = 0.0, total = 0.0
        recorrer(sesion) { m, objetivo in
            if objetivo.hasSuffix("%"), let pct = Double(objetivo.dropLast()) {
                suma += pct * m
                total += m
            }
        }
        return total > 0 ? suma / total * Referencias.ftp / 100 : nil
    }

    /// Tramo continuo más largo de correr en Z2 o más, en minutos.
    static func tramoCorriendo(_ sesion: SesionPlan) -> Int {
        var mayor = 0.0
        recorrer(sesion) { m, objetivo in
            if objetivo.hasPrefix("Z"), let z = Int(objetivo.dropFirst()), z >= 2 { mayor = max(mayor, m) }
        }
        return Int(mayor)
    }

    /// Recorre los pasos teniendo en cuenta las repeticiones ("5x").
    private static func recorrer(_ sesion: SesionPlan, _ visitar: (Double, String) -> Void) {
        var veces = 1.0
        for linea in sesion.pasos.components(separatedBy: "\n") {
            let texto = linea.trimmingCharacters(in: .whitespaces)
            if texto.isEmpty { veces = 1; continue }
            if texto.hasSuffix("x"), let n = Double(texto.dropLast()) { veces = n; continue }
            guard texto.hasPrefix("- ") else { continue }
            let partes = texto.dropFirst(2).split(separator: " ").map(String.init)
            guard let duracion = partes.first, duracion.hasSuffix("m"),
                  let m = Double(duracion.dropLast()) else { continue }
            visitar(m * veces, partes.count > 1 ? partes[1] : "")
        }
    }

    /// El parte del último entreno del plan hecho en los tres últimos días.
    static func ultimo(plan: [SesionPlan], hechas: [SesionHecha]) -> Parte? {
        let hoy = Calendario.texto(Date())
        let limite = Calendario.texto(Date().addingTimeInterval(-3 * 86400))
        let cruce = Analisis.cumplimiento(plan: plan, hechas: hechas, hoy: hoy)
            .filter { ($0.estado == .hecha || $0.estado == .aMedias) && $0.sesion.fecha >= limite }
        // El día más reciente con algo hecho; dentro de él, mejor el cardio que la fuerza.
        guard let ultimoDia = cruce.last?.sesion.fecha else { return nil }
        let delUltimo = cruce.filter { $0.sesion.fecha == ultimoDia }
        guard let c = delUltimo.last(where: { $0.sesion.deporte != .fuerza }) ?? delUltimo.last else { return nil }
        let delDia = hechas.filter { $0.dia == c.sesion.fecha && $0.deporte == c.sesion.deporte.rawValue }
        let minutos = delDia.map(\.minutos).reduce(0, +)
        func media(_ valor: KeyPath<SesionHecha, Double?>) -> Double? {
            let pares = delDia.compactMap { s in s[keyPath: valor].map { ($0, s.minutos) } }
            let peso = pares.map(\.1).reduce(0, +)
            return peso > 0 ? pares.map { $0.0 * $0.1 }.reduce(0, +) / peso : nil
        }
        return Parte(
            sesion: c.sesion, estado: c.estado,
            minutosPrevistos: c.minutosPlan, minutosHechos: minutos,
            pulsoMedio: media(\.pulso),
            objetivoPulso: zonaPrincipal(c.sesion).flatMap { Referencias.rango(zona: $0) },
            potenciaMedia: media(\.potencia),
            objetivoPotencia: potenciaPrevista(c.sesion),
            puntos: c.estado == .hecha ? c.sesion.xp : c.sesion.xp / 2)
    }
}

// MARK: - Diario de dolor

struct RegistroDolor: Codable, Identifiable {
    var id: String { dia }
    let dia: String
    let valor: Int
}

enum DiarioDolor {
    private static let clave = "dolor.diario.v1"

    static var registros: [RegistroDolor] {
        guard let datos = UserDefaults.standard.data(forKey: clave),
              let lista = try? JSONDecoder().decode([RegistroDolor].self, from: datos) else { return [] }
        return lista.sorted { $0.dia < $1.dia }
    }

    static func apuntar(_ valor: Int, dia: String) {
        var lista = registros.filter { $0.dia != dia }
        lista.append(RegistroDolor(dia: dia, valor: valor))
        if let datos = try? JSONEncoder().encode(lista.sorted { $0.dia < $1.dia }) {
            UserDefaults.standard.set(datos, forKey: clave)
        }
        // El último valor se sigue guardando aparte para la pantalla y el entrenador.
        if dia == lista.map(\.dia).max() {
            UserDefaults.standard.set(valor, forKey: "dolorUltimaCarrera")
        }
    }

    static func valor(dia: String) -> Int? {
        registros.first { $0.dia == dia }?.valor
    }
}

// MARK: - Escalera de vuelta a correr

struct Peldano: Identifiable {
    var id: Int { minutos }
    let minutos: Int
    let estado: Int        // 2 hecho, 1 siguiente, 0 bloqueado
    let validas: Int       // carreras que ya cuentan para abrirlo
}

struct Escalera {
    let peldanos: [Peldano]
    var actual: Int { peldanos.first { $0.estado == 1 }?.minutos ?? peldanos.last?.minutos ?? 3 }
    var validas: Int { peldanos.first { $0.estado == 1 }?.validas ?? 0 }

    static let tramos = [3, 4, 6, 10, 20]
    /// Tramos de 3' y 4' ya superados antes de que existiera la app.
    static let superadosAntes = 4

    /// Un peldaño se abre con dos carreras con tramos de esa duración o más y dolor de 0 a 2.
    static func calcular(plan: [SesionPlan], hechas: [SesionHecha]) -> Escalera {
        let hoy = Calendario.texto(Date())
        let carreras = Analisis.cumplimiento(plan: plan.filter { $0.tipo == "Run" }, hechas: hechas, hoy: hoy)
            .filter { $0.estado == .hecha || $0.estado == .aMedias }
            .map { (tramo: Partes.tramoCorriendo($0.sesion), dolor: DiarioDolor.valor(dia: $0.sesion.fecha)) }
        var siguienteMarcado = false
        let lista = tramos.map { minutos -> Peldano in
            let validas = carreras.filter { $0.tramo >= minutos && ($0.dolor ?? 99) <= 2 }.count
            if minutos <= superadosAntes || validas >= 2 {
                return Peldano(minutos: minutos, estado: 2, validas: max(validas, 2))
            }
            if !siguienteMarcado {
                siguienteMarcado = true
                return Peldano(minutos: minutos, estado: 1, validas: validas)
            }
            return Peldano(minutos: minutos, estado: 0, validas: validas)
        }
        return Escalera(peldanos: lista)
    }
}
