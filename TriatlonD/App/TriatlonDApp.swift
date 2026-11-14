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

    var body: some View {
        TabView {
            BaseView(almacen: almacen)
                .tabItem { Label("Base", systemImage: "flame") }
            TravesiaView()
                .tabItem { Label("Travesía", systemImage: "map") }
            SemanaView(plan: plan)
                .tabItem { Label("Plan", systemImage: "calendar") }
            LesionView()
                .tabItem { Label("Lesión", systemImage: "bandage") }
            FichaView(almacen: almacen)
                .tabItem { Label("Datos", systemImage: "chart.xyaxis.line") }
        }
        .tint(Tema.turquesa)
        .task { await almacen.recargar() }
    }
}
