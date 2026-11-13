// FichaView.swift
// ------------------------------------------------------------------
// Tus datos explicados: los dos depósitos de carga y las métricas del día.
// ------------------------------------------------------------------

import SwiftUI

struct FichaView: View {
    let estado: EstadoDia

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Ficha")
                    .font(.largeTitle.bold())

                Tarjeta {
                    Text("Los dos depósitos de carga")
                        .font(.headline)
                    HStack(alignment: .bottom, spacing: 14) {
                        Deposito(titulo: "Esta semana", detalle: "Se llena y se vacía rápido",
                                 valor: estado.carga.aguda, color: Tema.bici)
                        Deposito(titulo: "Tu fondo", detalle: "Sube y baja despacio",
                                 valor: estado.carga.cronica, color: Tema.turquesa)
                    }
                    Text(Juego.lecturaCarga(estado.carga))
                        .font(.footnote)
                        .foregroundStyle(Tema.textoSecundario)
                    Text("Carga calculada por la app con tus sesiones de 28 días. Puede no coincidir con la de Garmin.")
                        .font(.caption)
                        .foregroundStyle(Tema.textoSecundario)
                }

                HStack(spacing: 10) {
                    Metrica(titulo: "Sueño", valor: estado.sueno.horas.map { String(format: "%.1f h", $0) })
                    Metrica(titulo: "Pulso (VFC)", valor: estado.vfc.mediaSemanalMs.map { "\(Int($0)) ms" })
                    Metrica(titulo: "Peso", valor: estado.pesoKg.map { String(format: "%.1f kg", $0) })
                }
            }
            .padding(20)
        }
        .background(Tema.fondo)
        .foregroundStyle(Tema.texto)
    }
}

/// Depósito vertical: la altura del relleno es la carga sobre un tope de 600.
private struct Deposito: View {
    var titulo: String
    var detalle: String
    var valor: Double?
    var color: Color

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 12).fill(Tema.pista)
                    RoundedRectangle(cornerRadius: 12).fill(color)
                        .frame(height: geo.size.height * min((valor ?? 0) / 600, 1))
                }
            }
            .frame(height: 120)
            Text(valor.map { "\(Int($0))" } ?? "Sin datos")
                .font(.title2.bold())
            Text(titulo)
                .font(.subheadline)
            Text(detalle)
                .font(.caption)
                .foregroundStyle(Tema.textoSecundario)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct Metrica: View {
    var titulo: String
    var valor: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titulo)
                .font(.caption)
                .foregroundStyle(Tema.textoSecundario)
            Text(valor ?? "Sin datos")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Tema.superficie)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
