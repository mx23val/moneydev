import Foundation

// MARK: - Modelos Codable de MoneyBot AI

public enum UserIntent: String, Codable, Sendable {
    case REGISTRAR_TRANSACCION
    case COMPLETAR_DATO_FALTANTE
    case CONSULTAR_BALANCE
    case CONSULTA_ANALITICA
    case CONSULTA_GASTOS_FIJOS
    case SOLICITAR_CONSEJO
    case CONVERSACIONAL
    case TRANSFERIR_DINERO
    case CONFIRMAR_TRANSFERENCIA
    case DESCONOCIDA
}

public enum AITransactionType: String, Codable, Sendable {
    case GASTO
    case INGRESO
    
    public var toAppType: TransactionType {
        switch self {
        case .GASTO: return .expense
        case .INGRESO: return .income
        }
    }
}

public struct ExtractedTransaction: Codable, Sendable, Identifiable {
    public typealias TransactionType = AITransactionType
    
    public var id: String?
    public var titulo: String
    public var concepto: String
    public var categoria: String
    public var monto: Double
    public var tipo: AITransactionType
    public var fecha: String
    public var hora: String?
    public var faltaHora: Bool
    public var billetera: String?
    
    public var categoriaSugerida: String {
        return categoria
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case titulo
        case concepto
        case descripcion
        case detalle
        case nombre
        case categoria
        case categoriaSugerida
        case monto
        case tipo
        case fecha
        case hora
        case faltaHora
        case billetera
    }
    
    public init(
        id: String? = UUID().uuidString,
        titulo: String? = nil,
        concepto: String,
        categoria: String? = nil,
        categoriaSugerida: String? = nil,
        monto: Double,
        tipo: AITransactionType,
        fecha: String = "",
        hora: String? = nil,
        faltaHora: Bool = false,
        billetera: String? = nil
    ) {
        let rawCat = categoria ?? categoriaSugerida ?? (tipo == .INGRESO ? "Otros Ingresos" : "Otros")
        let finalCat = CategoryHelper.resolveCategory(nameOrKeyword: rawCat, type: tipo.toAppType)
        self.id = id ?? UUID().uuidString
        self.titulo = titulo ?? concepto
        self.concepto = concepto
        self.categoria = finalCat
        self.monto = monto
        self.tipo = tipo
        self.fecha = fecha
        self.hora = hora
        self.faltaHora = faltaHora
        self.billetera = billetera
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        
        if let rawTipo = try? container.decode(String.self, forKey: .tipo) {
            let upper = rawTipo.uppercased()
            if upper.contains("INGRESO") || upper.contains("INCOME") {
                self.tipo = .INGRESO
            } else {
                self.tipo = .GASTO
            }
        } else if let directType = try? container.decode(AITransactionType.self, forKey: .tipo) {
            self.tipo = directType
        } else {
            self.tipo = .GASTO
        }
        
        if let directDouble = try? container.decode(Double.self, forKey: .monto) {
            self.monto = directDouble
        } else if let directInt = try? container.decode(Int.self, forKey: .monto) {
            self.monto = Double(directInt)
        } else if let strAmount = try? container.decode(String.self, forKey: .monto) {
            let cleanStr = strAmount.replacingOccurrences(of: ",", with: ".")
                .replacingOccurrences(of: "S/", with: "")
                .replacingOccurrences(of: "$", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let parsed = Double(cleanStr) {
                self.monto = parsed
            } else {
                let numPattern = #"(\d+(?:\.\d+)?)"#
                if let r = try? NSRegularExpression(pattern: numPattern),
                   let m = r.firstMatch(in: cleanStr, range: NSRange(location: 0, length: cleanStr.utf16.count)) {
                    let ns = cleanStr as NSString
                    self.monto = Double(ns.substring(with: m.range(at: 1))) ?? 0.0
                } else {
                    self.monto = 0.0
                }
            }
        } else {
            self.monto = 0.0
        }
        
        let cDecoded = (try? container.decode(String.self, forKey: .categoria))
            ?? (try? container.decode(String.self, forKey: .categoriaSugerida))
            ?? (self.tipo == .INGRESO ? "Otros Ingresos" : "Otros")
        self.categoria = CategoryHelper.resolveCategory(nameOrKeyword: cDecoded, type: self.tipo.toAppType)
        
        let rawConcepto = try? container.decode(String.self, forKey: .concepto)
        let rawTitulo = try? container.decode(String.self, forKey: .titulo)
        let rawDesc = try? container.decode(String.self, forKey: .descripcion)
        let rawDetalle = try? container.decode(String.self, forKey: .detalle)
        let rawNombre = try? container.decode(String.self, forKey: .nombre)
        
        let resolvedTitulo = rawTitulo ?? rawNombre ?? rawDesc ?? rawConcepto ?? rawDetalle ?? "Movimiento"
        let resolvedConcepto = rawConcepto ?? rawDesc ?? rawDetalle ?? rawTitulo ?? rawNombre ?? "Movimiento"
        
        self.titulo = resolvedTitulo
        self.concepto = resolvedConcepto
        self.fecha = (try? container.decode(String.self, forKey: .fecha)) ?? ""
        self.hora = try? container.decodeIfPresent(String.self, forKey: .hora)
        self.faltaHora = (try? container.decode(Bool.self, forKey: .faltaHora)) ?? false
        self.billetera = try? container.decodeIfPresent(String.self, forKey: .billetera)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(titulo, forKey: .titulo)
        try container.encode(concepto, forKey: .concepto)
        try container.encode(categoria, forKey: .categoria)
        try container.encode(monto, forKey: .monto)
        try container.encode(tipo, forKey: .tipo)
        try container.encode(fecha, forKey: .fecha)
        try container.encodeIfPresent(hora, forKey: .hora)
        try container.encode(faltaHora, forKey: .faltaHora)
        try container.encodeIfPresent(billetera, forKey: .billetera)
    }
}

public struct ExtractedTransfer: Codable, Sendable {
    public var origen: String?
    public var destino: String?
    public var monto: Double?
    public var confirmado: Bool?
    
