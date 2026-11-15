// TarjetasProgreso.swift
// ------------------------------------------------------------------
// El parte del último entreno y la cabecera de horas de cada semana.
// ------------------------------------------------------------------

import SwiftUI

/// Previsto frente a hecho del último entreno, con los puntos ganados.
struct TarjetaParte: View {
    let parte: Parte
    @State private var sensacion = Sensacion(dia: "", deporte: "")
    @State private var puntosVisibles = 0
    @State private var aparecido = false

    var body: some View {
        Tarjeta {
            HStack {
                Label("Parte del entreno", systemImage: "flag.checkered")
                    .font(.headline)
                Spacer()
                Text("+\(puntosVisibles)")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(Tema.experiencia)
                    .contentTransition(.numericText())
            }
            Text("\(Calendario.etiqueta(parte.sesion.fecha)) · \(parte.sesion.titulo)")
                .font(.subheadline.bold())
            Text(parte.estado == .hecha ? "Cumplida" : "A medias: no llegó al 80 % del tiempo")
                .font(.caption.bold())
                .foregroundStyle(parte.estado == .hecha ? Tema.carrera : Tema.experiencia)

            if let previstos = parte.minutosPrevistos {
                FilaComparada(titulo: "Duración", hecho: "\(Int(parte.minutosHechos))'",
                              objetivo: "\(Int(previstos))'",
                              progreso: min(parte.minutosHechos / previstos, 1),
                              bien: parte.minutosHechos >= previstos * 0.8, aparecido: aparecido)
            }
            if let vatios = parte.potenciaMedia, let objetivo = parte.objetivoPotencia {
                FilaComparada(titulo: "Potencia media", hecho: "\(Int(vatios)) W", objetivo: "\(Int(objetivo)) W",
                              progreso: min(vatios / objetivo, 1),
                              bien: abs(vatios - objetivo) <= objetivo * 0.08, aparecido: aparecido)
            }
            if let pulso = parte.pulsoMedio, let rango = parte.objetivoPulso {
                let dentro = Int(pulso) >= rango.desde - 5 && Int(pulso) <= rango.hasta
                FilaComparada(titulo: "Pulso medio", hecho: "\(Int(pulso)) ppm", objetivo: "\(rango.desde)-\(rango.hasta)",
                              progreso: min(pulso / Double(rango.hasta), 1),
                              bien: dentro, aparecido: aparecido)
            }
            Text(lectura)
                .font(.footnote)
                .foregroundStyle(Tema.textoSecundario)

            Divider().overlay(Tema.pista)
            Text("¿Cómo te ha ido?")
                .font(.subheadline.bold())
            SelectorDiez(titulo: "Esfuerzo", extremos: ("muy fácil", "al límite"), valor: $sensacion.esfuerzo, color: Tema.bici)
            SelectorDiez(titulo: "Ánimo", extremos: ("por los suelos", "a tope"), valor: $sensacion.animo, color: Tema.turquesa)
            SelectorDiez(titulo: "Molestias", extremos: ("nada", "no puedo"), valor: $sensacion.dolor, color: Tema.alerta)
            if (sensacion.dolor ?? 0) >= 4 {
                Text(parte.sesion.tipo == "Run"
                     ? "Con 4 o más: la próxima carrera pasa a bici o piscina."
                     : "Con 4 o más, coméntalo al entrenador en la revisión semanal.")
                    .font(.caption)
                    .foregroundStyle(Tema.alerta)
            }
        }
        .onChange(of: sensacion.esfuerzo) { _, _ in Sensaciones.guardar(sensacion) }
        .onChange(of: sensacion.animo) { _, _ in Sensaciones.guardar(sensacion) }
        .onChange(of: sensacion.dolor) { _, _ in Sensaciones.guardar(sensacion) }
        .onAppear {
            sensacion = Sensaciones.de(dia: parte.sesion.fecha, deporte: parte.sesion.deporte)
            if parte.sesion.tipo == "Run", sensacion.dolor == nil {
                sensacion.dolor = DiarioDolor.valor(dia: parte.sesion.fecha)
            }
            guard !aparecido else { return }
            withAnimation(.easeOut(duration: 1.0)) { aparecido = true }
            withAnimation(.spring(duration: 1.2).delay(0.3)) { puntosVisibles = parte.puntos }
        }
    }

