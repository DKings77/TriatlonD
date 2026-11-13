// BaseView.swift
// ------------------------------------------------------------------
// Pantalla principal: el personaje en su campamento y la energía del día.
// El personaje es todavía un hueco: el arte llegará más adelante.
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

                ZStack {
                    RoundedRectangle(cornerRadius: 20).fill(Tema.superficie)
                    VStack(spacing: 10) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 96))
                            .foregroundStyle(Tema.turquesa)
                        Text("Aquí irá tu personaje")
                            .font(.footnote)
                            .foregroundStyle(Tema.textoSecundario)
                    }
                }
                .frame(height: 300)
                .accessibilityLabel("Hueco para el personaje")

                Tarjeta {
                    HStack {
                        Text("Energía")
                            .font(.headline)
                        Spacer()
                        Text(textoEnergia)
                            .font(.title2.bold())
                    }
                    BarraProgreso(valor: Juego.energia(estado) ?? 0, color: Tema.turquesa)
                    Text("Sale de tu sueño y tu variabilidad del pulso, y del readiness cuando está disponible.")
                        .font(.footnote)
                        .foregroundStyle(Tema.textoSecundario)
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

    private var textoEnergia: String {
        guard let e = Juego.energia(estado) else { return "Sin datos" }
        return "\(Int(e))"
    }
}