    enum CodingKeys: String, CodingKey {
        case origen, destino, monto, confirmado, billeteraOrigen, billeteraDestino
    }
    
    public init(origen: String? = nil, destino: String? = nil, monto: Double? = nil, confirmado: Bool? = nil) {
        self.origen = origen
        self.destino = destino
        self.monto = monto
        self.confirmado = confirmado
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.origen = (try? container.decodeIfPresent(String.self, forKey: .origen)) ?? (try? container.decodeIfPresent(String.self, forKey: .billeteraOrigen))
        self.destino = (try? container.decodeIfPresent(String.self, forKey: .destino)) ?? (try? container.decodeIfPresent(String.self, forKey: .billeteraDestino))
        self.confirmado = try? container.decodeIfPresent(Bool.self, forKey: .confirmado)
        if let d = try? container.decodeIfPresent(Double.self, forKey: .monto) {
            self.monto = d
        } else if let s = try? container.decodeIfPresent(String.self, forKey: .monto), let parsed = Double(s) {
            self.monto = parsed
        } else {
            self.monto = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(origen, forKey: .origen)
        try container.encodeIfPresent(destino, forKey: .destino)
        try container.encodeIfPresent(monto, forKey: .monto)
        try container.encodeIfPresent(confirmado, forKey: .confirmado)
    }
}

public struct MoneyBotAIResponse: Codable, Sendable {
    public let intencion: UserIntent
    public var transacciones: [ExtractedTransaction]
    public let razonamiento: String
    public let esperaRespuestaUsuario: Bool
    public let parametroPendiente: String?
    public var transaccionesEnEspera: [ExtractedTransaction]
    public let transaccionEnEspera: ExtractedTransaction?
    public let hora: String?
    public let fecha: String?
    public let transferencia: ExtractedTransfer?
    
    enum CodingKeys: String, CodingKey {
        case intencion
        case transacciones
        case transaccion
        case movimientos
        case movimiento
        case razonamiento
        case respuesta
        case mensaje
        case answer
        case text
        case response
        case content
        case reply
        case esperaRespuestaUsuario
        case parametroPendiente
        case transaccionesEnEspera
        case transaccionEnEspera
        case movimientosEnEspera
        case hora
        case fecha
        case transferencia
        case datosTransferencia
    }
    
    public init(
        intencion: UserIntent,
        transacciones: [ExtractedTransaction] = [],
        razonamiento: String = "",
        esperaRespuestaUsuario: Bool = false,
        parametroPendiente: String? = nil,
        transaccionesEnEspera: [ExtractedTransaction] = [],
        transaccionEnEspera: ExtractedTransaction? = nil,
        hora: String? = nil,
        fecha: String? = nil,
        transferencia: ExtractedTransfer? = nil
    ) {
        self.intencion = intencion
        self.transacciones = transacciones
        self.razonamiento = razonamiento
        self.esperaRespuestaUsuario = esperaRespuestaUsuario
        self.parametroPendiente = parametroPendiente
        var enEspera = transaccionesEnEspera
        if enEspera.isEmpty, let single = transaccionEnEspera {
            enEspera = [single]
        }
        self.transaccionesEnEspera = enEspera
        self.transaccionEnEspera = transaccionEnEspera ?? enEspera.first
        self.hora = hora
        self.fecha = fecha
        self.transferencia = transferencia
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let rawInt = try? container.decode(String.self, forKey: .intencion) {
            let upper = rawInt.uppercased()
            if upper.contains("COMPLETAR") || upper.contains("FALTANTE") {
                self.intencion = .COMPLETAR_DATO_FALTANTE
            } else if upper.contains("CONFIRMAR_TRANSFERENCIA") {
                self.intencion = .CONFIRMAR_TRANSFERENCIA
            } else if upper.contains("TRANSFERIR") || upper.contains("TRANSFERENCIA") {
                self.intencion = .TRANSFERIR_DINERO
            } else if upper.contains("REGISTRAR") || upper.contains("TRANSACCION") {
                self.intencion = .REGISTRAR_TRANSACCION
            } else if upper.contains("FIJO") {
                self.intencion = .CONSULTA_GASTOS_FIJOS
            } else if upper.contains("ESTADISTICA") || upper.contains("ANALITICA") || upper.contains("RESUMEN") {
                self.intencion = .CONSULTA_ANALITICA
            } else if upper.contains("BALANCE") || upper.contains("SALDO") {
                self.intencion = .CONSULTAR_BALANCE
            } else if upper.contains("CONSEJO") {
                self.intencion = .SOLICITAR_CONSEJO
            } else if upper.contains("CONVERSACION") || upper.contains("SALUDO") || upper.contains("GRACIAS") ||
                      upper.contains("GENERAL") || upper.contains("PREGUNTA") || upper.contains("CONSULTA") ||
                      upper.contains("CULTURA") || upper.contains("INFO") || upper.contains("AYUDA") ||
                      upper.contains("CHAT") || upper.contains("RESPUESTA") {
                self.intencion = .CONVERSACIONAL
            } else {
                self.intencion = .CONVERSACIONAL
            }
        } else if let intent = try? container.decode(UserIntent.self, forKey: .intencion) {
            self.intencion = intent
        } else {
            self.intencion = .CONVERSACIONAL
        }
        
        self.transferencia = (try? container.decodeIfPresent(ExtractedTransfer.self, forKey: .transferencia))
            ?? (try? container.decodeIfPresent(ExtractedTransfer.self, forKey: .datosTransferencia))
        
        var parsedTxs: [ExtractedTransaction] = []
        if let list = try? container.decode([ExtractedTransaction].self, forKey: .transacciones) {
            parsedTxs = list
        } else if let single = try? container.decode(ExtractedTransaction.self, forKey: .transacciones) {
            parsedTxs = [single]
        } else if let list = try? container.decode([ExtractedTransaction].self, forKey: .movimientos) {
            parsedTxs = list
        } else if let single = try? container.decode(ExtractedTransaction.self, forKey: .transaccion) {
            parsedTxs = [single]
        } else if let single = try? container.decode(ExtractedTransaction.self, forKey: .movimiento) {
            parsedTxs = [single]
        }
        self.transacciones = parsedTxs
        
        var parsedEnEspera: [ExtractedTransaction] = []
        if let list = try? container.decode([ExtractedTransaction].self, forKey: .transaccionesEnEspera) {
            parsedEnEspera = list
        } else if let list = try? container.decode([ExtractedTransaction].self, forKey: .transaccionEnEspera) {
            parsedEnEspera = list
        } else if let list = try? container.decode([ExtractedTransaction].self, forKey: .movimientosEnEspera) {
            parsedEnEspera = list
        } else if let single = try? container.decode(ExtractedTransaction.self, forKey: .transaccionEnEspera) {
            parsedEnEspera = [single]
        } else if let single = try? container.decode(ExtractedTransaction.self, forKey: .transaccionesEnEspera) {
            parsedEnEspera = [single]
        }
        self.transaccionesEnEspera = parsedEnEspera
        self.transaccionEnEspera = parsedEnEspera.first
        
        let rRespuesta = try? container.decodeIfPresent(String.self, forKey: .respuesta)
        let rMensaje = try? container.decodeIfPresent(String.self, forKey: .mensaje)
        let rAnswer = try? container.decodeIfPresent(String.self, forKey: .answer)
        let rText = try? container.decodeIfPresent(String.self, forKey: .text)
        let rResponse = try? container.decodeIfPresent(String.self, forKey: .response)
        let rContent = try? container.decodeIfPresent(String.self, forKey: .content)
        let rReply = try? container.decodeIfPresent(String.self, forKey: .reply)
        let rRazonamiento = try? container.decodeIfPresent(String.self, forKey: .razonamiento)
        
        let candidates = [rRespuesta, rMensaje, rAnswer, rText, rResponse, rContent, rReply, rRazonamiento]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        if let directAnswer = candidates.first(where: { cand in
            let lower = cand.lowercased()
            return !lower.hasPrefix("el usuario ") && !lower.hasPrefix("el usuario está") && !lower.hasPrefix("el usuario hace") && !lower.hasPrefix("pregunta del usuario")
        }) {
            self.razonamiento = directAnswer
        } else {
            self.razonamiento = candidates.first ?? ""
        }
        
        self.esperaRespuestaUsuario = (try? container.decode(Bool.self, forKey: .esperaRespuestaUsuario)) ?? false
        self.parametroPendiente = try? container.decodeIfPresent(String.self, forKey: .parametroPendiente)
        self.hora = try? container.decodeIfPresent(String.self, forKey: .hora)
        self.fecha = try? container.decodeIfPresent(String.self, forKey: .fecha)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(intencion, forKey: .intencion)
        try container.encode(transacciones, forKey: .transacciones)
        try container.encode(razonamiento, forKey: .razonamiento)
        try container.encode(esperaRespuestaUsuario, forKey: .esperaRespuestaUsuario)
        try container.encodeIfPresent(parametroPendiente, forKey: .parametroPendiente)
        try container.encode(transaccionesEnEspera, forKey: .transaccionesEnEspera)
        try container.encodeIfPresent(transaccionEnEspera, forKey: .transaccionEnEspera)
        try container.encodeIfPresent(hora, forKey: .hora)
        try container.encodeIfPresent(fecha, forKey: .fecha)
    }
}

// MARK: - Servicio Aislado de Gemini AI

public final class MoneyBotAIService: Sendable {
    public static let shared = MoneyBotAIService()
    
