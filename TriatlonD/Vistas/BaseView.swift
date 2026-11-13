// BaseView.swift
// ------------------------------------------------------------------
// Pantalla principal: el personaje en su campamento y la energía del día.
// La escena y el personaje están dibujados y animados por código.
// ------------------------------------------------------------------

import SwiftUI

struct BaseView: View {
    let almacen: AlmacenEstado
    @State private var ajustesVisibles = false

    private var estado: EstadoDia { almacen.estado }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("David")
                            .font(.largeTitle.bold())
                        Text("Región 1 · etapa 11")
                            .font(.subheadline)
                            .foregroundStyle(Tema.textoSecundario)
                    }
                    Spacer()
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

                EscenaCampamento(energia: Juego.energia(estado) ?? 50, notaSueno: estado.sueno.puntuacion)

                Tarjeta {
                    HStack(spacing: 16) {
                        AnilloProgreso(valor: Juego.energia(estado) ?? 0, color: Tema.turquesa, etiqueta: "Energía")
                        VStack(alignment: .leading, spacing: 6) {
                            Text(fraseEnergia)
                                .font(.headline)
                            Text("La hoguera crece con tu energía. Sale de tu sueño y tu variabilidad del pulso.")
                                .font(.footnote)
                                .foregroundStyle(Tema.textoSecundario)
                        }
                    }
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
        }
        .background(Tema.fondo)
        .foregroundStyle(Tema.texto)
        .refreshable { await almacen.recargar() }
        .sheet(isPresented: $ajustesVisibles) {
            AjustesView(almacen: almacen)
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
