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
                    Text("Nivel \(nivel.numero)")
                        .font(.title3.bold())
                        .foregroundStyle(Tema.experiencia)
                    BarraProgreso(valor: Double(nivel.dentro) / Double(nivel.necesario) * 100, color: Tema.experiencia)
                    Text("\(nivel.dentro) de \(nivel.necesario) puntos · \(puntos) en total")
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
            Text("Una sesión cuenta como hecha con el 80 % de su duración. A medias da la mitad de puntos. El nivel cuenta desde que empezó este plan.")
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
    @State private var visible = false

    var body: some View {
        Tarjeta {
            Text("Constancia")
                .font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(Array(constancia.dias.enumerated()), id: \.offset) { indice, dia in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(dia.entrenado ? Tema.turquesa : Tema.pista)
                        .frame(height: 22)
                        .scaleEffect(visible ? 1 : 0.3)
                        .opacity(visible ? 1 : 0)
                        .animation(.spring(duration: 0.4).delay(Double(indice) * 0.015), value: visible)
                }
            }
            HStack(spacing: 0) {
                DatoSimple(titulo: "Racha actual", valor: "\(constancia.rachaActual) días")
                DatoSimple(titulo: "Mejor racha", valor: "\(constancia.mejorRacha) días")
                DatoSimple(titulo: "Días entrenados", valor: "\(constancia.diasEntrenados) de 35")
            }
            Text("Cada cuadro es un día, de hace cinco semanas a hoy.")
                .font(.caption)
                .foregroundStyle(Tema.textoSecundario)
        }
        .onAppear { visible = true }
        .onDisappear { visible = false }
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
                Chart {
                    ForEach(historico.bateria) { d in
                        BarMark(x: .value("Día", d.fecha, unit: .day), y: .value("Carga", d.valor * avance))
                            .foregroundStyle(Tema.turquesa)
                            .cornerRadius(3)
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
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 160)
                .revelado(avance)
                if let ultimo = tendencia.last {
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
