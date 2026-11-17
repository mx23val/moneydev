import Foundation
import SwiftUI

public struct CategoryItem: Identifiable, Hashable, Sendable {
    public var id: String { "\(name)_\(type.rawValue)" }
    public let name: String
    public let iconSymbol: String
    public let colorHex: String
    public let type: TransactionType
    public let synonyms: [String]
    
    public var color: Color {
        Color(hex: colorHex)
    }
    
    public init(name: String, iconSymbol: String, colorHex: String, type: TransactionType, synonyms: [String] = []) {
        self.name = name
        self.iconSymbol = iconSymbol
        self.colorHex = colorHex
        self.type = type
        self.synonyms = synonyms
    }
}

public enum CategoryHelper {
    public static let expenseCategories: [CategoryItem] = [
        CategoryItem(
            name: "Suscripciones",
            iconSymbol: "play.tv.fill",
            colorHex: "#8B5CF6",
            type: .expense,
            synonyms: [
                "suscripcion", "suscripción", "suscripciones", "subscripcion", "subscripción",
                "spotify", "netflix", "youtube", "youtube premium", "disney", "disney plus", "disney+",
                "hbo", "hbo max", "max", "prime video", "amazon prime", "apple music", "apple tv",
                "icloud", "chatgpt", "openai", "claude", "midjourney", "playstation plus", "ps plus",
                "xbox game pass", "game pass", "nintendo switch online", "nintendo online", "github",
                "canva", "adobe", "duolingo", "crunchyroll", "deezer", "tidal", "dropbox", "google one",
                "google drive", "microsoft 365", "office 365", "antivirus", "nordvpn", "vpn",
                "membresia", "membresía", "patreon", "twitch", "onlyfans", "hosting", "dominio", "vps",
                "saas", "software", "suscripcion mensual", "suscripcion anual", "app store", "play store"
            ]
        ),
        CategoryItem(
            name: "Alimentación",
            iconSymbol: "fork.knife",
            colorHex: "#F59E0B",
            type: .expense,
            synonyms: [
                "comida", "comidas", "comer", "comi", "comí", "comimos", "comieron", "comiendo", "alimento", "alimentos",
                "almuerzo", "almuerzos", "almorzar", "almorce", "almorcé", "almorzamos", "cena", "cenas", "cenar", "cene",
                "cené", "cenamos", "desayuno", "desayunos", "desayunar", "desayune", "desayuné", "desayunamos", "lonche",
                "restaurante", "restaurant", "restaurantes", "pizzeria", "pizzería", "pizza", "pizzas", "hamburguesa",
                "hamburguesas", "burger", "bembos", "mcdonalds", "kfc", "starbucks", "chifa", "chifas", "chifita",
                "polleria", "pollería", "pollo", "pollo a la brasa", "mostrito", "broaster", "ceviche", "cebiche",
                "cevicheria", "cevichería", "sushi", "carne", "parrilla", "empanada", "empanadas", "sandwich", "sandwiches",
                "helado", "helados", "heladeria", "heladería", "postre", "postres", "torta", "tortas", "pastel", "pasteleria",
                "pastelería", "dulces", "galleta", "galletas", "chocolate", "pan", "panaderia", "panadería", "panes",
                "jugo", "jugos", "licuado", "licuados", "refresco", "refrescos", "gaseosa", "gaseosas", "bebida no alcoholica",
                "agua", "té", "infusion", "cafe", "café", "cafeteria", "cafetería", "mercado", "supermercado", "abarrotes",
                "bodega", "snack", "snacks", "canchita", "palomitas", "popcorn", "delivery", "rappi", "pedidosya", "menu",
                "menú", "fruta", "frutas", "verduras", "salí a comer", "sali a comer", "salí a cenar", "sali a cenar"
            ]
        ),
        CategoryItem(
            name: "Transporte",
            iconSymbol: "car.fill",
            colorHex: "#38BDF8",
            type: .expense,
            synonyms: [
                "viaje", "viajes", "transporte", "pasaje", "pasajes", "taxi", "uber", "didi", "indrive", "cabify",
                "gasolina", "combustible", "petroleo", "grifo", "gnv", "glp", "bus", "micro", "colectivo", "combi",
                "metro", "tren", "peaje", "estacionamiento", "parqueo", "vuelo", "avion", "avión", "aeropuerto", "moto",
                "mantenimiento auto", "taller", "llanta", "scooter", "bici", "bicicleta", "coche", "auto", "carro",
                "alquiler de coche", "alquiler coche", "alquiler de auto", "alquiler auto", "alquiler de carro", "renta de auto"
            ]
        ),
        CategoryItem(
            name: "Apuestas y Juegos",
            iconSymbol: "dice.fill",
            colorHex: "#F43F5E",
            type: .expense,
            synonyms: [
                "apuesta", "apuestas", "apostar", "aposte", "aposté", "bet", "casino", "tragamonedas", "ruleta", "poker",
                "blackjack", "loteria", "lotería", "tinka", "ganagol", "teapuesto", "te apuesto", "betsson", "betano",
                "doradobet", "1xbet", "inkabet", "olimpobet", "apuestas deportivas", "polla", "quiniela", "rifa", "bingo",
                "juego de azar", "sorteo", "parley", "slot", "maquinitas", "jugada", "ticket apuesta"
            ]
        ),
        CategoryItem(
            name: "Vivienda",
            iconSymbol: "house.fill",
            colorHex: "#818CF8",
            type: .expense,
            synonyms: [
                "casa", "hogar", "departamento", "depa", "alquiler", "renta", "cuota casa", "muebles",
                "decoracion", "decoración", "pintura", "reparacion", "reparación", "mantenimiento depa", "hipoteca",
                "limpieza", "jardin", "cerrajero", "mudanza", "terreno", "habitacion", "cuarto"
            ]
        ),
        CategoryItem(
            name: "Compras",
            iconSymbol: "cart.fill",
            colorHex: "#EC4899",
            type: .expense,
            synonyms: [
                "ropa", "tienda", "mall", "zapatillas", "zapatos", "polo", "pantalon", "camisa", "casaca",
                "electronica", "celular", "gadget", "computadora", "laptop", "teclado", "mouse", "compras",
                "compra", "amazon", "aliexpress", "mercadolibre", "falabella", "ripley", "accesorios", "reloj"
            ]
        ),
        CategoryItem(
            name: "Servicios",
            iconSymbol: "bolt.fill",
            colorHex: "#06B6D4",
            type: .expense,
            synonyms: [
                "luz", "agua", "internet", "gas", "telefono", "telefono fijo", "celular plan", "recarga", "recargas",
                "mantenimiento", "cable", "recibo", "recibos", "sedapal", "enel", "luz del sur", "calidda", "claro",
                "movistar", "entel", "bitel", "servicios basicos", "cuota mantenimiento"
            ]
        ),
        CategoryItem(
            name: "Salud",
            iconSymbol: "cross.case.fill",
            colorHex: "#10B981",
            type: .expense,
            synonyms: [
                "farmacia", "medico", "medicina", "pastillas", "doctor", "hospital", "clinica", "dentista", "odontologo",
                "consulta", "analisis", "terapia", "psicologo", "lentes", "optica", "seguro medico", "eps", "emergencia"
            ]
        ),
        CategoryItem(
            name: "Entretenimiento",
            iconSymbol: "film.fill",
            colorHex: "#A855F7",
            type: .expense,
            synonyms: [
                "cine", "pelicula", "cineplanet", "cinemark", "fiesta", "discoteca", "bar", "cerveza", "trago",
                "concierto", "evento", "teatro", "boliche", "karaoke", "videojuegos", "steam", "playstation",
                "diversion", "paseo", "club", "parque de diversiones", "juegos"
            ]
        ),
        CategoryItem(
            name: "Educación",
            iconSymbol: "graduationcap.fill",
            colorHex: "#3B82F6",
            type: .expense,
            synonyms: [
                "universidad", "instituto", "colegio", "pension", "matricula", "curso", "cursos", "udemy", "platzi",
                "libros", "cuaderno", "fotocopias", "certificacion", "taller", "idiomas", "ingles", "clases"
            ]
        ),
        CategoryItem(
            name: "Mascotas",
            iconSymbol: "pawprint.fill",
            colorHex: "#F97316",
            type: .expense,
            synonyms: [
                "veterinaria", "perro", "gato", "comida perro", "comida gato", "ricocan", "ricocat", "vacuna",
                "bano mascota", "accesorio mascota", "correa", "arena gato", "mascotas"
            ]
        ),
        CategoryItem(
            name: "Cuidado Personal",
            iconSymbol: "sparkles",
            colorHex: "#D946EF",
            type: .expense,
            synonyms: [
                "corte", "barberia", "peluqueria", "peinado", "salon de belleza", "unas", "manicure", "pedicure",
                "spa", "masaje", "gimnasio", "gym", "suplementos", "proteina", "perfume", "cremas", "maquillaje"
            ]
        ),
        CategoryItem(
            name: "Otros",
            iconSymbol: "ellipsis.circle.fill",
            colorHex: "#64748B",
            type: .expense,
            synonyms: ["otros", "varios", "gasto", "imprevisto", "comision", "multa", "prestamo pago"]
        )
    ]
    
