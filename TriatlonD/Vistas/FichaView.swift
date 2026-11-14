// FichaView.swift
// ------------------------------------------------------------------
// Datos: los dos depósitos de carga, las gráficas de las últimas
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

                Tarjeta {
                    Text("Los dos depósitos de carga")
                        .font(.headline)
                    HStack(alignment: .bottom, spacing: 14) {
                        Deposito(titulo: "Esta semana", detalle: "Se llena y se vacía rápido",
                                 valor: estado.carga.aguda, color: Tema.bici)
                        Deposito(titulo: "Tu fondo", detalle: "Sube y baja despacio",
                                 valor: estado.carga.cronica, color: Tema.turquesa)
                    }
                    Text(Juego.lecturaCarga(estado.carga))
                        .font(.footnote)
                        .foregroundStyle(Tema.textoSecundario)
                }

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

/// Depósito vertical: la altura del relleno es la carga sobre un tope de 600.
private struct Deposito: View {
    var titulo: String
    var detalle: String
    var valor: Double?
    var color: Color
    @State private var lleno = 0.0

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 12).fill(Tema.pista)
                    RoundedRectangle(cornerRadius: 12).fill(color)
                        .frame(height: geo.size.height * lleno)
                }
            }
            .frame(height: 120)
            .onAppear {
                lleno = 0
                withAnimation(.spring(duration: 1.1, bounce: 0.35)) { lleno = min((valor ?? 0) / 600, 1) }
            }
            .onChange(of: valor) { _, nuevo in
                withAnimation(.spring(duration: 0.8, bounce: 0.3)) { lleno = min((nuevo ?? 0) / 600, 1) }
            }
            Text(valor.map { "\(Int($0))" } ?? "Sin datos")
                .font(.title2.bold())
                .contentTransition(.numericText())
            Text(titulo)
                .font(.subheadline)
            Text(detalle)
                .font(.caption)
                .foregroundStyle(Tema.textoSecundario)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
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
