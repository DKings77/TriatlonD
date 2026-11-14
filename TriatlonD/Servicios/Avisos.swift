// Avisos.swift
// ------------------------------------------------------------------
// Aviso la víspera: una notificación del propio iPhone, la noche antes,
// con las sesiones del día siguiente. No necesita internet ni servidor.
// ------------------------------------------------------------------

import Foundation
import UserNotifications

enum Avisos {
    static var activos: Bool { UserDefaults.standard.bool(forKey: "avisos.activos") }
    static var hora: Int {
        let h = UserDefaults.standard.integer(forKey: "avisos.hora")
        return h > 0 ? h : 21
    }

    static func pedirPermiso() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Reprograma los avisos de los próximos 7 días a partir del plan.
    static func reprogramar(_ sesiones: [SesionPlan]) {
        let centro = UNUserNotificationCenter.current()
        centro.getPendingNotificationRequests { pendientes in
            centro.removePendingNotificationRequests(withIdentifiers: pendientes.map(\.identifier).filter { $0.hasPrefix("vispera-") })
            guard activos else { return }
            let calendario = Calendar(identifier: .gregorian)
            let hoy = calendario.startOfDay(for: Date())
            for dias in 1...7 {
                guard let manana = calendario.date(byAdding: .day, value: dias, to: hoy) else { continue }
                let texto = Calendario.texto(manana)
                let delDia = sesiones.filter { $0.fecha == texto }.sorted { $0.nombre < $1.nombre }
                guard !delDia.isEmpty,
                      let vispera = calendario.date(byAdding: .day, value: -1, to: manana),
                      let disparo = calendario.date(bySettingHour: hora, minute: 0, second: 0, of: vispera),
                      disparo > Date() else { continue }
                let contenido = UNMutableNotificationContent()
                contenido.title = "Mañana toca"
                contenido.body = delDia.map(\.titulo).joined(separator: "\n")
                contenido.sound = .default
                let partes = calendario.dateComponents([.year, .month, .day, .hour, .minute], from: disparo)
                let peticion = UNNotificationRequest(
                    identifier: "vispera-\(texto)", content: contenido,
                    trigger: UNCalendarNotificationTrigger(dateMatching: partes, repeats: false))
                centro.add(peticion)
            }
        }
    }
}
