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

                EscenaCorredor(energia: Juego.energia(estado) ?? 50, notaSueno: estado.sueno.puntuacion)

                Tarjeta {
                    HStack(spacing: 16) {
                        AnilloProgreso(valor: Juego.energia(estado) ?? 0, color: Tema.turquesa, etiqueta: "Energía")
                        VStack(alignment: .leading, spacing: 6) {
                            Text(fraseEnergia)
                                .font(.headline)
                            Text("Tu personaje corre más ligero cuanta más energía tienes. Sale de tu sueño y tu variabilidad del pulso.")
                                .font(.footnote)
                                .foregroundStyle(Tema.textoSecundario)
                        }
                    }
                }

                if let historico = almacen.historico {
                    TarjetaNota(nota: Nota.calcular(historico: historico, pesoKg: estado.pesoKg))
                }

                if let historico = almacen.historico,
                   let parte = Partes.ultimo(plan: plan.sesiones, hechas: historico.sesiones) {
                    TarjetaParte(parte: parte)
                        .id(parte.sesion.id)
                }

                Tarjeta {
                    Text("Últimas sesiones")
                        .font(.headline)
                    ForEach(estado.actividades) { a in
                        HStack {
                            Text(a.nombre ?? "Sesión")
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int(a.minutos ?? 0))'")
                                .font(.subheadline.bold())
                                .foregroundStyle(Tema.experiencia)
                        }
                    }
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
