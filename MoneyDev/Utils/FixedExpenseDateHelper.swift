import Foundation

public enum FixedExpenseDateHelper {
    public static let peruTimeZone: TimeZone = TimeZone(identifier: "America/Lima") ?? TimeZone(secondsFromGMT: -5 * 3600)!
    
    public static let daysOfWeekNames = [
        "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"
    ]
    
    public static let monthsNames = [
        "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
        "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"
    ]
    
    public static func isLeapYear(_ year: Int) -> Bool {
        return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
    }
    
    public static func getMaxDaysInMonth(year: Int, month1Indexed: Int) -> Int {
        switch month1Indexed {
        case 1, 3, 5, 7, 8, 10, 12:
            return 31
        case 2:
            return isLeapYear(year) ? 29 : 28
        case 4, 6, 9, 11:
            return 30
        default:
            return 31
        }
    }
    
    public static func getMaxSelectableDaysForYearlyMonth(_ month1Indexed: Int) -> Int {
        switch month1Indexed {
        case 2:
            return 28 // Especificación MoneyDev: en selector anual para febrero, máximo 28
        case 4, 6, 9, 11:
            return 30
        default:
            return 31
        }
    }
    
    public static func getEffectiveDueDayForMonth(targetDay: Int, year: Int, month1Indexed: Int) -> Int {
        let maxDays = getMaxDaysInMonth(year: year, month1Indexed: month1Indexed)
        return targetDay > maxDays ? maxDays : targetDay
    }
    
    public static func getEffectiveYearlyDueDay(targetDay: Int, targetMonth: Int, year: Int) -> Int {
        if targetMonth == 2 && targetDay == 28 && isLeapYear(year) {
            return 27 // Especificación MoneyDev: año bisiesto con 28 de feb asigna al 27
        }
        let maxDays = getMaxDaysInMonth(year: year, month1Indexed: targetMonth)
        return targetDay > maxDays ? maxDays : targetDay
    }
    
    public static func getNextDueDate(expense: FixedExpense, fromDate: Date = Date()) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = peruTimeZone
        
        var comp = cal.dateComponents([.year, .month, .day, .weekday], from: fromDate)
        comp.hour = 9
        comp.minute = 0
        comp.second = 0
        
        guard var due = cal.date(from: comp) else { return fromDate }
        
