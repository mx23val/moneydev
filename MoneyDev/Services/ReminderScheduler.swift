import Foundation
import UserNotifications
import UIKit

public enum ReminderScheduler {
    public static let dailyReminderIdentifier = "moneydev_daily_reminder"
    public static let dailyReminderMorningIdentifier = "moneydev_daily_reminder_morning"
    public static let dailyReminderEveningIdentifier = "moneydev_daily_reminder_evening"
    public static let fixedExpenseCategory = "moneydev_fixed_expense"
    
    
    public static func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("ReminderScheduler: Error solicitando permisos: \(error)")
            return false
        }
    }
    
    public static func checkNotificationPermission() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }
    
    /// Actualiza los recordatorios diarios validando las transacciones de cada día:
    /// - 9:00 AM: se envía si no se registró ningún movimiento antes de las 9:00 AM en el día.
    /// - 5:00 PM: se envía si no se registró ningún movimiento antes de las 5:00 PM en el día.
    /// - Si se registró antes de las 9 AM, no sale ni a las 9 AM ni a las 5 PM.
    /// - Si se registró entre 9 AM y 5 PM (ej. 3 PM), a las 5 PM ya no sale.
    /// - Si no se registró nada en el día, salen ambas (9 AM y 5 PM).
    public static func updateDailyReminders(transactions: [Transaction], notificationsEnabled: Bool) {
        let center = UNUserNotificationCenter.current()
        
        Task { @MainActor in
            await AppIconManager.synchronizeAppIcon()
        }
        
        guard notificationsEnabled else {
            cancelDailyReminder()
            return
        }
        
        center.getPendingNotificationRequests { requests in
            let dailyIds = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix("moneydev_daily_reminder") }
            
            var allIdsToRemove = Set(dailyIds)
            allIdsToRemove.insert(dailyReminderIdentifier)
            allIdsToRemove.insert(dailyReminderMorningIdentifier)
            allIdsToRemove.insert(dailyReminderEveningIdentifier)
            
            center.removePendingNotificationRequests(withIdentifiers: Array(allIdsToRemove))
            
            let cal = Calendar(identifier: .gregorian)
            let now = Date()
            
            // Programar para hoy y los siguientes 7 días validando cada fecha
            for dayOffset in 0...7 {
                guard let targetDay = cal.date(byAdding: .day, value: dayOffset, to: now) else { continue }
                let comp = cal.dateComponents([.year, .month, .day], from: targetDay)
                guard let targetDateAtStart = cal.date(from: comp),
                      let target9AM = cal.date(bySettingHour: 9, minute: 0, second: 0, of: targetDateAtStart),
                      let target5PM = cal.date(bySettingHour: 17, minute: 0, second: 0, of: targetDateAtStart) else {
                    continue
                }
                
                let dateKey = String(format: "%04d%02d%02d", comp.year ?? 0, comp.month ?? 0, comp.day ?? 0)
                
                // Movimientos registrados en este día específico
                let dayTransactions = transactions.filter { tx in
                    let txDate = Date(timeIntervalSince1970: Double(tx.dateMillis) / 1000.0)
                    return cal.isDate(txDate, inSameDayAs: targetDateAtStart)
                }
                
                let hasMovementBefore9AM = dayTransactions.contains { tx in
                    let txDate = Date(timeIntervalSince1970: Double(tx.dateMillis) / 1000.0)
                    return txDate < target9AM
                }
                
                let hasMovementBefore5PM = dayTransactions.contains { tx in
                    let txDate = Date(timeIntervalSince1970: Double(tx.dateMillis) / 1000.0)
                    return txDate < target5PM
                }
                
                // 1. Notificación 9:00 AM (Solo si no hubo registro antes de las 9:00 AM)
                if !hasMovementBefore9AM && target9AM > now {
                    let morningContent = UNMutableNotificationContent()
                    morningContent.title = "¡Buenos días! Mantén tu balance al día ☀️"
                    morningContent.body = "¿Hiciste algún pago o compras esta mañana? Recuerda registrar tus gastos para un control perfecto."
                    morningContent.sound = .default
                    
                    let morningComponents = cal.dateComponents([.year, .month, .day, .hour, .minute], from: target9AM)
                    let morningTrigger = UNCalendarNotificationTrigger(dateMatching: morningComponents, repeats: false)
                    let morningRequest = UNNotificationRequest(
                        identifier: "\(dailyReminderMorningIdentifier)_\(dateKey)",
                        content: morningContent,
                        trigger: morningTrigger
                    )
                    center.add(morningRequest) { error in
                        if let error {
                            print("ReminderScheduler: Error programando recordatorio 9 AM (\(dateKey)): \(error)")
                        }
                    }
                }
                
                // 2. Notificación 5:00 PM (Solo si no hubo registro antes de las 5:00 PM en el día)
                if !hasMovementBefore5PM && target5PM > now {
                    let eveningContent = UNMutableNotificationContent()
                    eveningContent.title = "¿Tuviste gastos hoy? 💸"
                    eveningContent.body = "Aún estás a tiempo de registrar tus movimientos del día. ¡Solo toma unos segundos!"
                    eveningContent.sound = .default
                    
                    let eveningComponents = cal.dateComponents([.year, .month, .day, .hour, .minute], from: target5PM)
                    let eveningTrigger = UNCalendarNotificationTrigger(dateMatching: eveningComponents, repeats: false)
                    let eveningRequest = UNNotificationRequest(
                        identifier: "\(dailyReminderEveningIdentifier)_\(dateKey)",
                        content: eveningContent,
                        trigger: eveningTrigger
                    )
                    center.add(eveningRequest) { error in
                        if let error {
                            print("ReminderScheduler: Error programando recordatorio 5 PM (\(dateKey)): \(error)")
                        }
                    }
                }
            }
        }
    }
    
    public static func scheduleDailyReminder(transactions: [Transaction] = []) {
        updateDailyReminders(transactions: transactions, notificationsEnabled: true)
    }
    
    public static func cancelDailyReminder() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let dailyIds = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix("moneydev_daily_reminder") }
            
            var allIds = Set(dailyIds)
            allIds.insert(dailyReminderIdentifier)
            allIds.insert(dailyReminderMorningIdentifier)
            allIds.insert(dailyReminderEveningIdentifier)
            center.removePendingNotificationRequests(withIdentifiers: Array(allIds))
        }
    }
    
    public static func scheduleFixedExpenseNotification(
        id: Int64,
        name: String,
        amount: Double,
        currency: String,
        dueDate: Date,
        isOneDayBefore: Bool
    ) {
        let identifier = "moneydev_fixed_expense_\(id)"
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = FixedExpenseDateHelper.peruTimeZone
        
        let notifyDate: Date
        if isOneDayBefore {
            notifyDate = cal.date(byAdding: .day, value: -1, to: dueDate) ?? dueDate
        } else {
            notifyDate = dueDate
        }
        
        // Si la fecha ya pasó, no se programa
        if notifyDate <= Date() { return }
        
        let content = UNMutableNotificationContent()
        let formattedAmount = String(format: "%.2f", amount)
        
        if isOneDayBefore {
            content.title = "⏰ Mañana vence tu gasto fijo: \(name)"
            content.body = "Recuerda que mañana debes abonar \(currency) \(formattedAmount) para \(name). ¡Anticípate y mantén tus cuentas al día!"
        } else {
            content.title = "⏰ Hoy vence tu pago de gasto fijo: \(name)"
            content.body = "Hoy es el día de pago para \(name) (\(currency) \(formattedAmount)). Abre MoneyDev y registra tu pago para mantener tu balance actualizado."
        }
        content.sound = .default
        
        var comp = cal.dateComponents([.year, .month, .day], from: notifyDate)
        comp.hour = 9
        comp.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: comp, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error {
                print("ReminderScheduler: Error programando gasto fijo \(name): \(error)")
            }
        }
    }
    
    public static func cancelFixedExpenseNotification(id: Int64) {
        let identifier = "moneydev_fixed_expense_\(id)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
