// ClienteGarmin.swift
// ------------------------------------------------------------------
// Lee tus datos con la API personal oficial de Garmin, directamente
// desde el iPhone. Dos pasos: la clave se canjea por un token de
// 24 horas y con ese token se piden los datos.
//
// Lo que NO da esta API: readiness ni carga aguda/crónica.
// La carga se calcula aquí a partir de las actividades de 28 días.
// ------------------------------------------------------------------

import Foundation

struct ErrorGarmin: LocalizedError {
    var mensaje: String
    var errorDescription: String? { mensaje }
}

final class ClienteGarmin {
    private let base = "https://personal.connectapi.garmin.com"
    private var token: String?
    private var caduca = Date.distantPast

    private func obtenerToken() async throws -> String {
        if let token, Date() < caduca { return token }
        guard let clave = Llavero.leer("garminClave"), !clave.isEmpty else {
            throw ErrorGarmin(mensaje: "Falta la clave de Garmin en Ajustes.")
        }
        guard let url = URL(string: base + "/personalapitoken-service/personal-api/personal-api-key/token") else {
            throw ErrorGarmin(mensaje: "Dirección de Garmin no válida.")
        }
        var peticion = URLRequest(url: url)
        peticion.httpMethod = "POST"
        peticion.setValue("ApiKey \(clave)", forHTTPHeaderField: "Authorization")
        peticion.setValue("*/*", forHTTPHeaderField: "Accept")
        let (datos, respuesta) = try await URLSession.shared.data(for: peticion)
        let codigo = (respuesta as? HTTPURLResponse)?.statusCode ?? 0
        guard codigo == 200 else {
            throw ErrorGarmin(mensaje: "Garmin ha rechazado la clave (código \(codigo)). Revisa que esté bien copiada y no haya caducado.")
        }
        // Garmin devuelve el token como texto plano; por si cambia, también se acepta JSON.
        var nuevo = String(data: datos, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let objeto = try? JSONSerialization.jsonObject(with: datos) as? [String: Any],
           let dentro = objeto["access_token"] as? String {
            nuevo = dentro
        }
        guard !nuevo.isEmpty else { throw ErrorGarmin(mensaje: "Garmin no ha devuelto un token.") }
        token = nuevo
        caduca = Date().addingTimeInterval(23 * 3600)
        return nuevo
    }

    private func json(_ ruta: String) async throws -> Any {
        let actual = try await obtenerToken()
        guard let url = URL(string: base + ruta) else {
            throw ErrorGarmin(mensaje: "Dirección de Garmin no válida.")
        }
        var peticion = URLRequest(url: url)
        peticion.setValue("Bearer \(actual)", forHTTPHeaderField: "Authorization")
        peticion.setValue("application/json", forHTTPHeaderField: "Accept")
        let (datos, respuesta) = try await URLSession.shared.data(for: peticion)
        let codigo = (respuesta as? HTTPURLResponse)?.statusCode ?? 0
        if codigo == 401 { token = nil }
        guard codigo == 200 else { throw ErrorGarmin(mensaje: "Garmin respondió \(codigo).") }
        return try JSONSerialization.jsonObject(with: datos)
    }

    private func numero(_ valor: Any?) -> Double? {
        (valor as? NSNumber)?.doubleValue
    }

    private static let formatoDia: DateFormatter = {
        let formato = DateFormatter()
        formato.calendar = Calendar(identifier: .gregorian)
        formato.locale = Locale(identifier: "en_US_POSIX")
        formato.dateFormat = "yyyy-MM-dd"
        return formato
    }()

    private static func fecha(_ dia: Date) -> String {
        formatoDia.string(from: dia)
    }

    /// Carga de una sesión: la de Garmin si viene, si no el TSS, y si tampoco,
    /// una estimación por minutos y pulso medio.
    private func cargaDe(_ a: [String: Any]) -> Double? {
        if let garmin = numero(a["activityTrainingLoad"]), garmin > 0 { return garmin }
        if let tss = numero(a["trainingStressScore"]), tss > 0 { return tss }
        guard let segundos = numero(a["duration"]), segundos > 0 else { return nil }
        let minutos = segundos / 60
        guard let pulso = numero(a["averageHR"]) else { return minutos * 0.5 }
        return minutos * min(max((pulso - 80) / 70, 0.2), 1.5)
    }

    /// Carga aguda (suma de 7 días) y crónica (media semanal de 28 días).
    private func carga(_ actividades: [[String: Any]], hoy: String) -> Carga {
        var aguda = 0.0
        var total28 = 0.0
        var contadas = 0
        guard let referencia = Self.formatoDia.date(from: hoy) else {
            return Carga(aguda: nil, cronica: nil, relacion: nil, estadoRelacion: nil)
        }
        for a in actividades {
            guard let inicio = a["startTimeLocal"] as? String,
                  let dia = Self.formatoDia.date(from: String(inicio.prefix(10))),
                  let valor = cargaDe(a) else { continue }
            let dias = Calendar.current.dateComponents([.day], from: dia, to: referencia).day ?? 99
            guard dias >= 0, dias < 28 else { continue }
            contadas += 1
            total28 += valor
            if dias < 7 { aguda += valor }
        }
        guard contadas > 0 else {
            return Carga(aguda: nil, cronica: nil, relacion: nil, estadoRelacion: nil)
        }
        let cronica = total28 / 4
        let relacion = cronica > 0 ? (aguda / cronica * 10).rounded() / 10 : nil
        return Carga(aguda: aguda.rounded(), cronica: cronica.rounded(), relacion: relacion, estadoRelacion: nil)
    }

    /// Estado de hoy. Si un dato concreto falla, se deja vacío y sigue con el resto.
    func estadoDeHoy() async throws -> EstadoDia {
        let hoy = Self.fecha(Date())
        let hace30 = Self.fecha(Date().addingTimeInterval(-30 * 86400))
        _ = try await obtenerToken()

        let vfc = try? await json("/hrv-service/hrv/\(hoy)") as? [String: Any]
        let resumenVfc = vfc?["hrvSummary"] as? [String: Any]

        let sueno = try? await json("/sleep-service/sleep/dailySleep?date=\(hoy)") as? [String: Any]
        let notas = sueno?["sleepScores"] as? [String: Any]
        let notaSueno = numero(notas?["overall"]) ?? numero((notas?["overall"] as? [String: Any])?["value"])
        let segundos = numero(sueno?["sleepTimeSeconds"])

        let peso = try? await json("/weight-service/weight/range/\(hace30)/\(hoy)") as? [String: Any]
        let gramos = numero((peso?["totalAverage"] as? [String: Any])?["weight"])

        let lista = try? await json("/activitylist-service/activities/search/activities?start=0&limit=100") as? [[String: Any]]
        let actividades: [Actividad] = (lista ?? []).prefix(8).enumerated().map { indice, a in
            Actividad(
                id: numero(a["activityId"]).map { Int($0) } ?? indice,
                nombre: a["activityName"] as? String,
                tipo: (a["activityType"] as? [String: Any])?["typeKey"] as? String,
                inicio: a["startTimeLocal"] as? String,
                minutos: numero(a["duration"]).map { ($0 / 60).rounded() },
                metros: numero(a["distance"]),
                pulsoMedio: numero(a["averageHR"])
            )
        }

        return EstadoDia(
            dia: hoy,
            carga: carga(lista ?? [], hoy: hoy),
            vfc: VFC(anocheMs: numero(resumenVfc?["lastNightAvg"]),
                     mediaSemanalMs: numero(resumenVfc?["weeklyAvg"]),
                     estado: resumenVfc?["status"] as? String),
            sueno: Sueno(horas: segundos.map { $0 / 3600 }, puntuacion: notaSueno),
            readiness: Readiness(puntuacion: nil, nivel: nil),
            pesoKg: gramos.map { $0 / 1000 },
            actividades: actividades
        )
    }

    // MARK: - Histórico para las gráficas

    private func deporteDe(_ a: [String: Any]) -> String? {
        let tipo = ((a["activityType"] as? [String: Any])?["typeKey"] as? String ?? "").lowercased()
        if tipo.contains("ride") || tipo.contains("cycling") || tipo.contains("biking") { return "Bici" }
        if tipo.contains("run") { return "Carrera" }
        if tipo.contains("swim") { return "Agua" }
        if tipo.contains("strength") { return "Fuerza" }
        return nil
    }

    /// Cuatro semanas de carga, VFC y volumen, y catorce noches de sueño.
    func historico() async throws -> Historico {
        var resultado = Historico()
        let calendario = Calendar(identifier: .gregorian)
        let hoyTexto = Self.fecha(Date())
        guard let hoy = Self.formatoDia.date(from: hoyTexto) else { return resultado }
        _ = try await obtenerToken()

        // --- Actividades: carga diaria y volumen semanal
        let lista = (try? await json("/activitylist-service/activities/search/activities?start=0&limit=100") as? [[String: Any]]) ?? []
        var cargaPorDia: [Int: Double] = [:]          // días atrás -> carga
        var horasPorSemana: [String: Double] = [:]    // "semanasAtrás|deporte" -> horas
        let diaSemanaHoy = (calendario.component(.weekday, from: hoy) + 5) % 7   // lunes = 0
        for a in lista {
            guard let inicio = a["startTimeLocal"] as? String,
                  let dia = Self.formatoDia.date(from: String(inicio.prefix(10))) else { continue }
            let atras = calendario.dateComponents([.day], from: dia, to: hoy).day ?? 999
            guard atras >= 0, atras < 60 else { continue }
            if let valor = cargaDe(a) { cargaPorDia[atras, default: 0] += valor }
            if let deporte = deporteDe(a), let segundos = numero(a["duration"]) {
                let semanasAtras = (atras + (6 - diaSemanaHoy)) / 7
                if semanasAtras < 4 {
                    horasPorSemana["\(semanasAtras)|\(deporte)", default: 0] += segundos / 3600
                }
            }
        }
        for atras in stride(from: 27, through: 0, by: -1) {
            var aguda = 0.0
            var total28 = 0.0
            for d in atras..<(atras + 28) {
                let valor = cargaPorDia[d] ?? 0
                total28 += valor
                if d < atras + 7 { aguda += valor }
            }
            if let fecha = calendario.date(byAdding: .day, value: -atras, to: hoy) {
                resultado.carga.append(DiaCarga(fecha: fecha, aguda: aguda, cronica: total28 / 4))
            }
        }
        let lunes = calendario.date(byAdding: .day, value: -diaSemanaHoy, to: hoy) ?? hoy
        for semanasAtras in stride(from: 3, through: 0, by: -1) {
            guard let inicio = calendario.date(byAdding: .day, value: -7 * semanasAtras, to: lunes) else { continue }
            for deporte in ["Bici", "Carrera", "Agua", "Fuerza"] {
                let horas = horasPorSemana["\(semanasAtras)|\(deporte)"] ?? 0
                resultado.volumen.append(VolumenSemana(inicio: inicio, deporte: deporte, horas: horas))
            }
        }

        // --- VFC de 28 días
        let hace28 = Self.fecha(hoy.addingTimeInterval(-27 * 86400))
        if let vfc = try? await json("/hrv-service/hrv/daily/\(hace28)/\(hoyTexto)") as? [String: Any],
           let noches = vfc["hrvSummaries"] as? [[String: Any]] {
            for n in noches {
                guard let texto = n["calendarDate"] as? String, let fecha = Self.formatoDia.date(from: texto),
                      let anoche = numero(n["lastNightAvg"]) else { continue }
                resultado.vfc.append(NocheVFC(fecha: fecha, anoche: anoche, media: numero(n["weeklyAvg"])))
            }
            resultado.vfc.sort { $0.fecha < $1.fecha }
        }

        // --- Sueño de 14 noches, en paralelo
        resultado.sueno = await withTaskGroup(of: NocheSueno?.self) { grupo in
            for i in 0..<14 {
                let texto = Self.fecha(hoy.addingTimeInterval(-Double(i) * 86400))
                grupo.addTask { [self] in
                    guard let s = try? await self.json("/sleep-service/sleep/dailySleep?date=\(texto)") as? [String: Any],
                          let segundos = self.numero(s["sleepTimeSeconds"]), segundos > 0,
                          let fecha = Self.formatoDia.date(from: texto) else { return nil }
                    let notas = s["sleepScores"] as? [String: Any]
                    let nota = self.numero(notas?["overall"]) ?? self.numero((notas?["overall"] as? [String: Any])?["value"])
                    return NocheSueno(fecha: fecha, horas: segundos / 3600, nota: nota)
                }
            }
            var noches: [NocheSueno] = []
            for await noche in grupo {
                if let noche { noches.append(noche) }
            }
            return noches.sorted { $0.fecha < $1.fecha }
        }
        return resultado
    }
}
