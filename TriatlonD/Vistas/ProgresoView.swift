// ProgresoView.swift
// ------------------------------------------------------------------
// ¿Voy mejorando? La parte de juego: la nota de triatleta, los logros,
// el plan cumplido y la constancia, y el mapa de la Travesía.
// ------------------------------------------------------------------

import SwiftUI

struct ProgresoView: View {
    let almacen: AlmacenEstado
    let plan: AlmacenPlan
    @State private var seccion = 0

    var body: some View {
        VStack(spacing: 0) {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Progreso")
                    .font(.largeTitle.bold())
                Text(Travesia.subtitulo(Date()))
                    .font(.subheadline)
                    .foregroundStyle(Tema.textoSecundario)
            }
            Picker("Sección", selection: $seccion) {
                Text("Nivel").tag(0)
                Text("Travesía").tag(1)
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.fondo)
        .foregroundStyle(Tema.texto)

        if seccion == 1 {
            TravesiaView(plan: plan, almacen: almacen, conCabecera: false)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let h = almacen.historico {
                        TarjetaNota(nota: Nota.calcular(historico: h, pesoKg: almacen.estado.pesoKg), detalle: true)
                        TarjetaLogros(logros: Logros.calcular(plan: plan.sesiones, historico: h, pesoKg: almacen.estado.pesoKg))
                        TarjetaConstancia(constancia: Analisis.constancia(h.sesiones, hoy: Date(), plan: plan.sesiones), hechas: h.sesiones, plan: plan.sesiones)
                        TarjetaCumplimiento(lista: Analisis.cumplimiento(plan: plan.sesiones, hechas: h.sesiones, hoy: Calendario.texto(Date())))
                    } else {
                        Tarjeta {
                            Text(almacen.cargando ? "Trayendo tus datos de Garmin…" : "Tu progreso aparece con los datos de Garmin. Añade la clave en Ajustes, desde el engranaje de Hoy.")
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
