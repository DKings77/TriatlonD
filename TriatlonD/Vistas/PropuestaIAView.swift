// PropuestaIAView.swift
// ------------------------------------------------------------------
// "Proponer semana": Claude lee tu estado y tu plan y propone la semana.
// Nada cambia hasta que pulsas "Usar esta semana", y nada sale hacia
// Garmin o Rouvy hasta que pulsas "Aprobar y enviar" en el plan.
// ------------------------------------------------------------------

import SwiftUI

struct PropuestaIAView: View {
    let plan: AlmacenPlan
    let almacen: AlmacenEstado
    var revision = false
    @Environment(\.dismiss) private var cerrar
    @State private var gastoUltimo: Double?
    @AppStorage("dolorUltimaCarrera") private var dolor = -1

    @State private var lunes = PropuestaIAView.lunesPorDefecto()
    @State private var indicaciones = ""
    @State private var exigencia = "Automática"
    @State private var pensando = false
    @State private var propuesta: PropuestaSemana?
    @State private var fallo: String?
    @State private var giro = 0.0

    private let claude = ClienteClaude()

    /// El lunes de la semana que viene.
    static func lunesPorDefecto() -> Date {
        let hoy = Calendar(identifier: .gregorian).startOfDay(for: Date())
        return hoy.addingTimeInterval(Double(8 - Calendario.diaSemana(hoy)) * 86400)
    }

