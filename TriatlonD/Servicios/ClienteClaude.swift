// ClienteClaude.swift
// ------------------------------------------------------------------
// Pide a Claude la propuesta de una semana de entrenos. Solo se llama
// cuando pulsas el botón: cada propuesta gasta un poco de tu monedero
// de la API. La clave vive en el llavero del iPhone.
// ------------------------------------------------------------------

import Foundation

struct PropuestaSemana {
    var explicacion: String
    var sesiones: [SesionPlan]
}

struct ErrorClaude: LocalizedError {
    var mensaje: String
    var errorDescription: String? { mensaje }
}

final class ClienteClaude {
    static let modelo = "claude-sonnet-5-5"

    func proponer(lunes: Date, contexto: String, exigencia: String, indicaciones: String) async throws -> PropuestaSemana {
        guard let clave = Llavero.leer("claudeClave"), !clave.isEmpty else {
            throw ErrorClaude(mensaje: "Falta la clave de la API de Claude en Ajustes.")
        }
        var peticion = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        peticion.httpMethod = "POST"
        peticion.timeoutInterval = 120
        peticion.setValue(clave, forHTTPHeaderField: "x-api-key")
        peticion.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        peticion.setValue("application/json", forHTTPHeaderField: "content-type")

        var mensaje = contexto
        switch exigencia {
        case "Suave": mensaje += "\n\nEXIGENCIA PEDIDA: semana suave, de descarga: menos horas y sin intensidad."
        case "Normal": mensaje += "\n\nEXIGENCIA PEDIDA: semana normal, como sus semanas habituales."
        case "Fuerte": mensaje += "\n\nEXIGENCIA PEDIDA: semana de carga: la parte alta de los rangos de horas y un día de bici con intensidad. La carrera no cambia: sigue las reglas de la lesión."
        default: break
        }
        let extra = indicaciones.trimmingCharacters(in: .whitespacesAndNewlines)
        if !extra.isEmpty {
            mensaje += "\n\nINDICACIONES DE DAVID PARA ESTA SEMANA (mandan sobre lo demás):\n" + extra
        }
        let cuerpo: [String: Any] = [
            "model": ClienteClaude.modelo,
            "max_tokens": 4000,
            "system": ContextoIA.reglas,
            "messages": [["role": "user", "content": mensaje]]
        ]
        peticion.httpBody = try JSONSerialization.data(withJSONObject: cuerpo)

        let (datos, respuesta) = try await URLSession.shared.data(for: peticion)
        let codigo = (respuesta as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: datos) as? [String: Any]) ?? [:]
        guard (200...299).contains(codigo) else {
            let detalle = (json["error"] as? [String: Any])?["message"] as? String
            switch codigo {
            case 401: throw ErrorClaude(mensaje: "La API de Claude ha rechazado la clave.")
            case 429: throw ErrorClaude(mensaje: "La API de Claude está saturada o sin saldo. Prueba en un rato.")
            default: throw ErrorClaude(mensaje: "La API de Claude respondió \(codigo). \(detalle ?? "")")
            }
        }
        let bloques = json["content"] as? [[String: Any]] ?? []
        let texto = bloques.compactMap { $0["text"] as? String }.joined()
        guard let inicio = texto.firstIndex(of: "{"), let fin = texto.lastIndex(of: "}"),
              let objeto = try? JSONSerialization.jsonObject(with: Data(texto[inicio...fin].utf8)) as? [String: Any],
              let lista = objeto["sesiones"] as? [[String: Any]] else {
            throw ErrorClaude(mensaje: "La propuesta no ha llegado en el formato esperado. Vuelve a pedirla.")
        }

        let semana = Calendario.semanaTemporada(lunes)
        var sesiones: [SesionPlan] = []
        for elemento in lista {
            guard let fecha = elemento["fecha"] as? String, let dia = Calendario.fecha(fecha),
                  Calendario.semanaTemporada(dia) == semana,
                  let tipo = elemento["tipo"] as? String,
                  ["Ride", "Run", "Swim", "WeightTraining"].contains(tipo),
                  let nombre = elemento["nombre"] as? String,
                  let pasos = elemento["pasos"] as? String else { continue }
            let esTest = nombre.localizedCaseInsensitiveContains("test")
            sesiones.append(SesionPlan(
                id: "IA-\(UUID().uuidString.prefix(8))", fecha: fecha, tipo: tipo,
                interior: tipo != "Run", nombre: nombre, pasos: pasos,
                seEnvia: tipo != "Swim" && !esTest, xp: 100))
        }
        guard !sesiones.isEmpty else {
            throw ErrorClaude(mensaje: "La propuesta ha llegado vacía. Vuelve a pedirla.")
        }
        return PropuestaSemana(explicacion: objeto["explicacion"] as? String ?? "", sesiones: sesiones)
    }
}

