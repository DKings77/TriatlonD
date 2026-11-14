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
    var historico: Historico?
    var ultimaActualizacion: Date?
    var novedad: String?
    var aviso: String? = "Datos de ejemplo del 13 de noviembre."

    private let garmin = ClienteGarmin()
    private static let claveUltimaSesion = "ultimaSesionVista"

    /// Recarga solo si han pasado más de cinco minutos desde la última vez.
    func recargarSiToca() async {
        if cargando { return }
        if let ultima = ultimaActualizacion, Date().timeIntervalSince(ultima) < 300 { return }
        await recargar()
    }

    func recargar() async {
        guard let clave = Llavero.leer("garminClave"), !clave.isEmpty else {
            estado = DatosEjemplo.hoy
            esReal = false
            historico = nil
            aviso = "Datos de ejemplo. Añade tu clave de Garmin en Ajustes."
            return
        }
        cargando = true
        defer { cargando = false }
        do {
            estado = try await garmin.estadoDeHoy()
            esReal = true
            aviso = nil
            historico = try? await garmin.historico()
            ultimaActualizacion = Date()
            avisarSiHaySesionNueva()
        } catch {
            aviso = error.localizedDescription
        }
    }

    /// Si la sesión más reciente no es la que vimos la última vez, lo anuncia.
    private func avisarSiHaySesionNueva() {
        guard let primera = estado.actividades.first else { return }
        let vista = UserDefaults.standard.integer(forKey: AlmacenEstado.claveUltimaSesion)
        if vista != 0, vista != primera.id {
            novedad = "Nueva sesión: \(primera.nombre ?? "entreno") · \(Int(primera.minutos ?? 0))'"
        }
        UserDefaults.standard.set(primera.id, forKey: AlmacenEstado.claveUltimaSesion)
    }
}