    private var yaPlanificadas: Int {
        let semana = Calendario.semanaTemporada(lunes)
        return plan.sesiones.filter { Calendario.fecha($0.fecha).map(Calendario.semanaTemporada) == semana }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if revision {
                        ResumenSemanaPasada(lunes: lunes.addingTimeInterval(-7 * 86400), plan: plan.sesiones,
                                            historico: almacen.historico)
                    }
                    Tarjeta {
                        Text(revision ? "Y la siguiente: S\(Calendario.semanaTemporada(lunes))" : "Semana S\(Calendario.semanaTemporada(lunes))")
                            .font(.title2.bold())
                        Text("Del \(Calendario.etiqueta(Calendario.texto(lunes))) al \(Calendario.etiqueta(Calendario.texto(lunes.addingTimeInterval(6 * 86400))))")
                            .font(.subheadline)
                            .foregroundStyle(Tema.textoSecundario)
                        HStack {
                            Button("Semana anterior") { cambiar(-7) }
                            Spacer()
                            Button("Semana siguiente") { cambiar(7) }
                        }
                        .font(.subheadline.bold())
                        .tint(Tema.turquesa)
                        if yaPlanificadas > 0 {
                            Text("Esa semana ya tiene \(yaPlanificadas) sesiones. Si usas la propuesta, las sustituye.")
                                .font(.caption)
                                .foregroundStyle(Tema.alerta)
                        }
                    }

                    Tarjeta {
                        Text("Exigencia")
                            .font(.headline)
                        Picker("Exigencia", selection: $exigencia) {
                            ForEach(["Automática", "Suave", "Normal", "Fuerte"], id: \.self) { Text($0) }
                        }
                        .pickerStyle(.segmented)
                        Text("En automática decide según tu carga, sueño y variabilidad.")
                            .font(.caption)
                            .foregroundStyle(Tema.textoSecundario)
                    }

                    Tarjeta {
                        Text("¿Algo que deba saber?")
                            .font(.headline)
                        TextField("Ej.: el jueves no puedo, quiero probar tramos de 6'", text: $indicaciones, axis: .vertical)
                            .lineLimit(2...5)
                            .padding(10)
                            .background(Tema.pista)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        Text("Se envían a Claude tu carga, sueño, variabilidad, peso, dolor, los entrenos de tres semanas y el plan. \(almacen.esReal ? "" : "Ahora mismo la app tiene datos de ejemplo, no los tuyos.")")
                            .font(.caption)
                            .foregroundStyle(Tema.textoSecundario)
                    }

                    Button {
                        Task { await pedir() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .rotationEffect(.degrees(giro))
                            Text(pensando ? "Pensando la semana…" : (propuesta == nil ? (revision ? "Revisar y proponer" : "Proponer semana") : "Proponer otra"))
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Tema.experiencia)
                        .foregroundStyle(Tema.fondo)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(pensando)

                    Text("Cada petición gasta unos céntimos. \(gastoUltimo.map { "La última: \(Gasto.texto($0)). " } ?? "")Este mes: \(Gasto.texto(Gasto.esteMes)).")
                        .font(.caption)
                        .foregroundStyle(Tema.textoSecundario)

                    if let fallo {
                        Text(fallo)
                            .font(.subheadline)
                            .foregroundStyle(Tema.alerta)
                    }

                    if let propuesta {
                        if !propuesta.explicacion.isEmpty {
                            Tarjeta {
                                Label(revision ? "Revisión y ajuste" : "Por qué esta semana", systemImage: "text.bubble")
                                    .font(.headline)
                                Text(propuesta.explicacion)
                                    .font(.subheadline)
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        if let total = Totales.porSemana(propuesta.sesiones).first {
                            Tarjeta {
                                CabeceraSemana(total: total, media: Totales.mediaReciente(almacen.historico))
                            }
                        }
                        ForEach(propuesta.sesiones.sorted { ($0.fecha, $0.nombre) < ($1.fecha, $1.nombre) }) { sesion in
                            FilaPropuesta(sesion: sesion)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        Button {
                            plan.sustituirSemana(lunes: lunes, por: propuesta.sesiones)
                            cerrar()
                        } label: {
                            Text("Usar esta semana")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(Tema.turquesa)
                                .foregroundStyle(Tema.fondo)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        Text("Pasa al plan, donde puedes retocar cada sesión. No se envía nada a Garmin ni a Rouvy hasta que pulses \"Aprobar y enviar\".")
                            .font(.caption)
                            .foregroundStyle(Tema.textoSecundario)
                    }
                }
                .padding(20)
                .animation(.spring(duration: 0.5), value: propuesta?.sesiones)
            }
            .background(Tema.fondo)
            .foregroundStyle(Tema.texto)
            .navigationTitle(revision ? "Revisión semanal" : "Entrenador")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { cerrar() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func cambiar(_ dias: Double) {
        lunes = lunes.addingTimeInterval(dias * 86400)
        propuesta = nil
        fallo = nil
    }

    private func pedir() async {
        pensando = true
        fallo = nil
        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { giro = 360 }
        defer {
            pensando = false
            withAnimation(.default) { giro = 0 }
        }
        let contexto = ContextoIA.texto(lunes: lunes, estado: almacen.estado, esReal: almacen.esReal,
                                        historico: almacen.historico, plan: plan.sesiones, dolor: dolor)
        do {
            let antes = Gasto.total
            propuesta = try await claude.proponer(lunes: lunes, contexto: contexto, exigencia: exigencia,
                                                  indicaciones: indicaciones, revision: revision)
            gastoUltimo = Gasto.total - antes
        } catch {
            fallo = error.localizedDescription
        }
    }
}

private struct FilaPropuesta: View {
    let sesion: SesionPlan
    @State private var abierta = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                Text(Calendario.etiqueta(sesion.fecha))
                    .font(.subheadline.bold())
                    .foregroundStyle(sesion.deporte.color)
                    .frame(width: 54, alignment: .leading)
                VStack(alignment: .leading, spacing: 4) {
                    Text(sesion.titulo)
                        .font(.subheadline.bold())
                    if let estructura = sesion.estructura {
                        Text(estructura)
                            .font(.caption)
                            .foregroundStyle(Tema.textoSecundario)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: abierta ? "chevron.up" : "chevron.down")
                    .font(.footnote)
                    .foregroundStyle(Tema.textoSecundario)
            }
            if abierta {
                ForEach(sesion.pasosLegibles()) { paso in
                    if paso.esCabecera {
                        Text(paso.texto).font(.caption.bold()).foregroundStyle(Tema.experiencia)
                    } else {
                        HStack {
                            Text(paso.texto).font(.caption.bold()).frame(width: 44, alignment: .leading)
                            Text(paso.detalle ?? "Sin objetivo").font(.caption)
                        }
                    }
                }
                .padding(.leading, 66)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.superficie)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.spring(duration: 0.3)) { abierta.toggle() } }
    }
}

/// Lo que pasó la semana anterior, con tus datos reales (sin IA).
struct ResumenSemanaPasada: View {
    let lunes: Date
    let plan: [SesionPlan]
    let historico: Historico?

    var body: some View {
        let desde = Calendario.texto(lunes)
        let hasta = Calendario.texto(lunes.addingTimeInterval(6 * 86400))
        let hechas = (historico?.sesiones ?? []).filter { $0.dia >= desde && $0.dia <= hasta }
        let delPlan = plan.filter { $0.fecha >= desde && $0.fecha <= hasta }
        let cruce = Analisis.cumplimiento(plan: delPlan, hechas: historico?.sesiones ?? [], hoy: Calendario.texto(Date()))
        let previsto = Totales.porSemana(delPlan).first
        let noches = (historico?.sueno ?? []).filter { n in let t = Calendario.texto(n.fecha); return t >= desde && t <= hasta }
        let dolor = DiarioDolor.registros.filter { $0.dia >= desde && $0.dia <= hasta }
        Tarjeta {
            Text("La semana pasada · S\(Calendario.semanaTemporada(lunes))")
                .font(.headline)
            ForEach([Deporte.bici, .agua, .carrera, .fuerza], id: \.self) { d in
                let real = hechas.filter { $0.deporte == d.rawValue }.map(\.minutos).reduce(0, +)
                let prev = previsto?.minutos[d] ?? 0
                if real > 0 || prev > 0 {
                    HStack {
                        Circle().fill(d.color).frame(width: 8, height: 8)
                        Text(d.rawValue).font(.subheadline)
                        Spacer()
                        Text(Totales.texto(real)).font(.subheadline.bold())
                        if prev > 0 {
                            Text("de \(Totales.texto(prev))").font(.caption).foregroundStyle(Tema.textoSecundario)
                        }
                    }
                }
            }
            HStack(spacing: 14) {
                if let p = Analisis.porcentaje(cruce) {
                    DatoSimple(titulo: "Plan cumplido", valor: "\(Int(p.rounded())) %")
                }
                if !noches.isEmpty {
                    DatoSimple(titulo: "Sueño medio", valor: String(format: "%.1f h", noches.map(\.horas).reduce(0, +) / Double(noches.count)))
                }
                if let peor = dolor.map(\.valor).max() {
                    DatoSimple(titulo: "Dolor máximo", valor: "\(peor)/10")
                }
            }
        }
    }
}
