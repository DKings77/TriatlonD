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

    /// Eventos de intervals.icu de sesiones borradas, a la espera del próximo envío.
    private(set) var pendientesBorrar: [Int]

    private static let claveGuardado = "plan.v1"
    private static let claveBorrar = "plan.borrar.v1"
    private let intervals = ClienteIntervals()

    init() {
        pendientesBorrar = UserDefaults.standard.array(forKey: AlmacenPlan.claveBorrar) as? [Int] ?? []
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
        UserDefaults.standard.set(pendientesBorrar, forKey: AlmacenPlan.claveBorrar)
    }

    func mover(_ id: String, a fecha: Date) {
        guard let indice = sesiones.firstIndex(where: { $0.id == id }) else { return }
        sesiones[indice].mover(a: fecha)
        guardar()
    }

    /// Número de orden que le toca a una sesión nueva de ese deporte en esa semana.
    func siguienteNumero(tipo: String, fecha: Date) -> Int {
        let semana = Calendario.semanaTemporada(fecha)
        let iguales = sesiones.filter {
            $0.tipo == tipo && Calendario.fecha($0.fecha).map(Calendario.semanaTemporada) == semana
        }
        return iguales.count + 1
    }

    /// Guarda una sesión nueva o los cambios de una que ya existía.
    func guardar(_ sesion: SesionPlan) {
        if let indice = sesiones.firstIndex(where: { $0.id == sesion.id }) {
            var nueva = sesion
            nueva.eventoId = sesiones[indice].eventoId
            // Si deja de enviarse o cambia de deporte, su evento antiguo sobra.
            if let evento = nueva.eventoId, !nueva.seEnvia || nueva.tipo != sesiones[indice].tipo {
                pendientesBorrar.append(evento)
                nueva.eventoId = nil
            }
            sesiones[indice] = nueva
        } else {
            sesiones.append(sesion)
        }
        guardar()
    }

    func borrar(_ id: String) {
        guard let indice = sesiones.firstIndex(where: { $0.id == id }) else { return }
        if let evento = sesiones[indice].eventoId { pendientesBorrar.append(evento) }
        sesiones.remove(at: indice)
        guardar()
    }

    /// Cambia todas las sesiones de una semana por las nuevas (propuesta de la IA).
    func sustituirSemana(lunes: Date, por nuevas: [SesionPlan]) {
        let semana = Calendario.semanaTemporada(lunes)
        let viejas = sesiones.filter { Calendario.fecha($0.fecha).map(Calendario.semanaTemporada) == semana }
        pendientesBorrar.append(contentsOf: viejas.compactMap(\.eventoId))
        sesiones.removeAll { vieja in viejas.contains { $0.id == vieja.id } }
        sesiones.append(contentsOf: nuevas)
        guardar()
    }

    /// Deja intervals.icu igual que el plan: crea, corrige, mueve y borra.
    func sincronizar() async {
        enviando = true
        defer { enviando = false }
        do {
            let borrados = pendientesBorrar.count
            pendientesBorrar = try await intervals.borrar(pendientesBorrar)
            guardar()
            let (resultado, ids) = try await intervals.sincronizar(sesiones.filter { $0.seEnvia })
            for (sesion, evento) in ids {
                if let indice = sesiones.firstIndex(where: { $0.id == sesion }) {
                    sesiones[indice].eventoId = evento
                }
            }
            guardar()
            mensaje = "Creadas: \(resultado.creados). Corregidas o movidas: \(resultado.actualizados). Sin cambios: \(resultado.sinCambios). Borradas: \(borrados - pendientesBorrar.count)."
        } catch {
            mensaje = error.localizedDescription
        }
    }
}
