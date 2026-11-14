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

    private func ilustrada(_ imagen: UIImage) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { linea in
            let t = linea.date.timeIntervalSinceReferenceDate
            let ritmo = deporte == nil ? 0.15 : 0.4 + energia / 100 * 1.4
            ZStack {
                LinearGradient(colors: [color.opacity(0.55), Tema.superficie, Tema.fondo],
                               startPoint: .top, endPoint: .bottom)
                Canvas { c, tam in
                    // Luces que flotan
                    for i in 0..<14 {
                        let semilla = Double(i) * 37.7
                        let x = (semilla.truncatingRemainder(dividingBy: 1) + Double(i) / 14) * tam.width
                        let y = (0.15 + (Double(i * 7 % 10) / 10) * 0.6) * tam.height
                        let r = 4 + Double(i % 4) * 5
                        let desplaza = (t * ritmo * 18 + semilla).truncatingRemainder(dividingBy: tam.width + 40)
                        let px = (x - desplaza).truncatingRemainder(dividingBy: tam.width + 40)
                        let rect = CGRect(x: px < -20 ? px + tam.width + 40 : px, y: y + sin(t + semilla) * 6, width: r, height: r)
                        c.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.05 + Double(i % 3) * 0.04)))
                    }
                    // Líneas de velocidad (no en descanso)
                    if deporte != nil {
                        for i in 0..<6 {
                            let y = tam.height * (0.3 + Double(i) * 0.09)
                            let largo = 40 + Double(i % 3) * 30
                            let x = tam.width - (t * ritmo * 260 + Double(i) * 97).truncatingRemainder(dividingBy: tam.width + largo)
                            var p = Path()
                            p.move(to: CGPoint(x: x, y: y))
                            p.addLine(to: CGPoint(x: x + largo, y: y))
                            c.stroke(p, with: .color(.white.opacity(0.10 + energia / 100 * 0.15)), lineWidth: 2)
                        }
                    }
                }
                Image(uiImage: imagen)
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 10)
                    .padding(.top, 12)
                    .scaleEffect(1 + sin(t * (deporte == nil ? 0.8 : 2.2 * ritmo)) * 0.012)
                    .offset(y: CGFloat(sin(t * 3.2 * ritmo)) * (deporte == nil ? 1 : 3))
                    .shadow(color: color.opacity(0.5), radius: 18)
                    .saturation(energia < 35 ? 0.75 : 1)
            }
        }
        .aspectRatio(350.0 / 400.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityLabel(deporte.map { "Tu personaje: hoy toca \($0.rawValue.lowercased())" } ?? "Tu personaje descansando")
    }
}
