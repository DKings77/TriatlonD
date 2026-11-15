// Sensaciones.swift
// ------------------------------------------------------------------
// Lo que apuntas tras cada entreno: esfuerzo, ánimo y molestias, de 0
// a 10. El dolor de las carreras se guarda además en el diario de
// dolor, que es el que abre los peldaños de la escalera.
// ------------------------------------------------------------------

import Foundation

struct Sensacion: Codable, Identifiable {
    var id: String { "\(dia)-\(deporte)" }
    let dia: String
    let deporte: String
    var esfuerzo: Int?
    var animo: Int?
    var dolor: Int?
}

enum Sensaciones {
    private static let clave = "sensaciones.v1"

    static var todas: [Sensacion] {
        guard let datos = UserDefaults.standard.data(forKey: clave),
              let lista = try? JSONDecoder().decode([Sensacion].self, from: datos) else { return [] }
        return lista.sorted { ($0.dia, $0.deporte) < ($1.dia, $1.deporte) }
    }

    static func de(dia: String, deporte: Deporte) -> Sensacion {
        todas.first { $0.dia == dia && $0.deporte == deporte.rawValue }
            ?? Sensacion(dia: dia, deporte: deporte.rawValue)
    }

    static func guardar(_ s: Sensacion) {
        var lista = todas.filter { $0.id != s.id }
        lista.append(s)
        if let datos = try? JSONEncoder().encode(lista.suffix(400)) {
            UserDefaults.standard.set(datos, forKey: clave)
        }
        if s.deporte == Deporte.carrera.rawValue, let dolor = s.dolor {
            DiarioDolor.apuntar(dolor, dia: s.dia)
        }
    }
}
