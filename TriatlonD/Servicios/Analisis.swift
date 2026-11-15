// Analisis.swift
// ------------------------------------------------------------------
// Cruces entre el plan y lo entrenado: qué sesiones se han cumplido,
// los puntos y el nivel que salen de ahí, la constancia y la relación
// entre sueño y variabilidad del pulso.
// ------------------------------------------------------------------

import Foundation

enum EstadoSesion {
    case hecha, aMedias, saltada, pendiente
}

struct Cumplimiento: Identifiable {
    var id: String { sesion.id }
    let sesion: SesionPlan
    let estado: EstadoSesion
    let minutosHechos: Double?
    let minutosPlan: Double?
}

struct Nivel {
    let numero: Int
    let dentro: Int       // puntos ya ganados dentro de este nivel
    let necesario: Int    // puntos que pide este nivel
}

struct Constancia {
    let dias: [(fecha: Date, entrenado: Bool)]   // últimos 35 días, del más antiguo al más reciente
    let rachaActual: Int
    let mejorRacha: Int
    let diasEntrenados: Int
}

enum Analisis {
    /// Minutos que suma una sesión del plan, leyendo sus pasos ("5x" multiplica el bloque siguiente).
    static func minutosPlan(_ sesion: SesionPlan) -> Double? {
        guard sesion.seEnvia else { return nil }
        var total = 0.0
        var veces = 1.0
        for linea in sesion.pasos.components(separatedBy: "\n") {
            let texto = linea.trimmingCharacters(in: .whitespaces)
            if texto.isEmpty { veces = 1; continue }
            if texto.hasSuffix("x"), let n = Double(texto.dropLast()) { veces = n; continue }
            guard texto.hasPrefix("- ") else { continue }
            let duracion = texto.dropFirst(2).split(separator: " ").first.map(String.init) ?? ""
            if duracion.hasSuffix("m"), let minutos = Double(duracion.dropLast()) {
                total += minutos * veces
            }
        }
        return total > 0 ? total : nil
    }

    /// Cruza cada sesión del plan con lo entrenado ese día en ese deporte. Si ese día no
    /// hay nada, acepta una sesión del mismo deporte hecha un día antes o después que no
    /// corresponda a otra sesión del plan (entrenos cambiados de día sin moverlos en la app).
    static func cumplimiento(plan: [SesionPlan], hechas: [SesionHecha], hoy: String) -> [Cumplimiento] {
        let ordenado = plan.sorted { ($0.fecha, $0.id) < ($1.fecha, $1.id) }
        var usadas = Set<Int>()
        var asignadas: [String: [SesionHecha]] = [:]
        // 1. Mismo día
        for sesion in ordenado {
            let delDia = hechas.filter { $0.dia == sesion.fecha && $0.deporte == sesion.deporte.rawValue && !usadas.contains($0.id) }
            if !delDia.isEmpty {
                asignadas[sesion.id] = delDia
                delDia.forEach { usadas.insert($0.id) }
            }
        }
        // 2. Un día antes o después, solo con lo que no se ha asignado
        for sesion in ordenado where asignadas[sesion.id] == nil {
            guard let fecha = Calendario.fecha(sesion.fecha) else { continue }
            let vecinos = [-1, 1].map { Calendario.texto(fecha.addingTimeInterval(Double($0) * 86400)) }
            if let otra = hechas.first(where: { vecinos.contains($0.dia) && $0.deporte == sesion.deporte.rawValue && !usadas.contains($0.id) }) {
                asignadas[sesion.id] = [otra]
                usadas.insert(otra.id)
            }
        }
        return ordenado.map { sesion in
            let previsto = minutosPlan(sesion)
            guard let delDia = asignadas[sesion.id] else {
                return Cumplimiento(sesion: sesion, estado: sesion.fecha < hoy ? .saltada : .pendiente,
                                    minutosHechos: nil, minutosPlan: previsto)
            }
            let hechos = delDia.map(\.minutos).reduce(0, +)
            let completa = previsto.map { hechos >= $0 * 0.8 } ?? true
            return Cumplimiento(sesion: sesion, estado: completa ? .hecha : .aMedias,
                                minutosHechos: hechos, minutosPlan: previsto)
        }
    }

