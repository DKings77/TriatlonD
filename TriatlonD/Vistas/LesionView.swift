// LesionView.swift
// ------------------------------------------------------------------
// Parte de lesión: el dolor tras la última carrera (se guarda en el
// móvil) y la escalera de vuelta a correr.
// La app registra; no diagnostica ni sustituye al fisio.
// ------------------------------------------------------------------

import SwiftUI

struct LesionView: View {
    // -1 significa que todavía no se ha registrado ningún valor.
    @AppStorage("dolorUltimaCarrera") private var dolor = -1

    private let niveles = [0, 2, 4, 6, 8, 10]
    private let peldanos: [(texto: String, estado: Int)] = [
        ("Tramos de 3' corriendo + 1' caminando", 2),
        ("Tramos de 4'", 2),
        ("Tramos de 6'", 1),
        ("Tramos de 10'", 0),
        ("20' seguidos: te quitas la venda", 0)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Parte de lesión")
                        .font(.largeTitle.bold())
                    Text("Fascia plantar y tendón de Aquiles")
                        .font(.subheadline)
                        .foregroundStyle(Tema.textoSecundario)
                }

                Tarjeta {
                    Text("¿Cuánto te ha dolido en la última carrera?")
                        .font(.headline)
                    HStack(spacing: 6) {
                        ForEach(niveles, id: \.self) { nivel in
                            Button {
                                dolor = nivel
                            } label: {
                                Text("\(nivel)")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, minHeight: 46)
                                    .background(color(nivel))
                                    .foregroundStyle(Tema.fondo)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Tema.texto, lineWidth: dolor == nivel ? 3 : 0)
                                    )
                            }
                            .accessibilityLabel("Dolor \(nivel) de 10")
                        }
                    }
                    HStack {
                        Text("Nada")
                        Spacer()
                        Text("No puedo apoyar")
                    }
                    .font(.caption)
                    .foregroundStyle(Tema.textoSecundario)
                    Text(lectura)
                        .font(.subheadline)
                }

                Tarjeta {
                    Text("Escalera de vuelta a correr")
                        .font(.headline)
                    ForEach(Array(peldanos.enumerated()), id: \.offset) { _, peldano in
                        HStack(spacing: 10) {
                            Image(systemName: icono(peldano.estado))
                                .foregroundStyle(colorPeldano(peldano.estado))
                            Text(peldano.texto)
                                .font(.subheadline)
                                .foregroundStyle(peldano.estado == 0 ? Tema.textoSecundario : Tema.texto)
                            Spacer()
                            Text(etiqueta(peldano.estado))
                                .font(.caption)
                                .foregroundStyle(colorPeldano(peldano.estado))
                        }
                    }
                    Text("Cada peldaño se abre con dos carreras seguidas con dolor de 0 a 2.")
                        .font(.caption)
                        .foregroundStyle(Tema.textoSecundario)
                }
            }
            .padding(20)
        }
        .background(Tema.fondo)
        .foregroundStyle(Tema.texto)
    }

    private var lectura: String {
        if dolor < 0 { return "Marca un valor después de cada carrera." }
        if dolor <= 2 { return "Bien: esta carrera cuenta para abrir el siguiente peldaño." }
        if dolor < 4 { return "Aceptable. Repite este peldaño antes de subir." }
        return "Con 4 o más paras: cuenta como misión cumplida y la siguiente carrera pasa a bici o piscina."
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

    private func etiqueta(_ estado: Int) -> String {
        switch estado {
        case 2: return "Hecho"
        case 1: return "Siguiente"
        default: return "Bloqueado"
        }
    }
}