/// Lo que Claude necesita saber: las reglas fijas y el estado de hoy.
enum ContextoIA {
    static let reglas = """
    Eres el entrenador de David, triatleta aficionado de Mataró que vuelve tras una lesión \
    (fascitis plantar y tendinitis del tendón de Aquiles). Objetivo: recuperar base aeróbica en bici \
    y natación, volver a correr sin dolor y bajar de peso. La constancia pesa más que el volumen.

    DISPONIBILIDAD (de 6:00 a 7:45 entre semana):
    - Lunes: fuerza 50' (1/2) y después carrera muy corta (2/2).
    - Martes: bici en rodillo.
    - Miércoles y viernes: fuerza 35' (1/2) y piscina (2/2).
    - Jueves: bici en rodillo.
    - Sábado: bici, o bici y carrera. La carrera puede pasar al domingo.
    - Domingo: libre o lo que se haya movido del sábado.

    CARRERA: nada de series ni volumen alto. Solo tramos de correr en Z2 con 1' caminando, \
    progresando poco a poco (escalera: tramos de 3', 4', 6', 10', 20' seguidos). Máximo dos carreras \
    por semana. Si el dolor de la última carrera fue 4 o más sobre 10, no subas el escalón o quita una carrera.

    CARGA: por defecto la semana tiene que parecerse en horas a sus semanas normales recientes \
    (mira HORAS POR SEMANA) y progresar un poco: entre 6 y 8 horas con las siete franjas ocupadas. \
    Bicis de entre semana de 60 a 75 minutos, la del sábado de 90 a 120, piscinas de 1700 a 2200 m. \
    Si la relación carga/fondo está por debajo de 0,8 hay margen: sube, no bajes. Una sola noche mala \
    o una semana floja por enfermedad ya pasada no justifican una semana suave. Aligera solo si hay \
    varias señales juntas (variabilidad del pulso cayendo varios días, sueño malo varias noches, \
    relación por encima de 1,3) y dilo. Cada cuatro semanas, una de descarga. En bici puede haber \
    un día con bloques de tempo o sweet spot (76-92 % del FTP); el resto, Z2 (65-75 %).

    REFERENCIAS: FTP 200 W. Zonas de pulso: Z1 108-135, Z2 136-150, Z3 151-159, Z4 160-170, Z5 171-187 ppm.

    NOMBRE DE CADA SESIÓN, obligatorio: "S<semana> D<día 1-7>: <letra><orden> <duración> <zona> [1/2 o 2/2] | <estructura>".
    - Letra: B bici, C carrera, N natación, F fuerza. El orden cuenta las sesiones de ese deporte en la semana (B1, B2, B3).
    - "1/2" y "2/2" solo cuando hay dos sesiones el mismo día; la fuerza va siempre primero.
    - Tras " | " va la estructura legible. La fuerza no lleva estructura.
    Ejemplos:
    S11 D1: F1 50' 1/2
    S11 D1: C1 35' Z2 2/2 | 5' cal + 5 x (4' Z2 + 1' caminar) + 5' enf
    S11 D2: B1 60' Z2 140W | 10' cal + 40' Z2 140W + 10' enf
    S11 D3: N1 1700m Z2 2/2 | 300 suave + 8 x 50 técnica + 3 x 300 aeróbico + 100 suave

    PASOS, en el formato exacto de intervals.icu (una línea por paso, minutos enteros):
    - Bici, en % del FTP: "- 10m 60%".
    - Carrera, por zona de pulso: "- 4m Z2 HR". Caminar es "- 1m Z1 HR".
    - Repeticiones: una línea "5x", debajo sus pasos, y una línea en blanco antes y después del bloque.
    - Se admiten líneas de título sin guion: "Calentamiento", "Enfriamiento".
    - Fuerza: una sola línea, "- 50m".
    - Natación: texto libre en metros, una línea por bloque (no se envía al reloj desde la app).
    Ejemplo de carrera:
    Calentamiento
    - 5m Z1 HR

    5x
    - 4m Z2 HR
    - 1m Z1 HR

    Enfriamiento
    - 5m Z1 HR

    La duración y los vatios del nombre tienen que coincidir con los pasos.

    RESPUESTA: solo un objeto JSON, sin texto alrededor ni bloques de código:
    {"explicacion": "tres o cuatro frases en español, claras y directas: qué has visto en los datos y qué cambia esta semana",
     "sesiones": [{"fecha": "aaaa-mm-dd", "tipo": "Ride|Run|Swim|WeightTraining", "nombre": "...", "pasos": "..."}]}
    No inventes datos que no estén en el contexto.
    """