    public typealias TransactionType = AITransactionType
    
    public var apiKey: String {
        return EnvConfig.geminiApiKey
    }
    
    private let candidateEndpoints: [String] = [
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent",
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-lite-latest:generateContent",
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent"
    ]
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 6.0
        config.timeoutIntervalForResource = 8.0
        return URLSession(configuration: config)
    }()
    
    private init() {}
    
    public static func generateTemporalReference(referenceDate: Date = Date()) -> (fechaHoy: String, horaActual: String, fechaAyer: String, isoHoy: String, isoAyer: String) {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDate) ?? referenceDate.addingTimeInterval(-86400)
        
        let df = DateFormatter()
        df.locale = Locale(identifier: "es_ES")
        df.dateFormat = "d 'de' MMMM"
        
        let tf = DateFormatter()
        tf.locale = Locale(identifier: "es_ES")
        tf.dateFormat = "hh:mm a"
        
        let isoDf = DateFormatter()
        isoDf.locale = Locale(identifier: "en_US_POSIX")
        isoDf.dateFormat = "yyyy-MM-dd"
        
        return (
            fechaHoy: df.string(from: referenceDate),
            horaActual: tf.string(from: referenceDate),
            fechaAyer: df.string(from: yesterday),
            isoHoy: isoDf.string(from: referenceDate),
            isoAyer: isoDf.string(from: yesterday)
        )
    }
    
