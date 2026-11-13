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
}
