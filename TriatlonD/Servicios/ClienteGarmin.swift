// ClienteGarmin.swift
// ------------------------------------------------------------------
// Lee tus datos con la API personal oficial de Garmin, directamente
// desde el iPhone. Dos pasos: la clave se canjea por un token de
// 24 horas y con ese token se piden los datos.
//
// Lo que NO da esta API: readiness ni carga aguda/crónica.
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

    private static func fecha(_ dia: Date) -> String {
        let formato = DateFormatter()
        formato.calendar = Calendar(identifier: .gregorian)
        formato.locale = Locale(identifier: "en_US_POSIX")
        formato.dateFormat = "yyyy-MM-dd"
        return formato.string(from: dia)
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

        let lista = try? await json("/activitylist-service/activities/search/activities?start=0&limit=8") as? [[String: Any]]
        let actividades: [Actividad] = (lista ?? []).enumerated().map { indice, a in
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
            carga: Carga(aguda: nil, cronica: nil, relacion: nil, estadoRelacion: nil),
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
