// TravesiaView.swift
// ------------------------------------------------------------------
// El mapa de la temporada. Cada semana es una etapa con sus sesiones
// como casillas (hecha, a medias, saltada o pendiente) y sus estrellas.
// Cada cuatro semanas, una región. El test de FTP es el jefe: al
// superarlo apuntas tu nuevo FTP y ves cuánto sube tu nota de bici.
// ------------------------------------------------------------------

import SwiftUI

enum Travesia {
    static let regiones = [
        "La costa de la base", "Las colinas", "El puerto de montaña",
        "La meseta", "El valle del ritmo", "La cumbre"
    ]

    /// La S7 abre la región 1; cada región dura cuatro semanas.
    static func region(_ semana: Int) -> Int { max(1, (semana - 7) / 4 + 1) }

    static func nombreRegion(_ region: Int) -> String {
        regiones[min(region - 1, regiones.count - 1)]
    }

    static func subtitulo(_ fecha: Date) -> String {
        let semana = Calendario.semanaTemporada(fecha)
        return "Región \(region(semana)) · etapa \(semana)"
    }

    static func estrellas(_ porcentaje: Double?) -> Int {
        guard let p = porcentaje else { return 0 }
        return p >= 90 ? 3 : (p >= 70 ? 2 : (p >= 50 ? 1 : 0))
    }
}

struct TravesiaView: View {
    let plan: AlmacenPlan
    let almacen: AlmacenEstado
    var conCabecera = true

    @State private var visible = false
    @State private var jefe: SesionPlan?

    private var semanaActual: Int { Calendario.semanaTemporada(Date()) }
    private var regionActual: Int { Travesia.region(semanaActual) }

    private var cruce: [Cumplimiento] {
        Analisis.cumplimiento(plan: plan.sesiones, hechas: almacen.historico?.sesiones ?? [],
                              hoy: Calendario.texto(Date()))
    }

    /// Semanas que se muestran: desde la S7 hasta el final de la región actual
    /// o la última semana planificada, de la más lejana (arriba) a la primera (abajo).
    private var semanas: [Int] {
        let planificadas = plan.sesiones.compactMap { Calendario.fecha($0.fecha).map(Calendario.semanaTemporada) }
        let finRegion = 7 + regionActual * 4 - 1
        let ultima = max(finRegion, planificadas.max() ?? finRegion)
        return Array((7...ultima).reversed())
    }

    var body: some View {
        ScrollViewReader { lector in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        if conCabecera {
                            Text("La Travesía")
                                .font(.largeTitle.bold())
                        }
                        Text("Región \(regionActual): \(Travesia.nombreRegion(regionActual))")
                            .font(conCabecera ? .subheadline : .headline)
                            .foregroundStyle(conCabecera ? Tema.textoSecundario : Tema.experiencia)
                    }
                    .padding(.bottom, 14)

                    ForEach(Array(semanas.enumerated()), id: \.element) { indice, semana in
                        let sesiones = cruce.filter { c in
                            Calendario.fecha(c.sesion.fecha).map(Calendario.semanaTemporada) == semana
                        }
                        NodoEtapa(semana: semana, sesiones: sesiones, actual: semana == semanaActual,
                                  ultimo: indice == semanas.count - 1, alPulsarJefe: { jefe = $0 })
                            .id(semana)
                            .opacity(visible ? 1 : 0)
                            .offset(y: visible ? 0 : 24)
                            .animation(.spring(duration: 0.5).delay(Double(indice) * 0.06), value: visible)
                        // El cartel va debajo de la primera semana de cada región (el camino sube).
                        if (semana - 7) % 4 == 0 && semana > 7 {
                            CartelRegion(region: Travesia.region(semana))
                        }
                    }
                    CartelRegion(region: 1)
                }
                .padding(20)
            }
            .onAppear {
                visible = true
                lector.scrollTo(semanaActual, anchor: .center)
            }
        }
        .background(Tema.fondo)
        .foregroundStyle(Tema.texto)
        .sheet(item: $jefe) { sesion in
            ResultadoFTPView(sesion: sesion, almacen: almacen)
        }
    }
}

