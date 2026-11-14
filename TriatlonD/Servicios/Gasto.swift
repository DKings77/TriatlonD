// Gasto.swift
// ------------------------------------------------------------------
// Lo que gasta el entrenador de tu monedero de la API. Cada respuesta
// de Claude dice cuántos tokens ha leído y escrito; con la tarifa de
// Sonnet 5.5 (2 $ por millón de entrada, 10 $ por millón de salida)
// se calcula el coste.
// ------------------------------------------------------------------

import Foundation

struct UsoIA: Codable, Identifiable {
    var id: String { "\(fecha)-\(entrada)-\(salida)" }
    let fecha: String
    let tipo: String
    let entrada: Int
    let salida: Int
    var dolares: Double { Double(entrada) * 2 / 1_000_000 + Double(salida) * 10 / 1_000_000 }
}

enum Gasto {
    private static let clave = "gasto.v1"

    static var usos: [UsoIA] {
        guard let datos = UserDefaults.standard.data(forKey: clave),
              let lista = try? JSONDecoder().decode([UsoIA].self, from: datos) else { return [] }
        return lista
    }

    static func apuntar(_ uso: UsoIA) {
        var lista = usos
        lista.append(uso)
        if let datos = try? JSONEncoder().encode(lista.suffix(500)) {
            UserDefaults.standard.set(datos, forKey: clave)
        }
    }

    static var esteMes: Double {
        let mes = String(Calendario.texto(Date()).prefix(7))
        return usos.filter { $0.fecha.hasPrefix(mes) }.map(\.dolares).reduce(0, +)
    }

    static var total: Double { usos.map(\.dolares).reduce(0, +) }

    static func texto(_ dolares: Double) -> String {
        dolares < 0.01 ? "menos de 1 céntimo" : String(format: "%.2f $", dolares)
    }
}
