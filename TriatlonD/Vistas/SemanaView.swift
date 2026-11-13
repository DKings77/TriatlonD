// SemanaView.swift
// ------------------------------------------------------------------
// Las misiones de la semana y el botón de aprobar. De momento la semana
// es la S11 guardada en la app. El botón envía las bicis a intervals.icu.
// ------------------------------------------------------------------

import SwiftUI

enum Deporte: String {
    case bici = "Bici"
    case agua = "Agua"
    case carrera = "Carrera"
    case fuerza = "Fuerza"

    var color: Color {
        switch self {
        case .bici: return Tema.bici
        case .agua: return Tema.natacion
        case .carrera: return Tema.carrera
        case .fuerza: return Tema.fuerza
        }
    }
}

struct Mision: Identifiable {
    let id: Int
    let dia: String
    let titulo: String
    let deportes: [Deporte]
    let xp: Int
    var esJefe = false
}

struct SemanaView: View {
    @State private var confirmarVisible = false
    @State private var enviando = false
    @State private var resultado: String?

    private let intervals = ClienteIntervals()

    // Las dos bicis de la S11 en el formato de intervals.icu, en escalones
    // (sin rampas ni repeticiones) para que Rouvy las importe sin problemas.
    private let bicis: [EntrenoBici] = [
        EntrenoBici(fecha: "2026-11-17", nombre: "S11 D2: B1 60' Z2 140W",
                    pasos: "- 10m 60%\n- 40m 74%\n- 10m 55%"),
        EntrenoBici(fecha: "2026-11-19", nombre: "S11 D4: B2 55' Z2 + 3x3' 171W",
                    pasos: "- 10m 60%\n- 20m 74%\n- 3m 90%\n- 3m 60%\n- 3m 90%\n- 3m 60%\n- 3m 90%\n- 3m 60%\n- 7m 55%")
    ]

    private let misiones: [Mision] = [
        Mision(id: 1, dia: "Lun", titulo: "Fuerza 50' + carrera 35'", deportes: [.fuerza, .carrera], xp: 200),
        Mision(id: 2, dia: "Mar", titulo: "Bici 60' Z2 · 140 W", deportes: [.bici], xp: 100),
        Mision(id: 3, dia: "Mié", titulo: "Fuerza 35' + natación 1.700 m", deportes: [.fuerza, .agua], xp: 200),
        Mision(id: 4, dia: "Jue", titulo: "Bici 55' Z2 + 3 x 3' a 171 W", deportes: [.bici], xp: 100),
        Mision(id: 5, dia: "Vie", titulo: "Fuerza 35' + natación 1.900 m", deportes: [.fuerza, .agua], xp: 200),
        Mision(id: 6, dia: "Sáb", titulo: "Jefe: test de FTP + carrera 38'", deportes: [.bici, .carrera], xp: 200, esJefe: true),
        Mision(id: 7, dia: "Dom", titulo: "Descanso junto a la hoguera", deportes: [], xp: 60)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Etapa 11")
                        .font(.largeTitle.bold())
                    Text("Misiones propuestas · pendientes de aprobar")
                        .font(.subheadline)
                        .foregroundStyle(Tema.textoSecundario)
                }

                ForEach(misiones) { mision in
                    FilaMision(mision: mision)
                }

                HStack {
                    Text("Etapa completa")
                    Spacer()
                    Text("+300 XP")
                        .bold()
                        .foregroundStyle(Tema.experiencia)
                }
                .font(.subheadline)

                Button {
                    confirmarVisible = true
                } label: {
                    Text(enviando ? "Enviando…" : "Aprobar semana")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Tema.turquesa)
                        .foregroundStyle(Tema.fondo)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(enviando)

                Text("Por ahora se envían las bicis del martes y el jueves. Carrera, natación y fuerza siguen programándose en Garmin.")
                    .font(.caption)
                    .foregroundStyle(Tema.textoSecundario)
            }
            .padding(20)
        }
        .background(Tema.fondo)
        .foregroundStyle(Tema.texto)
        .confirmationDialog("¿Enviar la semana?", isPresented: $confirmarVisible, titleVisibility: .visible) {
            Button("Enviar 2 sesiones de bici") {
                Task { await enviar() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se crearán en intervals.icu la bici del martes 17 y la del jueves 19. De ahí pasan solas a Rouvy y a Garmin.")
        }
        .alert("Semana", isPresented: Binding(get: { resultado != nil }, set: { if !$0 { resultado = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(resultado ?? "")
        }
    }

    private func enviar() async {
        enviando = true
        defer { enviando = false }
        do {
            let r = try await intervals.enviar(bicis)
            resultado = "Sesiones creadas: \(r.creados). Ya estaban: \(r.yaEstaban)."
        } catch {
            resultado = error.localizedDescription
        }
    }
}

private struct FilaMision: View {
    let mision: Mision

    var body: some View {
        HStack(spacing: 12) {
            Text(mision.dia)
                .font(.subheadline.bold())
                .foregroundStyle(mision.esJefe ? Tema.alerta : Tema.textoSecundario)
                .frame(width: 34, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                Text(mision.titulo)
                    .font(.subheadline)
                if !mision.deportes.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(mision.deportes, id: \.self) { deporte in
                            Text(deporte.rawValue)
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(deporte.color)
                                .foregroundStyle(Tema.fondo)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            Spacer()
            Text("\(mision.xp) XP")
                .font(.subheadline.bold())
                .foregroundStyle(Tema.experiencia)
        }
        .padding(12)
        .background(Tema.superficie)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(mision.esJefe ? Tema.alerta : Color.clear, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