    private func buildSystemPrompt(
        billeteraActiva: String,
        currentBalance: Double,
        currencySymbol: String,
        wallets: [Wallet],
        fechaHoy: String,
        horaActual: String,
        fechaAyer: String,
        isoHoy: String,
        isoAyer: String,
        transaccionPendienteDesc: String,
        resumenMovimientos: String,
        resumenGastosFijos: String,
        desgloseSaldos: String = "",
        chatHistory: [FinancialChatMessage] = []
    ) -> String {
        let walletsList = wallets.map { $0.name }.joined(separator: ", ")
        let walletsSection = walletsList.isEmpty ? billeteraActiva : walletsList
        let currentBalanceFormatted = String(format: "%.2f", currentBalance)
        let availableExpenses = CategoryHelper.allCategories(for: .expense).map { $0.name }.joined(separator: ", ")
        let availableIncomes = CategoryHelper.allCategories(for: .income).map { $0.name }.joined(separator: ", ")
        
        var historialDialogo = ""
        if !chatHistory.isEmpty {
            let recent = chatHistory.suffix(6)
            historialDialogo = recent.map { m in
                "\(m.isUser ? "Usuario" : "MoneyBot"): \(m.text)"
            }.joined(separator: "\n")
        }
        
        return """
        Eres MoneyBot, el asistente financiero inteligente, conciso, elocuente y amigable de la app MoneyDev.

        CONTEXTO ACTUAL:
        - Billetera seleccionada/activa en el chat: \(billeteraActiva)
        - Saldo actual disponible en \(billeteraActiva): \(currencySymbol) \(currentBalanceFormatted)
        - Total de cuentas activas registradas: \(wallets.count) cuentas ([\(walletsSection)])
        \(desgloseSaldos.isEmpty ? "" : "- Desglose de saldos y actividad por cuenta: [\(desgloseSaldos)]\n")- Moneda: \(currencySymbol)
        - Fecha de hoy: \(fechaHoy) (ISO: \(isoHoy))
        - Hora actual: \(horaActual)
        - Fecha de ayer: \(fechaAyer) (ISO: \(isoAyer))
        - Categorías oficiales para GASTO: [\(availableExpenses)]
        - Categorías oficiales para INGRESO: [\(availableIncomes)]
        - Transacción previa pendiente de completar: \(transaccionPendienteDesc)
        - Historial de diálogo reciente:
        \(historialDialogo.isEmpty ? "Sin diálogo previo." : historialDialogo)
        - Historial de movimientos:
        \(resumenMovimientos.isEmpty ? "Sin movimientos registrados." : resumenMovimientos)
        - Catálogo de gastos fijos:
        \(resumenGastosFijos.isEmpty ? "Sin gastos fijos registrados." : resumenGastosFijos)

        REGLAS ESTRICTAS DE RESPUESTA:

        1. ÁMBITO DE LA BILLETERA SELECCIONADA (\(billeteraActiva)):
           - El usuario tiene seleccionada la billetera "\(billeteraActiva)".
           - Toda pregunta o consulta sobre gastos, ingresos, mayor/menor gasto, totales, estadísticas o saldo (por ejemplo: "dime mi gasto más alto y cuándo fue", "¿cuánto gasté en comida?", "¿cuál fue mi último gasto?", "¿cuánto saldo tengo?"):
             * Debes responderla OBLIGATORIAMENTE Y EN PRIMER LUGAR respecto a los movimientos registrados en "\(billeteraActiva)".
             * Para "dime mi gasto más alto y cuándo fue": Busca el gasto con el monto más alto dentro de la billetera "\(billeteraActiva)", y menciona en "razonamiento" el monto exacto, categoría, concepto, la fecha legible y la hora exacta en que se realizó.
             * Solo debes consolidar o mencionar otras billeteras si el usuario dice explícitamente "en todas mis billeteras" o "en general / en total", o si la billetera seleccionada es "Todas las billeteras".

        2. CONSULTAS DE SALDO (intencion = "CONSULTAR_BALANCE"):
           - Si el usuario pregunta cuánto saldo tiene, cuánto dinero le queda, su balance o saldo disponible (ej: "cuánto saldo tengo", "mi saldo", "saldo en \(billeteraActiva)"):
             * Responde de forma concisa, directa y exacta:
               "Tu saldo disponible en \(billeteraActiva) es de \(currencySymbol) \(currentBalanceFormatted)."
             * Si pregunta por todas las billeteras o en general: Da el saldo total o el desglose usando los datos de CONTEXTO ACTUAL.

        3. REGISTRO DE MOVIMIENTOS (SIMPLES, MÚLTIPLES O COMPUESTOS):
           - Si el usuario menciona uno o varios gastos o ingresos (ej: "El día de ayer me fui a una discoteca y gasté 15 soles en trago 20 soles en pi Keo y 30 soles en taxi", "el día de ayer gasté 25 soles en comprar canchita y hoy me pagaron 500 soles de mi sueldo", "ayer gasté 25 soles en canchita", "ayer gasté 30 en taxi a las 7:35 pm y hoy cobré 100", "hoy pagué 20 de comida y 15 de pasaje", "gasté veinticinco soles en comprar un pollo"):
             * REGLA OBLIGATORIA DE EXTRACCIÓN MÚLTIPLE: Extrae CADA UNO de los movimientos mencionados individualmente. Si el usuario menciona 2, 3 o más gastos o ingresos en una misma frase, NUNCA omitas ninguno ni los consolides en uno solo; crea un objeto separado para CADA movimiento ("15 soles en trago", "20 soles en pi Keo" -> Piqueo, "30 soles en taxi").
             * Para cada movimiento:
               - titulo: Nombre descriptivo específico (ej. "Pollo", "Trago", "Piqueo", "Taxi", "Canchita", "Sueldo").
               - concepto: Toda la oración o frase completa dicha por el usuario (incluida toda la oración compuesta de los movimientos).
               - descripcion: Mismo detalle descriptivo del movimiento.
               - categoria: Asignar OBLIGATORIAMENTE una de las categorías oficiales de la lista (ESTÁ ESTRICTAMENTE PROHIBIDO INVENTAR CATEGORÍAS COMO 'Comida', 'Alimentos', 'Sueldo', etc.):
                 * REGLA DE ORO DE ALIMENTACIÓN: Si el movimiento es sobre comida, comer, comprar un pollo, pollo a la brasa, restaurante, chifa, pizza, hamburguesa, almuerzo, cena, desayuno, mercado, supermercado, víveres, café, postres o delivery de comida, la categoría DEBE SER OBLIGATORIAMENTE "Alimentación" (JAMÁS inventes "Comida" ni "Alimentos").
                 * REGLA DE ORO DE SALARIO: Si el movimiento es sobre sueldo, nómina, quincena o remuneración laboral, la categoría DEBE SER OBLIGATORIAMENTE "Salario" (JAMÁS inventes "Sueldo").
                 * Para otros movimientos, selecciona estrictamente de la lista oficial de GASTO o INGRESO. Si no coincide con ninguna, usa "Otros" (para gasto) o "Otros Ingresos" (para ingreso).
               - tipo: "GASTO" o "INGRESO" (sé muy preciso: si recibió dinero, cobro, salario o sueldo es "INGRESO"; si pagó, gastó o compró es "GASTO").
               - monto: Valor numérico positivo (Double).
               - billetera: Billetera mencionada o "\(billeteraActiva)".
               - fecha:
                 * Si la cláusula de este movimiento indica "ayer": "\(isoAyer)".
                 * Si la cláusula de este movimiento indica "hoy" o no menciona fecha: "\(isoHoy)".
                 * CADA movimiento tiene su PROPIA fecha independiente. En oraciones compuestas con "ayer" y "hoy", jamás asignes la misma fecha a ambos; pon "\(isoAyer)" al de ayer y "\(isoHoy)" al de hoy.
               - hora y faltaHora:
                 * Si el usuario indicó una hora para ese movimiento (ej: "a las 7:35 pm", "7 de la noche", "a las 8 am", "19:00", "7:15 a.m.", "a las 5 con 20 de la tarde"):
                   Extrae la hora exacta con AM/PM (ej. "07:35 PM", "07:00 PM", "08:00 AM", "05:20 PM") o 24h (ej. "19:35", "19:00", "08:00", "17:20").
                   Distingue con total fidelidad entre P.M. y A.M. y conserva los minutos exactos indicados por el usuario.
                   faltaHora = false.
                 * Si el usuario NO indicó hora para ese movimiento:
                   - Si el movimiento es de HOY (o sin fecha explícita):
                     hora = "\(horaActual)", faltaHora = false.
                   - Si el movimiento es de AYER:
                     hora = null, faltaHora = true.
                     ¡REGLA OBLIGATORIA!: Cuando un gasto o ingreso sea del día de AYER y el usuario NO haya especificado la hora, NUNCA lo registres con la hora actual. Debe quedar en espera para preguntarle la hora exacta al usuario.

             * CLASIFICACIÓN ENTRE "transacciones" Y "transaccionesEnEspera":
               - Todo movimiento que tenga faltaHora == false (movimientos de hoy, o de ayer con hora ya indicada) se incluye de inmediato en el arreglo "transacciones".
               - Todo movimiento del día de AYER que no tenga hora (faltaHora == true):
                 * NO lo incluyas en "transacciones".
                 * Inclúyelo en el arreglo "transaccionesEnEspera" (y pon el primer elemento en "transaccionEnEspera") con fecha = "\(isoAyer)", hora = null, faltaHora = true.
                 * Establece esperaRespuestaUsuario = true y parametroPendiente = "HORA".

             * EN "razonamiento":
               - Si hay movimientos en "transaccionesEnEspera":
                 * Si también hubo movimientos listos en "transacciones" (ej: hoy sueldo), confirma primero el registro de esos movimientos.
                 * Luego, menciona claramente todos los movimientos detectados de ayer y pregunta la hora exacta del PRIMER movimiento pendiente en la cola.
                   Ejemplo: "Detecté tus 3 gastos de ayer: Trago (\(currencySymbol) 15.00), Piqueo (\(currencySymbol) 20.00) y Taxi (\(currencySymbol) 30.00). ¿A qué hora exacta realizaste el gasto de \(currencySymbol) 15.00 en trago?"
                   Ejemplo con 1 gasto de ayer: "¿A qué hora exacta realizaste este gasto de ayer de \(currencySymbol) 25.00 en canchita?"
               - Si todos los movimientos tenían faltaHora == false:
                 Confirma todos los movimientos registrados con sus fechas respectivas (ayer u hoy) y horas si fueron especificadas.

        4. COMPLETAR DATO FALTANTE:
           - Si en el contexto hay "Transacciones pendientes de completar hora" y el usuario responde la hora (ej: "A las nueve P.M.", "a las 7:35 pm", "7:00 pm", "a las 7 de la noche", "a las 3 de la tarde", "7 am", "a las 8", "19:35", o si da las horas de todos como "el trago a las 9pm, el piqueo a las 11pm y el taxi a las 2am"):
             * intencion = "COMPLETAR_DATO_FALTANTE".
             * MANTÉN ESTRICTAMENTE EL TIPO ORIGINAL de las transacciones pendientes (si era INGRESO queda como INGRESO, si era GASTO queda como GASTO). JAMÁS cambies un ingreso a gasto ni viceversa.
             * MANTÉN LA FECHA ORIGINAL ("\(isoAyer)").
             * MANTÉN EL MONTO ORIGINAL de cada transacción previa pendiente.
             * ¡REGLA ABSOLUTA DE CONCEPTO!: El "concepto" de la transacción DEBE SER OBLIGATORIAMENTE toda la oración original completa que dictó el usuario (concepto_oracion_completa), incluidos todos los movimientos compuestos. NUNCA pongas la hora ("a las 7:30 pm") como concepto.
             * ¡REGLA ABSOLUTA DE TÍTULO!: El "titulo" DEBE SER el nombre del movimiento (ej: "Trago", "Piqueo", "Canchita", "Taxi"), NUNCA la hora.
             * ¡REGLA ABSOLUTA DE CATEGORÍA!: Clasifica OBLIGATORIAMENTE la categoría oficial que corresponde a ese movimiento (ej: "Entretenimiento" para trago/discoteca, "Alimentación" para piqueo/canchita/comida, "Transporte" para taxi). NUNCA uses "Otros" si el movimiento corresponde a una categoría conocida.
             * Si el usuario responde la hora para la primera transacción pendiente:
               - Coloca esa transacción completada en el arreglo "transacciones" con la hora indicada con AM/PM o 24h, y faltaHora = false.
               - Coloca las transacciones pendientes restantes en "transaccionesEnEspera" (y la primera restante en "transaccionEnEspera").
               - Si aún quedan transacciones en "transaccionesEnEspera":
                 * esperaRespuestaUsuario = true, parametroPendiente = "HORA".
                 * En "razonamiento": Confirma el registro de la transacción actual usando su nombre real y la hora, y pregunta la hora exacta de la siguiente transacción pendiente.
                   Ejemplo: "¡Listo! He registrado tu gasto de \(currencySymbol) 15.00 en trago a las 07:30 PM. ¿A qué hora exacta realizaste el gasto de \(currencySymbol) 20.00 en piqueo el día de ayer?"
               - Si ya no quedan más transacciones pendientes (se completó la última):
                 * esperaRespuestaUsuario = false, parametroPendiente = null, transaccionesEnEspera = [], transaccionEnEspera = null.
                 * En "razonamiento": Confirma que todos los movimientos pendientes quedaron registrados con éxito con sus nombres reales y horas.
             * Si el usuario responde las horas de TODAS las transacciones a la vez:
               - Coloca TODAS las transacciones completadas con sus horas respectivas en "transacciones", faltaHora = false.
               - esperaRespuestaUsuario = false, parametroPendiente = null, transaccionesEnEspera = [], transaccionEnEspera = null.
               - En "razonamiento": Confirma todos los movimientos registrados con sus horas.

         5. TRANSFERENCIAS ENTRE BILLETERAS POR VOZ (intencion = "TRANSFERIR_DINERO" o "CONFIRMAR_TRANSFERENCIA"):
            - ¡MUY IMPORTANTE!: Esta intención aplica EXCLUSIVAMENTE cuando el usuario pide explícitamente transferir o mover dinero entre dos billeteras suyas (ej: "Transfiere 100 soles de BCP a Interbank", "Pasa 50 soles a Yape").
            - ¡NUNCA CONFUNDIR CON PAGOS, DEUDAS, PRÉSTAMOS NI COMPRAS!:
              Si el usuario dice "pagué...", "pago...", "gasté...", "saqué...", "compré...", "deuda de...", "crédito de...", "préstamo de..." (por ejemplo: "Pagué una deuda de Yape 500 soles", "Pagué una deuda de Yapp", "Saqué un préstamo de BCP de 1000 soles"):
              ESTO ES ESTRICTAMENTE UN REGISTRO DE TRANSACCIÓN (intencion = "REGISTRAR_TRANSACCION") en la billetera activa actual ("\(billeteraActiva)").
              Bajo NINGUNA circunstancia debes interpretarlo como transferencia ni verificar otras billeteras ni decir "no encontré la billetera". El movimiento se debe registrar SIEMPRE en la billetera activa actual, con el nombre del banco o app ("Yape", "BCP", etc.) como concepto o título, y categoría "Deuda" o "Préstamo" según corresponda.
            - Si el usuario SÍ pide una transferencia explícita entre billeteras:
              * VALIDACIÓN ESTRICTA DEL NOMBRE DE BILLETERAS:
                - Las billeteras disponibles registradas son: [\(walletsSection)].
                - Si el nombre de la billetera destino u origen dicho por el usuario NO coincide con ninguna de las disponibles:
                  Aclara amablemente en "razonamiento" que no encontraste esa billetera y lista cuáles son sus billeteras disponibles [\(walletsSection)].
                - Si el origen no fue especificado, asume la billetera activa ("\(billeteraActiva)"), salvo que coincida con el destino.
                - Si ambas billeteras son válidas y hay saldo suficiente:
                  intencion = "TRANSFERIR_DINERO".
                  transferencia = { "origen": "...", "destino": "...", "monto": 100.0, "confirmado": false }
                  razonamiento = OBLIGATORIAMENTE pregunta de confirmación:
                  "¿Estás seguro de que deseas transferir \(currencySymbol) [monto] de '[Billetera Origen]' a '[Billetera Destino]'?"
                  esperaRespuestaUsuario = true
            - Si hay una transferencia pendiente y el usuario responde afirmativamente ("sí", "confirmo", "estoy seguro", "proceder", "dale", "hazlo"):
              * intencion = "CONFIRMAR_TRANSFERENCIA".
              * razonamiento = "Procediendo con la transferencia..."
         
         6. REGLA DE BANCOS DE PERÚ, PRÉSTAMOS Y DEUDAS (Yape, Plin, BCP, Interbank, BBVA, Scotiabank):
            * Si el usuario dice que sacó o pidió un préstamo (ej: "Saque un prestamo de yape de 500 soles", "Préstamo de BCP de 1000 soles"):
              - tipo: "INGRESO"
              - categoria: "Préstamo"
              - titulo y concepto: Nombre del banco ("Yape", "BCP", "Plin", "Interbank", "BBVA", "Scotiabank").
            * Si el usuario dice que pagó su deuda, crédito o cuota (ej: "Pagué mi deuda de yape 500 soles", "Pagué mi credito de yape 500 soles"):
              - tipo: "GASTO"
              - categoria: "Deuda"
              - titulo y concepto: Nombre del banco ("Yape", "BCP", "Plin", "Interbank", "BBVA", "Scotiabank").

        7. REGLA ESTRICTA AL REGISTRAR:
           - Únicamente al registrar un nuevo gasto/ingreso (intención REGISTRAR_TRANSACCION o COMPLETAR_DATO_FALTANTE), NO agregues sermones teóricos de ahorro no solicitados.
           - Esta restricción NO prohíbe dar saldos cuando el usuario PREGUNTA expresamente por ellos ("¿Cuánto saldo tengo?").

        6. CONSEJOS:
           - Si pide un consejo, responde OBLIGATORIAMENTE iniciando con:
             "Okey un consejo para tu billetera \(billeteraActiva) sería..."
           - Da un consejo breve, directo y basado en sus datos sin rodeos.

        7. CONSULTAS DE ESTADÍSTICAS Y GASTOS FIJOS:
           - Si consulta por resumen de gastos/ingresos, ordenar de mayor a menor gasto, o gastos vs ingresos: responde con las cifras exactas del historial de la billetera activa. Si no hay datos suficientes, responde: "No existen datos suficientes referente a lo que me estás preguntando."
           - Si consulta sobre gastos fijos (cuál es el más alto, más bajo, frecuencia o próximo día de pago): responde usando el catálogo de gastos fijos. Si no tiene gastos fijos registrados, responde: "No existen datos suficientes referente a lo que me estás preguntando."

        8. CORTESÍA, HUMOR Y CONVERSACIÓN (intencion = "CONVERSACIONAL"):
           - Si el usuario pide un chiste ("dime un chiste", "cuéntame un chiste", "broma"), cuéntale en "razonamiento" un chiste simpático, gracioso y ocurrente. ¡Sé creativo y divertido!
           - Si el usuario pide enviar saludos ("manda saludos a Pedro", "quiero que mandes saludos a mi amigo Mauricio que está en la selva"):
             * Extrae con total limpieza el nombre y contexto del destinatario (ej. "Mauricio que está en la selva") y responde afectuosamente: "¡Un gran saludo para Mauricio que está en la selva! 👋 Espero que le vaya excelente.".
             * ¡JAMÁS repitas partes del comando como "Quiero que mandes mi amigo..."!
           - Si el usuario saluda, dice "cuéntame", "¿cómo estás?" o charla de manera amigable, responde con calidez, personalidad y empatía.
           - Si el usuario dice "gracias", "hasta luego", "chau", etc., devuelve un agradecimiento o despedida amable.
           - Mantén siempre transacciones = [], transaccionesEnEspera = [], esperaRespuestaUsuario = false.

        9. RESPUESTA UNIVERSAL A CUALQUIER PREGUNTA, MATEMÁTICAS Y CULTURA GENERAL (intencion = "CONVERSACIONAL"):
           - Como asistente de inteligencia artificial avanzado respaldado por Gemini, DEBES responder de forma completa, precisa, inteligente, didáctica y elocuente a CUALQUIER tipo de pregunta formulada por el usuario (ciencia, historia, geografía, cultura general, curiosidades, definiciones, redacción, traducción, matemáticas, vida cotidiana, etc.).
           - ¡REGLA FUNDAMENTAL DE RESPUESTA!: En "respuesta" y "razonamiento" DEBES dar SIEMPRE la respuesta real, completa, explicativa y directa a la consulta del usuario. ESTÁ ESTRICTAMENTE PROHIBIDO emitir meta-comentarios sobre la pregunta (como "El usuario está preguntando sobre..." o "Pregunta teórica..."). Si el usuario pregunta "¿Qué es la inflación?", responde de inmediato explicando qué es la inflación con total claridad.
           - Si el usuario pregunta por operaciones matemáticas o cálculos ("cuánto es 5 x 45", "5 + 35", "cuánto es el 18% de 500", "calcula 120 / 4"):
             * Resuelve el cálculo con exactitud matemática y explica el resultado claramente en "respuesta" y "razonamiento".
           - Si el usuario hace cualquier pregunta general o de cultura ("quién pintó la mona lisa", "por qué el cielo es azul", "capital de Francia", "explica la teoría de la relatividad", "receta de pastel de chocolate", etc.):
             * Responde con conocimiento profundo, claridad y naturalidad en "respuesta" y "razonamiento".
             * ESTRICTAMENTE PROHIBIDO añadir frases robóticas o forzadas como "y sigo atento para cuidar tus finanzas" o "¿deseas registrar un movimiento?". Responde con total naturalidad como la IA avanzada que eres. Únicamente habla de finanzas si el usuario lo solicita explícitamente.
        10. CONSULTAS DETALLADAS DE CUENTAS, ACTIVIDAD, INGRESOS Y CATEGORÍAS (intencion = "CONSULTAR_BALANCE" o "CONVERSACIONAL"):
           - Cuentas activas, número de cuentas y nombres:
             * Si el usuario pregunta cuántas cuentas tiene activas, el número de cuentas o los nombres de sus cuentas (ej: 'cuántas cuentas tengo activas', 'número de cuentas', 'nombre de las cuentas', 'nombres de las cuentas'):
               Responde indicando claramente la cantidad exacta de cuentas activas (\(wallets.count)), lista cada una con su nombre y su saldo disponible según el desglose de saldos.
           - Cuentas más usadas:
             * Si pregunta cuáles son sus cuentas más usadas o con más movimientos:
               Identifica la cuenta con mayor cantidad de movimientos y flujo registrada en el desglose, e indica el ranking de actividad de sus cuentas.
           - Mayor ingreso en general o por cuenta específica:
             * Si pregunta cuál es su mayor ingreso en general o en una cuenta específica (ej: 'cuál es mi mayor ingreso', 'mayor ingreso en BCP', 'mayor ingreso en Yape'):
               Busca en el historial de movimientos el ingreso con el monto más alto (filtrado por la cuenta solicitada si aplica), indicando el monto exacto, categoría, concepto y fecha.
           - Categoría con mayor y menor gasto ("en qué gasto más", "en qué gasto menos", "categoría más alta", "categoría más baja", "gastos más altos"):
               Analiza la sumatoria de gastos por categoría en base al historial de movimientos y responde con las categorías líder y menor, y los gastos individuales más altos.
           - Consultas generales, matemáticas y saludos no financieros:
               Si la pregunta no es de finanzas, respóndela inteligentemente con exactitud y empatía, respondiendo directa y brillantemente a la consulta.

        FORMATO JSON OBLIGATORIO:
        {
          "intencion": "CONVERSACIONAL",
          "transacciones": [],
          "transaccionesEnEspera": [],
          "transaccionEnEspera": null,
          "respuesta": "Texto de la respuesta real, completa, didáctica y directa que leerá el usuario respondiendo exactamente a su consulta",
          "razonamiento": "Mismo texto de respuesta directa para el usuario",
          "esperaRespuestaUsuario": false,
          "parametroPendiente": null,
          "transferencia": null
        }
        """
    }
    
