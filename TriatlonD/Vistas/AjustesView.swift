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