private struct CartelRegion: View {
    let region: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "flag.fill")
                .foregroundStyle(Tema.experiencia)
            Text("Región \(region): \(Travesia.nombreRegion(region))")
                .font(.caption.bold())
                .foregroundStyle(Tema.experiencia)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Tema.experiencia.opacity(0.12))
        .clipShape(Capsule())
        .padding(.vertical, 8)
    }
}

private struct NodoEtapa: View {
    let semana: Int
    let sesiones: [Cumplimiento]
    let actual: Bool
    let ultimo: Bool
    let alPulsarJefe: (SesionPlan) -> Void
    @State private var latido = false

    private var porcentaje: Double? { Analisis.porcentaje(sesiones) }
    private var jefe: Cumplimiento? {
        sesiones.first { $0.sesion.nombre.localizedCaseInsensitiveContains("test") }
    }
    private var futura: Bool { semana > Calendario.semanaTemporada(Date()) }
    private var anteriorALaApp: Bool { sesiones.isEmpty && !futura && semana < 10 }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Camino: punto y línea hacia la etapa anterior
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(colorPunto)
                        .frame(width: actual ? 34 : 22, height: actual ? 34 : 22)
                    if actual {
                        Circle()
                            .stroke(Tema.turquesa, lineWidth: 2)
                            .frame(width: 46, height: 46)
                            .scaleEffect(latido ? 1.25 : 0.9)
                            .opacity(latido ? 0 : 1)
                        Image(systemName: "figure.run")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Tema.fondo)
                    } else if jefe != nil {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Tema.fondo)
                    }
                }
                .frame(width: 46, height: 46)
                if !ultimo {
                    Rectangle()
                        .fill(Tema.pista)
                        .frame(width: 3)
                        .frame(minHeight: 30, maxHeight: .infinity)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Etapa \(semana)")
                        .font(.headline)
                    if actual {
                        Text("estás aquí")
                            .font(.caption.bold())
                            .foregroundStyle(Tema.turquesa)
                    }
                    Spacer()
                    Estrellas(numero: futura ? 0 : Travesia.estrellas(porcentaje), apagadas: futura || sesiones.isEmpty)
                }
                if anteriorALaApp {
                    Text("Superada antes de la app")
                        .font(.caption)
                        .foregroundStyle(Tema.textoSecundario)
                } else if sesiones.isEmpty {
                    Text("Por planificar: pídesela al entrenador en Plan")
                        .font(.caption)
                        .foregroundStyle(Tema.textoSecundario)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(34), spacing: 6), count: 7), alignment: .leading, spacing: 6) {
                        ForEach(sesiones) { c in
                            Casilla(cumplimiento: c)
                        }
                    }
                    if let p = porcentaje {
                        Text("\(Int(p.rounded())) % cumplido")
                            .font(.caption)
                            .foregroundStyle(Tema.textoSecundario)
                    }
                }
                if let jefe {
                    Button {
                        alPulsarJefe(jefe.sesion)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                            Text(jefe.estado == .hecha ? "Jefe superado: apunta tu FTP" : "Jefe: test de FTP · \(Calendario.etiqueta(jefe.sesion.fecha))")
                                .font(.subheadline.bold())
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .padding(10)
                        .foregroundStyle(Tema.fondo)
                        .background(Tema.experiencia)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(actual ? Tema.superficie : Tema.superficie.opacity(futura ? 0.45 : 0.8))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(actual ? Tema.turquesa : .clear, lineWidth: 1.5))
            .padding(.bottom, 12)
        }
        .onAppear {
            if actual {
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { latido = true }
            }
        }
    }

    private var colorPunto: Color {
        if actual { return Tema.turquesa }
        if jefe != nil { return Tema.experiencia }
        if futura { return Tema.pista }
        if anteriorALaApp { return Tema.carrera.opacity(0.6) }
        switch Travesia.estrellas(porcentaje) {
        case 3, 2: return Tema.carrera
        case 1: return Tema.experiencia
        default: return sesiones.isEmpty ? Tema.pista : Tema.alerta
        }
    }
}

/// Una sesión como casilla: icono del deporte y color según cómo fue.
private struct Casilla: View {
    let cumplimiento: Cumplimiento

