import SwiftUI

public struct FixedExpensesDialog: View {
    @Bindable var viewModel: ExpenseViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var isAddSheetOpen: Bool = false
    @State private var expenseNameToEdit: FixedExpense? = nil
    @State private var alertMessage: String? = nil
    @State private var showAlert: Bool = false
    
    public init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AppColors.midnightBlack.ignoresSafeArea()
                
                if viewModel.fixedExpenses.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 56))
                            .foregroundStyle(Color(hex: "#38BDF8").opacity(0.8))
                        
                        Text("No tienes gastos fijos programados")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                        
                        Text("Agrega suscripciones, servicios, alquiler o préstamos para que MoneyDev te avise puntualmente.")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        Button {
                            isAddSheetOpen = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                Text("Nuevo Gasto Fijo")
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#38BDF8"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.top, 10)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(viewModel.fixedExpenses) { expense in
                                FixedExpenseRow(expense: expense, currencySymbol: viewModel.financialSummary.currencySymbol) {
                                    registerPayment(for: expense)
                                } onDelete: {
                                    deleteExpense(expense)
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Gastos Fijos (\(viewModel.fixedExpenses.count)/30)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") {
                        viewModel.closeFixedExpensesDialog()
                        dismiss()
                    }
                    .foregroundStyle(AppColors.textSecondary)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddSheetOpen = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color(hex: "#38BDF8"))
                    }
                }
            }
            .sheet(isPresented: $isAddSheetOpen) {
                AddEditFixedExpenseSheet(viewModel: viewModel)
            }
            .alert("Gastos Fijos", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }
    
    private func registerPayment(for expense: FixedExpense) {
        let (success, message) = viewModel.registerFixedExpensePayment(expense)
        alertMessage = message
        showAlert = true
    }
    
    private func deleteExpense(_ expense: FixedExpense) {
        _ = viewModel.deleteFixedExpense(expense.id)
    }
}

// MARK: - Row Component
struct FixedExpenseRow: View {
    let expense: FixedExpense
    let currencySymbol: String
    let onPay: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(expense.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                    
                    Text(FixedExpenseDateHelper.getFrequencyDescription(expense: expense))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "#38BDF8"))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(currencySymbol) \(FormatHelper.formatCurrency(expense.amount))")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(AppColors.expenseRoseLight)
                    
                    Text(expense.category)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.textMuted)
                }
            }
            
            Divider().background(AppColors.cardBorderNavy)
            
            HStack {
                // Next due date
                let nextDue = FixedExpenseDateHelper.getNextDueDate(expense: expense)
                let dateStr = DateFormatter.localizedString(from: nextDue, dateStyle: .short, timeStyle: .none)
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                    Text("Vence: \(dateStr)")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(AppColors.textSecondary)
                
                Spacer()
                
                // Botón Registrar Pago
                Button(action: onPay) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Registrar Pago")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.incomeEmerald)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.expenseRose)
                        .padding(6)
                        .background(AppColors.expenseBg.opacity(0.5))
                        .clipShape(Circle())
                }
            }
        }
        .padding(14)
        .background(AppColors.darkNavySurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.cardBorderNavy, lineWidth: 1)
        )
    }
}

// MARK: - Add/Edit Fixed Expense Sheet
struct AddEditFixedExpenseSheet: View {
    @Bindable var viewModel: ExpenseViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var amountString: String = ""
    @State private var category: String = "Servicios"
    @State private var frequency: FixedExpenseFrequency = .monthly
    @State private var dayOfWeek: Int = 1
    @State private var dayOfMonth: Int = 1
    @State private var monthOfYear: Int = 1
    @State private var notifyTiming: FixedExpenseNotifyTiming = .sameDay
    @State private var notificationsEnabled: Bool = true
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.midnightBlack.ignoresSafeArea()
                
                Form {
                    Section("Datos Principales") {
                        TextField("Nombre del servicio o pago (ej: Netflix)", text: $name)
                            .foregroundStyle(AppColors.textPrimary)
                        
                        TextField("Monto (ej: 45.00)", text: $amountString)
                            .keyboardType(.decimalPad)
                            .foregroundStyle(AppColors.textPrimary)
                        
                        Picker("Categoría", selection: $category) {
                            ForEach(CategoryHelper.expenseCategories) { cat in
                                Text(cat.name).tag(cat.name)
                            }
                        }
                    }
                    .listRowBackground(AppColors.darkNavySurface)
                    
                    Section("Frecuencia y Fecha de Vencimiento") {
                        Picker("Frecuencia", selection: $frequency) {
                            ForEach(FixedExpenseFrequency.allCases, id: \.self) { freq in
                                Text(freq.displayName).tag(freq)
                            }
                        }
                        
                        if frequency == .weekly {
                            Picker("Día de la semana", selection: $dayOfWeek) {
                                ForEach(1...7, id: \.self) { day in
                                    Text(FixedExpenseDateHelper.daysOfWeekNames[day - 1]).tag(day)
                                }
                            }
                        }
                        
                        if frequency == .monthly || frequency == .yearly {
                            let maxDays = frequency == .yearly ? FixedExpenseDateHelper.getMaxSelectableDaysForYearlyMonth(monthOfYear) : 31
                            Picker("Día del mes", selection: $dayOfMonth) {
                                ForEach(1...maxDays, id: \.self) { day in
                                    Text("Día \(day)").tag(day)
                                }
                            }
                        }
                        
                        if frequency == .yearly {
                            Picker("Mes", selection: $monthOfYear) {
                                ForEach(1...12, id: \.self) { m in
                                    Text(FixedExpenseDateHelper.monthsNames[m - 1]).tag(m)
                                }
                            }
                        }
                    }
                    .listRowBackground(AppColors.darkNavySurface)
                    
                    Section("Notificaciones") {
                        Toggle("Activar recordatorios", isOn: $notificationsEnabled)
                        
                        Picker("Avisarme", selection: $notifyTiming) {
                            ForEach(FixedExpenseNotifyTiming.allCases, id: \.self) { t in
                                Text(t.displayName).tag(t)
                            }
                        }
                    }
                    .listRowBackground(AppColors.darkNavySurface)
                    
                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppColors.expenseRoseLight)
                        }
                        .listRowBackground(AppColors.expenseBg.opacity(0.4))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Nuevo Gasto Fijo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(AppColors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") { saveFixedExpense() }
                        .font(.headline)
                        .foregroundStyle(Color(hex: "#38BDF8"))
                }
            }
        }
    }
    
    private func saveFixedExpense() {
        let cleanAmount = amountString.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let amount = Double(cleanAmount), amount > 0 else {
            errorMessage = "Ingresa un monto válido mayor a 0."
            return
        }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "El nombre no puede estar vacío."
            return
        }
        
        let newExpense = FixedExpense(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            category: category,
            frequency: frequency,
            dayOfWeek: dayOfWeek,
            dayOfMonth: dayOfMonth,
            monthOfYear: monthOfYear,
            notifyTiming: notifyTiming,
            notificationsEnabled: notificationsEnabled
        )
        
        let (success, msg) = viewModel.addFixedExpense(newExpense)
        if success {
            dismiss()
        } else {
            errorMessage = msg
        }
    }
}
