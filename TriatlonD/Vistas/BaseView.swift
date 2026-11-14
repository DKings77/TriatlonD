// BaseView.swift
// ------------------------------------------------------------------
// Pantalla principal: el personaje en su campamento y la energía del día.
// La escena y el personaje están dibujados y animados por código.
// ------------------------------------------------------------------

import SwiftUI

struct BaseView: View {
    let almacen: AlmacenEstado
    let plan: AlmacenPlan
    @State private var ajustesVisibles = false

    private var estado: EstadoDia { almacen.estado }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("David")
                            .font(.largeTitle.bold())
                        Text(Travesia.subtitulo(Date()))
                            .font(.subheadline)
                            .foregroundStyle(Tema.textoSecundario)
                    }
                    Spacer()
                    Button {
                        Task { await almacen.recargar() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .rotationEffect(.degrees(almacen.cargando ? 360 : 0))
                            .animation(almacen.cargando ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                                       value: almacen.cargando)
                    }
                    .disabled(almacen.cargando)
                    .accessibilityLabel("Actualizar datos")
                    Button {
                        ajustesVisibles = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Ajustes")
                }

                if let aviso = almacen.aviso {
                    Text(aviso)
                        .font(.footnote)
                        .foregroundStyle(Tema.experiencia)
                }

                if let hora = almacen.ultimaActualizacion {
                    Text("Actualizado a las \(hora.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(Tema.textoSecundario)
                }

                if let novedad = almacen.novedad {
                    HStack(spacing: 10) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Tema.experiencia)
                        Text(novedad)
                            .font(.subheadline.bold())
                        Spacer(minLength: 0)
                        Button {
                            withAnimation { almacen.novedad = nil }
                        } label: {
                            Image(systemName: "xmark")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Cerrar aviso")
                    }
                    .padding(.leading, 14)
                    .background(Tema.superficie)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Tema.experiencia, lineWidth: 1))
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }

                if let motivos = Juego.modoBaja(estado, historico: almacen.historico) {
                    TarjetaModoBaja(motivos: motivos)
                }

                HStack(alignment: .top, spacing: 12) {
                    EscenaPersonaje(deporte: deporteDeHoy, energia: Juego.energia(estado) ?? 50, notaSueno: estado.sueno.puntuacion)
                        .frame(maxWidth: .infinity)
                    PanelEnergia(estado: estado, historico: almacen.historico, frase: fraseEnergia)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 250)

                TarjetaHoyToca(plan: plan, almacen: almacen)

                if let historico = almacen.historico,
                   let parte = Partes.ultimo(plan: plan.sesiones, hechas: historico.sesiones) {
                    TarjetaParte(parte: parte)
                        .id(parte.sesion.id)
                }

            }
            .padding(20)
            .animation(.spring(duration: 0.5), value: almacen.novedad)
        }
        .background(Tema.fondo)
        .foregroundStyle(Tema.texto)
        .refreshable { await almacen.recargar() }
        .sheet(isPresented: $ajustesVisibles) {
            AjustesView(almacen: almacen, plan: plan)
        }
    }

    /// Lo que toca hoy: la primera sesión pendiente, si no la primera de hoy; nada = descanso.
    private var deporteDeHoy: Deporte? {
        let hoy = Calendario.texto(Date())
        let cruce = Analisis.cumplimiento(plan: plan.sesiones, hechas: almacen.historico?.sesiones ?? [], hoy: hoy)
            .filter { $0.sesion.fecha == hoy }
        // La fuerza va antes que el resto el mismo día, pero el personaje enseña el deporte principal.
        let principal = cruce.filter { $0.sesion.deporte != .fuerza }
        if let elegido = (principal.first { $0.estado == .pendiente } ?? principal.first)?.sesion.deporte {
            return elegido
        }
        // Día solo de fuerza o sin nada: el próximo deporte del plan; si no hay, carrera.
        let proximo = plan.ordenadas.first { $0.fecha > hoy && $0.deporte != .fuerza }
        return proximo?.deporte ?? .carrera
    }

    private var fraseEnergia: String {
        guard let e = Juego.energia(estado) else { return "Sin datos de energía" }
        if e >= 75 { return "Con fuerzas para todo" }
        if e >= 55 { return "Bien, sin excesos" }
        if e >= 35 { return "Hoy, suave" }
        return "Toca descansar"
    }
}

/// Aviso de Modo Baja: el cuerpo pide aflojar.
struct TarjetaModoBaja: View {
    let motivos: [String]
    @State private var latido = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "battery.25")
                    .font(.title2)
                    .foregroundStyle(Tema.alerta)
                    .scaleEffect(latido ? 1.12 : 1)
                Text("Modo Baja")
                    .font(.title3.bold())
                    .foregroundStyle(Tema.alerta)
            }
            ForEach(motivos, id: \.self) { motivo in
                Text("• " + motivo)
                    .font(.subheadline)
            }
            Text("Hoy, sesión suave o descanso. El entrenador lo tendrá en cuenta si le pides la semana.")
                .font(.footnote)
                .foregroundStyle(Tema.textoSecundario)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.alerta.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Tema.alerta.opacity(0.6), lineWidth: 1))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever()) { latido = true }
        }
    }
}

