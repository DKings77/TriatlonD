// TarjetaNota.swift
// ------------------------------------------------------------------
// La nota de triatleta: anillo con la media y una barra por deporte.
// ------------------------------------------------------------------

import SwiftUI

struct TarjetaNota: View {
    let nota: NotaTriatleta
    var detalle = false
    @State private var anterior: [String: Double] = [:]
    @State private var aparecido = false

    var body: some View {
        Tarjeta {
            HStack(spacing: 16) {
                AnilloProgreso(valor: aparecido ? (nota.global ?? 0) : 0, color: Tema.experiencia, etiqueta: "de 100")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nota de triatleta")
                        .font(.caption)
                        .foregroundStyle(Tema.textoSecundario)
                    Text(nota.global.map(Nota.nivel) ?? "Sin datos")
                        .font(.title3.bold())
                        .foregroundStyle(Tema.experiencia)
                    Text("Categoría \(nota.categoria) · \(nota.edad) años")
                        .font(.caption)
                        .foregroundStyle(Tema.textoSecundario)
                    if let g = nota.global, let antes = anterior["Global"] {
                        Variacion(diferencia: g - antes)
                    }
                }
            }
            ForEach(nota.deportes) { d in
                FilaNota(nota: d, anterior: anterior[d.deporte.rawValue], detalle: detalle, aparecido: aparecido)
            }
            if detalle {
                Text("El 100 es el mejor del mundo de tu categoría; el 0, el sofá. Carrera: tablas oficiales de edad de 2025 (USATF). Bici y natación no tienen tablas oficiales de edad: se comparan con el nivel mundial y se ajustan con el mismo factor (\(String(format: "%.4f", nota.factor))). Las tablas cambian al subir de categoría. Cuenta tu mejor marca de los últimos 60 días, así que baja si paras.")
                    .font(.caption)
                    .foregroundStyle(Tema.textoSecundario)
            }
        }
        .onAppear {
            anterior = Nota.registrar(nota)
            withAnimation(.easeOut(duration: 1.2)) { aparecido = true }
        }
    }
}

private struct FilaNota: View {
    let nota: NotaDeporte
    let anterior: Double?
    let detalle: Bool
    let aparecido: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(nota.deporte.rawValue)
                    .font(.subheadline.bold())
                    .foregroundStyle(nota.deporte.color)
                Text(nota.marca)
                    .font(.caption)
                    .foregroundStyle(Tema.textoSecundario)
                Spacer()
                if let n = nota.nota, let anterior {
                    Variacion(diferencia: n - anterior)
                }
                Text(nota.nota.map { "\(Int($0.rounded()))" } ?? "–")
                    .font(.title3.bold().monospacedDigit())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Tema.pista)
                    Capsule().fill(nota.deporte.color.gradient)
                        .frame(width: geo.size.width * (aparecido ? (nota.nota ?? 0) / 100 : 0))
                    // Marcas de nivel: aficionado (45), regional (70), mundial (90)
                    ForEach([45.0, 70.0, 90.0], id: \.self) { m in
                        Rectangle().fill(Tema.fondo.opacity(0.6))
                            .frame(width: 2)
                            .offset(x: geo.size.width * m / 100)
                    }
                }
            }
            .frame(height: 10)
            Text(detalle ? nota.fuente + (nota.siguiente.map { " · " + $0 } ?? "") : nota.fuente)
                    .font(.caption)
                    .foregroundStyle(Tema.textoSecundario)
        }
    }
}

private struct Variacion: View {
    let diferencia: Double

    var body: some View {
        if abs(diferencia) >= 0.5 {
            Label(String(format: "%+.0f", diferencia), systemImage: diferencia > 0 ? "arrow.up" : "arrow.down")
                .font(.caption.bold())
                .foregroundStyle(diferencia > 0 ? Tema.carrera : Tema.alerta)
        }
    }
}
