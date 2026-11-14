// EditorSesionView.swift
// ------------------------------------------------------------------
// Crea una sesión nueva o edita una del plan. El nombre se monta solo
// con tu nomenclatura (S12 D2: B1 …) a partir del día y el deporte.
// ------------------------------------------------------------------

import SwiftUI

struct EditorSesionView: View {
    let plan: AlmacenPlan
    let original: SesionPlan?
    @Environment(\.dismiss) private var cerrar

    @State private var tipo = "Ride"
    @State private var dia = Date()
    @State private var numero = 1
    @State private var titulo = ""
    @State private var estructura = ""
    @State private var pasos = ""
    @State private var preparado = false

    private let tipos = [("Ride", "Bici"), ("Run", "Carrera"), ("Swim", "Agua"), ("WeightTraining", "Fuerza")]

    private var nombre: String {
        Nomenclatura.nombre(fecha: dia, tipo: tipo, numero: numero, titulo: titulo, estructura: estructura)
    }

    private var vistaPrevia: SesionPlan {
        SesionPlan(id: original?.id ?? "M-\(UUID().uuidString.prefix(8))",
                   fecha: Calendario.texto(dia), tipo: tipo, interior: tipo != "Run",
                   nombre: nombre, pasos: pasos,
                   seEnvia: tipo != "Swim" && !nombre.localizedCaseInsensitiveContains("test"), xp: 100)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Qué y cuándo") {
                    Picker("Deporte", selection: $tipo) {
                        ForEach(tipos, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    .pickerStyle(.segmented)
                    DatePicker("Día", selection: $dia, displayedComponents: .date)
                    Stepper("Orden en la semana: \(Nomenclatura.letra(tipo))\(numero)", value: $numero, in: 1...9)
                }

                if original == nil {
                    Section("Partir de una sesión tipo") {
                        ForEach(Plantilla.todas.filter { $0.tipo == tipo }) { plantilla in
                            Button(plantilla.etiqueta) {
                                titulo = plantilla.titulo
                                estructura = plantilla.estructura
                                pasos = plantilla.pasos
                            }
                        }
                    }
                }

                Section {
                    TextField("Duración y zona: 60' Z2 140W", text: $titulo)
                    TextField("Estructura: 10' cal + 40' Z2 + 10' enf", text: $estructura, axis: .vertical)
                    Text(nombre)
                        .font(.footnote.bold())
                        .foregroundStyle(Tema.turquesa)
                } header: {
                    Text("Nombre")
                } footer: {
                    Text("Si hay dos sesiones el mismo día, añade 1/2 o 2/2 al final de la duración y zona.")
                }

                Section {
                    TextEditor(text: $pasos)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 150)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Pasos")
                } footer: {
                    Text(ayuda)
                }

                if !pasos.isEmpty {
                    Section("Así se entiende") {
                        ForEach(vistaPrevia.pasosLegibles()) { paso in
                            if paso.esCabecera {
                                Text(paso.texto).font(.footnote.bold())
                            } else {
                                HStack {
                                    Text(paso.texto).font(.footnote.bold()).frame(width: 44, alignment: .leading)
                                    Text(paso.detalle ?? "Sin objetivo").font(.footnote)
                                }
                            }
                        }
                        if let minutos = Analisis.minutosPlan(vistaPrevia) {
                            Text("Total: \(Int(minutos)) minutos")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(original == nil ? "Nueva sesión" : "Editar sesión")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        plan.guardar(vistaPrevia)
                        cerrar()
                    }
                    .disabled(titulo.trimmingCharacters(in: .whitespaces).isEmpty || pasos.isEmpty)
                }
            }
            .onAppear(perform: preparar)
            .onChange(of: tipo) { _, _ in recalcularNumero() }
            .onChange(of: dia) { _, _ in recalcularNumero() }
        }
        .preferredColorScheme(.dark)
    }

    private var ayuda: String {
        switch tipo {
        case "Ride": return "Un paso por línea, en % del FTP: \"- 10m 60%\". Para repetir: una línea \"3x\", debajo sus pasos, y una línea en blanco antes y después."
        case "Run": return "Un paso por línea, por zona de pulso: \"- 4m Z2 HR\". Caminar: \"- 1m Z1 HR\". Para repetir: una línea \"5x\", debajo sus pasos, y una línea en blanco antes y después."
        case "Swim": return "Texto libre. La natación no se envía al reloj desde la app."
        default: return "Una sola línea con la duración: \"- 50m\"."
        }
    }

    private func preparar() {
        guard !preparado else { return }
        preparado = true
        if let original {
            tipo = original.tipo
            dia = Calendario.fecha(original.fecha) ?? Date()
            let partes = Nomenclatura.partes(original.nombre)
            numero = partes.numero ?? 1
            titulo = partes.titulo
            estructura = partes.estructura
            pasos = original.pasos
        } else {
            numero = plan.siguienteNumero(tipo: tipo, fecha: dia)
        }
    }

    private func recalcularNumero() {
        guard preparado, original == nil else { return }
        numero = plan.siguienteNumero(tipo: tipo, fecha: dia)
    }
}