    public static let incomeCategories: [CategoryItem] = [
        CategoryItem(
            name: "Salario",
            iconSymbol: "banknote.fill",
            colorHex: "#10B981",
            type: .income,
            synonyms: [
                "sueldo", "salario", "quincena", "mensualidad", "pago trabajo", "honorarios", "remuneracion",
                "ingreso mensual", "ingreso laboral", "empleo", "gratificacion", "cts", "liquidacion", "bono laboral"
            ]
        ),
        CategoryItem(
            name: "Ventas",
            iconSymbol: "tag.fill",
            colorHex: "#34D399",
            type: .income,
            synonyms: [
                "venta", "ventas", "vendi", "vendí", "comercio", "negocio", "ganancia negocio", "cliente", "factura",
                "cobro cliente", "ingreso venta", "mercaderia vendida"
            ]
        ),
        CategoryItem(
            name: "Premios y Apuestas",
            iconSymbol: "trophy.fill",
            colorHex: "#FBBF24",
            type: .income,
            synonyms: [
                "gane apuesta", "gané apuesta", "premio", "premios", "loteria", "sorteo", "bingo", "tinka ganada",
                "ganagol", "ganancia casino", "betsson ganado", "apuesta ganada", "ruleta ganada"
            ]
        ),
        CategoryItem(
            name: "Inversiones",
            iconSymbol: "chart.line.uptrend.xyaxis",
            colorHex: "#06B6D4",
            type: .income,
            synonyms: [
                "dividendos", "rendimiento", "intereses", "plazo fijo", "cripto", "acciones", "fondo mutuo",
                "ganancia capital", "ganancia inversiones"
            ]
        ),
        CategoryItem(
            name: "Regalos",
            iconSymbol: "gift.fill",
            colorHex: "#EC4899",
            type: .income,
            synonyms: [
                "regalo", "propina", "me dieron", "me regalaron", "cumpleanos", "donacion", "apoyo familiar"
            ]
        ),
        CategoryItem(
            name: "Devoluciones",
            iconSymbol: "arrow.uturn.backward.circle.fill",
            colorHex: "#38BDF8",
            type: .income,
            synonyms: [
                "me devolvieron", "cobro deuda", "reembolso", "devolucion", "me pagaron lo prestado"
            ]
        ),
        CategoryItem(
            name: "Otros Ingresos",
            iconSymbol: "plus.circle.fill",
            colorHex: "#64748B",
            type: .income,
            synonyms: ["ingreso extra", "otros ingresos", "dinero", "cobro extra", "cashback"]
        )
    ]
    
