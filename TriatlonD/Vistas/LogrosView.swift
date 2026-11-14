// LogrosView.swift
// ------------------------------------------------------------------
// Tarjeta de logros en Base y la vitrina completa.
// ------------------------------------------------------------------

import SwiftUI

struct TarjetaLogros: View {
    let logros: [Logro]
    @State private var vitrina = false
    @State private var brillo = false

    var body: some View {
        let conseguidos = logros.filter(\.conseguido)
        let nuevos = Logros.nuevos(logros)
        Button {
            vitrina = true
        } label: {
            Tarjeta {
                HStack {
                    Label("Logros", systemImage: "trophy.fill")
                        .font(.headline)
                        .foregroundStyle(Tema.experiencia)
                    Spacer()
                    Text("\(conseguidos.count) de \(logros.count)")
                        .font(.subheadline.bold())
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Tema.textoSecundario)
                }
                if let nuevo = nuevos.first {
                    HStack(spacing: 10) {
                        Image(systemName: nuevo.icono)
                            .font(.title2)
                            .foregroundStyle(Tema.experiencia)
                            .scaleEffect(brillo ? 1.2 : 0.9)
                            .shadow(color: Tema.experiencia.opacity(brillo ? 0.9 : 0), radius: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("¡Nuevo! \(nuevo.titulo)")
                                .font(.subheadline.bold())
                            Text(nuevo.detalle)
                                .font(.caption)
                                .foregroundStyle(Tema.textoSecundario)
                        }
                    }
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.8).repeatForever()) { brillo = true }
                    }
                } else {
                    HStack(spacing: 8) {
                        ForEach(conseguidos.suffix(6)) { l in
                            Image(systemName: l.icono)
                                .foregroundStyle(Tema.experiencia)
                                .frame(width: 30, height: 30)
                                .background(Tema.experiencia.opacity(0.15))
                                .clipShape(Circle())
                        }
                        if conseguidos.isEmpty {
                            Text("El primero está cerca: mira la vitrina.")
                                .font(.caption)
                                .foregroundStyle(Tema.textoSecundario)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $vitrina) {
            VitrinaLogros(logros: logros)
        }
    }
}

struct VitrinaLogros: View {
    let logros: [Logro]
    @Environment(\.dismiss) private var cerrar
    @State private var visible = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(Array(logros.enumerated()), id: \.element.id) { i, l in
                        VStack(spacing: 8) {
                            Image(systemName: l.conseguido ? l.icono : "lock.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(l.conseguido ? Tema.experiencia : Tema.textoSecundario)
                                .frame(width: 60, height: 60)
                                .background((l.conseguido ? Tema.experiencia : Tema.pista).opacity(l.conseguido ? 0.15 : 0.6))
                                .clipShape(Circle())
                            Text(l.titulo)
                                .font(.subheadline.bold())
                                .multilineTextAlignment(.center)
                            Text(l.detalle)
                                .font(.caption)
                                .foregroundStyle(Tema.textoSecundario)
                                .multilineTextAlignment(.center)
                            if let fecha = l.fecha {
                                Text(fecha == "antes" ? "Ya lo tenías" : "Conseguido \(Calendario.etiqueta(fecha))")
                                    .font(.caption2.bold())
                                    .foregroundStyle(Tema.carrera)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 170)
                        .background(Tema.superficie)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .opacity(visible ? (l.conseguido ? 1 : 0.6) : 0)
                        .scaleEffect(visible ? 1 : 0.8)
                        .animation(.spring(duration: 0.4).delay(Double(i) * 0.03), value: visible)
                    }
                }
                .padding(20)
            }
            .background(Tema.fondo)
            .foregroundStyle(Tema.texto)
            .navigationTitle("Vitrina de logros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { cerrar() }
                }
            }
            .onAppear { visible = true }
        }
        .preferredColorScheme(.dark)
    }
}
