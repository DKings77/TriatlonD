// EscenaCampamento.swift
// ------------------------------------------------------------------
// La escena de la pantalla Base, dibujada y animada por código:
// cielo con estrellas que parpadean, hoguera que crepita y tu personaje
// respirando y parpadeando. La hoguera crece con tu energía y las
// ojeras salen si has dormido mal.
//
// Es un personaje provisional hecho con formas. El arte final de estilo
// anime se sustituirá aquí cuando lo tengamos.
// ------------------------------------------------------------------

import SwiftUI

struct EscenaCampamento: View {
    var energia: Double        // 0-100: tamaño de la hoguera
    var notaSueno: Double?     // por debajo de 65 salen ojeras

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { linea in
            Canvas { contexto, tamano in
                let t = linea.date.timeIntervalSinceReferenceDate
                let escala = tamano.width / 350
                contexto.scaleBy(x: escala, y: escala)
                dibujarFondo(&contexto, t: t)
                dibujarHoguera(&contexto, t: t)
                dibujarPersonaje(&contexto, t: t)
            }
        }
        .aspectRatio(350.0 / 400.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityLabel("Tu personaje junto a la hoguera del campamento")
    }

    // MARK: - Colores

    private let cielo = Color(red: 0.075, green: 0.102, blue: 0.200)
    private let colinas = Color(red: 0.110, green: 0.153, blue: 0.282)
    private let mar = Color(red: 0.086, green: 0.188, blue: 0.353)
    private let suelo = Color(red: 0.102, green: 0.141, blue: 0.251)
    private let piel = Color(red: 0.910, green: 0.706, blue: 0.549)
    private let pielSombra = Color(red: 0.851, green: 0.643, blue: 0.486)
    private let pelo = Color(red: 0.227, green: 0.149, blue: 0.094)
    private let camiseta = Color(red: 0.137, green: 0.655, blue: 0.612)
    private let franja = Color(red: 0.549, green: 0.922, blue: 0.882)
    private let pantalon = Color(red: 0.106, green: 0.165, blue: 0.322)

    // MARK: - Formas

    private func poligono(_ puntos: [(CGFloat, CGFloat)]) -> Path {
        var camino = Path()
        guard let primero = puntos.first else { return camino }
        camino.move(to: CGPoint(x: primero.0, y: primero.1))
        for punto in puntos.dropFirst() {
            camino.addLine(to: CGPoint(x: punto.0, y: punto.1))
        }
        camino.closeSubpath()
        return camino
    }

