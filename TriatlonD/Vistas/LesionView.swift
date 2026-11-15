// LesionView.swift
// ------------------------------------------------------------------
// Parte de lesión: apuntas el dolor de cada carrera y la escalera de
// vuelta a correr se calcula sola con las carreras hechas del plan.
// ------------------------------------------------------------------

import SwiftUI
import Charts

struct LesionView: View {
    let almacen: AlmacenEstado
    let plan: AlmacenPlan
    var conCabecera = true

    @State private var dia = Date()
    @State private var registros = DiarioDolor.registros
    @State private var preparado = false

    private let niveles = [0, 1, 2, 3, 4, 5, 6, 8, 10]

    private var diaTexto: String { Calendario.texto(dia) }
    private var valorDelDia: Int? { registros.first { $0.dia == diaTexto }?.valor }
    private var escalera: Escalera {
        _ = registros
        return Escalera.calcular(plan: plan.sesiones, hechas: almacen.historico?.sesiones ?? [])
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    if conCabecera {
                        Text("Parte de lesión")
                            .font(.largeTitle.bold())
                    }
                    Text("Fascia plantar y tendón de Aquiles")
                        .font(.subheadline)
                        .foregroundStyle(Tema.textoSecundario)
                }

                Tarjeta {
                    Text("¿Cuánto te ha dolido?")
                        .font(.headline)
                    DatePicker("Carrera del", selection: $dia, in: ...Date(), displayedComponents: .date)
                        .tint(Tema.turquesa)
                        .font(.subheadline)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                        ForEach(niveles, id: \.self) { nivel in
                            Button {
                                DiarioDolor.apuntar(nivel, dia: diaTexto)
                                withAnimation(.spring(duration: 0.4)) { registros = DiarioDolor.registros }
                            } label: {
                                Text("\(nivel)")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(color(nivel))
                                    .foregroundStyle(Tema.fondo)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Tema.texto, lineWidth: valorDelDia == nivel ? 3 : 0)
                                    )
                                    .scaleEffect(valorDelDia == nivel ? 1.06 : 1)
                            }
                            .accessibilityLabel("Dolor \(nivel) de 10")
                        }
                    }
                    HStack {
                        Text("0 nada · 2 carga")
                        Spacer()
                        Text("10 no puedo apoyar")
                    }
                    .font(.caption)
                    .foregroundStyle(Tema.textoSecundario)
                    Text(lectura)
                        .font(.subheadline)
                }

                if registros.count >= 1 {
                    Tarjeta {
                        Text("Diario de dolor")
                            .font(.headline)
                        Chart {
                            RuleMark(y: .value("Límite", 4))
                                .foregroundStyle(Tema.alerta.opacity(0.6))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            ForEach(registros.suffix(20)) { r in
                                if let fecha = Calendario.fecha(r.dia) {
                                    BarMark(x: .value("Día", fecha, unit: .day), y: .value("Dolor", r.valor))
                                        .foregroundStyle(color(r.valor))
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .chartYScale(domain: 0...10)
                        .frame(height: 140)
                        Text(resumenDiario)
                            .font(.footnote)
                        Text("La línea roja es el 4: a partir de ahí se para y la siguiente carrera pasa a bici o piscina.")
                            .font(.caption)
                            .foregroundStyle(Tema.textoSecundario)
                    }
                }

                let otras = Sensaciones.todas.filter { $0.deporte != Deporte.carrera.rawValue && ($0.dolor ?? 0) > 0 }.suffix(6)
                if !otras.isEmpty {
                    Tarjeta {
                        Text("Molestias en otros deportes")
                            .font(.headline)
                        ForEach(Array(otras)) { s in
                            HStack {
                                Text("\(Calendario.etiqueta(s.dia)) · \(s.deporte)")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(s.dolor ?? 0)/10")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(color(s.dolor ?? 0))
                            }
                        }
                        Text("Se apuntan en el parte de cada entreno, en Hoy.")
                            .font(.caption)
                            .foregroundStyle(Tema.textoSecundario)
                    }
                }

                Tarjeta {
                    Text("Escalera de vuelta a correr")
                        .font(.headline)
                    ForEach(escalera.peldanos) { peldano in
                        HStack(spacing: 10) {
                            Image(systemName: icono(peldano.estado))
                                .foregroundStyle(colorPeldano(peldano.estado))
                                .frame(width: 22)
                            Text(peldano.minutos == 20 ? "20' seguidos: te quitas la venda" : "Tramos de \(peldano.minutos)' corriendo")
                                .font(.subheadline)
                                .foregroundStyle(peldano.estado == 0 ? Tema.textoSecundario : Tema.texto)
                            Spacer()
                            Text(etiqueta(peldano))
                                .font(.caption)
                                .foregroundStyle(colorPeldano(peldano.estado))
                        }
                    }
                    Text("Cada peldaño se abre con dos carreras del plan con tramos de esa duración y dolor de 0 a 2. Los tramos de 3' y 4' ya los tenías superados.")
                        .font(.caption)
                        .foregroundStyle(Tema.textoSecundario)
                }
            }
            .padding(20)
        }
        .background(Tema.fondo)
        .foregroundStyle(Tema.texto)
        .onAppear(perform: preparar)
    }

    /// Propone el día de la última carrera hecha.
    private func preparar() {
        registros = DiarioDolor.registros
        guard !preparado else { return }
        preparado = true
        if let ultima = almacen.historico?.sesiones.filter({ $0.deporte == "Carrera" }).map(\.dia).max(),
           let fecha = Calendario.fecha(ultima) {
            dia = fecha
        }
    }

    private var lectura: String {
        guard let valor = valorDelDia else { return "Marca un valor después de cada carrera." }
        if valor <= 2 { return "Bien: esta carrera cuenta para abrir el siguiente peldaño." }
        if valor < 4 { return "Aceptable. Repite este peldaño antes de subir." }
        return "Con 4 o más paras: cuenta como misión cumplida y la siguiente carrera pasa a bici o piscina."
    }

    private var resumenDiario: String {
        let ultimas = registros.suffix(4).map(\.valor)
        guard !ultimas.isEmpty else { return "" }
        let media = Double(ultimas.reduce(0, +)) / Double(ultimas.count)
        let tendencia: String
        if ultimas.count >= 3, let primera = ultimas.first, let ultima = ultimas.last {
            tendencia = ultima < primera ? ", y bajando" : (ultima > primera ? ", y subiendo: vigílalo" : ", estable")
        } else {
            tendencia = ""
        }
        return "Media de las últimas \(ultimas.count): \(String(format: "%.1f", media)) sobre 10\(tendencia)."
    }

    private func color(_ nivel: Int) -> Color {
        switch nivel {
        case 0...2: return Tema.carrera
        case 3...4: return Tema.experiencia
        case 5...6: return Tema.bici
        default: return Tema.alerta
        }
    }

    private func icono(_ estado: Int) -> String {
        switch estado {
        case 2: return "checkmark.circle.fill"
        case 1: return "circle.dotted"
        default: return "lock"
        }
    }

    private func colorPeldano(_ estado: Int) -> Color {
        switch estado {
        case 2: return Tema.carrera
        case 1: return Tema.experiencia
        default: return Tema.textoSecundario
        }
    }

    private func etiqueta(_ p: Peldano) -> String {
        switch p.estado {
        case 2: return "Hecho"
        case 1: return "Siguiente · \(p.validas) de 2"
        default: return "Bloqueado"
        }
    }
}