    private var lectura: String {
        var frases: [String] = []
        if let vatios = parte.potenciaMedia, let objetivo = parte.objetivoPotencia {
            if vatios > objetivo * 1.08 { frases.append("Ibas por encima de lo previsto: en Z2, menos es más.") }
            else if vatios < objetivo * 0.92 { frases.append("Algo por debajo de la potencia prevista.") }
            else { frases.append("Potencia clavada.") }
        }
        if parte.sesion.tipo == "Run" {
            frases.append("En carrera el pulso medio incluye los tramos caminando, así que es normal que quede algo bajo.")
        } else if let pulso = parte.pulsoMedio, let rango = parte.objetivoPulso, Int(pulso) > rango.hasta {
            frases.append("El pulso se fue por encima de la zona.")
        }
        return frases.joined(separator: " ")
    }
}

private struct FilaComparada: View {
    let titulo: String
    let hecho: String
    let objetivo: String
    let progreso: Double
    let bien: Bool
    let aparecido: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(titulo)
                    .font(.caption)
                    .foregroundStyle(Tema.textoSecundario)
                Spacer()
                Text(hecho)
                    .font(.subheadline.bold())
                Text("de \(objetivo)")
                    .font(.caption)
                    .foregroundStyle(Tema.textoSecundario)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Tema.pista)
                    Capsule().fill(bien ? Tema.carrera : Tema.experiencia)
                        .frame(width: geo.size.width * (aparecido ? progreso : 0))
                }
            }
            .frame(height: 8)
        }
    }
}

/// Cabecera de una semana del plan: horas previstas por deporte frente a tu media.
struct CabeceraSemana: View {
    let total: TotalSemana
    let media: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("S\(total.semana)")
                    .font(.title3.bold())
                Spacer()
                Text(Totales.texto(total.total) + " previstas")
                    .font(.subheadline.bold())
                    .foregroundStyle(Tema.turquesa)
            }
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(orden, id: \.self) { d in
                        if let m = total.minutos[d], m > 0 {
                            Rectangle()
                                .fill(d.color)
                                .frame(width: max(4, geo.size.width * m / max(total.total, 1) - 2))
                        }
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 8)
            HStack(spacing: 10) {
                ForEach(orden, id: \.self) { d in
                    if let m = total.minutos[d], m > 0 {
                        HStack(spacing: 4) {
                            Circle().fill(d.color).frame(width: 7, height: 7)
                            Text("\(d.rawValue) \(Totales.texto(m))")
                        }
                    }
                }
            }
            .font(.caption)
            .foregroundStyle(Tema.textoSecundario)
            if let media {
                let diferencia = total.total / 60 - media
                Text("Tu media real de las últimas 4 semanas: \(String(format: "%.1f", media)) h (\(diferencia >= 0 ? "+" : "")\(String(format: "%.1f", diferencia)) h)")
                    .font(.caption)
                    .foregroundStyle(diferencia < -1.5 ? Tema.experiencia : Tema.textoSecundario)
            }
        }
        .padding(.top, 6)
    }

    private var orden: [Deporte] { [.bici, .agua, .carrera, .fuerza] }
}

/// Fila de once botones, del 0 al 10.
struct SelectorDiez: View {
    let titulo: String
    let extremos: (String, String)
    @Binding var valor: Int?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(titulo)
                    .font(.caption.bold())
                Spacer()
                Text(valor.map { "\($0)" } ?? "sin apuntar")
                    .font(.caption.bold())
                    .foregroundStyle(valor == nil ? Tema.textoSecundario : color)
            }
            HStack(spacing: 3) {
                ForEach(0...10, id: \.self) { n in
                    Button {
                        withAnimation(.spring(duration: 0.25)) { valor = (valor == n ? nil : n) }
                    } label: {
                        Text("\(n)")
                            .font(.caption2.bold())
                            .frame(maxWidth: .infinity, minHeight: 28)
                            .background(valor.map { n <= $0 } == true ? color.opacity(0.25 + Double(n) * 0.065) : Tema.pista)
                            .foregroundStyle(valor == n ? Tema.fondo : Tema.texto)
                            .background(valor == n ? color : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Text(extremos.0)
                Spacer()
                Text(extremos.1)
            }
            .font(.caption2)
            .foregroundStyle(Tema.textoSecundario)
        }
    }
}
