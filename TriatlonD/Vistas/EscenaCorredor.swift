// EscenaCorredor.swift
// ------------------------------------------------------------------
// Tu personaje corriendo, en estilo anime y dibujado por código:
// media melena castaña, barba, ojos claros y el pie vendado. Corre de
// verdad (piernas y brazos en ciclo), el pelo ondea y el fondo tiene
// luces que pasan. Va más rápido cuanta más energía tienes; si vas
// justo, suda, y si has dormido mal le salen ojeras.
//
// Sigue siendo dibujo vectorial. Cuando haya ilustraciones de verdad,
// se sustituyen aquí.
// ------------------------------------------------------------------

import SwiftUI

struct EscenaCorredor: View {
    var energia: Double        // 0-100
    var notaSueno: Double?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { linea in
            Canvas { contexto, tamano in
                let t = linea.date.timeIntervalSinceReferenceDate
                let escala = tamano.width / 350
                contexto.scaleBy(x: escala, y: escala)
                dibujarFondo(&contexto, t: t)
                dibujarCorredor(&contexto, t: t)
            }
        }
        .aspectRatio(350.0 / 400.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityLabel("Tu personaje corriendo")
    }

    // MARK: - Colores

    private let trazo = Color(red: 0.086, green: 0.071, blue: 0.118)
    private let piel = Color(red: 0.937, green: 0.741, blue: 0.588)
    private let pielSombra = Color(red: 0.820, green: 0.612, blue: 0.467)
    private let pelo = Color(red: 0.239, green: 0.161, blue: 0.106)
    private let peloBrillo = Color(red: 0.420, green: 0.298, blue: 0.204)
    private let top = Color(red: 0.118, green: 0.588, blue: 0.561)
    private let topSombra = Color(red: 0.082, green: 0.431, blue: 0.412)
    private let pantalon = Color(red: 0.094, green: 0.149, blue: 0.310)
    private let zapatilla = Color(red: 1.0, green: 0.478, blue: 0.239)
    private let ojos = Color(red: 0.420, green: 0.612, blue: 0.769)

    // MARK: - Geometría

    private func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    /// Punto a cierta distancia de otro. El ángulo se mide desde la vertical hacia abajo;
    /// positivo es hacia delante (derecha).
    private func desde(_ origen: CGPoint, _ angulo: Double, _ largo: CGFloat) -> CGPoint {
        CGPoint(x: origen.x + largo * CGFloat(sin(angulo)), y: origen.y + largo * CGFloat(cos(angulo)))
    }

    private func segmento(_ a: CGPoint, _ b: CGPoint) -> Path {
        var camino = Path()
        camino.move(to: a)
        camino.addLine(to: b)
        return camino
    }

    private func poligono(_ puntos: [CGPoint]) -> Path {
        var camino = Path()
        guard let primero = puntos.first else { return camino }
        camino.move(to: primero)
        for punto in puntos.dropFirst() { camino.addLine(to: punto) }
        camino.closeSubpath()
        return camino
    }

