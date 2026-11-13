// SemanaView.swift
// ------------------------------------------------------------------
// Las misiones de la semana y el botón de aprobar. De momento la semana
// es la S11 guardada en la app. El botón envía bici, carrera y fuerza a intervals.icu.
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

    // La S11 en el formato de intervals.icu. Los nombres siguen la nomenclatura
    // "S11 D1: C1 35' Z2 2/2 | estructura". Bici en % de un FTP de 200 W y en escalones;
    // carrera por zonas de pulso con tramos de caminar; fuerza solo con duración.
    private let plan: [EntrenoPlan] = [
        EntrenoPlan(fecha: "2026-11-14", tipo: "Run", interior: false,
                    nombre: "S10 D6: C2 35' Z2 | 5' cal + 5 x (4' Z2 + 1' caminar) + 5' enf",
                    pasos: "Calentamiento\n- 5m Z1 HR\n\n5x\n- 4m Z2 HR\n- 1m Z1 HR\n\nEnfriamiento\n- 5m Z1 HR"),
        EntrenoPlan(fecha: "2026-11-15", tipo: "Ride", interior: true,
                    nombre: "S10 D7: B3 60' Z2 140W | 10' cal + 40' Z2 140W + 10' enf",
                    pasos: "- 10m 60%\n- 40m 70%\n- 10m 55%"),
        EntrenoPlan(fecha: "2026-11-16", tipo: "WeightTraining", interior: true,
                    nombre: "S11 D1: F1 50' 1/2",
                    pasos: "- 50m"),
        EntrenoPlan(fecha: "2026-11-16", tipo: "Run", interior: false,
                    nombre: "S11 D1: C1 35' Z2 2/2 | 5' cal + 5 x (4' Z2 + 1' caminar) + 5' enf",
                    pasos: "Calentamiento\n- 5m Z1 HR\n\n5x\n- 4m Z2 HR\n- 1m Z1 HR\n\nEnfriamiento\n- 5m Z1 HR"),
        EntrenoPlan(fecha: "2026-11-17", tipo: "Ride", interior: true,
                    nombre: "S11 D2: B1 60' Z2 140W | 10' cal + 40' Z2 140W + 10' enf",
                    pasos: "- 10m 60%\n- 40m 70%\n- 10m 55%"),
        EntrenoPlan(fecha: "2026-11-18", tipo: "WeightTraining", interior: true,
                    nombre: "S11 D3: F2 35' 1/2",
                    pasos: "- 35m"),
        EntrenoPlan(fecha: "2026-11-19", tipo: "Ride", interior: true,
                    nombre: "S11 D4: B2 55' Z2 | 10' cal + 20' Z2 140W + 3 x (3' 172W + 3' rec) + 7' enf",
                    pasos: "- 10m 60%\n- 20m 70%\n- 3m 86%\n- 3m 60%\n- 3m 86%\n- 3m 60%\n- 3m 86%\n- 3m 60%\n- 7m 55%"),
        EntrenoPlan(fecha: "2026-11-20", tipo: "WeightTraining", interior: true,
                    nombre: "S11 D5: F3 35' 1/2",
                    pasos: "- 35m"),
        EntrenoPlan(fecha: "2026-11-21", tipo: "Run", interior: false,
                    nombre: "S11 D6: C2 38' Z2 2/2 | 5' cal + 4 x (6' Z2 + 1' caminar) + 5' enf",
                    pasos: "Calentamiento\n- 5m Z1 HR\n\n4x\n- 6m Z2 HR\n- 1m Z1 HR\n\nEnfriamiento\n- 5m Z1 HR")
    ]

    private let misiones: [Mision] = [
        Mision(id: 1, dia: "Lun", titulo: "Fuerza 50' + carrera 35'", deportes: [.fuerza, .carrera], xp: 200),
        Mision(id: 2, dia: "Mar", titulo: "Bici 60' Z2 · 140 W", deportes: [.bici], xp: 100),
        Mision(id: 3, dia: "Mié", titulo: "Fuerza 35' + natación 1.700 m", deportes: [.fuerza, .agua], xp: 200),
        Mision(id: 4, dia: "Jue", titulo: "Bici 55' Z2 + 3 x 3' a 172 W", deportes: [.bici], xp: 100),
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

                Text("Se envían bici, carrera y fuerza. La natación sigue programándose en Garmin y el test de FTP se hace con el de Rouvy.")
                    .font(.caption)
                    .foregroundStyle(Tema.textoSecundario)
            }
            .padding(20)
        }
        .background(Tema.fondo)
        .foregroundStyle(Tema.texto)
        .confirmationDialog("¿Enviar la semana?", isPresented: $confirmarVisible, titleVisibility: .visible) {
            Button("Enviar 9 sesiones") {
                Task { await enviar() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se dejarán en intervals.icu la carrera del sábado 14, la bici del domingo 15, las 2 bicis, las 2 carreras y las 3 sesiones de fuerza de la S11. Lo que ya exista se corrige en vez de duplicarse. De ahí pasan solas a Garmin, y las bicis también a Rouvy. La natación y el test de FTP no se envían desde aquí.")
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
            let r = try await intervals.enviar(plan)
            resultado = "Creadas: \(r.creados). Corregidas: \(r.actualizados). Sin cambios: \(r.sinCambios)."
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
