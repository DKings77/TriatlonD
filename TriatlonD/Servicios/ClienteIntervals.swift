// ClienteIntervals.swift
// ------------------------------------------------------------------
// Envía entrenos al calendario de intervals.icu. Desde ahí salen solos
// hacia Garmin, y las bicis además hacia Rouvy (el entreno del día).
// Antes de crear mira lo que ya hay, para no duplicar si se pulsa dos veces.
// ------------------------------------------------------------------

import Foundation

struct EntrenoPlan {
    let fecha: String        // yyyy-MM-dd
    let tipo: String         // tipo de intervals.icu: Ride, Run, WeightTraining
    let interior: Bool
    let nombre: String       // con tu nomenclatura: "S11 D1: C1 35' Z2 2/2 | ..."
    let pasos: String        // formato de intervals.icu, p. ej. "- 10m 60%" o "- 4m Z2 HR"
}

struct ResultadoEnvio {
    var creados = 0
    var yaEstaban = 0
}

struct ErrorIntervals: LocalizedError {
    var mensaje: String
    var errorDescription: String? { mensaje }
}

final class ClienteIntervals {
    private let base = "https://intervals.icu/api/v1/athlete/0"

    private func peticion(_ ruta: String, metodo: String = "GET", cuerpo: Data? = nil) async throws -> Data {
        guard let clave = Llavero.leer("intervalsClave"), !clave.isEmpty else {
            throw ErrorIntervals(mensaje: "Falta la clave de intervals.icu en Ajustes.")
        }
        guard let url = URL(string: base + ruta) else {
            throw ErrorIntervals(mensaje: "Dirección de intervals.icu no válida.")
        }
        var p = URLRequest(url: url)
        p.httpMethod = metodo
        p.httpBody = cuerpo
        let credencial = Data("API_KEY:\(clave)".utf8).base64EncodedString()
        p.setValue("Basic \(credencial)", forHTTPHeaderField: "Authorization")
        p.setValue("application/json", forHTTPHeaderField: "Accept")
        p.setValue("application/json", forHTTPHeaderField: "Content-Type")
        p.setValue("TriatlonD/0.3 (uso personal)", forHTTPHeaderField: "User-Agent")
        let (datos, respuesta) = try await URLSession.shared.data(for: p)
        let codigo = (respuesta as? HTTPURLResponse)?.statusCode ?? 0
        if codigo == 401 || codigo == 403 {
            throw ErrorIntervals(mensaje: "intervals.icu ha rechazado la clave (código \(codigo)).")
        }
        guard (200...299).contains(codigo) else {
            throw ErrorIntervals(mensaje: "intervals.icu respondió \(codigo).")
        }
        return datos
    }

    /// Crea los entrenos que aún no existan (mismo día y mismo nombre).
    func enviar(_ entrenos: [EntrenoPlan]) async throws -> ResultadoEnvio {
        var resultado = ResultadoEnvio()
        guard let primero = entrenos.map(\.fecha).min(), let ultimo = entrenos.map(\.fecha).max() else {
            return resultado
        }
        let datos = try await peticion("/events?oldest=\(primero)&newest=\(ultimo)")
        let existentes = (try? JSONSerialization.jsonObject(with: datos) as? [[String: Any]]) ?? []
        let claves = Set(existentes.map { evento -> String in
            let dia = String((evento["start_date_local"] as? String ?? "").prefix(10))
            return dia + "|" + (evento["name"] as? String ?? "")
        })

        for entreno in entrenos {
            if claves.contains(entreno.fecha + "|" + entreno.nombre) {
                resultado.yaEstaban += 1
                continue
            }
            let cuerpo: [String: Any] = [
                "category": "WORKOUT",
                "start_date_local": entreno.fecha + "T00:00:00",
                "type": entreno.tipo,
                "indoor": entreno.interior,
                "name": entreno.nombre,
                "description": entreno.pasos
            ]
            _ = try await peticion("/events", metodo: "POST",
                                   cuerpo: try JSONSerialization.data(withJSONObject: cuerpo))
            resultado.creados += 1
        }
        return resultado
    }
}
