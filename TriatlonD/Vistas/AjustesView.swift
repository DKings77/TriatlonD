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
    @AppStorage("ref.ftp") private var ftp = 200.0
    @AppStorage("ref.z1") private var z1 = 108
    @AppStorage("ref.z2") private var z2 = 136
    @AppStorage("ref.z3") private var z3 = 151
    @AppStorage("ref.z4") private var z4 = 160
    @AppStorage("ref.z5") private var z5 = 171
    @AppStorage("ref.max") private var maximo = 187
    @AppStorage("ref.pesoObjetivo") private var pesoObjetivo = 82.0
    @AppStorage("ref.fechaPeso") private var fechaPeso = "2027-06-21"
    @State private var claveClaude = ""
    @State private var hayClaude = Llavero.leer("claudeClave") != nil

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("FTP: \(Int(ftp)) W", value: $ftp, in: 100...400, step: 1)
                    Stepper("Empieza Z1: \(z1) ppm", value: $z1, in: 80...200)
                    Stepper("Empieza Z2: \(z2) ppm", value: $z2, in: 80...200)
                    Stepper("Empieza Z3: \(z3) ppm", value: $z3, in: 80...200)
                    Stepper("Empieza Z4: \(z4) ppm", value: $z4, in: 80...200)
                    Stepper("Empieza Z5: \(z5) ppm", value: $z5, in: 80...210)
                    Stepper("Pulso máximo: \(maximo) ppm", value: $maximo, in: 150...220)
                    Button("Volver a los valores de Garmin") {
                        ftp = 200; z1 = 108; z2 = 136; z3 = 151; z4 = 160; z5 = 171; maximo = 187
                    }
                } header: {
                    Text("Tus referencias")
                } footer: {
                    Text("Si cambias el FTP tras un test, cámbialo también en Garmin, Rouvy e intervals.icu (o pídemelo): los entrenos se envían en % del FTP y cada sitio usa el suyo.")
                }

                Section {
                    Stepper(String(format: "Peso objetivo: %.1f kg", pesoObjetivo), value: $pesoObjetivo, in: 60...100, step: 0.5)
                    DatePicker("Para el", selection: Binding(
                        get: { Calendario.fecha(fechaPeso) ?? Date() },
                        set: { fechaPeso = Calendario.texto($0) }
                    ), in: Date()..., displayedComponents: .date)
                } header: {
                    Text("Objetivo de peso")
                }

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
