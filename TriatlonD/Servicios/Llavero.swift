// Llavero.swift
// ------------------------------------------------------------------
// Guarda las claves (Garmin, intervals.icu) en el llavero del iPhone,
// que las cifra. Nunca van en el código ni en el repositorio.
// ------------------------------------------------------------------

import Foundation
import Security

enum Llavero {
    private static let servicio = "com.davidreyes.triatlond"

    private static func consulta(_ clave: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: clave
        ]
    }

    /// Guarda el valor; si llega vacío, borra lo que hubiera.
    static func guardar(_ valor: String, clave: String) {
        SecItemDelete(consulta(clave) as CFDictionary)
        guard !valor.isEmpty else { return }
        var nuevo = consulta(clave)
        nuevo[kSecValueData as String] = Data(valor.utf8)
        SecItemAdd(nuevo as CFDictionary, nil)
    }

    static func leer(_ clave: String) -> String? {
        var busqueda = consulta(clave)
        busqueda[kSecReturnData as String] = true
        busqueda[kSecMatchLimit as String] = kSecMatchLimitOne
        var resultado: AnyObject?
        guard SecItemCopyMatching(busqueda as CFDictionary, &resultado) == errSecSuccess,
              let datos = resultado as? Data else { return nil }
        return String(data: datos, encoding: .utf8)
    }
}
