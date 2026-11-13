// AlmacenEstado.swift
// ------------------------------------------------------------------
// Guarda el estado que pintan las pantallas. Arranca con los datos de
// ejemplo y, si hay clave de Garmin, los cambia por los reales.
// ------------------------------------------------------------------

import SwiftUI
import Observation

@MainActor
@Observable
final class AlmacenEstado {
    var estado = DatosEjemplo.hoy
    var cargando = false
    var esReal = false
    var aviso: String? = "Datos de ejemplo del 13 de noviembre."

    private let garmin = ClienteGarmin()

    func recargar() async {
        guard let clave = Llavero.leer("garminClave"), !clave.isEmpty else {
            estado = DatosEjemplo.hoy
            esReal = false
            aviso = "Datos de ejemplo. Añade tu clave de Garmin en Ajustes."
            return
        }
        cargando = true
        defer { cargando = false }
        do {
            estado = try await garmin.estadoDeHoy()
            esReal = true
            aviso = nil
        } catch {
            aviso = error.localizedDescription
        }
    }
}
