// TravesiaView.swift
// ------------------------------------------------------------------
// El mapa de la temporada como un camino de etapas, de arriba (el jefe)
// hacia abajo (lo ya recorrido). Datos fijos de la región 1 por ahora.
// ------------------------------------------------------------------

import SwiftUI

enum EstadoEtapa {
    case superada, refugio, actual, jefe
}

struct Etapa: Identifiable {
    let id: Int
    let titulo: String
    let detalle: String
    let estado: EstadoEtapa
}

struct TravesiaView: View {
    private let etapas: [Etapa] = [
        Etapa(id: 12, titulo: "Jefe: test de FTP", detalle: "Sábado 21 de noviembre", estado: .jefe),
        Etapa(id: 11, titulo: "Etapa 11 · estás aquí", detalle: "Semana puente", estado: .actual),
        Etapa(id: 10, titulo: "Etapa 10 · en el refugio", detalle: "Semana a medias", estado: .refugio),
        Etapa(id: 9, titulo: "Etapa 9", detalle: "Superada", estado: .superada),
        Etapa(id: 8, titulo: "Etapa 8", detalle: "Superada", estado: .superada),
        Etapa(id: 7, titulo: "Etapa 7", detalle: "Superada", estado: .superada)
    ]

    @State private var visible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("La Travesía")
                        .font(.largeTitle.bold())
                    Text("Región 1: la costa de la base")
                        .font(.subheadline)
                        .foregroundStyle(Tema.textoSecundario)
                }

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(etapas.enumerated()), id: \.element.id) { indice, etapa in
                        // El camino se recorre de abajo arriba: lo último aparece primero.
                        let retraso = Double(etapas.count - 1 - indice) * 0.16
                        FilaEtapa(etapa: etapa)
                            .opacity(visible ? 1 : 0)
                            .offset(x: visible ? 0 : -24)
                            .animation(.spring(duration: 0.5).delay(retraso), value: visible)
                        if etapa.id != etapas.last?.id {
                            Rectangle()
                                .fill(etapa.estado == .jefe ? Tema.pista : Tema.turquesa)
                                .frame(width: 3, height: visible ? 26 : 0)
                                .frame(height: 26, alignment: .bottom)
                                .padding(.leading, 21)
                                .animation(.easeOut(duration: 0.3).delay(retraso), value: visible)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tema.superficie)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                Tarjeta {
                    Text("Para vencer al jefe")
                        .font(.headline)
                    Text("Supera tus 200 W de FTP y se abre la región 2.")
                        .font(.subheadline)
                        .foregroundStyle(Tema.textoSecundario)
                }
            }
            .padding(20)
        }
        .background(Tema.fondo)
        .foregroundStyle(Tema.texto)
        .onAppear { visible = true }
        .onDisappear { visible = false }
    }
}

private struct FilaEtapa: View {
    let etapa: Etapa
    @State private var late = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                if etapa.estado == .actual || etapa.estado == .jefe {
                    Circle()
                        .stroke(color, lineWidth: 2)
                        .frame(width: 45, height: 45)
                        .scaleEffect(late ? 1.45 : 1)
                        .opacity(late ? 0 : 0.9)
                        .onAppear {
                            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { late = true }
                        }
                }
                Circle()
                    .fill(color)
                    .frame(width: 45, height: 45)
                Image(systemName: icono)
                    .font(.headline)
                    .foregroundStyle(Tema.fondo)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(etapa.titulo)
                    .font(etapa.estado == .superada ? .subheadline : .headline)
                Text(etapa.detalle)
                    .font(.footnote)
                    .foregroundStyle(Tema.textoSecundario)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch etapa.estado {
        case .superada: return Tema.turquesa
        case .refugio: return Tema.experiencia
        case .actual: return Tema.bici
        case .jefe: return Tema.alerta
        }
    }

    private var icono: String {
        switch etapa.estado {
        case .superada: return "checkmark"
        case .refugio: return "house"
        case .actual: return "figure.walk"
        case .jefe: return "bolt"
        }
    }
}
