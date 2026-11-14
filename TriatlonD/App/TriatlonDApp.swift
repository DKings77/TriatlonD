// TriatlonDApp.swift
// ------------------------------------------------------------------
// Punto de entrada de la app y barra de pestañas con las cinco pantallas.
// Los datos salen de Garmin si hay clave en Ajustes; si no, de los de ejemplo.
// ------------------------------------------------------------------

import SwiftUI

@main
struct TriatlonDApp: App {
    var body: some Scene {
        WindowGroup {
            PestanasView()
                .preferredColorScheme(.dark)
        }
    }
}

struct PestanasView: View {
    @State private var almacen = AlmacenEstado()
    @State private var plan = AlmacenPlan()
    @Environment(\.scenePhase) private var fase

    var body: some View {
        TabView {
            BaseView(almacen: almacen, plan: plan)
                .tabItem { Label("Hoy", systemImage: "sun.max.fill") }
            ProgresoView(almacen: almacen, plan: plan)
                .background(Tema.fondo)
                .tabItem { Label("Progreso", systemImage: "trophy.fill") }
            SemanaView(plan: plan, almacen: almacen)
                .tabItem { Label("Plan", systemImage: "calendar") }
            CuerpoView(almacen: almacen, plan: plan)
                .background(Tema.fondo)
                .tabItem { Label("Cuerpo", systemImage: "heart.text.square") }
            FichaView(almacen: almacen, plan: plan)
                .tabItem { Label("Rendimiento", systemImage: "chart.xyaxis.line") }
        }
        .tint(Tema.turquesa)
        .task {
            Avisos.reprogramar(plan.sesiones)
            await almacen.recargar()
        }
        .onChange(of: fase) { _, nueva in
            // Al volver a la app (por ejemplo, tras un entreno) se piden los datos de nuevo.
            if nueva == .active {
                Task { await almacen.recargarSiToca() }
            }
        }
    }
}
