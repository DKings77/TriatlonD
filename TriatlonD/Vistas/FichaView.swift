// FichaView.swift
// ------------------------------------------------------------------
// Datos: el medidor de carga, las gráficas de las últimas
// semanas (carga, sueño, pulso y volumen) y los cruces entre ellas.
// Todo se dibuja animado al entrar.
// ------------------------------------------------------------------

import SwiftUI
import Charts

struct FichaView: View {
    let almacen: AlmacenEstado

    private var estado: EstadoDia { almacen.estado }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Datos")
                    .font(.largeTitle.bold())

                MedidorCarga(carga: estado.carga)

                HStack(spacing: 10) {
                    Metrica(titulo: "Sueño", valor: estado.sueno.horas.map { String(format: "%.1f h", $0) })
                    Metrica(titulo: "Pulso (VFC)", valor: estado.vfc.mediaSemanalMs.map { "\(Int($0)) ms" })
                    Metrica(titulo: "Peso", valor: estado.pesoKg.map { String(format: "%.1f kg", $0) })
                }

                if let historico = almacen.historico {
                    let lecturas = Lecturas.todas(historico)
                    if !lecturas.isEmpty {
                        Tarjeta {
                            Label("Lo que cuentan tus datos", systemImage: "sparkles")
                                .font(.headline)
                            ForEach(lecturas, id: \.self) { frase in
                                Text(frase)
                                    .font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    GraficaCarga(dias: historico.carga)
                    GraficaSueno(noches: historico.sueno)
                    GraficaVFC(noches: historico.vfc)
                    GraficaVolumen(semanas: historico.volumen)
                } else if almacen.cargando {
                    Tarjeta {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Trayendo cuatro semanas de datos de Garmin…")
                                .font(.subheadline)
                        }
                    }
                } else {
                    Tarjeta {
                        Text("Las gráficas aparecen con datos reales. Añade tu clave de Garmin en Ajustes, desde el engranaje de Base.")
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

// MARK: - Gráficas

/// Carga de la semana frente al fondo, 28 días. La línea se dibuja de izquierda a derecha.
private struct GraficaCarga: View {
    let dias: [DiaCarga]
    @State private var avance = 0.0

    var body: some View {
        Tarjeta {
            Text("Carga: semana frente a fondo")
                .font(.headline)
            Chart {
                ForEach(dias) { dia in
                    LineMark(x: .value("Día", dia.fecha), y: .value("Carga", dia.aguda), series: .value("Serie", "Esta semana"))
                        .foregroundStyle(by: .value("Serie", "Esta semana"))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Día", dia.fecha), y: .value("Carga", dia.cronica), series: .value("Serie", "Tu fondo"))
                        .foregroundStyle(by: .value("Serie", "Tu fondo"))
                        .interpolationMethod(.catmullRom)
                }
            }
            .chartForegroundStyleScale(["Esta semana": Tema.bici, "Tu fondo": Tema.turquesa])
            .frame(height: 180)
            .mask(alignment: .leading) {
                GeometryReader { geo in
                    Rectangle().frame(width: geo.size.width * avance)
                }
            }
            Text("Cuando la línea naranja va muy por encima de la turquesa, estás cargando más de lo que tu cuerpo tiene asimilado.")
                .font(.caption)
                .foregroundStyle(Tema.textoSecundario)
        }
        .onAppear {
            avance = 0
            withAnimation(.easeInOut(duration: 1.4)) { avance = 1 }
        }
    }
}

/// Horas de sueño de 14 noches. Las barras crecen desde abajo.
private struct GraficaSueno: View {
    let noches: [NocheSueno]
    @State private var avance = 0.0

    var body: some View {
        Tarjeta {
            Text("Sueño de las últimas noches")
                .font(.headline)
            Chart {
                ForEach(noches) { noche in
                    BarMark(x: .value("Noche", noche.fecha, unit: .day), y: .value("Horas", noche.horas * avance))
                        .foregroundStyle(color(noche))
                        .cornerRadius(3)
                }
                RuleMark(y: .value("Objetivo", 7))
                    .foregroundStyle(Tema.textoSecundario)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .chartYScale(domain: 0...10)
            .frame(height: 170)
            Text("Verde, 7 h o más. Amarillo, entre 6 y 7. Rojo, menos de 6. La línea marca las 7 h.")
                .font(.caption)
                .foregroundStyle(Tema.textoSecundario)
        }
        .onAppear {
            avance = 0
            withAnimation(.spring(duration: 1.0, bounce: 0.25)) { avance = 1 }
        }
    }

    private func color(_ noche: NocheSueno) -> Color {
        if noche.horas >= 7 { return Tema.carrera }
        if noche.horas >= 6 { return Tema.experiencia }
        return Tema.alerta
    }
}

/// Variabilidad del pulso noche a noche y su media semanal.
private struct GraficaVFC: View {
    let noches: [NocheVFC]
    @State private var avance = 0.0

    var body: some View {
        Tarjeta {
            Text("Variabilidad del pulso")
                .font(.headline)
            Chart {
                ForEach(noches) { noche in
                    AreaMark(x: .value("Noche", noche.fecha), y: .value("VFC", noche.anoche))
                        .foregroundStyle(Tema.natacion.opacity(0.18))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Noche", noche.fecha), y: .value("VFC", noche.anoche), series: .value("Serie", "Cada noche"))
                        .foregroundStyle(Tema.natacion)
                        .interpolationMethod(.catmullRom)
                    if let media = noche.media {
                        LineMark(x: .value("Noche", noche.fecha), y: .value("VFC", media), series: .value("Serie", "Media semanal"))
                            .foregroundStyle(Tema.experiencia)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    }
                }
            }
            .frame(height: 170)
            .mask(alignment: .leading) {
                GeometryReader { geo in
                    Rectangle().frame(width: geo.size.width * avance)
                }
            }
            Text("Azul, cada noche. Amarillo discontinuo, tu media de siete días. Si el azul cae varios días por debajo, toca aflojar.")
                .font(.caption)
                .foregroundStyle(Tema.textoSecundario)
        }
        .onAppear {
            avance = 0
            withAnimation(.easeInOut(duration: 1.4)) { avance = 1 }
        }
    }
}

/// Horas por deporte de las últimas cuatro semanas, apiladas.
private struct GraficaVolumen: View {
    let semanas: [VolumenSemana]
    @State private var avance = 0.0

    var body: some View {
        Tarjeta {
            Text("Horas por semana y deporte")
                .font(.headline)
            Chart {
                ForEach(semanas) { semana in
                    BarMark(x: .value("Semana", semana.inicio, unit: .weekOfYear), y: .value("Horas", semana.horas * avance))
                        .foregroundStyle(by: .value("Deporte", semana.deporte))
                        .cornerRadius(3)
                }
            }
            .chartForegroundStyleScale([
                "Bici": Tema.bici, "Carrera": Tema.carrera, "Agua": Tema.natacion, "Fuerza": Tema.fuerza
            ])
            .frame(height: 190)
        }
        .onAppear {
            avance = 0
            withAnimation(.spring(duration: 1.0, bounce: 0.25)) { avance = 1 }
        }
    }
}

// MARK: - Piezas

/// Medidor compacto de carga: una regla con cuatro zonas y un marcador que
/// se desliza hasta tu relación entre la carga de la semana y tu fondo.
private struct MedidorCarga: View {
    let carga: Carga
    @State private var posicion = 0.0

    // La regla va de 0 a 2: baja hasta 0,8, óptima hasta 1,3, alta hasta 1,5 y muy alta después.
    private let zonas: [(color: Color, parte: Double)] = [
        (Tema.natacion, 0.40), (Tema.carrera, 0.25), (Tema.experiencia, 0.10), (Tema.alerta, 0.25)
    ]

    var body: some View {
        Tarjeta {
            HStack {
                Text("Carga")
                    .font(.headline)
                Spacer()
                Text(estado.texto)
                    .font(.subheadline.bold())
                    .foregroundStyle(estado.color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        ForEach(Array(zonas.enumerated()), id: \.offset) { _, zona in
                            Rectangle()
                                .fill(zona.color.opacity(0.85))
                                .frame(width: geo.size.width * zona.parte)
                        }
                    }
                    .frame(height: 10)
                    .clipShape(Capsule())
                    Circle()
                        .fill(Tema.texto)
                        .overlay(Circle().stroke(Tema.fondo, lineWidth: 3))
                        .frame(width: 20, height: 20)
                        .offset(x: (geo.size.width - 20) * posicion)
                }
                .frame(height: 20)
            }
            .frame(height: 20)
            HStack(spacing: 0) {
                Dato(titulo: "Esta semana", valor: carga.aguda.map { "\(Int($0))" })
                Dato(titulo: "Tu fondo", valor: carga.cronica.map { "\(Int($0))" })
                Dato(titulo: "Relación", valor: carga.relacion.map { String(format: "%.1f", $0) })
            }
            Text(Juego.lecturaCarga(carga))
                .font(.footnote)
                .foregroundStyle(Tema.textoSecundario)
        }
        .onAppear { mover(a: carga.relacion) }
        .onChange(of: carga.relacion) { _, nueva in mover(a: nueva) }
        .accessibilityElement(children: .combine)
    }

    private func mover(a relacion: Double?) {
        posicion = 0
        withAnimation(.spring(duration: 1.1, bounce: 0.3)) {
            posicion = min(max((relacion ?? 0) / 2, 0), 1)
        }
    }

    private var estado: (texto: String, color: Color) {
        guard let r = carga.relacion else { return ("Sin datos", Tema.textoSecundario) }
        if r < 0.8 { return ("Baja", Tema.natacion) }
        if r <= 1.3 { return ("Óptima", Tema.carrera) }
        if r <= 1.5 { return ("Alta", Tema.experiencia) }
        return ("Muy alta", Tema.alerta)
    }
}

private struct Dato: View {
    var titulo: String
    var valor: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titulo)
                .font(.caption)
                .foregroundStyle(Tema.textoSecundario)
            Text(valor ?? "Sin datos")
                .font(.title3.bold())
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Metrica: View {
    var titulo: String
    var valor: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titulo)
                .font(.caption)
                .foregroundStyle(Tema.textoSecundario)
            Text(valor ?? "Sin datos")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Tema.superficie)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
