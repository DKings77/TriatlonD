// EscenaPersonaje.swift
// ------------------------------------------------------------------
// Tu personaje ilustrado según lo que toca hoy: natación, bici, carrera,
// fuerza o descanso. Si falta la ilustración de ese deporte, se usa el
// corredor dibujado. El fondo se mueve más rápido cuanta más energía.
// ------------------------------------------------------------------

import SwiftUI
import UIKit

struct EscenaPersonaje: View {
    let deporte: Deporte?        // nil = descanso
    let energia: Double          // 0-100
    let notaSueno: Double?

    static func imagen(_ deporte: Deporte?) -> UIImage? {
        let nombre: String
        switch deporte {
        case .agua: nombre = "personaje_natacion"
        case .bici: nombre = "personaje_bici"
        case .carrera: nombre = "personaje_carrera"
        case .fuerza: nombre = "personaje_fuerza"
        case nil: nombre = "personaje_descanso"
        }
        return UIImage(named: nombre)
    }

    var body: some View {
        if let imagen = EscenaPersonaje.imagen(deporte) {
            ilustrada(imagen)
        } else {
            EscenaCorredor(energia: energia, notaSueno: notaSueno)
        }
    }

    private var color: Color { deporte?.color ?? Tema.natacion.opacity(0.6) }

    /// Ilustración fija sobre un fondo suave del color del deporte.
    private func ilustrada(_ imagen: UIImage) -> some View {
        ZStack {
            LinearGradient(colors: [color.opacity(0.45), Tema.superficie],
                           startPoint: .top, endPoint: .bottom)
            Image(uiImage: imagen)
                .resizable()
                .scaledToFit()
                .padding(8)
                .saturation(energia < 35 ? 0.75 : 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityLabel(deporte.map { "Tu personaje: hoy toca \($0.rawValue.lowercased())" } ?? "Tu personaje descansando")
    }
}
