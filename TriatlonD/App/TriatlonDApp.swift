// TriatlonDApp.swift
// ------------------------------------------------------------------
// Punto de entrada de la app y barra de pestañas con las cinco pantallas.
// De momento todas leen los datos de ejemplo guardados en la app.
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
    private let estado = DatosEjemplo.hoy

    var body: some View {
        TabView {
            BaseView(estado: estado)
                .tabItem { Label("Base", systemImage: "flame") }
            TravesiaView()
                .tabItem { Label("Travesía", systemImage: "map") }
            SemanaView()
                .tabItem { Label("Semana", systemImage: "calendar") }
            LesionView()
                .tabItem { Label("Lesión", systemImage: "bandage") }
            FichaView(estado: estado)
                .tabItem { Label("Ficha", systemImage: "chart.bar") }
        }
        .tint(Tema.turquesa)
    }
}
