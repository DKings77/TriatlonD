// Copia.swift
// ------------------------------------------------------------------
// Copia de seguridad de lo que solo vive en el iPhone: el plan, el
// diario de dolor, la historia de la nota y tus referencias. Las
// claves NO van en la copia: siguen solo en el llavero.
// ------------------------------------------------------------------

import Foundation
import UniformTypeIdentifiers
import SwiftUI

enum Copia {
    private static let claves = [
        "plan.v1", "plan.borrar.v1", "dolor.diario.v1", "nota.historia.v1",
        "dolorUltimaCarrera", "ultimaSesionVista",
        "ref.ftp", "ref.z1", "ref.z2", "ref.z3", "ref.z4", "ref.z5", "ref.max",
        "ref.pesoObjetivo", "ref.fechaPeso", "ref.nacimiento"
    ]

    /// Escribe la copia en un archivo temporal y devuelve su dirección.
    static func exportar() throws -> URL {
        var contenido: [String: Any] = ["version": 1, "fecha": Calendario.texto(Date())]
        var datos: [String: Any] = [:]
        for clave in claves {
            guard let valor = UserDefaults.standard.object(forKey: clave) else { continue }
            if let binario = valor as? Data {
                datos[clave] = ["data": binario.base64EncodedString()]
            } else {
                datos[clave] = valor
            }
        }
        contenido["datos"] = datos
        let json = try JSONSerialization.data(withJSONObject: contenido, options: [.prettyPrinted, .sortedKeys])
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TriatlonD-copia-\(Calendario.texto(Date())).json")
        try json.write(to: url, options: .atomic)
        return url
    }

    /// Restaura una copia. Devuelve cuántos datos se han recuperado.
    static func importar(_ url: URL) throws -> Int {
        let acceso = url.startAccessingSecurityScopedResource()
        defer { if acceso { url.stopAccessingSecurityScopedResource() } }
        let json = try Data(contentsOf: url)
        guard let contenido = try JSONSerialization.jsonObject(with: json) as? [String: Any],
              let datos = contenido["datos"] as? [String: Any] else {
            throw ErrorIntervals(mensaje: "El archivo no es una copia de Triatlón D.")
        }
        var recuperados = 0
        for (clave, valor) in datos where claves.contains(clave) {
            if let envoltorio = valor as? [String: Any], let texto = envoltorio["data"] as? String,
               let binario = Data(base64Encoded: texto) {
                UserDefaults.standard.set(binario, forKey: clave)
            } else {
                UserDefaults.standard.set(valor, forKey: clave)
            }
            recuperados += 1
        }
        return recuperados
    }
}
