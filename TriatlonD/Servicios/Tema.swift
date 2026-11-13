// Tema.swift
// ------------------------------------------------------------------
// Colores de la app (tema oscuro) y un color por deporte.
// ------------------------------------------------------------------

import SwiftUI

enum Tema {
    static let fondo = Color(red: 0.055, green: 0.071, blue: 0.125)
    static let superficie = Color(red: 0.102, green: 0.125, blue: 0.212)
    static let pista = Color(red: 0.149, green: 0.180, blue: 0.290)
    static let texto = Color(red: 0.949, green: 0.957, blue: 0.980)
    static let textoSecundario = Color(red: 0.545, green: 0.576, blue: 0.690)
    static let turquesa = Color(red: 0.176, green: 0.831, blue: 0.769)
    static let experiencia = Color(red: 1.0, green: 0.820, blue: 0.400)
    static let alerta = Color(red: 1.0, green: 0.302, blue: 0.427)
    static let natacion = Color(red: 0.231, green: 0.655, blue: 1.0)
    static let bici = Color(red: 1.0, green: 0.541, blue: 0.239)
    static let carrera = Color(red: 0.482, green: 0.878, blue: 0.416)
}

/// Tarjeta con el fondo y las esquinas comunes a toda la app.
struct Tarjeta<Contenido: View>: View {
    @ViewBuilder var contenido: () -> Contenido

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            contenido()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Tema.superficie)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// Barra horizontal de 0 a 100.
struct BarraProgreso: View {
    var valor: Double
    var color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Tema.pista)
                Capsule().fill(color)
                    .frame(width: geo.size.width * min(max(valor, 0), 100) / 100)
            }
        }
        .frame(height: 8)
    }
}
