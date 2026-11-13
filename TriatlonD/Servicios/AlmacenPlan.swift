// AlmacenPlan.swift
// ------------------------------------------------------------------
// Guarda el plan en el iPhone y lo sincroniza con intervals.icu.
// Mover una sesión de día solo cambia el plan; al aprobar, la app deja
// el calendario de intervals.icu igual que el plan.
// ------------------------------------------------------------------

import SwiftUI
import Observation

@MainActor
@Observable
final class AlmacenPlan {
    var sesiones: [SesionPlan]
    var enviando = false
    var mensaje: String?

    private static let claveGuardado = "plan.v1"
    private let intervals = ClienteIntervals()

    init() {
        if let datos = UserDefaults.standard.data(forKey: AlmacenPlan.claveGuardado),
           let guardadas = try? JSONDecoder().decode([SesionPlan].self, from: datos) {
            sesiones = guardadas
        } else {
            sesiones = PlanInicial.sesiones
        }
    }

    var ordenadas: [SesionPlan] {
        sesiones.sorted { ($0.fecha, $0.id) < ($1.fecha, $1.id) }
    }

    private func guardar() {
        if let datos = try? JSONEncoder().encode(sesiones) {
            UserDefaults.standard.set(datos, forKey: AlmacenPlan.claveGuardado)
        }
    }

    func mover(_ id: String, a fecha: Date) {
        guard let indice = sesiones.firstIndex(where: { $0.id == id }) else { return }
        sesiones[indice].mover(a: fecha)
        guardar()
    }

    /// Deja intervals.icu igual que el plan: crea, corrige y mueve.
    func sincronizar() async {
        enviando = true
        defer { enviando = false }
        do {
            let (resultado, ids) = try await intervals.sincronizar(sesiones.filter { $0.seEnvia })
            for (sesion, evento) in ids {
                if let indice = sesiones.firstIndex(where: { $0.id == sesion }) {
                    sesiones[indice].eventoId = evento
                }
            }
            guardar()
            mensaje = "Creadas: \(resultado.creados). Corregidas o movidas: \(resultado.actualizados). Sin cambios: \(resultado.sinCambios)."
        } catch {
            mensaje = error.localizedDescription
        }
    }
}