    var body: some View {
        let color = cumplimiento.sesion.deporte.color
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(fondo(color))
            RoundedRectangle(cornerRadius: 8)
                .stroke(cumplimiento.estado == .pendiente ? color.opacity(0.7) : .clear, lineWidth: 1.5)
            Image(systemName: icono)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(cumplimiento.estado == .hecha || cumplimiento.estado == .aMedias ? Tema.fondo : color)
            if cumplimiento.estado == .saltada {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Tema.alerta)
            }
        }
        .frame(width: 34, height: 34)
        .accessibilityLabel("\(cumplimiento.sesion.titulo)")
    }

    private func fondo(_ color: Color) -> Color {
        switch cumplimiento.estado {
        case .hecha: return color
        case .aMedias: return color.opacity(0.5)
        case .saltada: return Tema.alerta.opacity(0.12)
        case .pendiente: return .clear
        }
    }

    private var icono: String {
        switch cumplimiento.sesion.deporte {
        case .bici: return "bicycle"
        case .agua: return "figure.pool.swim"
        case .carrera: return "figure.run"
        case .fuerza: return "dumbbell.fill"
        }
    }
}

private struct Estrellas: View {
    let numero: Int
    let apagadas: Bool

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < numero ? "star.fill" : "star")
                    .font(.caption)
                    .foregroundStyle(i < numero ? Tema.experiencia : Tema.textoSecundario.opacity(apagadas ? 0.3 : 0.7))
            }
        }
    }
}

/// Resultado del jefe: apuntas el FTP del test y ves cuánto cambia tu nota de bici.
struct ResultadoFTPView: View {
    let sesion: SesionPlan
    let almacen: AlmacenEstado
    @Environment(\.dismiss) private var cerrar
    @AppStorage("ref.ftp") private var ftpGuardado = 200.0
    @State private var ftp = 200.0
    @State private var guardado = false

    private var peso: Double { almacen.estado.pesoKg ?? almacen.historico?.peso.last?.valor ?? 88 }
    private var factor: Double { Nota.factor(edad: Nota.categoria(Nota.edad()).edadTabla) }
    private func nota(_ vatios: Double) -> Double { min(100, vatios / peso / (Nota.wkgMundial * factor) * 100) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text(sesion.titulo)
                    .font(.headline)
                Text("Haz el test de rampa de Rouvy y apunta aquí el FTP que te dé.")
                    .font(.subheadline)
                    .foregroundStyle(Tema.textoSecundario)

                Tarjeta {
                    Text("\(Int(ftp)) W")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Stepper("FTP", value: $ftp, in: 100...400, step: 1)
                        .labelsHidden()
                    Text(String(format: "%.2f W/kg con %.1f kg", ftp / peso, peso))
                        .font(.subheadline)
                }

                Tarjeta {
                    Text("Tu nota de bici")
                        .font(.headline)
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(Int(nota(ftpGuardado).rounded()))")
                            .font(.title.bold())
                            .foregroundStyle(Tema.textoSecundario)
                        Image(systemName: "arrow.right")
                        Text("\(Int(nota(ftp).rounded()))")
                            .font(.title.bold())
                            .foregroundStyle(ftp >= ftpGuardado ? Tema.carrera : Tema.alerta)
                            .contentTransition(.numericText())
                    }
                    BarraProgreso(valor: nota(ftp), color: Tema.bici)
                }

                Button {
                    withAnimation(.spring) {
                        ftpGuardado = ftp
                        guardado = true
                    }
                } label: {
                    Text(guardado ? "FTP guardado" : "Guardar nuevo FTP")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(guardado ? Tema.carrera : Tema.experiencia)
                        .foregroundStyle(Tema.fondo)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(guardado)
                if guardado {
                    Text("Cámbialo también en Garmin, Rouvy e intervals.icu, o pídemelo: los entrenos van en % del FTP y cada sitio usa el suyo.")
                        .font(.caption)
                        .foregroundStyle(Tema.textoSecundario)
                }
                Spacer()
            }
            .padding(20)
            .background(Tema.fondo)
            .foregroundStyle(Tema.texto)
            .animation(.spring(duration: 0.3), value: ftp)
            .navigationTitle("Jefe de la región")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { cerrar() }
                }
            }
            .onAppear { ftp = ftpGuardado }
        }
        .preferredColorScheme(.dark)
    }
}