/// Lo que toca hoy según el plan (o mañana, si hoy ya está todo hecho o es descanso).
struct TarjetaHoyToca: View {
    let plan: AlmacenPlan
    let almacen: AlmacenEstado
    @State private var elegida: SesionPlan?

    var body: some View {
        let hoy = Calendario.texto(Date())
        let manana = Calendario.texto(Date().addingTimeInterval(86400))
        let cruce = Analisis.cumplimiento(plan: plan.sesiones, hechas: almacen.historico?.sesiones ?? [], hoy: hoy)
        let deHoy = cruce.filter { $0.sesion.fecha == hoy }
        let pendientesHoy = deHoy.filter { $0.estado == .pendiente }
        let mostrar = pendientesHoy.isEmpty ? cruce.filter { $0.sesion.fecha == manana } : deHoy
        let titulo = !pendientesHoy.isEmpty ? "Hoy toca" : (deHoy.isEmpty ? "Hoy, descanso. Mañana toca" : "Hoy, hecho. Mañana toca")
        Tarjeta {
            Label(titulo, systemImage: pendientesHoy.isEmpty ? "moon.stars.fill" : "flag.fill")
                .font(.headline)
                .foregroundStyle(pendientesHoy.isEmpty ? Tema.textoSecundario : Tema.turquesa)
            if mostrar.isEmpty {
                Text("Nada planificado. Pídele la semana al entrenador en Plan.")
                    .font(.subheadline)
                    .foregroundStyle(Tema.textoSecundario)
            }
            ForEach(mostrar) { c in
                Button {
                    elegida = c.sesion
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: c.estado == .hecha ? "checkmark.circle.fill" : icono(c.sesion.deporte))
                            .font(.title3)
                            .foregroundStyle(c.sesion.deporte.color)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.sesion.titulo)
                                .font(.subheadline.bold())
                            if let e = c.sesion.estructura {
                                Text(e)
                                    .font(.caption)
                                    .foregroundStyle(Tema.textoSecundario)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Tema.textoSecundario)
                    }
                    .opacity(c.estado == .hecha ? 0.6 : 1)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(item: $elegida) { sesion in
            DetalleSesionView(sesion: sesion, plan: plan)
        }
    }

    private func icono(_ d: Deporte) -> String {
        switch d {
        case .bici: return "bicycle"
        case .agua: return "figure.pool.swim"
        case .carrera: return "figure.run"
        case .fuerza: return "dumbbell.fill"
        }
    }
}

/// Al lado del personaje: la energía como una batería de cinco niveles
/// y lo que la explica (sueño, VFC y carga).
struct PanelEnergia: View {
    let estado: EstadoDia
    let historico: Historico?
    let frase: String
    @State private var visible = false

    private var energia: Double { Juego.energia(estado) ?? 0 }
    private var nivel: Int { Int((energia / 20).rounded(.up)).clamped(0, 5) }
    private var color: Color {
        switch nivel {
        case 5, 4: return Tema.carrera
        case 3: return Tema.turquesa
        case 2: return Tema.experiencia
        default: return Tema.alerta
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Energía")
                .font(.caption)
                .foregroundStyle(Tema.textoSecundario)
            HStack(alignment: .bottom, spacing: 10) {
                // Batería de cinco segmentos
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 2).fill(Tema.pista).frame(width: 16, height: 4)
                    ForEach((1...5).reversed(), id: \.self) { n in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(n <= nivel && visible ? color : Tema.pista)
                            .frame(width: 34, height: 15)
                            .animation(.spring(duration: 0.4).delay(Double(5 - n) * 0.08), value: visible)
                    }
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(Juego.energia(estado).map { "\(Int($0))" } ?? "–")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                    Text("Nivel \(nivel) de 5")
                        .font(.caption2.bold())
                        .foregroundStyle(Tema.textoSecundario)
                }
            }
            Text(frase)
                .font(.subheadline.bold())
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 3) {
                fila("moon.zzz.fill", estado.sueno.horas.map { String(format: "%.1f h", $0) } ?? "–")
                fila("waveform.path.ecg", estado.vfc.anocheMs.map { "\(Int($0)) ms" } ?? "–")
                fila("gauge.with.dots.needle.50percent", estado.carga.relacion.map { String(format: "carga %.1f", $0) } ?? "–")
            }
            Spacer(minLength: 0)
            if Juego.modoBaja(estado, historico: historico) == nil {
                Label("Sin Modo Baja", systemImage: "checkmark.circle.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(Tema.carrera)
            } else {
                Label("Modo Baja", systemImage: "battery.25")
                    .font(.caption2.bold())
                    .foregroundStyle(Tema.alerta)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Tema.superficie)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onAppear { visible = true }
    }

    private func fila(_ icono: String, _ texto: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icono)
                .font(.caption2)
                .foregroundStyle(Tema.textoSecundario)
                .frame(width: 14)
            Text(texto)
                .font(.caption)
        }
    }
}

private extension Int {
    func clamped(_ a: Int, _ b: Int) -> Int { Swift.min(Swift.max(self, a), b) }
}