    private func elipse(_ centro: CGPoint, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: centro.x - rx, y: centro.y - ry, width: rx * 2, height: ry * 2))
    }

    /// Tramo grueso con contorno oscuro, como una línea de dibujo.
    private func tubo(_ c: inout GraphicsContext, _ a: CGPoint, _ b: CGPoint, _ ancho: CGFloat, _ color: Color) {
        let redondo = StrokeStyle(lineWidth: ancho + 3, lineCap: .round)
        c.stroke(segmento(a, b), with: .color(trazo), style: redondo)
        c.stroke(segmento(a, b), with: .color(color), style: StrokeStyle(lineWidth: ancho, lineCap: .round))
    }

    // MARK: - Fondo

    private func dibujarFondo(_ c: inout GraphicsContext, t: Double) {
        c.fill(Path(CGRect(x: 0, y: 0, width: 350, height: 400)), with: .color(Color(red: 0.063, green: 0.110, blue: 0.290)))
        c.fill(poligono([pt(0, 0), pt(350, 0), pt(350, 150), pt(0, 62)]), with: .color(Color(red: 0.392, green: 0.573, blue: 0.839)))
        c.fill(poligono([pt(0, 62), pt(350, 150), pt(350, 262), pt(0, 158)]), with: .color(Color(red: 0.165, green: 0.322, blue: 0.639)))
        c.fill(poligono([pt(0, 158), pt(350, 262), pt(350, 330), pt(0, 246)]), with: .color(Color(red: 0.094, green: 0.188, blue: 0.439)))

        // Luces desenfocadas que pasan hacia atrás.
        let luces: [(CGFloat, CGFloat, CGFloat, Double, Int)] = [
            (30, 250, 14, 0.0, 0), (90, 300, 9, 1.1, 1), (150, 210, 11, 2.3, 2), (210, 330, 16, 0.6, 0),
            (260, 240, 8, 1.8, 3), (310, 300, 12, 2.9, 1), (60, 180, 7, 3.5, 3), (190, 270, 6, 0.9, 2),
            (330, 200, 10, 2.0, 0), (120, 350, 13, 1.5, 3)
        ]
        let tonos: [Color] = [
            Color(red: 1.0, green: 0.84, blue: 0.42), Color(red: 1.0, green: 0.62, blue: 0.72),
            Color(red: 0.72, green: 0.86, blue: 1.0), .white
        ]
        let velocidad = 26.0 + 30.0 * min(max(energia, 0), 100) / 100
        for (x0, y, radio, fase, tono) in luces {
            let recorrido = (Double(x0) - t * velocidad).truncatingRemainder(dividingBy: 400)
            let x = CGFloat(recorrido < 0 ? recorrido + 400 : recorrido) - 25
            let brillo = 0.22 + 0.16 * sin(t * 1.3 + fase)
            c.fill(elipse(pt(x, y), radio, radio), with: .color(tonos[tono].opacity(brillo)))
        }

        // Líneas de velocidad.
        for i in 0..<5 {
            let fase = (t * 1.4 + Double(i) * 0.23).truncatingRemainder(dividingBy: 1)
            let y = CGFloat(120 + i * 44)
            let x = CGFloat(120 - fase * 150)
            c.stroke(segmento(pt(x, y), pt(x - 34, y)), with: .color(.white.opacity(0.35 * (1 - fase))),
                     style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }

        c.fill(elipse(pt(178, 376), 58, 8), with: .color(.black.opacity(0.28)))
    }

    // MARK: - Personaje

    private func dibujarCorredor(_ c: inout GraphicsContext, t: Double) {
        let vigor = min(max(energia, 0), 100) / 100
        let fase = t * (5.2 + 3.2 * vigor)
        let bote = -abs(CGFloat(sin(fase))) * 6
        let cadera = pt(170, 240 + bote)
        let hombro = pt(cadera.x + 13, cadera.y - 84)

        // Pierna: muslo y espinilla. La rodilla se dobla más cuando la pierna va atrás.
        func pierna(_ desfase: Double, _ color: Color, vendada: Bool) {
            let muslo = 0.78 * sin(fase + desfase)
            let flexion = 0.30 + 1.05 * (0.5 + 0.5 * sin(fase + desfase + 2.3))
            let espinilla = muslo - flexion
            let rodilla = desde(cadera, muslo, 50)
            let tobillo = desde(rodilla, espinilla, 52)
            tubo(&c, cadera, rodilla, 19, color)
            tubo(&c, rodilla, tobillo, 15, color)
            tubo(&c, cadera, desde(cadera, muslo, 22), 22, pantalon)
            if vendada {
                c.stroke(segmento(desde(rodilla, espinilla, 38), desde(rodilla, espinilla, 50)),
                         with: .color(Color(red: 0.95, green: 0.96, blue: 0.98)), style: StrokeStyle(lineWidth: 16, lineCap: .butt))
            }
            let punta = desde(tobillo, espinilla + 1.45, 17)
            tubo(&c, tobillo, punta, 11, zapatilla)
            c.stroke(segmento(tobillo, desde(tobillo, espinilla + 1.45, 8)), with: .color(.white),
                     style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }

        // Brazo: codo siempre doblado, balancea al contrario que la pierna de su lado.
        func brazo(_ desfase: Double, _ color: Color) {
            let alto = -0.85 * sin(fase + desfase)
            let origen = pt(hombro.x - 2, hombro.y + 8)
            let codo = desde(origen, alto, 34)
            let mano = desde(codo, alto + 1.5, 30)
            tubo(&c, origen, codo, 13, color)
            tubo(&c, codo, mano, 11, color)
            c.fill(elipse(mano, 7.5, 7.5), with: .color(trazo))
            c.fill(elipse(mano, 6, 6), with: .color(color))
        }

        // Detrás: brazo y pierna del lado lejano, en tono más oscuro.
        brazo(0, pielSombra)
        pierna(.pi, pielSombra, vendada: false)

        // Tronco.
        tubo(&c, cadera, hombro, 40, top)
        let medio = pt((cadera.x + hombro.x) / 2, (cadera.y + hombro.y) / 2)
        c.stroke(segmento(pt(medio.x - 2, medio.y + 14), pt(medio.x - 1, medio.y + 20)), with: .color(topSombra),
                 style: StrokeStyle(lineWidth: 40, lineCap: .butt))
        c.fill(Path(roundedRect: CGRect(x: medio.x - 9, y: medio.y - 16, width: 24, height: 17), cornerRadius: 3), with: .color(.white))
        c.draw(Text("D").font(.system(size: 13, weight: .heavy)).foregroundColor(trazo), at: pt(medio.x + 3, medio.y - 7.5))
        c.fill(elipse(cadera, 18, 13), with: .color(pantalon))

        // Delante: pierna del pie vendado y brazo cercano.
        pierna(0, piel, vendada: true)
        tubo(&c, hombro, pt(hombro.x + 4, hombro.y - 14), 14, piel)
        brazo(.pi, piel)

        dibujarCabeza(&c, t: t, fase: fase, centro: pt(hombro.x + 8, hombro.y - 42), vigor: vigor)
    }

    private func dibujarCabeza(_ c: inout GraphicsContext, t: Double, fase: Double, centro: CGPoint, vigor: Double) {
        let x = centro.x
        let y = centro.y
        let onda = CGFloat(sin(fase * 0.5)) * 4

        // Melena por detrás, con mechones que ondean hacia atrás.
        c.fill(elipse(pt(x - 5, y - 3), 31, 31), with: .color(trazo))
        c.fill(elipse(pt(x - 5, y - 3), 29.5, 29.5), with: .color(pelo))
        c.fill(poligono([pt(x - 24, y - 12), pt(x - 46 + onda, y + 6), pt(x - 36, y + 8), pt(x - 50 + onda, y + 24),
                         pt(x - 34, y + 22), pt(x - 40 + onda * 0.6, y + 38), pt(x - 20, y + 26), pt(x - 14, y + 4)]),
               with: .color(pelo))

        // Cara.
        c.fill(elipse(centro, 26.5, 28.5), with: .color(trazo))
        c.fill(elipse(centro, 25, 27), with: .color(piel))

        // Barba y bigote.
        c.fill(poligono([pt(x - 24, y + 4), pt(x - 21, y + 17), pt(x - 11, y + 26), pt(x + 3, y + 28), pt(x + 15, y + 24),
                         pt(x + 23, y + 12), pt(x + 24, y + 3), pt(x + 18, y + 11), pt(x + 12, y + 13), pt(x + 4, y + 11),
                         pt(x - 6, y + 13), pt(x - 15, y + 10)]),
               with: .color(pelo))
        c.fill(poligono([pt(x - 5, y + 12), pt(x + 5, y + 10), pt(x + 15, y + 12), pt(x + 13, y + 15), pt(x + 5, y + 14), pt(x - 3, y + 15)]),
               with: .color(pelo))
        c.fill(elipse(pt(x + 6, y + 19), 4.2, 3), with: .color(Color(red: 0.42, green: 0.16, blue: 0.16)))

        // Ojos grandes de anime, con parpadeo.
        let abiertos = t.truncatingRemainder(dividingBy: 3.6) > 0.15
        for (dx, ancho) in [(CGFloat(-5), CGFloat(6.5)), (CGFloat(13), CGFloat(5.5))] {
            let ojo = pt(x + dx, y - 2)
            if abiertos {
                c.fill(elipse(ojo, ancho, 7.5), with: .color(.white))
                c.fill(elipse(pt(ojo.x + 1, ojo.y + 1), ancho * 0.66, 6), with: .color(ojos))
                c.fill(elipse(pt(ojo.x + 1, ojo.y + 1.5), ancho * 0.34, 3.4), with: .color(trazo))
                c.fill(elipse(pt(ojo.x - 1, ojo.y - 2.5), 1.8, 1.8), with: .color(.white))
                c.stroke(segmento(pt(ojo.x - ancho, ojo.y - 6.5), pt(ojo.x + ancho, ojo.y - 6.5)), with: .color(trazo),
                         style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            } else {
                c.stroke(segmento(pt(ojo.x - ancho, ojo.y), pt(ojo.x + ancho, ojo.y)), with: .color(trazo),
                         style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            }
            if let nota = notaSueno, nota < 65 {
                c.stroke(segmento(pt(ojo.x - ancho + 1, ojo.y + 9.5), pt(ojo.x + ancho - 1, ojo.y + 9.5)),
                         with: .color(pielSombra), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            }
        }
        // Cejas decididas y nariz.
        c.stroke(segmento(pt(x - 13, y - 14), pt(x + 1, y - 11.5)), with: .color(pelo), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        c.stroke(segmento(pt(x + 8, y - 11.5), pt(x + 19, y - 14)), with: .color(pelo), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        c.stroke(segmento(pt(x + 6, y + 3), pt(x + 8, y + 6)), with: .color(pielSombra), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))

        // Flequillo ondulado con raya y mechón lateral.
        c.fill(poligono([pt(x - 26, y - 4), pt(x - 24, y - 22), pt(x - 8, y - 32), pt(x + 12, y - 31), pt(x + 25, y - 18),
                         pt(x + 27, y - 2), pt(x + 20, y - 13), pt(x + 11, y - 19), pt(x + 4, y - 11), pt(x - 4, y - 19),
                         pt(x - 13, y - 9), pt(x - 19, y - 14)]),
               with: .color(pelo))
        c.fill(poligono([pt(x + 22, y - 14), pt(x + 30, y + 2), pt(x + 27 + onda * 0.3, y + 17), pt(x + 21, y + 8)]), with: .color(pelo))
        c.stroke(segmento(pt(x - 15, y - 24), pt(x - 3, y - 27)), with: .color(peloBrillo), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        c.stroke(segmento(pt(x + 6, y - 26), pt(x + 16, y - 21)), with: .color(peloBrillo), style: StrokeStyle(lineWidth: 2, lineCap: .round))

        // Si vas justo de energía, suda.
        if vigor < 0.5 {
            for i in 0..<2 {
                let caida = (t * 0.9 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
                let gota = pt(x - 30 - CGFloat(i) * 9, y - 10 + CGFloat(caida) * 26)
                c.fill(elipse(gota, 2.2, 3.4), with: .color(Color(red: 0.72, green: 0.88, blue: 1.0).opacity(1 - caida)))
            }
        }
    }
}
