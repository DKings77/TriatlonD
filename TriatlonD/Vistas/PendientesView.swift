// PendientesView.swift
// ------------------------------------------------------------------
// Las tres pantallas que aún no están construidas. Cada una explica
// qué habrá, para que la app ya tenga su forma final de cinco pestañas.
// ------------------------------------------------------------------

import SwiftUI

struct TravesiaView: View {
    var body: some View {
        Pendiente(titulo: "La Travesía", icono: "map",
                  texto: "El mapa de la temporada: cada semana es una etapa y el jefe de la región es el test de FTP.")
    }
}

struct SemanaView: View {
    var body: some View {
        Pendiente(titulo: "Semana", icono: "calendar",
                  texto: "Las misiones que propone la IA y el botón para aprobar la semana y enviarla al reloj.")
    }
}

struct LesionView: View {
    var body: some View {
        Pendiente(titulo: "Parte de lesión", icono: "bandage",
                  texto: "El dolor de 0 a 10 tras cada carrera y la escalera de vuelta a correr.")
    }
}

private struct Pendiente: View {
    var titulo: String
    var icono: String
    var texto: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icono)
                .font(.system(size: 56))
                .foregroundStyle(Tema.turquesa)
            Text(titulo)
                .font(.title.bold())
            Text(texto)
                .font(.body)
                .foregroundStyle(Tema.textoSecundario)
                .multilineTextAlignment(.center)
            Text("En construcción")
                .font(.footnote.bold())
                .foregroundStyle(Tema.experiencia)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tema.fondo)
        .foregroundStyle(Tema.texto)
    }
}