    public static func normalize(_ text: String) -> String {
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "es_PE"))
            .lowercased()
    }
    
    public static func getCategoryIcon(name: String, type: TransactionType) -> String {
        if name.caseInsensitiveCompare("Transferencia") == .orderedSame {
            return "arrow.left.arrow.right"
        }
        let list = (type == .expense) ? expenseCategories : incomeCategories
        if let found = list.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return found.iconSymbol
        }
        return (type == .expense) ? "creditcard.fill" : "banknote.fill"
    }
    
    public static func getCategoryColorHex(name: String, type: TransactionType) -> String {
        if name.caseInsensitiveCompare("Transferencia") == .orderedSame {
            return "#38BDF8"
        }
        let list = (type == .expense) ? expenseCategories : incomeCategories
        if let found = list.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return found.colorHex
        }
        return (type == .expense) ? "#F87171" : "#34D399"
    }
    
    public static func getCategoryColor(name: String, type: TransactionType) -> Color {
        Color(hex: getCategoryColorHex(name: name, type: type))
    }
    
    public static func hasWordOrPhrase(normText: String, normTarget: String) -> Bool {
        if normTarget.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        let cleanTarget = normalize(normTarget)
        if cleanTarget.contains(" ") {
            return normText.contains(cleanTarget)
        }
        let pattern = "(?i)(?:^|[^a-z0-9])\(NSRegularExpression.escapedPattern(for: cleanTarget))(?:$|[^a-z0-9])"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(normText.startIndex..., in: normText)
            return regex.firstMatch(in: normText, range: range) != nil
        }
        return normText.contains(cleanTarget)
    }
    
    public static func matchesTransactionSearch(
        title: String,
        category: String,
        notes: String,
        query: String,
        type: TransactionType
    ) -> Bool {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanQuery.isEmpty { return true }
        
        let normQuery = normalize(cleanQuery)
        let normTitle = normalize(title)
        let normCategory = normalize(category)
        let normNotes = normalize(notes)
        
        if normTitle.contains(normQuery) || normCategory.contains(normQuery) || normNotes.contains(normQuery) {
            return true
        }
        
        let tokens = normQuery.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        if tokens.count > 1 {
            let combined = "\(normTitle) \(normCategory) \(normNotes)"
            return tokens.allSatisfy { combined.contains($0) }
        }
        return false
    }
}

// MARK: - Color Hex Extension
extension Color {
    public init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
