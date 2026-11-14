// TarjetasDatos.swift
// ------------------------------------------------------------------
// Tarjetas de la pestaña Datos que cruzan el plan con lo entrenado y
// miran el rendimiento: cumplimiento, constancia, forma, zonas,
// eficiencia, potencia, carrera, natación, recuperación y peso.
// ------------------------------------------------------------------

import SwiftUI
import Charts

// MARK: - Resumen

/// Planificado frente a hecho, con los puntos y el nivel que salen de ahí.
struct TarjetaCumplimiento: View {
    let lista: [Cumplimiento]

    var body: some View {
        let puntos = Analisis.puntos(lista)
        let nivel = Analisis.nivel(puntos: puntos)
        Tarjeta {
            Text("Planificado frente a hecho")
                .font(.headline)
            HStack(spacing: 16) {
                AnilloProgreso(valor: Analisis.porcentaje(lista) ?? 0, color: Tema.carrera, etiqueta: "% hecho")
                VStack(alignment: .leading, spacing: 6) {
                    Text("Constancia · tramo \(nivel.numero)")
                        .font(.title3.bold())
                        .foregroundStyle(Tema.experiencia)
                    BarraProgreso(valor: Double(nivel.dentro) / Double(nivel.necesario) * 100, color: Tema.experiencia)
                    Text("\(nivel.dentro) de \(nivel.necesario) puntos para el siguiente tramo · \(puntos) en total")
                        .font(.caption)
                        .foregroundStyle(Tema.textoSecundario)
                }
            }
            ForEach(lista) { c in
                HStack(spacing: 10) {
                    Image(systemName: icono(c.estado))
                        .foregroundStyle(color(c.estado))
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(c.sesion.titulo)
                            .font(.subheadline)
                        Text(detalle(c))
                            .font(.caption)
                            .foregroundStyle(Tema.textoSecundario)
                    }
                    Spacer(minLength: 0)
                }
            }
            Text("Una sesión cuenta como hecha con el 80 % de su duración. A medias da la mitad de puntos. Los puntos miden tu constancia con el plan; tu nivel real es la nota de triatleta.")
                .font(.caption)
                .foregroundStyle(Tema.textoSecundario)
        }
    }

    private func icono(_ estado: EstadoSesion) -> String {
        switch estado {
        case .hecha: return "checkmark.circle.fill"
        case .aMedias: return "circle.lefthalf.filled"
        case .saltada: return "xmark.circle"
        case .pendiente: return "circle"
        }
    }

    private func color(_ estado: EstadoSesion) -> Color {
        switch estado {
        case .hecha: return Tema.carrera
        case .aMedias: return Tema.experiencia
        case .saltada: return Tema.alerta
        case .pendiente: return Tema.textoSecundario
        }
    }

    private func detalle(_ c: Cumplimiento) -> String {
        let dia = Calendario.etiqueta(c.sesion.fecha)
        switch c.estado {
        case .hecha:
            return "\(dia) · hecha" + (c.minutosHechos.map { ", \(Int($0))'" } ?? "")
        case .aMedias:
            return "\(dia) · a medias: \(Int(c.minutosHechos ?? 0))' de \(Int(c.minutosPlan ?? 0))'"
        case .saltada:
            return "\(dia) · no hecha"
        case .pendiente:
            return "\(dia) · pendiente"
        }
    }
}

/// Cinco semanas de puntos: un día entrenado, un punto encendido.
struct TarjetaConstancia: View {
    let constancia: Constancia
    let hechas: [SesionHecha]
    let plan: [SesionPlan]
    @State private var visible = false
    @State private var elegido: String?

    private let calendario = Calendar(identifier: .gregorian)
    private var hoy: Date { calendario.startOfDay(for: Date()) }
    private var hoyTexto: String { Calendario.texto(Date()) }

