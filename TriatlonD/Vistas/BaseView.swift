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

                EscenaPersonaje(deporte: deporteDeHoy, energia: Juego.energia(estado) ?? 50, notaSueno: estado.sueno.puntuacion)

                Tarjeta {
                    HStack(spacing: 16) {
                        AnilloProgreso(valor: Juego.energia(estado) ?? 0, color: Tema.turquesa, etiqueta: "Energía")
                        VStack(alignment: .leading, spacing: 6) {
                            Text(fraseEnergia)
                                .font(.headline)
                            Text("Tu personaje corre más ligero cuanta más energía tienes. Sale de tu sueño y tu variabilidad del pulso.")
                                .font(.footnote)
                                .foregroundStyle(Tema.textoSecundario)
                            if Juego.modoBaja(estado, historico: almacen.historico) == nil {
                                Label("Modo Baja: no activo", systemImage: "battery.100")
                                    .font(.caption.bold())
                                    .foregroundStyle(Tema.carrera)
                            }
                        }
                    }
                }

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
        return (principal.first { $0.estado == .pendiente } ?? principal.first ?? cruce.first)?.sesion.deporte
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