    /// Puntos: los de la sesión si está hecha, la mitad si quedó a medias.
    static func puntos(_ lista: [Cumplimiento]) -> Int {
        lista.reduce(0) { suma, c in
            switch c.estado {
            case .hecha: return suma + c.sesion.xp
            case .aMedias: return suma + c.sesion.xp / 2
            default: return suma
            }
        }
    }

    /// El nivel N pide 400 + 100·N puntos.
    static func nivel(puntos: Int) -> Nivel {
        var numero = 1
        var resto = puntos
        while resto >= 400 + 100 * numero {
            resto -= 400 + 100 * numero
            numero += 1
        }
        return Nivel(numero: numero, dentro: resto, necesario: 400 + 100 * numero)
    }

    /// Porcentaje de sesiones ya vencidas que se han hecho (las a medias cuentan la mitad).
    static func porcentaje(_ lista: [Cumplimiento]) -> Double? {
        let vencidas = lista.filter { $0.estado != .pendiente }
        guard !vencidas.isEmpty else { return nil }
        let valor = vencidas.reduce(0.0) { suma, c in
            suma + (c.estado == .hecha ? 1 : (c.estado == .aMedias ? 0.5 : 0))
        }
        return valor / Double(vencidas.count) * 100
    }

    /// Días seguidos cumpliendo: entrenando o descansando cuando el plan lo dice.
    /// Antes de que existiera el plan, solo cuentan los días entrenados.
    static func constancia(_ hechas: [SesionHecha], hoy: Date, plan: [SesionPlan] = []) -> Constancia {
        let calendario = Calendar(identifier: .gregorian)
        let conEntreno = Set(hechas.map(\.dia))
        let conPlan = Set(plan.map(\.fecha))
        let inicioPlan = plan.map(\.fecha).min() ?? "9999"
        var dias: [(fecha: Date, entrenado: Bool)] = []
        var cumple: [Bool] = []
        for atras in stride(from: 59, through: 0, by: -1) {
            guard let fecha = calendario.date(byAdding: .day, value: -atras, to: hoy) else { continue }
            let texto = Calendario.texto(fecha)
            let entrenado = conEntreno.contains(texto)
            let descansoPlanificado = (texto >= inicioPlan && !conPlan.contains(texto)) || Comodines.usados.contains(texto)
            if atras < 35 { dias.append((fecha, entrenado)) }
            cumple.append(entrenado || descansoPlanificado)
        }
        var mejor = 0
        var seguida = 0
        for ok in cumple {
            seguida = ok ? seguida + 1 : 0
            mejor = max(mejor, seguida)
        }
        // La racha actual no se rompe por no haber entrenado todavía hoy.
        var actual = 0
        for (indice, ok) in cumple.reversed().enumerated() {
            if ok { actual += 1 } else if indice > 0 { break }
        }
        return Constancia(dias: dias, rachaActual: actual, mejorRacha: mejor,
                          diasEntrenados: dias.filter { $0.entrenado }.count)
    }

    /// VFC media tras noches de 7 h o más frente a noches más cortas.
    static func suenoYVfc(_ h: Historico) -> (largas: Double, cortas: Double)? {
        let calendario = Calendar(identifier: .gregorian)
        var largas: [Double] = []
        var cortas: [Double] = []
        for noche in h.sueno {
            guard let vfc = h.vfc.first(where: { calendario.isDate($0.fecha, inSameDayAs: noche.fecha) }) else { continue }
            if noche.horas >= 7 { largas.append(vfc.anoche) } else { cortas.append(vfc.anoche) }
        }
        guard largas.count >= 2, cortas.count >= 2 else { return nil }
        return (largas.reduce(0, +) / Double(largas.count), cortas.reduce(0, +) / Double(cortas.count))
    }

    /// "6:41" a partir de segundos.
    static func minutosYSegundos(_ segundos: Double) -> String {
        let total = Int(segundos.rounded())
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }
}
