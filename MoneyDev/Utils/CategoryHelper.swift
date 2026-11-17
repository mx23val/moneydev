import Foundation
import SwiftUI

public struct CategoryItem: Identifiable, Hashable, Sendable, Codable {
    public var id: String { "\(name)_\(type.rawValue)" }
    public let name: String
    public let iconSymbol: String
    public let colorHex: String
    public let type: TransactionType
    public let synonyms: [String]
    
    enum CodingKeys: String, CodingKey {
        case name, iconSymbol, colorHex, type, synonyms
    }
    
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
                "polleria", "pollería", "pollo", "pollo a la brasa", "comprar un pollo", "comprar pollo", "pollos", "pollo entero", "medio pollo", "cuarto de pollo", "mostrito", "broaster", "ceviche", "cebiche",
                "cevicheria", "cevichería", "sushi", "carne", "parrilla", "empanada", "empanadas", "sandwich", "sandwiches",
                "helado", "helados", "heladeria", "heladería", "postre", "postres", "torta", "tortas", "pastel", "pasteleria",
                "pastelería", "dulces", "galleta", "galletas", "chocolate", "pan", "panaderia", "panadería", "panes",
                "jugo", "jugos", "licuado", "licuados", "refresco", "refrescos", "gaseosa", "gaseosas", "bebida no alcoholica",
                "agua", "té", "infusion", "cafe", "café", "cafeteria", "cafetería", "mercado", "supermercado", "abarrotes",
                "bodega", "snack", "snacks", "canchita", "palomitas", "popcorn", "delivery", "rappi", "pedidosya", "menu",
                "menú", "fruta", "frutas", "verduras", "salí a comer", "sali a comer", "salí a cenar", "sali a cenar",
                "comidita", "lonchecito", "antojo", "antojos", "piqueo", "piqueos", "pi keo", "piqueito", "piqueitos", "picar", "bocadito", "bocaditos", "tapas"
            ]
        ),
        CategoryItem(
            name: "Transporte",
            iconSymbol: "car.fill",
            colorHex: "#0284C7",
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
            colorHex: "#E11D48",
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
            colorHex: "#6366F1",
            type: .expense,
            synonyms: [
                "casa", "hogar", "departamento", "depa", "alquiler", "renta", "cuota casa", "muebles",
                "decoracion", "decoración", "pintura", "reparacion", "reparación", "mantenimiento depa", "hipoteca",
                "limpieza", "jardin", "cerrajero", "mudanza", "terreno", "habitacion", "cuarto"
            ]
        ),
        CategoryItem(
            name: "Electrónica y Tecnología",
            iconSymbol: "laptopcomputer.and.iphone",
            colorHex: "#06B6D4",
            type: .expense,
            synonyms: [
                "electronica", "electrónica", "tecnologia", "tecnología", "celular", "celulares", "telefono", "teléfono",
                "telefonos", "smartphone", "iphone", "samsung", "xiaomi", "huawei", "motorola", "laptop", "laptops",
                "notebook", "computadora", "computadoras", "pc", "ordenador", "tablet", "tablets", "ipad", "monitor",
                "pantalla", "teclado", "mouse", "audifonos", "audífonos", "auriculares", "airpods", "cargador",
                "cargadores", "cable usb", "usb", "disco duro", "ssd", "memoria", "ram", "tarjeta de video", "gpu",
                "procesador", "impresora", "camara", "cámara", "parlante", "altavoz", "alexa", "google home",
                "gadget", "gadgets", "smartwatch", "reloj inteligente", "apple watch", "consola", "consolas",
                "playstation", "ps5", "ps4", "xbox", "nintendo", "nintendo switch", "videojuego", "videojuegos",
                "tele", "televisor", "smart tv", "proyector", "gadget tecnologico"
            ]
        ),
        CategoryItem(
            name: "Compras",
            iconSymbol: "cart.fill",
            colorHex: "#EC4899",
            type: .expense,
            synonyms: [
                "ropa", "tienda", "mall", "zapatillas", "zapatos", "polo", "pantalon", "camisa", "casaca",
                "vestido", "falda", "shorts", "medias", "calzado", "sandalias", "botas",
                "compras", "compra", "amazon", "aliexpress", "mercadolibre", "falabella", "ripley", "accesorios", "reloj",
                "billetera compra", "cartera", "mochila", "bolso"
            ]
        ),
        CategoryItem(
            name: "Servicios",
            iconSymbol: "bolt.fill",
            colorHex: "#14B8A6",
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
            colorHex: "#D946EF",
            type: .expense,
            synonyms: [
                "cine", "pelicula", "cineplanet", "cinemark", "fiesta", "discoteca", "disco", "bar", "cerveza", "cervezas", "chela", "chelas", "trago", "tragos",
                "concierto", "evento", "teatro", "boliche", "karaoke", "videojuegos", "steam", "playstation",
                "diversion", "paseo", "club", "parque de diversiones", "juegos", "juerga", "farra", "coctel", "cocteles", "cocktail"
            ]
        ),
        CategoryItem(
            name: "Educación",
            iconSymbol: "graduationcap.fill",
            colorHex: "#2563EB",
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
            colorHex: "#FB7185",
            type: .expense,
            synonyms: [
                "corte", "barberia", "peluqueria", "peinado", "salon de belleza", "unas", "manicure", "pedicure",
                "spa", "masaje", "gimnasio", "gym", "suplementos", "proteina", "perfume", "cremas", "maquillaje"
            ]
        ),
        CategoryItem(
            name: "Deuda",
            iconSymbol: "creditcard.and.123",
            colorHex: "#DC2626",
            type: .expense,
            synonyms: [
                "deuda", "deudas", "pago de deuda", "pague mi deuda", "pagué mi deuda", "pago deuda",
                "credito", "crédito", "pago de credito", "pague mi credito", "pagué mi crédito", "pago credito",
                "tarjeta de credito pago", "amortizacion", "amortización", "cuota prestamo", "cuota préstamo",
                "pago prestamo", "pago préstamo", "deuda yape", "deuda plin", "deuda bcp", "deuda interbank",
                "deuda bbva", "deuda scotiabank", "credito yape", "credito plin", "credito bcp",
                "cuota banco", "prestamo pago", "pague mi prestamo", "pague prestamo"
            ]
        ),
        CategoryItem(
            name: "Otros",
            iconSymbol: "ellipsis.circle.fill",
            colorHex: "#64748B",
            type: .expense,
            synonyms: ["otros", "varios", "gasto", "imprevisto", "comision", "multa"]
        )
    ]
    
    public static let incomeCategories: [CategoryItem] = [
        CategoryItem(
            name: "Salario",
            iconSymbol: "banknote.fill",
            colorHex: "#059669",
            type: .income,
            synonyms: [
                "sueldo", "salario", "quincena", "mensualidad", "remuneracion",
                "ingreso mensual", "ingreso laboral", "empleo", "gratificacion", "cts", "liquidacion", "bono laboral"
            ]
        ),
        CategoryItem(
            name: "Trabajo",
            iconSymbol: "briefcase.fill",
            colorHex: "#16A34A",
            type: .income,
            synonyms: [
                "trabajo", "freelance", "freelancer", "chamba", "cachuelo", "honorarios", "servicios",
                "consultoria", "asesoria", "proyecto freelance", "pago trabajo", "cobro trabajo", "honorarios freelance"
            ]
        ),
        CategoryItem(
            name: "Ventas",
            iconSymbol: "tag.fill",
            colorHex: "#84CC16",
            type: .income,
            synonyms: [
                "venta", "ventas", "vendi", "vendí", "comercio", "negocio", "ganancia negocio", "cliente", "factura",
                "cobro cliente", "ingreso venta", "mercaderia vendida"
            ]
        ),
        CategoryItem(
            name: "Premios y Apuestas",
            iconSymbol: "trophy.fill",
            colorHex: "#EAB308",
            type: .income,
            synonyms: [
                "gane apuesta", "gané apuesta", "premio", "premios", "loteria", "sorteo", "bingo", "tinka ganada",
                "ganagol", "ganancia casino", "betsson ganado", "apuesta ganada", "ruleta ganada"
            ]
        ),
        CategoryItem(
            name: "Inversiones",
            iconSymbol: "chart.line.uptrend.xyaxis",
            colorHex: "#0D9488",
            type: .income,
            synonyms: [
                "dividendos", "rendimiento", "intereses", "plazo fijo", "cripto", "acciones", "fondo mutuo",
                "ganancia capital", "ganancia inversiones"
            ]
        ),
        CategoryItem(
            name: "Regalos",
            iconSymbol: "gift.fill",
            colorHex: "#F472B6",
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
            name: "Préstamo",
            iconSymbol: "building.columns.fill",
            colorHex: "#7C3AED",
            type: .income,
            synonyms: [
                "prestamo", "préstamo", "prestamos", "préstamos", "saque un prestamo", "saqué un préstamo",
                "saque prestamo", "saqué préstamo", "pedi un prestamo", "pedí un préstamo", "me prestaron",
                "pedi prestado", "pedí prestado", "credito bancario", "crédito bancario", "prestamo recibido",
                "credito recibido", "prestamo de yape", "prestamo de bcp", "prestamo de plin",
                "prestamo de interbank", "prestamo de bbva", "prestamo de scotiabank", "desembolso", "prestamo yape"
            ]
        ),
        CategoryItem(
            name: "Otros Ingresos",
            iconSymbol: "plus.circle.fill",
            colorHex: "#475569",
            type: .income,
            synonyms: ["ingreso extra", "otros ingresos", "dinero", "cobro extra", "cashback"]
        )
    ]
    
    // MARK: - Paleta de Colores Curada de Alto Contraste y Únicos
    public static let distinctColorPalette: [String] = [
        "#A855F7", "#F43F5E", "#10B981", "#3B82F6", "#F59E0B",
        "#06B6D4", "#EC4899", "#84CC16", "#F97316", "#6366F1",
        "#14B8A6", "#D946EF", "#0284C7", "#E11D48", "#8B5CF6",
        "#EAB308", "#059669", "#7C3AED", "#16A34A", "#FB7185",
        "#0D9488", "#DC2626", "#38BDF8", "#FBBF24", "#34D399",
        "#9333EA", "#C026D3", "#4F46E5", "#2563EB", "#F472B6",
        "#65A30D", "#D97706", "#EA580C", "#BE123C", "#991B1B",
        "#86198F", "#5B21B6", "#1E40AF", "#155E75", "#115E59",
        "#166534", "#3F6212", "#854D0E", "#9A3412", "#9F1239"
    ]
    
    private static func hslToHex(h: Double, s: Double, l: Double) -> String {
        let c = (1.0 - abs(2.0 * l - 1.0)) * s
        let x = c * (1.0 - abs((h * 6.0).truncatingRemainder(dividingBy: 2.0) - 1.0))
        let m = l - c / 2.0
        
        var r = 0.0, g = 0.0, b = 0.0
        let seg = Int(h * 6.0) % 6
        switch seg {
        case 0: (r, g, b) = (c, x, 0)
        case 1: (r, g, b) = (x, c, 0)
        case 2: (r, g, b) = (0, c, x)
        case 3: (r, g, b) = (0, x, c)
        case 4: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        
        let redInt = Int(round((r + m) * 255.0))
        let greenInt = Int(round((g + m) * 255.0))
        let blueInt = Int(round((b + m) * 255.0))
        return String(format: "#%02X%02X%02X", redInt, greenInt, blueInt)
    }
    
    /// Obtiene un color único garantizado que no se repita con ninguna categoría existente
    public static func getNextUniqueColor(for type: TransactionType) -> String {
        let existingColors = Set(
            (expenseCategories + incomeCategories + getCustomCategories())
                .map { $0.colorHex.trimmingCharacters(in: .whitespaces).uppercased() }
        )
        
        for color in distinctColorPalette {
            let upper = color.uppercased()
            if !existingColors.contains(upper) {
                return color
            }
        }
        
        let count = existingColors.count
        let hue = Double((count * 137) % 360) / 360.0
        return hslToHex(h: hue, s: 0.82, l: 0.52)
    }
    
    // MARK: - Categorías Personalizadas en UserDefaults
    private static let customCategoriesKey = "user_custom_categories"
    
    /// Verifica si un nombre de categoría coincide con una categoría predefinida o alguno de sus sinónimos
    public static func isForbiddenOrPredefinedCategory(name: String, type: TransactionType) -> Bool {
        let norm = normalize(name)
        if norm.isEmpty { return true }
        if norm == "comida" || norm == "comidas" || norm == "alimento" || norm == "alimentos" || norm == "pollo" || norm == "sueldo" {
            return true
        }
        let allPredefined = expenseCategories + incomeCategories
        for cat in allPredefined {
            if normalize(cat.name) == norm { return true }
            for syn in cat.synonyms {
                let normSyn = normalize(syn)
                if normSyn == norm || hasWordOrPhrase(normText: norm, normTarget: normSyn) { return true }
            }
        }
        return false
    }
    
    /// Elimina de UserDefaults cualquier categoría personalizada que haya sido creada por error o que colisione con las categorías predefinidas o sus sinónimos (ej: "Comida")
    public static func purgeInvalidCustomCategories() {
        guard let data = UserDefaults.standard.data(forKey: customCategoriesKey),
              var list = try? JSONDecoder().decode([CategoryItem].self, from: data) else {
            return
        }
        let initialCount = list.count
        list.removeAll { isForbiddenOrPredefinedCategory(name: $0.name, type: $0.type) }
        if list.count != initialCount {
            if let cleanedData = try? JSONEncoder().encode(list) {
                UserDefaults.standard.set(cleanedData, forKey: customCategoriesKey)
            }
        }
    }
    
    public static func getCustomCategories() -> [CategoryItem] {
        guard let data = UserDefaults.standard.data(forKey: customCategoriesKey),
              var list = try? JSONDecoder().decode([CategoryItem].self, from: data) else {
            return []
        }
        // Limpiar cualquier categoría que coincida con predefinidas o sinónimos
        let initialCount = list.count
        list.removeAll { isForbiddenOrPredefinedCategory(name: $0.name, type: $0.type) }
        if list.count != initialCount {
            if let cleanedData = try? JSONEncoder().encode(list) {
                UserDefaults.standard.set(cleanedData, forKey: customCategoriesKey)
            }
        }
        return list
    }
    
    public static func isCustomCategory(_ category: CategoryItem) -> Bool {
        if isForbiddenOrPredefinedCategory(name: category.name, type: category.type) {
            return false
        }
        let custom = getCustomCategories()
        return custom.contains(where: {
            $0.id == category.id || ($0.name.caseInsensitiveCompare(category.name) == .orderedSame && $0.type == category.type)
        })
    }
    
    public static func isCustomCategory(name: String, type: TransactionType? = nil) -> Bool {
        if let type = type, isForbiddenOrPredefinedCategory(name: name, type: type) {
            return false
        }
        let custom = getCustomCategories()
        if let type = type {
            return custom.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame && $0.type == type })
        }
        return custom.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })
    }
    
    @discardableResult
    public static func deleteCustomCategory(name: String, type: TransactionType? = nil) -> Bool {
        var current = getCustomCategories()
        let initialCount = current.count
        if let type = type {
            current.removeAll(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame && $0.type == type })
        } else {
            current.removeAll(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })
        }
        guard current.count != initialCount else { return false }
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: customCategoriesKey)
        }
        return true
    }
    
    @discardableResult
    public static func addCustomCategory(name: String, type: TransactionType, iconSymbol: String = "tag.fill", colorHex: String? = nil) -> CategoryItem {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // Si coincide con una categoría predefinida o sinónimo, jamás duplicar ni crear
        let resolved = resolveCategory(nameOrKeyword: trimmed, type: type)
        let base = (type == .expense) ? expenseCategories : incomeCategories
        if let existingBase = base.first(where: { $0.name.caseInsensitiveCompare(resolved) == .orderedSame }) {
            return existingBase
        }
        
        var current = getCustomCategories()
        if let existing = current.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame && $0.type == type }) {
            return existing
        }
        
        let finalColor = colorHex ?? getNextUniqueColor(for: type)
        let newCat = CategoryItem(name: trimmed, iconSymbol: iconSymbol, colorHex: finalColor, type: type, synonyms: [normalize(trimmed)])
        current.append(newCat)
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: customCategoriesKey)
        }
        return newCat
    }
    
    public static func allCategories(for type: TransactionType) -> [CategoryItem] {
        let base = (type == .expense) ? expenseCategories : incomeCategories
        let custom = getCustomCategories().filter { $0.type == type }
        var result = base
        for c in custom {
            if !isForbiddenOrPredefinedCategory(name: c.name, type: type),
               !result.contains(where: { $0.name.caseInsensitiveCompare(c.name) == .orderedSame }) {
                result.append(c)
            }
        }
        return result
    }
    
    /// Devuelve todas las categorías disponibles para Gastos Fijos (categorías base de gastos + únicamente las categorías personalizadas de tipo gasto creadas por el usuario)
    public static func allCategoriesForFixedExpenses() -> [CategoryItem] {
        var result = expenseCategories
        let custom = getCustomCategories().filter { $0.type == .expense }
        for c in custom {
            if !isForbiddenOrPredefinedCategory(name: c.name, type: .expense),
               !result.contains(where: { $0.name.caseInsensitiveCompare(c.name) == .orderedSame }) {
                result.append(c)
            }
        }
        return result
    }
    
    public static func normalize(_ text: String) -> String {
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "es_PE"))
            .lowercased()
    }
    
    /// Resuelve de forma infalible una categoría garantizando que SIEMPRE devuelva una categoría
    /// predefinida oficial (o personalizada explícitamente por el usuario).
    /// Si recibe sinónimos como "comida", "comprar un pollo", "pollo", "almuerzo", "cena", etc.,
    /// devolverá SIEMPRE la categoría oficial "Alimentación" con ícono fork.knife. NUNCA crea categorías automáticas.
    public static func resolveCategory(nameOrKeyword: String, type: TransactionType) -> String {
        let trimmed = nameOrKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return (type == .income) ? "Otros Ingresos" : "Otros"
        }
        
        if trimmed.caseInsensitiveCompare("Transferencia") == .orderedSame {
            return "Transferencia"
        }
        
        let norm = normalize(trimmed)
        let base = (type == .expense) ? expenseCategories : incomeCategories
        
        // 1. Coincidencia exacta de nombre con categorías predefinidas oficiales del tipo
        if let exactBase = base.first(where: {
            $0.name.caseInsensitiveCompare(trimmed) == .orderedSame || normalize($0.name) == norm
        }) {
            return exactBase.name
        }
        
        // 2. Coincidencia exacta con sinónimos de las categorías predefinidas del tipo
        for cat in base {
            for syn in cat.synonyms {
                let normSyn = normalize(syn)
                if norm == normSyn {
                    return cat.name
                }
            }
        }
        
        // 3. Coincidencia por palabra o frase en los sinónimos predefinidos (ordenados de más largos a más cortos)
        for cat in base {
            let sortedSynonyms = cat.synonyms.sorted { $0.count > $1.count }
            for syn in sortedSynonyms {
                let normSyn = normalize(syn)
                if hasWordOrPhrase(normText: norm, normTarget: normSyn) || norm.contains(normSyn) {
                    return cat.name
                }
            }
        }
        
        // 4. Buscar en las categorías predefinidas oficiales del tipo opuesto (por si se infirió tipo invertido)
        let otherType: TransactionType = (type == .expense) ? .income : .expense
        let otherBase = (otherType == .expense) ? expenseCategories : incomeCategories
        
        if let exactOtherBase = otherBase.first(where: {
            $0.name.caseInsensitiveCompare(trimmed) == .orderedSame || normalize($0.name) == norm
        }) {
            return exactOtherBase.name
        }
        
        for cat in otherBase {
            let sortedSynonyms = cat.synonyms.sorted { $0.count > $1.count }
            for syn in sortedSynonyms {
                let normSyn = normalize(syn)
                if norm == normSyn || hasWordOrPhrase(normText: norm, normTarget: normSyn) || norm.contains(normSyn) {
                    return cat.name
                }
            }
        }
        
        // 5. Coincidencia con categorías personalizadas creadas explícitamente por el usuario
        // (descartando estrictamente cualquier categoría prohibida o duplicada de predefinidas)
        let custom = getCustomCategories().filter { $0.type == type && !isForbiddenOrPredefinedCategory(name: $0.name, type: type) }
        if let exactCustom = custom.first(where: {
            $0.name.caseInsensitiveCompare(trimmed) == .orderedSame || normalize($0.name) == norm
        }) {
            return exactCustom.name
        }
        
        let otherCustom = getCustomCategories().filter { $0.type == otherType && !isForbiddenOrPredefinedCategory(name: $0.name, type: otherType) }
        if let exactOtherCustom = otherCustom.first(where: {
            $0.name.caseInsensitiveCompare(trimmed) == .orderedSame || normalize($0.name) == norm
        }) {
            return exactOtherCustom.name
        }
        
        // 6. Fallback seguro: Jamás inventar categorías en automático, usar Otros / Otros Ingresos
        return (type == .income) ? "Otros Ingresos" : "Otros"
    }
    
    public static func getCategoryIcon(name: String, type: TransactionType) -> String {
        if name.caseInsensitiveCompare("Transferencia") == .orderedSame {
            return "arrow.left.arrow.right"
        }
        let resolved = resolveCategory(nameOrKeyword: name, type: type)
        let list = allCategories(for: type)
        if let found = list.first(where: { $0.name.caseInsensitiveCompare(resolved) == .orderedSame }) {
            return found.iconSymbol
        }
        // Buscar también en el otro tipo por si es una categoría personalizada creada en ingreso/gasto
        let otherType: TransactionType = (type == .expense) ? .income : .expense
        let otherList = allCategories(for: otherType)
        if let foundOther = otherList.first(where: { $0.name.caseInsensitiveCompare(resolved) == .orderedSame }) {
            return foundOther.iconSymbol
        }
        return (type == .expense) ? "ellipsis.circle.fill" : "plus.circle.fill"
    }
    
    public static func getCategoryColorHex(name: String, type: TransactionType) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return (type == .expense) ? "#F43F5E" : "#10B981"
        }
        if trimmed.caseInsensitiveCompare("Transferencia") == .orderedSame {
            return "#38BDF8"
        }
        let resolved = resolveCategory(nameOrKeyword: trimmed, type: type)
        let list = allCategories(for: type)
        if let found = list.first(where: { $0.name.caseInsensitiveCompare(resolved) == .orderedSame }) {
            return found.colorHex
        }
        // Buscar también en el otro tipo por si es una categoría personalizada creada en ingreso/gasto
        let otherType: TransactionType = (type == .expense) ? .income : .expense
        let otherList = allCategories(for: otherType)
        if let foundOther = otherList.first(where: { $0.name.caseInsensitiveCompare(resolved) == .orderedSame }) {
            return foundOther.colorHex
        }
        // Jamás registrar categorías en automático. Usar color de Otros / Otros Ingresos
        return (type == .expense) ? "#64748B" : "#475569"
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
