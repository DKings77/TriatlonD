// AjustesView.swift
// ------------------------------------------------------------------
// Aquí se pega la clave personal de Garmin. Se guarda en el llavero
// del iPhone y solo se envía a Garmin.
// ------------------------------------------------------------------

import SwiftUI

struct AjustesView: View {
    let almacen: AlmacenEstado
    @Environment(\.dismiss) private var cerrar
    @State private var claveGarmin = ""
    @State private var hayClave = Llavero.leer("garminClave") != nil
    @State private var claveIntervals = ""
    @State private var hayIntervals = Llavero.leer("intervalsClave") != nil
    @State private var claveClaude = ""
    @State private var hayClaude = Llavero.leer("claudeClave") != nil

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Clave personal de Garmin", text: $claveGarmin)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text(hayClave ? "Hay una clave guardada en este iPhone." : "No hay ninguna clave guardada.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Garmin")
                } footer: {
                    Text("Se guarda cifrada en el llavero del iPhone y solo se envía a Garmin.")
                }

                Section {
                    Button("Guardar y probar") {
                        Llavero.guardar(claveGarmin.trimmingCharacters(in: .whitespacesAndNewlines), clave: "garminClave")
                        claveGarmin = ""
                        hayClave = true
                        Task { await almacen.recargar() }
                    }
                    .disabled(claveGarmin.isEmpty)

                    if hayClave {
                        Button("Borrar la clave", role: .destructive) {
                            Llavero.guardar("", clave: "garminClave")
                            hayClave = false
                            Task { await almacen.recargar() }
                        }
                    }
                }

                Section {
                    SecureField("Clave de intervals.icu", text: $claveIntervals)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text(hayIntervals ? "Hay una clave guardada en este iPhone." : "No hay ninguna clave guardada.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Guardar") {
                        Llavero.guardar(claveIntervals.trimmingCharacters(in: .whitespacesAndNewlines), clave: "intervalsClave")
                        claveIntervals = ""
                        hayIntervals = true
                    }
                    .disabled(claveIntervals.isEmpty)
                    if hayIntervals {
                        Button("Borrar la clave", role: .destructive) {
                            Llavero.guardar("", clave: "intervalsClave")
                            hayIntervals = false
                        }
                    }
                } header: {
                    Text("intervals.icu")
                } footer: {
                    Text("Sirve para enviar los entrenos desde la pestaña Plan. Solo se envía a intervals.icu.")
                }

                Section {
                    SecureField("Clave de la API de Claude", text: $claveClaude)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text(hayClaude ? "Hay una clave guardada en este iPhone." : "No hay ninguna clave guardada.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Guardar") {
                        Llavero.guardar(claveClaude.trimmingCharacters(in: .whitespacesAndNewlines), clave: "claudeClave")
                        claveClaude = ""
                        hayClaude = true
                    }
                    .disabled(claveClaude.isEmpty)
                    if hayClaude {
                        Button("Borrar la clave", role: .destructive) {
                            Llavero.guardar("", clave: "claudeClave")
                            hayClaude = false
                        }
                    }
                } header: {
                    Text("Entrenador (Claude)")
                } footer: {
                    Text("Sirve para el botón \"Proponer semana\". Solo se usa cuando lo pulsas y gasta de tu monedero de la API: unos céntimos por propuesta. Solo se envía a Anthropic.")
                }

                Section {
                    if almacen.cargando {
                        Text("Consultando a Garmin…")
                    } else if almacen.esReal {
                        Text("Conectado: la app muestra tus datos reales de Garmin.")
                    }
                    if let aviso = almacen.aviso {
                        Text(aviso)
                    }
                } header: {
                    Text("Estado")
                }
            }
            .navigationTitle("Ajustes")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { cerrar() }
                }
            }
        }
    }
}