        switch expense.frequency {
        case .daily:
            return due
            
        case .everyTwoDays:
            let anchor = Date(timeIntervalSince1970: Double(expense.createdAt) / 1000.0)
            let diffDays = cal.dateComponents([.day], from: anchor, to: due).day ?? 0
            if diffDays % 2 != 0 {
                due = cal.date(byAdding: .day, value: 1, to: due) ?? due
            }
            return due
            
        case .weekly:
            let targetWeekday = (expense.dayOfWeek % 7) + 1 // Convert 1=Mon..7=Sun to 1=Sun..7=Sat
            let currentWeekday = cal.component(.weekday, from: due)
            var daysUntil = targetWeekday - currentWeekday
            if daysUntil < 0 { daysUntil += 7 }
            return cal.date(byAdding: .day, value: daysUntil, to: due) ?? due
            
        case .monthly:
            let currentYear = cal.component(.year, from: due)
            let currentMonth = cal.component(.month, from: due)
            let effectiveDay = getEffectiveDueDayForMonth(targetDay: expense.dayOfMonth, year: currentYear, month1Indexed: currentMonth)
            
            var monthComp = cal.dateComponents([.year, .month], from: due)
            monthComp.day = effectiveDay
            monthComp.hour = 9
            monthComp.minute = 0
            monthComp.second = 0
            
            if let monthDate = cal.date(from: monthComp) {
                if monthDate < fromDate && !cal.isDate(monthDate, inSameDayAs: fromDate) {
                    return cal.date(byAdding: .month, value: 1, to: monthDate) ?? monthDate
                }
                return monthDate
            }
            return due
            
        case .yearly:
            let currentYear = cal.component(.year, from: due)
            let targetMonth = max(1, min(12, expense.monthOfYear))
            let effectiveDay = getEffectiveYearlyDueDay(targetDay: expense.dayOfMonth, targetMonth: targetMonth, year: currentYear)
            
            var yearComp = DateComponents()
            yearComp.year = currentYear
            yearComp.month = targetMonth
            yearComp.day = effectiveDay
            yearComp.hour = 9
            yearComp.minute = 0
            yearComp.second = 0
            
            if var yearDate = cal.date(from: yearComp) {
                if yearDate < fromDate && !cal.isDate(yearDate, inSameDayAs: fromDate) {
                    yearDate = cal.date(byAdding: .year, value: 1, to: yearDate) ?? yearDate
                }
                return yearDate
            }
            return due
        }
    }
    
    public static func shouldNotifyToday(expense: FixedExpense, todayDate: Date = Date()) -> Bool {
        guard expense.notificationsEnabled else { return false }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = peruTimeZone
        
        let nextDue = getNextDueDate(expense: expense, fromDate: todayDate)
        
        switch expense.notifyTiming {
        case .oneDayBefore:
            guard let dayBefore = cal.date(byAdding: .day, value: -1, to: nextDue) else { return false }
            return cal.isDate(todayDate, inSameDayAs: dayBefore)
        case .sameDay:
            return cal.isDate(todayDate, inSameDayAs: nextDue)
        }
    }
    
    public static func isExpensePaidForCurrentCycle(
        expense: FixedExpense,
        transactions: [Transaction],
        currentDate: Date = Date()
    ) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = peruTimeZone
        
        // 1. Verificación por botón directo "Registrar Pago"
        if expense.lastPaidDateMillis > 0 {
            let lastPaid = Date(timeIntervalSince1970: Double(expense.lastPaidDateMillis) / 1000.0)
            if isSamePeriod(expense: expense, d1: lastPaid, d2: currentDate, cal: cal) {
                return true
            }
        }
        
        // 2. Verificación si ya hay un gasto coincidente en la billetera
        let normName = CategoryHelper.normalize(expense.name)
        let hasMatching = transactions.contains { tx in
            guard tx.type == .expense else { return false }
            let txDate = Date(timeIntervalSince1970: Double(tx.dateMillis) / 1000.0)
            guard isSamePeriod(expense: expense, d1: txDate, d2: currentDate, cal: cal) else { return false }
            
            let normTitle = CategoryHelper.normalize(tx.title)
            let isNameMatch = normTitle.contains(normName) || normName.contains(normTitle)
            let isAmountMatch = abs(tx.amount - expense.amount) < 0.01
            return isNameMatch && isAmountMatch
        }
        return hasMatching
    }
    
    private static func isSamePeriod(expense: FixedExpense, d1: Date, d2: Date, cal: Calendar) -> Bool {
        switch expense.frequency {
        case .daily:
            return cal.isDate(d1, inSameDayAs: d2)
        case .everyTwoDays:
            let diff = cal.dateComponents([.day], from: d1, to: d2).day ?? 0
            return abs(diff) < 2
        case .weekly:
            return cal.component(.yearForWeekOfYear, from: d1) == cal.component(.yearForWeekOfYear, from: d2) &&
                   cal.component(.weekOfYear, from: d1) == cal.component(.weekOfYear, from: d2)
        case .monthly:
            return cal.component(.year, from: d1) == cal.component(.year, from: d2) &&
                   cal.component(.month, from: d1) == cal.component(.month, from: d2)
        case .yearly:
            return cal.component(.year, from: d1) == cal.component(.year, from: d2)
        }
    }
    
    public static func getFrequencyDescription(expense: FixedExpense) -> String {
        switch expense.frequency {
        case .daily:
            return "Diario"
        case .everyTwoDays:
            return "Interdiario"
        case .weekly:
            let dayName = daysOfWeekNames[safe: expense.dayOfWeek - 1] ?? "Lunes"
            return "Semanal (cada \(dayName))"
        case .monthly:
            return "Mensual (día \(expense.dayOfMonth))"
        case .yearly:
            let monthName = monthsNames[safe: expense.monthOfYear - 1] ?? "Enero"
            return "Anual (\(expense.dayOfMonth) de \(monthName))"
        }
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