    // MARK: - Método Principal de Procesamiento
    public func processQuery(
        prompt: String,
        billeteraActiva: String = "BCP",
        currentBalance: Double,
        currencySymbol: String = "S/",
        wallets: [Wallet] = [],
        fechaHoy: String? = nil,
        horaActual: String? = nil,
        fechaAyer: String? = nil,
        transaccionPendiente: ExtractedTransaction? = nil,
        transaccionesPendientes: [ExtractedTransaction] = [],
        resumenMovimientos: String = "",
        resumenGastosFijos: String = "",
        desgloseSaldos: String = "",
        chatHistory: [FinancialChatMessage] = []
    ) async throws -> MoneyBotAIResponse {
        let phoneticCleaned = SpeechRecognitionService.normalizePhoneticSpokenText(prompt)
        let cleanPrompt = phoneticCleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPrompt.isEmpty else {
            return MoneyBotAIResponse(intencion: .DESCONOCIDA, transacciones: [], razonamiento: "El mensaje está vacío.")
        }
        guard !apiKey.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let temporal = Self.generateTemporalReference()
        let resolvedFechaHoy = fechaHoy ?? temporal.fechaHoy
        let resolvedHoraActual = horaActual ?? temporal.horaActual
        let resolvedFechaAyer = fechaAyer ?? temporal.fechaAyer
        let isoHoy = temporal.isoHoy
        let isoAyer = temporal.isoAyer
        
        var transaccionesList: [ExtractedTransaction] = []
        if !transaccionesPendientes.isEmpty {
            transaccionesList = transaccionesPendientes
        } else if let p = transaccionPendiente {
            transaccionesList = [p]
        }
        
        var transaccionPendienteDesc = "Ninguna"
        if !transaccionesList.isEmpty {
            transaccionPendienteDesc = transaccionesList.enumerated().map { index, pendiente in
                let tipoLabel = pendiente.tipo == .INGRESO ? "Ingreso" : "Gasto"
                let fechaDesc = pendiente.fecha.isEmpty ? "" : ", fecha original: \(pendiente.fecha)"
                return "\(index + 1). \(tipoLabel): \(pendiente.titulo), tipo: \(pendiente.tipo.rawValue), monto: \(pendiente.monto), concepto_oracion_completa: \"\(pendiente.concepto)\", categoría: \(pendiente.categoria), billetera: \(pendiente.billetera ?? billeteraActiva)\(fechaDesc)"
            }.joined(separator: "\n")
        }
        
        let systemPrompt = buildSystemPrompt(
            billeteraActiva: billeteraActiva,
            currentBalance: currentBalance,
            currencySymbol: currencySymbol,
            wallets: wallets,
            fechaHoy: resolvedFechaHoy,
            horaActual: resolvedHoraActual,
            fechaAyer: resolvedFechaAyer,
            isoHoy: isoHoy,
            isoAyer: isoAyer,
            transaccionPendienteDesc: transaccionPendienteDesc,
            resumenMovimientos: resumenMovimientos,
            resumenGastosFijos: resumenGastosFijos,
            desgloseSaldos: desgloseSaldos,
            chatHistory: chatHistory
        )
        
        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "\(systemPrompt)\n\nMensaje del usuario: \"\(cleanPrompt)\""]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.25,
                "maxOutputTokens": 800,
                "response_mime_type": "application/json"
            ]
        ]
        
        let httpBody = try JSONSerialization.data(withJSONObject: payload)
        var lastError: Error? = nil
        
        for baseUrl in candidateEndpoints {
            guard let url = URL(string: "\(baseUrl)?key=\(apiKey)") else { continue }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = httpBody
            
            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else { continue }
                guard httpResponse.statusCode == 200 else { continue }
                
                if let parsedResponse = parseGeminiResponse(data: data) {
                    return parsedResponse
                }
            } catch {
                lastError = error
                continue
            }
        }
        
        if let error = lastError {
            throw error
        }
        
        throw URLError(.cannotConnectToHost)
    }
    
    private func parseGeminiResponse(data: Data) -> MoneyBotAIResponse? {
        guard let rootJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = rootJson["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            return nil
        }
        
        let textParts = parts.compactMap { part -> String? in
            if let isThought = part["thought"] as? Bool, isThought {
                return nil
            }
            return part["text"] as? String
        }
        let rawText = textParts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawText.isEmpty else { return nil }
        
        var clean = rawText
        if clean.hasPrefix("```json") {
            clean = clean.replacingOccurrences(of: "```json", with: "")
            if clean.hasSuffix("```") {
                clean = String(clean.dropLast(3))
            }
        } else if clean.hasPrefix("```") {
            clean = clean.replacingOccurrences(of: "```", with: "")
        }
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = clean.data(using: .utf8) else {
            if !clean.isEmpty {
                return MoneyBotAIResponse(intencion: .CONVERSACIONAL, transacciones: [], razonamiento: clean, esperaRespuestaUsuario: false)
            }
            return nil
        }
        
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode(MoneyBotAIResponse.self, from: jsonData) {
            // Solo retornarlo de inmediato si tiene una respuesta válida o transacciones
            if !decoded.razonamiento.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !decoded.transacciones.isEmpty {
                return decoded
            }
        }
        
        // 2. Intentar parsear como diccionario flexible si la estructura estricta difiere
        if let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            let possibleKeys = ["respuesta", "mensaje", "answer", "text", "content", "reply", "razonamiento"]
            for key in possibleKeys {
                if let str = dict[key] as? String {
                    let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                    let lower = trimmed.lowercased()
                    // Descartar meta-comentarios si es posible
                    if !trimmed.isEmpty && !lower.hasPrefix("el usuario ") && !lower.hasPrefix("el usuario está") {
                        return MoneyBotAIResponse(
                            intencion: .CONVERSACIONAL,
                            transacciones: [],
                            razonamiento: trimmed,
                            esperaRespuestaUsuario: false
                        )
                    }
                }
            }
            // Si solo había razonamiento con meta-comentario, usarlo antes que nada
            for key in possibleKeys {
                if let str = dict[key] as? String, !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return MoneyBotAIResponse(
                        intencion: .CONVERSACIONAL,
                        transacciones: [],
                        razonamiento: str.trimmingCharacters(in: .whitespacesAndNewlines),
                        esperaRespuestaUsuario: false
                    )
                }
            }
        }
        
        // 3. Si Gemini respondió en texto plano, Markdown o respuesta conversacional libre:
        // ¡Usar el texto directo como respuesta para NUNCA descartar lo generado!
        if !clean.isEmpty {
            return MoneyBotAIResponse(
                intencion: .CONVERSACIONAL,
                transacciones: [],
                razonamiento: clean,
                esperaRespuestaUsuario: false
            )
        }
        
        return nil
    }
}
