// ClienteIntervals.swift
// ------------------------------------------------------------------
// Sincroniza el plan con el calendario de intervals.icu. Desde ahí los
// entrenos salen solos hacia Garmin, y las bicis además hacia Rouvy.
// No duplica: reconoce lo ya enviado, lo corrige y lo mueve de día.
// ------------------------------------------------------------------

import Foundation

struct ResultadoEnvio {
    var creados = 0
    var actualizados = 0
    var sinCambios = 0
}

struct ErrorIntervals: LocalizedError {
    var mensaje: String
    var codigo = 0
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
        p.setValue("TriatlonD/0.6 (uso personal)", forHTTPHeaderField: "User-Agent")
        let (datos, respuesta) = try await URLSession.shared.data(for: p)
        let codigo = (respuesta as? HTTPURLResponse)?.statusCode ?? 0
        if codigo == 401 || codigo == 403 {
            throw ErrorIntervals(mensaje: "intervals.icu ha rechazado la clave (código \(codigo)).")
        }
        guard (200...299).contains(codigo) else {
            throw ErrorIntervals(mensaje: "intervals.icu respondió \(codigo).", codigo: codigo)
        }
        return datos
    }

    /// Borra eventos del calendario. Devuelve los que no se han podido borrar.
    func borrar(_ ids: [Int]) async throws -> [Int] {
        var quedan: [Int] = []
        for id in Set(ids) {
            do {
                _ = try await peticion("/events/\(id)", metodo: "DELETE")
            } catch let error as ErrorIntervals where error.codigo == 404 || error.codigo == 422 {
                continue   // ya no existía
            } catch let error as ErrorIntervals where error.codigo >= 500 {
                quedan.append(id)
            }
        }
        return quedan
    }

    /// Devuelve el recuento y, por cada sesión, el id de su evento en intervals.icu.
    func sincronizar(_ sesiones: [SesionPlan]) async throws -> (ResultadoEnvio, [String: Int]) {
        var resultado = ResultadoEnvio()
        var ids: [String: Int] = [:]
        if sesiones.isEmpty { return (resultado, ids) }
        guard let primera = sesiones.map(\.fecha).min(), let ultima = sesiones.map(\.fecha).max(),
              let inicio = Calendario.fecha(primera), let fin = Calendario.fecha(ultima) else {
            return (resultado, ids)
        }
        // Margen de tres semanas a cada lado para encontrar sesiones movidas de día.
        let desde = Calendario.texto(inicio.addingTimeInterval(-21 * 86400))
        let hasta = Calendario.texto(fin.addingTimeInterval(21 * 86400))
        let datos = try await peticion("/events?oldest=\(desde)&newest=\(hasta)")
        let existentes = (try? JSONSerialization.jsonObject(with: datos) as? [[String: Any]]) ?? []

        var porId: [Int: [String: Any]] = [:]
        var porDiaYTipo: [String: Int] = [:]
        for evento in existentes {
            guard let id = (evento["id"] as? NSNumber)?.intValue else { continue }
            porId[id] = evento
            let dia = String((evento["start_date_local"] as? String ?? "").prefix(10))
            porDiaYTipo[dia + "|" + (evento["type"] as? String ?? "")] = id
        }
        var usados = Set(sesiones.compactMap(\.eventoId))

        for sesion in sesiones {
            // 1) El evento que ya creó la app. 2) Uno del mismo día y deporte aún sin dueño.
            var id: Int?
            if let propio = sesion.eventoId, porId[propio] != nil {
                id = propio
            } else if let candidato = porDiaYTipo[sesion.fecha + "|" + sesion.tipo], !usados.contains(candidato) {
                id = candidato
                usados.insert(candidato)
            }

            var cuerpo: [String: Any] = [
                "category": "WORKOUT",
                "start_date_local": sesion.fecha + "T00:00:00",
                "type": sesion.tipo,
                "indoor": sesion.interior,
                "name": sesion.nombre,
                "description": sesion.pasos
            ]

            if let id, let previo = porId[id] {
                let mismoDia = String((previo["start_date_local"] as? String ?? "").prefix(10)) == sesion.fecha
                let igual = mismoDia
                    && (previo["name"] as? String) == sesion.nombre
                    && (previo["description"] as? String) == sesion.pasos
                if igual {
                    resultado.sinCambios += 1
                } else {
                    cuerpo["id"] = id
                    _ = try await peticion("/events/\(id)", metodo: "PUT",
                                           cuerpo: try JSONSerialization.data(withJSONObject: cuerpo))
                    resultado.actualizados += 1
                }
                ids[sesion.id] = id
            } else {
                let respuesta = try await peticion("/events", metodo: "POST",
                                                   cuerpo: try JSONSerialization.data(withJSONObject: cuerpo))
                if let creado = try? JSONSerialization.jsonObject(with: respuesta) as? [String: Any],
                   let nuevo = (creado["id"] as? NSNumber)?.intValue {
                    ids[sesion.id] = nuevo
                }
                resultado.creados += 1
            }
        }
        return (resultado, ids)
    }
}
