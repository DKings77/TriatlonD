// SemanaView.swift
// ------------------------------------------------------------------
// El plan de entrenos. Toca una sesión para ver sus pasos con vatios y
// pulsaciones o para cambiarla de día. "Aprobar y enviar" deja
// intervals.icu igual que el plan.
// ------------------------------------------------------------------

import SwiftUI

struct SemanaView: View {
    let plan: AlmacenPlan
    @State private var confirmarVisible = false
    @State private var elegida: SesionPlan?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Plan")
                        .font(.largeTitle.bold())
                    Text("Toca una sesión para ver sus pasos o cambiarla de día")
                        .font(.subheadline)
                        .foregroundStyle(Tema.textoSecundario)
                }

                ForEach(plan.ordenadas) { sesion in
                    Button {
                        elegida = sesion
                    } label: {
                        FilaSesion(sesion: sesion)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    confirmarVisible = true
                } label: {
                    Text(plan.enviando ? "Enviando…" : "Aprobar y enviar")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Tema.turquesa)
                        .foregroundStyle(Tema.fondo)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(plan.enviando)

                Text("Bici, carrera y fuerza se envían a intervals.icu y de ahí a Garmin y Rouvy. La natación se programa en Garmin aparte y el test de FTP se hace con el de Rouvy.")
                    .font(.caption)
                    .foregroundStyle(Tema.textoSecundario)
            }
            .padding(20)
            .animation(.spring(duration: 0.5), value: plan.sesiones)
        }
        .background(Tema.fondo)
        .foregroundStyle(Tema.texto)
        .sheet(item: $elegida) { sesion in
            DetalleSesionView(sesion: sesion, plan: plan)
        }
        .confirmationDialog("¿Enviar el plan?", isPresented: $confirmarVisible, titleVisibility: .visible) {
            Button("Enviar") {
                Task { await plan.sincronizar() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se dejará intervals.icu igual que este plan: crea lo que falte, corrige lo que haya cambiado y mueve lo que hayas cambiado de día. No duplica.")
        }
        .alert("Plan", isPresented: Binding(get: { plan.mensaje != nil }, set: { if !$0 { plan.mensaje = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(plan.mensaje ?? "")
        }
    }
}

private struct FilaSesion: View {
    let sesion: SesionPlan

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(Calendario.etiqueta(sesion.fecha))
                .font(.subheadline.bold())
                .foregroundStyle(Tema.textoSecundario)
                .frame(width: 54, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                Text(sesion.titulo)
                    .font(.subheadline.bold())
                if let estructura = sesion.estructura {
                    Text(estructura)
                        .font(.caption)
                        .foregroundStyle(Tema.textoSecundario)
                }
                HStack(spacing: 6) {
                    Text(sesion.deporte.rawValue)
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(sesion.deporte.color)
                        .foregroundStyle(Tema.fondo)
                        .clipShape(Capsule())
                    if !sesion.seEnvia {
                        Text("No se envía desde aquí")
                            .font(.caption2)
                            .foregroundStyle(Tema.textoSecundario)
                    } else if sesion.eventoId != nil {
                        Label("Enviada", systemImage: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(Tema.turquesa)
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(Tema.textoSecundario)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.superficie)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

/// Los pasos de una sesión con sus vatios y pulsaciones, y el cambio de día.
struct DetalleSesionView: View {
    let sesion: SesionPlan
    let plan: AlmacenPlan
    @Environment(\.dismiss) private var cerrar
    @State private var dia = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(sesion.nombre)
                        .font(.headline)

                    Tarjeta {
                        Text("Pasos")
                            .font(.headline)
                        ForEach(sesion.pasosLegibles()) { paso in
                            if paso.esCabecera {
                                Text(paso.texto)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Tema.experiencia)
                                    .padding(.top, 4)
                            } else {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(paso.texto)
                                        .font(.subheadline.bold())
                                        .frame(width: 48, alignment: .leading)
                                    Text(paso.detalle ?? "Sin objetivo")
                                        .font(.subheadline)
                                        .foregroundStyle(paso.detalle == nil ? Tema.textoSecundario : Tema.texto)
                                }
                            }
                        }
                    }

                    Tarjeta {
                        Text("Cambiar de día")
                            .font(.headline)
                        DatePicker("Día", selection: $dia, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .tint(Tema.turquesa)
                        Button {
                            plan.mover(sesion.id, a: dia)
                            cerrar()
                        } label: {
                            Text("Mover a este día")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .background(Tema.turquesa)
                                .foregroundStyle(Tema.fondo)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(Calendario.texto(dia) == sesion.fecha)
                        Text(sesion.seEnvia
                             ? "El nombre se ajusta solo a la semana y el día nuevos. El cambio llega a Garmin y Rouvy cuando pulses \"Aprobar y enviar\"."
                             : "Esta sesión no pasa por intervals.icu: el cambio de día queda solo en la app y hay que moverla también en Garmin.")
                            .font(.caption)
                            .foregroundStyle(Tema.textoSecundario)
                    }
                }
                .padding(20)
            }
            .background(Tema.fondo)
            .foregroundStyle(Tema.texto)
            .navigationTitle(Calendario.etiqueta(sesion.fecha))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { cerrar() }
                }
            }
            .onAppear {
                dia = Calendario.fecha(sesion.fecha) ?? Date()
            }
        }
        .preferredColorScheme(.dark)
    }
}