    private func caja(_ x: CGFloat, _ y: CGFloat, _ ancho: CGFloat, _ alto: CGFloat, radio: CGFloat = 0) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: ancho, height: alto), cornerRadius: radio)
    }

    private func elipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
    }

    private func linea(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) -> Path {
        var camino = Path()
        camino.move(to: CGPoint(x: x1, y: y1))
        camino.addLine(to: CGPoint(x: x2, y: y2))
        return camino
    }

    // MARK: - Dibujo

    private func dibujarFondo(_ c: inout GraphicsContext, t: Double) {
        c.fill(caja(0, 0, 350, 400), with: .color(cielo))

        let estrellas: [(CGFloat, CGFloat, Double)] = [
            (40, 40, 0.0), (96, 72, 1.3), (150, 30, 2.1), (230, 96, 0.7),
            (322, 130, 2.9), (60, 130, 1.9), (200, 54, 3.4), (120, 110, 0.4)
        ]
        for (x, y, fase) in estrellas {
            let brillo = 0.35 + 0.65 * abs(sin(t * 0.9 + fase))
            c.fill(elipse(x, y, 1.6, 1.6), with: .color(.white.opacity(brillo)))
        }

        c.fill(elipse(290, 58, 22, 22), with: .color(Color(red: 0.867, green: 0.890, blue: 0.961)))
        c.fill(elipse(282, 52, 20, 20), with: .color(cielo))

        c.fill(poligono([(0, 250), (60, 190), (110, 236), (170, 170), (240, 240), (300, 200), (350, 244), (350, 300), (0, 300)]),
               with: .color(colinas))
        c.fill(caja(0, 270, 350, 36), with: .color(mar))
        // Reflejo de la luna que se mueve despacio sobre el mar.
        let vaiven = CGFloat(sin(t * 0.6)) * 6
        c.fill(caja(262 + vaiven, 280, 44, 2, radio: 1), with: .color(.white.opacity(0.25)))
        c.fill(caja(272 - vaiven, 288, 28, 2, radio: 1), with: .color(.white.opacity(0.18)))
        c.fill(poligono([(0, 300), (90, 293), (175, 290), (260, 293), (350, 300), (350, 400), (0, 400)]),
               with: .color(suelo))
    }

    private func dibujarHoguera(_ c: inout GraphicsContext, t: Double) {
        let fuerza = CGFloat(0.55 + 0.75 * min(max(energia, 0), 100) / 100)
        let temblor = CGFloat(1 + 0.09 * sin(t * 9) + 0.06 * sin(t * 13.7))
        let alto = 34 * fuerza * temblor
        let ladeo = CGFloat(sin(t * 5.3)) * 3

        // Resplandor en el suelo.
        c.fill(elipse(71, 348, 46 * fuerza, 9), with: .color(Color(red: 1, green: 0.54, blue: 0.24).opacity(0.18)))

        let tronco = Color(red: 0.353, green: 0.227, blue: 0.133)
        c.stroke(linea(44, 352, 98, 340), with: .color(tronco), style: StrokeStyle(lineWidth: 8, lineCap: .round))
        c.stroke(linea(46, 340, 96, 352), with: .color(Color(red: 0.42, green: 0.271, blue: 0.157)),
                 style: StrokeStyle(lineWidth: 8, lineCap: .round))

        c.fill(poligono([(56, 342), (62, 342 - alto * 0.55), (71 + ladeo, 342 - alto), (80, 342 - alto * 0.5), (86, 342)]),
               with: .color(Color(red: 1, green: 0.541, blue: 0.239)))
        c.fill(poligono([(63, 342), (67, 342 - alto * 0.35), (71 + ladeo * 0.6, 342 - alto * 0.62), (76, 342 - alto * 0.3), (79, 342)]),
               with: .color(Color(red: 1, green: 0.82, blue: 0.4)))

        // Chispas que suben.
        for i in 0..<4 {
            let fase = (t * 0.45 + Double(i) / 4).truncatingRemainder(dividingBy: 1)
            let x = 71 + CGFloat(sin(fase * 6 + Double(i) * 1.7)) * 8
            let y = 330 - CGFloat(fase) * 60 * fuerza
            c.fill(elipse(x, y, 1.6, 1.6), with: .color(Color(red: 1, green: 0.82, blue: 0.4).opacity(1 - fase)))
        }
    }

    private func dibujarPersonaje(_ c: inout GraphicsContext, t: Double) {
        // Piernas, zapatillas y venda: quietas.
        c.fill(caja(166, 250, 18, 96), with: .color(piel))
        c.fill(caja(196, 250, 18, 96), with: .color(piel))
        c.fill(caja(158, 344, 30, 14, radio: 6), with: .color(Tema.turquesa))
        c.fill(caja(194, 344, 30, 14, radio: 6), with: .color(Tema.turquesa))
        c.fill(caja(195, 320, 20, 24), with: .color(Color(red: 0.949, green: 0.957, blue: 0.98)))
        c.stroke(linea(195, 328, 215, 324), with: .color(Color(red: 0.725, green: 0.753, blue: 0.839)), lineWidth: 1.5)
        c.stroke(linea(195, 336, 215, 332), with: .color(Color(red: 0.725, green: 0.753, blue: 0.839)), lineWidth: 1.5)

        // Aviso de la lesión: un aro que late alrededor del pie.
        let latido = CGFloat(sin(t * 3))
        c.stroke(elipse(205, 332, 19 + latido * 2.5, 19 + latido * 2.5),
                 with: .color(Tema.alerta.opacity(0.55 + 0.35 * Double(latido))),
                 style: StrokeStyle(lineWidth: 2, dash: [4, 4]))

        // Tronco y cabeza: suben y bajan al respirar.
        var arriba = c
        arriba.translateBy(x: 0, y: CGFloat(sin(t * 1.6)) * 1.6)

        arriba.fill(poligono([(170, 112), (160, 128), (158, 150), (162, 168), (174, 164), (171, 148), (171, 132), (174, 120)]),
                    with: .color(pelo))
        arriba.fill(poligono([(210, 112), (220, 128), (222, 150), (218, 168), (206, 164), (209, 148), (209, 132), (206, 120)]),
                    with: .color(pelo))
        arriba.fill(poligono([(158, 162), (146, 170), (140, 226), (152, 228), (160, 190)]), with: .color(piel))
        arriba.fill(poligono([(222, 162), (234, 170), (240, 226), (228, 228), (220, 190)]), with: .color(piel))
        arriba.fill(poligono([(162, 228), (218, 228), (220, 272), (194, 272), (190, 252), (186, 272), (160, 272)]),
                    with: .color(pantalon))
        arriba.fill(poligono([(158, 160), (174, 155), (190, 153), (206, 155), (222, 160), (218, 232), (162, 232)]),
                    with: .color(camiseta))
        arriba.fill(poligono([(159, 190), (221, 190), (220, 200), (160, 200)]), with: .color(franja))
        arriba.fill(poligono([(158, 160), (144, 170), (147, 188), (161, 184)]), with: .color(camiseta))
        arriba.fill(poligono([(222, 160), (236, 170), (233, 188), (219, 184)]), with: .color(camiseta))
        arriba.fill(caja(183, 146, 14, 14), with: .color(pielSombra))
        arriba.fill(elipse(190, 126, 21, 24), with: .color(piel))
        arriba.fill(poligono([(170, 128), (172, 146), (180, 153), (190, 154), (200, 153), (208, 146), (210, 128), (205, 141), (190, 144), (175, 141)]),
                    with: .color(pelo))
        arriba.fill(poligono([(167, 127), (164, 108), (172, 97), (192, 93), (208, 96), (216, 108), (213, 127), (207, 112), (199, 120), (192, 108), (184, 120), (177, 110)]),
                    with: .color(pelo))

        // Ojos: parpadea cada cuatro segundos.
        let ojosAbiertos = t.truncatingRemainder(dividingBy: 4) > 0.16
        if ojosAbiertos {
            arriba.fill(elipse(181, 128, 4.2, 5), with: .color(.white))
            arriba.fill(elipse(199, 128, 4.2, 5), with: .color(.white))
            arriba.fill(elipse(181.5, 129, 2.8, 3.8), with: .color(Color(red: 0.357, green: 0.227, blue: 0.118)))
            arriba.fill(elipse(198.5, 129, 2.8, 3.8), with: .color(Color(red: 0.357, green: 0.227, blue: 0.118)))
            arriba.fill(elipse(182.5, 127.5, 1, 1), with: .color(.white))
            arriba.fill(elipse(199.5, 127.5, 1, 1), with: .color(.white))
        } else {
            arriba.stroke(linea(177, 129, 185, 129), with: .color(pelo), lineWidth: 1.6)
            arriba.stroke(linea(195, 129, 203, 129), with: .color(pelo), lineWidth: 1.6)
        }
        arriba.stroke(linea(175, 121, 186, 122), with: .color(pelo), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        arriba.stroke(linea(194, 122, 205, 121), with: .color(pelo), style: StrokeStyle(lineWidth: 2, lineCap: .round))

        // Ojeras si la noche ha sido floja.
        if let nota = notaSueno, nota < 65 {
            let ojera = Color(red: 0.69, green: 0.498, blue: 0.369)
            arriba.stroke(linea(177, 136, 185, 136), with: .color(ojera), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            arriba.stroke(linea(195, 136, 203, 136), with: .color(ojera), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
        arriba.stroke(linea(185, 142, 195, 142), with: .color(Color(red: 0.478, green: 0.29, blue: 0.212)),
                      style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    }
}

/// Anillo de 0 a 100 que se llena al aparecer.
struct AnilloProgreso: View {
    var valor: Double
    var color: Color
    var etiqueta: String
    @State private var mostrado = 0.0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Tema.pista, lineWidth: 9)
            Circle()
                .trim(from: 0, to: mostrado / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(valor))")
                    .font(.title2.bold())
                    .contentTransition(.numericText())
                Text(etiqueta)
                    .font(.caption2)
                    .foregroundStyle(Tema.textoSecundario)
            }
        }
        .frame(width: 92, height: 92)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) { mostrado = min(max(valor, 0), 100) }
        }
        .onChange(of: valor) { _, nuevo in
            withAnimation(.easeOut(duration: 0.8)) { mostrado = min(max(nuevo, 0), 100) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(etiqueta): \(Int(valor)) de 100")
    }
}
