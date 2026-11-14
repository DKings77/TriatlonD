// CuerpoView.swift
// ------------------------------------------------------------------
// ¿Cómo responde mi cuerpo? La lesión (dolor y escalera) y la
// recuperación: sueño, variabilidad del pulso, pulso en reposo y peso.
// ------------------------------------------------------------------

import SwiftUI

struct CuerpoView: View {
    let almacen: AlmacenEstado
    let plan: AlmacenPlan
    @State private var seccion = 0

    private var estado: EstadoDia { almacen.estado }

    var body: some View {
        VStack(spacing: 0) {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cuerpo")
                .font(.largeTitle.bold())
            Picker("Sección", selection: $seccion) {
                Text("Lesión").tag(0)
                Text("Recuperación").tag(1)
                Text("Peso").tag(2)
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.fondo)
        .foregroundStyle(Tema.texto)

        if seccion == 0 {
            LesionView(almacen: almacen, plan: plan, conCabecera: false)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let h = almacen.historico {
                        if seccion == 1 {
                            HStack(spacing: 10) {
                                Metrica(titulo: "Sueño", valor: estado.sueno.horas.map { String(format: "%.1f h", $0) })
                                Metrica(titulo: "VFC", valor: estado.vfc.mediaSemanalMs.map { "\(Int($0)) ms" })
                                Metrica(titulo: "Reposo", valor: h.pulsoReposo.map { "\(Int($0)) ppm" })
                            }
                            if let motivos = Juego.modoBaja(estado, historico: h) {
                                TarjetaModoBaja(motivos: motivos)
                            }
                            GraficaSueno(noches: h.sueno)
                            GraficaVFC(noches: h.vfc)
                            TarjetaRecuperacion(historico: h)
                        } else {
                            GraficaPeso(dias: h.peso)
                        }
                    } else {
                        Tarjeta {
                            Text(almacen.cargando ? "Trayendo tus datos de Garmin…" : "Aparece con los datos de Garmin.")
                                .font(.subheadline)
                                .foregroundStyle(Tema.textoSecundario)
                        }
                    }
                }
                .padding(20)
            }
            .background(Tema.fondo)
            .foregroundStyle(Tema.texto)
            .refreshable { await almacen.recargar() }
        }
        }
        .background(Tema.fondo)
    }
}