    static func texto(lunes: Date, estado: EstadoDia, esReal: Bool, historico: Historico?,
                      plan: [SesionPlan], dolor: Int) -> String {
        var lineas: [String] = []
        let hoy = Calendario.texto(Date())
        let domingo = lunes.addingTimeInterval(6 * 86400)
        lineas.append("Hoy es \(hoy). Propón la semana S\(Calendario.semanaTemporada(lunes)), del lunes \(Calendario.texto(lunes)) al domingo \(Calendario.texto(domingo)).")

        lineas.append("\nESTADO DE HOY" + (esReal ? " (Garmin)" : " (datos de ejemplo, no reales: sé prudente)") + ":")
        func dato(_ nombre: String, _ valor: Double?, _ unidad: String = "") {
            if let valor { lineas.append("- \(nombre): \(String(format: "%.1f", valor))\(unidad)") }
        }
        dato("Carga de los últimos 7 días", estado.carga.aguda)
        dato("Fondo (media semanal de 28 días)", estado.carga.cronica)
        dato("Relación carga/fondo", estado.carga.relacion)
        dato("Variabilidad del pulso anoche", estado.vfc.anocheMs, " ms")
        dato("Variabilidad media semanal", estado.vfc.mediaSemanalMs, " ms")
        dato("Sueño de anoche", estado.sueno.horas, " h")
        dato("Nota de sueño", estado.sueno.puntuacion)
        dato("Peso", estado.pesoKg, " kg")
        if dolor >= 0 {
            lineas.append("- Dolor en la última carrera: \(dolor) sobre 10")
        } else {
            lineas.append("- Dolor en la última carrera: sin registrar")
        }

        if let h = historico {
            if let forma = h.formaYRampa {
                lineas.append("- Forma (fondo menos semana): \(Int(forma.forma)). Rampa del fondo en 7 días: \(Int(forma.rampa))")
            }
            dato("Pulso en reposo", h.pulsoReposo, " ppm")
            dato("Pulso en reposo, media de 7 días", h.pulsoReposo7, " ppm")
            dato("FTP estimado por sus mejores 20'", h.ftpEstimado, " W")
            let noches = h.sueno.suffix(7).map { String(format: "%.1f", $0.horas) }.joined(separator: ", ")
            if !noches.isEmpty { lineas.append("- Horas de sueño de las últimas noches: \(noches)") }
            let vfc = h.vfc.suffix(7).map { String(Int($0.anoche)) }.joined(separator: ", ")
            if !vfc.isEmpty { lineas.append("- Variabilidad de las últimas noches (ms): \(vfc)") }

            let semanas = Dictionary(grouping: h.volumen, by: \.inicio).sorted { $0.key < $1.key }
            if !semanas.isEmpty {
                lineas.append("\nHORAS POR SEMANA (la última está sin terminar):")
                for (inicio, partes) in semanas {
                    let total = partes.map(\.horas).reduce(0, +)
                    let detalle = partes.map { "\($0.deporte) \(String(format: "%.1f", $0.horas))" }.joined(separator: ", ")
                    lineas.append("- Semana del \(Calendario.texto(inicio)): \(String(format: "%.1f", total)) h (\(detalle))")
                }
            }

            let limite = Calendario.texto(Date().addingTimeInterval(-21 * 86400))
            let recientes = h.sesiones.filter { $0.dia >= limite }.sorted { $0.dia < $1.dia }
            if !recientes.isEmpty {
                lineas.append("\nENTRENOS HECHOS EN LAS ÚLTIMAS TRES SEMANAS:")
                for s in recientes {
                    var fila = "- \(s.dia) \(s.deporte ?? "Otro"): \(s.nombre), \(Int(s.minutos))'"
                    if let metros = s.metros, metros > 0 { fila += ", \(String(format: "%.1f", metros / 1000)) km" }
                    if let pulso = s.pulso { fila += ", \(Int(pulso)) ppm" }
                    if let potencia = s.potencia { fila += ", \(Int(potencia)) W" }
                    lineas.append(fila)
                }
            }

            let cruce = Analisis.cumplimiento(plan: plan, hechas: h.sesiones, hoy: hoy)
            let pasadas = cruce.filter { $0.estado != .pendiente }
            if !pasadas.isEmpty {
                lineas.append("\nPLAN FRENTE A HECHO:")
                for c in pasadas {
                    let estado: String
                    switch c.estado {
                    case .hecha: estado = "hecha"
                    case .aMedias: estado = "a medias"
                    case .saltada: estado = "no hecha"
                    case .pendiente: estado = "pendiente"
                    }
                    lineas.append("- \(c.sesion.fecha) \(c.sesion.titulo): \(estado)")
                }
            }
        }

        let ordenado = plan.sorted { ($0.fecha, $0.id) < ($1.fecha, $1.id) }
        let desde = Calendario.texto(lunes.addingTimeInterval(-14 * 86400))
        let previas = ordenado.filter { $0.fecha >= desde && $0.fecha < Calendario.texto(lunes) }
        if !previas.isEmpty {
            lineas.append("\nPLAN DE LAS DOS SEMANAS ANTERIORES (para dar continuidad a números y progresión):")
            for s in previas {
                lineas.append("- \(s.fecha) \(s.nombre)")
                lineas.append("  pasos: " + s.pasos.replacingOccurrences(of: "\n", with: " / "))
            }
        }
        let actuales = ordenado.filter {
            Calendario.fecha($0.fecha).map(Calendario.semanaTemporada) == Calendario.semanaTemporada(lunes)
        }
        if !actuales.isEmpty {
            lineas.append("\nLO QUE YA HAY PLANIFICADO ESA SEMANA (tu propuesta lo sustituye; respétalo si sigue teniendo sentido):")
            for s in actuales { lineas.append("- \(s.fecha) \(s.nombre)") }
        }
        return lineas.joined(separator: "\n")
    }
}