    /// Cinco semanas de lunes a domingo, terminando en la semana actual.
    private var semanas: [[Date]] {
        let lunes = hoy.addingTimeInterval(-Double(Calendario.diaSemana(hoy) - 1) * 86400)
        return (0..<5).reversed().map { atras in
            (0..<7).compactMap { d in calendario.date(byAdding: .day, value: d - atras * 7, to: lunes) }
        }
    }

    private var cruce: [Cumplimiento] {
        Analisis.cumplimiento(plan: plan, hechas: hechas, hoy: hoyTexto)
    }

    var body: some View {
        Tarjeta {
            HStack {
                Text("Constancia")
                    .font(.headline)
                Spacer()
                Text(rangoMeses)
                    .font(.caption)
                    .foregroundStyle(Tema.textoSecundario)
            }
            // Cabecera de días
            HStack(spacing: 4) {
                Text("").frame(width: 28)
                ForEach(Calendario.nombresDia, id: \.self) { d in
                    Text(String(d.prefix(1)))
                        .font(.caption2.bold())
                        .foregroundStyle(Tema.textoSecundario)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(Array(semanas.enumerated()), id: \.offset) { fila, semana in
                HStack(spacing: 4) {
                    Text("S\(Calendario.semanaTemporada(semana[0]))")
                        .font(.caption2.bold())
                        .foregroundStyle(Tema.textoSecundario)
                        .frame(width: 28, alignment: .leading)
                    ForEach(Array(semana.enumerated()), id: \.offset) { col, dia in
                        celda(dia)
                            .scaleEffect(visible ? 1 : 0.4)
                            .opacity(visible ? 1 : 0)
                            .animation(.spring(duration: 0.4).delay(Double(fila * 7 + col) * 0.012), value: visible)
                    }
                }
            }
            if let elegido {
                detalle(elegido)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            HStack(spacing: 0) {
                DatoSimple(titulo: "Racha actual", valor: "\(constancia.rachaActual) días")
                DatoSimple(titulo: "Mejor racha", valor: "\(constancia.mejorRacha) días")
                DatoSimple(titulo: "Días entrenados", valor: "\(diasEntrenados) de \(diasPasados)")
            }
            Text("Cada casilla es un día, de lunes a domingo. Los iconos son lo que entrenaste; cuanto más intenso el fondo, más tiempo. Una X roja es una sesión del plan que no se hizo; los iconos con borde son lo que queda por hacer. Toca un día para ver el detalle.")
                .font(.caption)
                .foregroundStyle(Tema.textoSecundario)
        }
        .animation(.spring(duration: 0.3), value: elegido)
        .onAppear { visible = true }
        .onDisappear { visible = false }
    }

    private var diasPasados: Int {
        semanas.joined().filter { $0 <= hoy }.count
    }
    private var diasEntrenados: Int {
        let conEntreno = Set(hechas.map(\.dia))
        return semanas.joined().filter { $0 <= hoy && conEntreno.contains(Calendario.texto($0)) }.count
    }
    private var rangoMeses: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "LLLL"
        let primero = f.string(from: semanas.first?.first ?? hoy)
        let ultimo = f.string(from: semanas.last?.last ?? hoy)
        return primero == ultimo ? primero.capitalized : "\(primero.capitalized) – \(ultimo)"
    }

    @ViewBuilder
    private func celda(_ dia: Date) -> some View {
        let texto = Calendario.texto(dia)
        let delDia = hechas.filter { $0.dia == texto }
        let minutos = delDia.map(\.minutos).reduce(0, +)
        let deportes = orden(delDia.compactMap { $0.deporte.flatMap(Deporte.init(rawValue:)) })
        let planDia = cruce.filter { $0.sesion.fecha == texto }
        let saltadas = planDia.filter { $0.estado == .saltada }
        let pendientes = planDia.filter { $0.estado == .pendiente }
        let futuro = dia > hoy
        let esHoy = texto == hoyTexto
        let numero = calendario.component(.day, from: dia)

        Button {
            elegido = elegido == texto ? nil : texto
        } label: {
            VStack(spacing: 2) {
                Text(numero == 1 ? "1 \(mesCorto(dia))" : "\(numero)")
                    .font(.system(size: 9, weight: esHoy ? .heavy : .semibold))
                    .foregroundStyle(esHoy ? Tema.turquesa : (futuro ? Tema.textoSecundario.opacity(0.6) : Tema.textoSecundario))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                HStack(spacing: 1) {
                    if !deportes.isEmpty {
                        ForEach(deportes.prefix(2), id: \.self) { d in
                            Image(systemName: icono(d))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(d.color)
                        }
                    } else if !pendientes.isEmpty {
                        ForEach(orden(pendientes.map(\.sesion.deporte)).prefix(2), id: \.self) { d in
                            Image(systemName: icono(d))
                                .font(.system(size: 10))
                                .foregroundStyle(d.color.opacity(0.55))
                        }
                    } else if !saltadas.isEmpty {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Tema.alerta)
                    }
                }
                .frame(height: 13)
                Spacer(minLength: 0)
            }
            .padding(4)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(fondo(minutos: minutos, futuro: futuro))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(esHoy ? Tema.turquesa : (elegido == texto ? Tema.texto : (pendientes.isEmpty ? .clear : Tema.textoSecundario.opacity(0.35))),
                            style: StrokeStyle(lineWidth: esHoy || elegido == texto ? 2 : 1, dash: pendientes.isEmpty || esHoy ? [] : [3, 2]))
            )
            .overlay(alignment: .topTrailing) {
                if !saltadas.isEmpty && !deportes.isEmpty {
                    Circle().fill(Tema.alerta).frame(width: 5, height: 5).padding(4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(Calendario.etiqueta(texto)): \(deportes.isEmpty ? "sin entreno" : "\(Int(minutos)) minutos")")
    }

    private func fondo(minutos: Double, futuro: Bool) -> Color {
        if futuro { return Tema.pista.opacity(0.35) }
        switch minutos {
        case 0: return Tema.pista
        case ..<45: return Tema.turquesa.opacity(0.18)
        case ..<90: return Tema.turquesa.opacity(0.32)
        default: return Tema.turquesa.opacity(0.5)
        }
    }

    @ViewBuilder
    private func detalle(_ texto: String) -> some View {
        let delDia = hechas.filter { $0.dia == texto }
        let planDia = cruce.filter { $0.sesion.fecha == texto }
        VStack(alignment: .leading, spacing: 6) {
            Text(Calendario.etiqueta(texto))
                .font(.subheadline.bold())
            if delDia.isEmpty && planDia.isEmpty {
                Text(texto > hoyTexto ? "Nada planificado." : "Descanso.")
                    .font(.caption)
                    .foregroundStyle(Tema.textoSecundario)
            }
            ForEach(delDia) { s in
                HStack(spacing: 8) {
                    let d = s.deporte.flatMap(Deporte.init(rawValue:)) ?? .fuerza
                    Image(systemName: icono(d)).foregroundStyle(d.color).frame(width: 18)
                    Text(s.nombre).font(.caption).lineLimit(1)
                    Spacer()
                    Text("\(Int(s.minutos))'").font(.caption.bold())
                }
            }
            ForEach(planDia.filter { $0.estado == .saltada || $0.estado == .pendiente }) { c in
                HStack(spacing: 8) {
                    Image(systemName: c.estado == .saltada ? "xmark.circle" : "circle.dashed")
                        .foregroundStyle(c.estado == .saltada ? Tema.alerta : Tema.textoSecundario)
                        .frame(width: 18)
                    Text(c.sesion.titulo).font(.caption).lineLimit(1)
                    Spacer()
                    Text(c.estado == .saltada ? "no hecha" : "pendiente")
                        .font(.caption2)
                        .foregroundStyle(Tema.textoSecundario)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.pista.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func orden(_ lista: [Deporte]) -> [Deporte] {
        [Deporte.agua, .bici, .carrera, .fuerza].filter { lista.contains($0) }
    }

    private func icono(_ d: Deporte) -> String {
        switch d {
        case .bici: return "bicycle"
        case .agua: return "figure.pool.swim"
        case .carrera: return "figure.run"
        case .fuerza: return "dumbbell.fill"
        }
    }

    private func mesCorto(_ dia: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "MMM"
        return f.string(from: dia).replacingOccurrences(of: ".", with: "")
    }
}

// MARK: - Carga

struct TarjetaForma: View {
    let forma: Double
    let rampa: Double

    var body: some View {
        Tarjeta {
            Text("Forma y rampa")
                .font(.headline)
            HStack(spacing: 0) {
                DatoSimple(titulo: "Forma", valor: (forma >= 0 ? "+" : "") + "\(Int(forma))")
                DatoSimple(titulo: "Rampa semanal", valor: (rampa >= 0 ? "+" : "") + "\(Int(rampa))")
            }
            Text(lectura)
                .font(.footnote)
                .foregroundStyle(Tema.textoSecundario)
        }
    }

    private var lectura: String {
        let fresco = forma >= 0 ? "Forma positiva: llegas descansado." : "Forma negativa: llevas fatiga acumulada, normal cuando construyes."
        if rampa > 40 { return fresco + " El fondo sube rápido esta semana; no encadenes otra igual." }
        if rampa < -15 { return fresco + " El fondo está bajando: has entrenado menos que las semanas anteriores." }
        return fresco + " El fondo se mueve a un ritmo sostenible."
    }
}

/// Horas en cada zona de pulso por semana.
struct GraficaZonas: View {
    let zonas: [TiempoZona]
    @State private var avance = 0.0

    var body: some View {
        Tarjeta {
            Text("Tiempo en zonas de pulso")
                .font(.headline)
            Chart {
                ForEach(zonas) { z in
                    BarMark(x: .value("Semana", z.semana, unit: .weekOfYear), y: .value("Horas", z.horas * avance))
                        .foregroundStyle(by: .value("Zona", z.zona))
                        .cornerRadius(3)
                }
            }
            .chartForegroundStyleScale([
                "Z1": Tema.natacion, "Z2": Tema.carrera, "Z3": Tema.experiencia, "Z4": Tema.bici, "Z5": Tema.alerta
            ])
            .frame(height: 180)
            if let suave = porcentajeSuave {
                Text("Esta semana, el \(Int(suave)) % en Z1 y Z2. En fase de base conviene estar cerca del 80 %.")
                    .font(.caption)
                    .foregroundStyle(Tema.textoSecundario)
            }
        }
        .onAppear {
            avance = 0
            withAnimation(.spring(duration: 1.0, bounce: 0.25)) { avance = 1 }
        }
    }

    private var porcentajeSuave: Double? {
        guard let ultima = zonas.map(\.semana).max() else { return nil }
        let semana = zonas.filter { $0.semana == ultima }
        let total = semana.map(\.horas).reduce(0, +)
        guard total > 0 else { return nil }
        let suave = semana.filter { $0.zona == "Z1" || $0.zona == "Z2" }.map(\.horas).reduce(0, +)
        return suave / total * 100
    }
}

// MARK: - Rendimiento

/// Vatios (o metros por minuto) por pulsación: si sube, la base mejora.
struct GraficaEficiencia: View {
    let puntos: [PuntoSerie]
    @State private var avance = 0.0

    var body: some View {
        Tarjeta {
            Text("Eficiencia aeróbica")
                .font(.headline)
            Chart {
                ForEach(puntos) { p in
                    LineMark(x: .value("Día", p.fecha), y: .value("Eficiencia", p.valor), series: .value("Serie", p.serie))
                        .foregroundStyle(by: .value("Serie", p.serie))
                        .symbol(by: .value("Serie", p.serie))
                        .interpolationMethod(.monotone)
                }
            }
            .chartForegroundStyleScale([
                "Bici: vatios por pulsación": Tema.bici,
                "Carrera: metros por minuto y pulsación": Tema.carrera
            ])
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 190)
            .revelado(avance)
            Text("Lo que rindes por cada pulsación. Si la línea sube con el paso de las semanas, tu base aeróbica mejora aunque no hagas test.")
                .font(.caption)
                .foregroundStyle(Tema.textoSecundario)
        }
        .onAppear {
            avance = 0
            withAnimation(.easeInOut(duration: 1.4)) { avance = 1 }
        }
    }
}

/// Mejores vatios sostenidos, este mes frente al anterior.
struct GraficaPotencia: View {
    let marcas: [MarcaPotencia]
    let ftpEstimado: Double?
    @State private var avance = 0.0

    var body: some View {
        Tarjeta {
            Text("Curva de potencia")
                .font(.headline)
            Chart {
                ForEach(marcas) { m in
                    BarMark(x: .value("Duración", m.duracion), y: .value("Vatios", m.vatios * avance))
                        .position(by: .value("Periodo", m.periodo))
                        .foregroundStyle(by: .value("Periodo", m.periodo))
                        .cornerRadius(3)
                }
            }
            .chartForegroundStyleScale(["28 días anteriores": Tema.pista, "Últimos 28 días": Tema.bici])
            .chartXScale(domain: ["5 s", "1 min", "5 min", "20 min"])
            .frame(height: 180)
            if let ftp = ftpEstimado {
                Text("FTP estimado con tu mejor esfuerzo de 20 minutos del mes: \(Int(ftp)) W. Tu FTP configurado es \(Int(Referencias.ftp)) W. Solo es fiable si ese esfuerzo fue a tope.")
                    .font(.caption)
                    .foregroundStyle(Tema.textoSecundario)
            }
        }
        .onAppear {
            avance = 0
            withAnimation(.spring(duration: 1.0, bounce: 0.25)) { avance = 1 }
        }
    }
}

/// Las últimas carreras con su ritmo y su pulso.
struct TarjetaCarreras: View {
    let carreras: [SesionHecha]

    var body: some View {
        Tarjeta {
            Text("Vuelta a correr")
                .font(.headline)
            ForEach(carreras) { c in
                HStack {
                    Text(Calendario.etiqueta(c.dia))
                        .font(.subheadline.bold())
                        .frame(width: 58, alignment: .leading)
                    Text("\(Int(c.minutos))'")
                        .font(.subheadline)
                        .frame(width: 40, alignment: .leading)
                    Text(ritmo(c))
                        .font(.subheadline)
                    Spacer()
                    Text(c.pulso.map { "\(Int($0)) ppm" } ?? "")
                        .font(.subheadline)
                        .foregroundStyle(Tema.textoSecundario)
                }
            }
            Text("Ritmo medio de la sesión entera, con los tramos de caminar incluidos. Mismo pulso y ritmo más rápido es progreso.")
                .font(.caption)
                .foregroundStyle(Tema.textoSecundario)
        }
    }

    private func ritmo(_ c: SesionHecha) -> String {
        guard let metros = c.metros, metros > 0 else { return "Sin distancia" }
        return Analisis.minutosYSegundos(c.minutos * 60 / (metros / 1000)) + " min/km"
    }
}

/// Ritmo de natación por cada 100 m. Más bajo es más rápido.
struct GraficaNatacion: View {
    let sesiones: [DiaValor]
    @State private var avance = 0.0

    var body: some View {
        Tarjeta {
            Text("Natación: ritmo por 100 m")
                .font(.headline)
            Chart {
                ForEach(sesiones) { s in
                    LineMark(x: .value("Día", s.fecha), y: .value("Segundos", s.valor))
                        .foregroundStyle(Tema.natacion)
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Día", s.fecha), y: .value("Segundos", s.valor))
                        .foregroundStyle(Tema.natacion)
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxis {
                AxisMarks { valor in
                    AxisGridLine()
                    AxisValueLabel {
                        if let segundos = valor.as(Double.self) {
                            Text(Analisis.minutosYSegundos(segundos))
                        }
                    }
                }
            }
            .frame(height: 160)
            .revelado(avance)
            if let ultima = sesiones.last {
                Text("Última sesión: \(Analisis.minutosYSegundos(ultima.valor)) min/100 m, descansos incluidos. Cuanto más abajo, más rápido.")
                    .font(.caption)
                    .foregroundStyle(Tema.textoSecundario)
            }
        }
        .onAppear {
            avance = 0
            withAnimation(.easeInOut(duration: 1.2)) { avance = 1 }
        }
    }
}

// MARK: - Cuerpo

struct TarjetaRecuperacion: View {
    let historico: Historico
    @State private var avance = 0.0

    var body: some View {
        Tarjeta {
            Text("Recuperación")
                .font(.headline)
            HStack(spacing: 0) {
                DatoSimple(titulo: "Pulso en reposo", valor: historico.pulsoReposo.map { "\(Int($0)) ppm" } ?? "Sin datos")
                DatoSimple(titulo: "Media de 7 días", valor: historico.pulsoReposo7.map { "\(Int($0)) ppm" } ?? "Sin datos")
            }
            if !historico.bateria.isEmpty {
                Text("Body Battery recargada cada día")
                    .font(.subheadline)
                    .padding(.top, 4)
                if let ultimo = historico.bateria.last {
                    DatoUltimo(principal: "\(Int(ultimo.valor))", etiqueta: "última noche", color: Tema.turquesa,
                               secundario: "media \(Int(historico.bateria.map(\.valor).reduce(0, +) / Double(historico.bateria.count)))")
                }
                Chart {
                    ForEach(historico.bateria) { d in
                        BarMark(x: .value("Día", d.fecha, unit: .day), y: .value("Carga", d.valor * avance))
                            .foregroundStyle(d.id == historico.bateria.last?.id ? Tema.turquesa : Tema.turquesa.opacity(0.55))
                            .cornerRadius(3)
                            .annotation(position: .top, spacing: 2) {
                                if d.id == historico.bateria.last?.id {
                                    Text("\(Int(d.valor))")
                                        .font(.caption2.bold())
                                        .foregroundStyle(Tema.turquesa)
                                }
                            }
                    }
                }
                .chartYScale(domain: 0...100)
                .frame(height: 130)
            }
            if let cruce = Analisis.suenoYVfc(historico) {
                Text("Tras noches de 7 h o más tu VFC media es \(Int(cruce.largas)) ms; tras noches más cortas, \(Int(cruce.cortas)) ms.")
                    .font(.footnote)
            }
            Text("Un pulso en reposo por encima de tu media varios días seguidos suele avisar de fatiga o de que estás incubando algo.")
                .font(.caption)
                .foregroundStyle(Tema.textoSecundario)
        }
        .onAppear {
            avance = 0
            withAnimation(.spring(duration: 1.0, bounce: 0.25)) { avance = 1 }
        }
    }
}

/// Peso con su tendencia (media de las últimas siete pesadas) y vatios por kilo.
struct GraficaPeso: View {
    let dias: [DiaValor]
    @State private var avance = 0.0

    private var tendencia: [DiaValor] {
        dias.indices.map { i in
            let ventana = dias[max(0, i - 6)...i].map(\.valor)
            return DiaValor(fecha: dias[i].fecha, valor: ventana.reduce(0, +) / Double(ventana.count))
        }
    }

    var body: some View {
        Tarjeta {
            Text("Peso")
                .font(.headline)
            if dias.isEmpty {
                Text("No hay pesadas en Garmin en los últimos 60 días. Registra tu peso en Garmin Connect y aparecerá aquí.")
                    .font(.subheadline)
                    .foregroundStyle(Tema.textoSecundario)
            } else if dias.count < 3, let ultima = dias.last {
                Text("\(String(format: "%.1f", ultima.valor)) kg")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("Con tu FTP de \(Int(Referencias.ftp)) W son \(String(format: "%.2f", Referencias.ftp / ultima.valor)) W/kg.")
                    .font(.footnote)
                LineaObjetivoPeso(actual: ultima.valor)
                Text("Solo hay \(dias.count == 1 ? "una pesada" : "dos pesadas") en Garmin en los últimos 60 días. Con tres o más aparece la gráfica con su tendencia.")
                    .font(.caption)
                    .foregroundStyle(Tema.textoSecundario)
            } else {
                Chart {
                    ForEach(dias) { d in
                        PointMark(x: .value("Día", d.fecha), y: .value("Peso", d.valor))
                            .foregroundStyle(Tema.textoSecundario)
                    }
                    ForEach(tendencia) { d in
                        LineMark(x: .value("Día", d.fecha), y: .value("Peso", d.valor))
                            .foregroundStyle(Tema.experiencia)
                            .interpolationMethod(.monotone)
                    }
                    RuleMark(y: .value("Objetivo", Referencias.pesoObjetivo))
                        .foregroundStyle(Tema.carrera.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 160)
                .revelado(avance)
                if let ultimo = tendencia.last {
                    LineaObjetivoPeso(actual: ultimo.valor)
                    Text("Tendencia: \(String(format: "%.1f", ultimo.valor)) kg. Con tu FTP de \(Int(Referencias.ftp)) W son \(String(format: "%.2f", Referencias.ftp / ultimo.valor)) W/kg.")
                        .font(.footnote)
                }
                Text("Los puntos son cada pesada; la línea, la media de las últimas siete, que es la que importa.")
                    .font(.caption)
                    .foregroundStyle(Tema.textoSecundario)
            }
        }
        .onAppear {
            avance = 0
            withAnimation(.easeInOut(duration: 1.2)) { avance = 1 }
        }
    }
}

// MARK: - Pieza común

struct DatoSimple: View {
    var titulo: String
    var valor: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titulo)
                .font(.caption)
                .foregroundStyle(Tema.textoSecundario)
            Text(valor)
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Cuánto falta hasta el peso objetivo y a qué ritmo semanal.
struct LineaObjetivoPeso: View {
    let actual: Double

    var body: some View {
        let objetivo = Referencias.pesoObjetivo
        let falta = actual - objetivo
        let fecha = Calendario.fecha(Referencias.fechaObjetivo) ?? Date()
        let semanas = max(1, fecha.timeIntervalSinceNow / (7 * 86400))
        let ritmo = falta / semanas * 1000
        // Peso de partida: 88,4 kg en octubre de 2026.
        let inicio = max(88.4, actual)
        let progreso = max(0, min(1, (inicio - actual) / max(inicio - objetivo, 0.1)))
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Objetivo \(String(format: "%.0f", objetivo)) kg")
                    .font(.subheadline.bold())
                    .foregroundStyle(Tema.carrera)
                Spacer()
                Text(falta > 0 ? "faltan \(String(format: "%.1f", falta)) kg" : "¡conseguido!")
                    .font(.subheadline.bold())
            }
            BarraProgreso(valor: progreso * 100, color: Tema.carrera)
            if falta > 0 {
                Text("Para llegar el \(fecha.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "es_ES")))): unos \(Int(ritmo.rounded())) g por semana durante \(Int(semanas)) semanas. \(ritmo <= 500 ? "Es un ritmo sostenible." : "Es un ritmo exigente: más de medio kilo por semana.")")
                    .font(.caption)
                    .foregroundStyle(Tema.textoSecundario)
            }
        }
    }
}
