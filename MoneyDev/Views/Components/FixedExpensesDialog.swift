import SwiftUI

public struct FixedExpensesDialog: View {
    @Bindable var viewModel: ExpenseViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var isAddSheetOpen: Bool = false
    @State private var showRankingSummary: Bool = false
    @State private var expenseToEdit: FixedExpense? = nil
    @State private var expenseToDelete: FixedExpense? = nil
    @State private var showDeleteConfirmation: Bool = false
    
    // Notificación Toast aislada localmente para este diálogo
    @State private var dialogToast: ExpenseViewModel.FloatingToastData? = nil
    
    private var activeTheme: AppColorTheme {
        viewModel.activeTheme
    }

    public init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                ThemedModalBackground(theme: activeTheme)
                
                if viewModel.fixedExpenses.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 56))
                            .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentIconColor)
                        
                        Text("No tienes gastos fijos programados")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.white)
                            .contrastTextOutline()
                        
                        Text("Agrega suscripciones, servicios, alquiler o préstamos para que MoneyDev te avise puntualmente.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.8))
                            .contrastTextOutline()
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        Button {
                            isAddSheetOpen = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .black))
                                Text("Nuevo Gasto Fijo")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundStyle(activeTheme == .electricBlack ? Color.black : activeTheme.onPrimaryText)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: activeTheme == .electricBlack ? [Color.white, Color(hex: "#E2E8F0")] : activeTheme.gradient,
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .shadow(color: activeTheme.primary.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .padding(.top, 10)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(viewModel.fixedExpenses) { expense in
                                FixedExpenseRow(
                                    expense: expense,
                                    wallets: viewModel.wallets,
                                    currencySymbol: viewModel.financialSummary.currencySymbol,
                                    theme: activeTheme,
                                    onPay: {
                                        registerPayment(for: expense)
                                    },
                                    onEdit: {
                                        expenseToEdit = expense
                                    },
                                    onDelete: {
                                        expenseToDelete = expense
                                        showDeleteConfirmation = true
                                    }
                                )
                            }
                        }
                        .padding(16)
                    }
                }
                
                // Notificación Flotante Superior (Aislada exclusivamente dentro de esta ventana)
                if let toast = dialogToast {
                    VStack {
                        FloatingToastView(toast: toast, theme: activeTheme) {
                            withAnimation(.easeOut(duration: 0.25)) {
                                dialogToast = nil
                            }
                        }
                        .padding(.top, 6)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(200)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Gastos Fijos (\(viewModel.fixedExpenses.count)/30)")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.white)
                        .contrastTextOutline()
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") {
                        closeDialog()
                    }
                    .foregroundStyle(Color.white)
                    .contrastTextOutline()
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 14) {
                        Button {
                            showRankingSummary = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentIconColor)
                        }
                        .accessibilityLabel("Ver gastos fijos ordenados de mayor a menor y monto total")
                        
                        Button {
                            isAddSheetOpen = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentIconColor)
                        }
                        .accessibilityLabel("Agregar nuevo gasto fijo")
                    }
                }
            }
            .sheet(isPresented: $showRankingSummary) {
                FixedExpensesRankingSummarySheet(viewModel: viewModel)
                    .themedSheetContainer(theme: activeTheme)
            }
            .sheet(isPresented: $isAddSheetOpen) {
                AddEditFixedExpenseSheet(viewModel: viewModel) { createdName in
                    showDialogToast(
                        title: "¡Gasto Fijo Guardado!",
                        message: "Se registró '\(createdName)' correctamente.",
                        isSuccess: true
                    )
                }
                .themedSheetContainer(theme: activeTheme)
            }
            .sheet(item: $expenseToEdit) { expense in
                AddEditFixedExpenseSheet(viewModel: viewModel, expenseToEdit: expense) { updatedName in
                    showDialogToast(
                        title: "¡Gasto Fijo Actualizado!",
                        message: "Se actualizó '\(updatedName)' correctamente.",
                        isSuccess: true
                    )
                }
                .themedSheetContainer(theme: activeTheme)
            }
            .alert("¿Eliminar Gasto Fijo?", isPresented: $showDeleteConfirmation, presenting: expenseToDelete) { expense in
                Button("Eliminar", role: .destructive) {
                    deleteExpense(expense)
                }
                Button("Cancelar", role: .cancel) {
                    expenseToDelete = nil
                }
            } message: { expense in
                Text("¿Estás seguro de que deseas eliminar '\(expense.name)'? Se cancelarán los recordatorios asociados.")
            }
            .onDisappear {
                dialogToast = nil
                viewModel.closeFixedExpensesDialog()
            }
        }
    }
    
    private func closeDialog() {
        dialogToast = nil
        viewModel.closeFixedExpensesDialog()
        dismiss()
    }
    
    private func registerPayment(for expense: FixedExpense) {
        let (success, message) = viewModel.registerFixedExpensePayment(expense)
        showDialogToast(
            title: success ? "¡Pago Registrado!" : "Aviso de Pago",
            message: message,
            isSuccess: success
        )
    }
    
    private func deleteExpense(_ expense: FixedExpense) {
        let (success, message) = viewModel.deleteFixedExpense(expense.id)
        showDialogToast(
            title: success ? "Gasto Fijo Eliminado" : "Error al Eliminar",
            message: success ? "Se eliminó '\(expense.name)' correctamente." : message,
            isSuccess: success
        )
        expenseToDelete = nil
    }
    
    private func showDialogToast(title: String, message: String, isSuccess: Bool, duration: Double = 3.5) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            dialogToast = ExpenseViewModel.FloatingToastData(title: title, message: message, isSuccess: isSuccess)
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.25)) {
                    dialogToast = nil
                }
            }
        }
    }
}

// MARK: - Row Component (Sin bordes, con sombreado y alto contraste)
struct FixedExpenseRow: View {
    let expense: FixedExpense
    let wallets: [Wallet]
    let currencySymbol: String
    var theme: AppColorTheme = .electricBlue
    let onPay: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private static let dueDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.timeZone = FixedExpenseDateHelper.peruTimeZone
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    var body: some View {
        let isPaidCycle = FixedExpenseDateHelper.isPaidForCurrentPeriod(expense: expense)
        let nextDue = FixedExpenseDateHelper.getNextDueDate(expense: expense)
        let dateStr = Self.dueDateFormatter.string(from: nextDue)
        let assignedWallet = wallets.first(where: { $0.id == expense.walletId })
        let catIcon = CategoryHelper.getCategoryIcon(name: expense.category, type: .expense)
        let catColor = CategoryHelper.getCategoryColor(name: expense.category, type: .expense)
        
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(expense.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)
                        .contrastTextOutline()
                    
                    HStack(spacing: 6) {
                        Text(FixedExpenseDateHelper.getFrequencyDescription(expense: expense))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme == .electricBlack ? Color.white : theme.accentTextColor)
                            .contrastTextOutline()
                        
                        // Etiqueta de la billetera asignada
                        if let wallet = assignedWallet {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: wallet.colorHex))
                                    .frame(width: 6, height: 6)
                                Text(wallet.name)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.white)
                                    .contrastTextOutline()
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color(hex: wallet.colorHex).opacity(0.22))
                            .clipShape(Capsule())
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(currencySymbol) \(FormatHelper.formatCurrency(expense.amount))")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(AppColors.expenseRoseLight)
                        .contrastTextOutline()
                    
                    HStack(spacing: 4) {
                        Image(systemName: catIcon)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(catColor)
                        Text(expense.category)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white)
                            .contrastTextOutline()
                    }
                }
            }
            
            Divider().background(Color.white.opacity(0.12))
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if isPaidCycle {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.incomeEmeraldLight)
                            Text("Al día • Próximo:")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppColors.incomeEmeraldLight)
                                .contrastTextOutline()
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                        Text(isPaidCycle ? dateStr : "Vence: \(dateStr)")
                            .font(.system(size: 11, weight: .semibold))
                            .contrastTextOutline()
                    }
                    .foregroundStyle(isPaidCycle ? AppColors.incomeEmeraldLight : Color.white.opacity(0.9))
                }
                
                Spacer()
                
                // Botón Registrar Pago con sombreado y sin bordes
                Button(action: onPay) {
                    HStack(spacing: 5) {
                        Image(systemName: isPaidCycle ? "checkmark.circle.fill" : "creditcard.fill")
                        Text(isPaidCycle ? "Pago Registrado" : "Registrar Pago")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isPaidCycle ? AppColors.incomeEmeraldLight : .white)
                    .contrastTextOutline()
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(isPaidCycle ? AppColors.incomeEmerald.opacity(0.2) : AppColors.incomeEmerald)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: isPaidCycle ? Color.clear : AppColors.incomeEmerald.opacity(0.35), radius: 5, x: 0, y: 2)
                }
                .disabled(isPaidCycle)
                
                // Botón Editar con sombreado y sin bordes
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(7)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.35), radius: 3)
                }
                .accessibilityLabel("Editar gasto fijo")
                
                // Botón Eliminar con sombreado y sin bordes
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppColors.expenseRoseLight)
                        .padding(7)
                        .background(AppColors.expenseBg.opacity(0.65))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.35), radius: 3)
                }
                .accessibilityLabel("Eliminar gasto fijo")
            }
        }
        .padding(14)
        .background(
            ThemedCardBackgroundView(theme: theme, cornerRadius: 16)
        )
    }
}

// MARK: - Add/Edit Fixed Expense Sheet (Sin bordes, con sombreado, alto contraste y categorías sincronizadas)
struct AddEditFixedExpenseSheet: View {
    @Bindable var viewModel: ExpenseViewModel
    var expenseToEdit: FixedExpense? = nil
    var onSaved: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var amountString: String = ""
    @State private var category: String = "Servicios"
    @State private var selectedWalletId: Int64 = 1
    @State private var frequency: FixedExpenseFrequency = .monthly
    @State private var dayOfWeek: Int = 1
    @State private var dayOfMonth: Int = 1
    @State private var monthOfYear: Int = 1
    @State private var notifyTiming: FixedExpenseNotifyTiming = .sameDay
    @State private var notificationsEnabled: Bool = true
    @State private var errorMessage: String? = nil
    
    // Notificación Toast aislada para la hoja de creación
    @State private var sheetToast: ExpenseViewModel.FloatingToastData? = nil
    
    private var activeTheme: AppColorTheme {
        viewModel.activeTheme
    }
    
    // Lista de categorías para Gastos Fijos (incluye todas las nuevas categorías creadas por el usuario)
    private var availableCategories: [CategoryItem] {
        CategoryHelper.allCategoriesForFixedExpenses()
    }
    
    private var themedCardBackground: some View {
        ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 14)
    }
    
    private var hasChanges: Bool {
        guard let expense = expenseToEdit else { return false }
        
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName != expense.name.trimmingCharacters(in: .whitespacesAndNewlines) {
            return true
        }
        
        let cleanAmount = amountString.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        let currentAmount = Double(cleanAmount) ?? 0.0
        if abs(currentAmount - expense.amount) > 0.0001 {
            return true
        }
        
        if category != expense.category {
            return true
        }
        
        if selectedWalletId != expense.walletId {
            return true
        }
        
        if frequency != expense.frequency {
            return true
        }
        
        if frequency == .weekly && dayOfWeek != expense.dayOfWeek {
            return true
        }
        
        if (frequency == .monthly || frequency == .yearly) && dayOfMonth != expense.dayOfMonth {
            return true
        }
        
        if frequency == .yearly && monthOfYear != expense.monthOfYear {
            return true
        }
        
        if notificationsEnabled != expense.notificationsEnabled {
            return true
        }
        
        if notificationsEnabled && notifyTiming != expense.notifyTiming {
            return true
        }
        
        return false
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ThemedModalBackground(theme: activeTheme)
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 16) {
                            // 1. Campo Nombre del Gasto Fijo
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 4) {
                                    Text("Nombre del Servicio o Pago")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentTextColor)
                                        .contrastTextOutline()
                                    
                                    Text("*(Obligatorio)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(AppColors.expenseRoseLight)
                                        .contrastTextOutline()
                                    
                                    Spacer()
                                    
                                    Text("\(name.count)/35")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(AppColors.textMuted)
                                }
                                
                                TextField("Ej: Netflix, Internet, Alquiler, Gym...", text: $name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.white)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 13)
                                    .background(themedCardBackground)
                                    .onChange(of: name) { _, newValue in
                                        if newValue.count > 35 {
                                            name = String(newValue.prefix(35))
                                        }
                                    }
                            }
                            
                            // 2. Campo Monto
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Monto del Pago")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentTextColor)
                                    .contrastTextOutline()
                                
                                HStack(spacing: 6) {
                                    Text(viewModel.financialSummary.currencySymbol)
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .foregroundStyle(AppColors.expenseRoseLight)
                                        .contrastTextOutline()
                                    
                                    TextField("0.00", text: $amountString)
                                        .font(.system(size: 32, weight: .black, design: .rounded))
                                        .foregroundStyle(Color.white)
                                        .contrastTextOutline()
                                        .keyboardType(.decimalPad)
                                        .onChange(of: amountString) { _, newValue in
                                            amountString = FormatHelper.validateMoneyInput(newValue)
                                        }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(themedCardBackground)
                            }
                            
                            // 3. Campo Selector de Categoría (Incluye categorías creadas por el usuario)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Categoría")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentTextColor)
                                    .contrastTextOutline()
                                
                                Menu {
                                    ForEach(availableCategories) { cat in
                                        Button {
                                            withAnimation(nil) {
                                                category = cat.name
                                            }
                                        } label: {
                                            HStack {
                                                Image(systemName: cat.iconSymbol)
                                                Text(cat.name)
                                                if category.caseInsensitiveCompare(cat.name) == .orderedSame {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        let icon = CategoryHelper.getCategoryIcon(name: category, type: .expense)
                                        let color = CategoryHelper.getCategoryColor(name: category, type: .expense)
                                        
                                        ZStack {
                                            Circle()
                                                .fill(color.opacity(0.22))
                                                .frame(width: 32, height: 32)
                                            Image(systemName: icon)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(color)
                                        }
                                        .frame(width: 32, height: 32)
                                        
                                        Text(category)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(Color.white)
                                            .contrastTextOutline()
                                            .lineLimit(1)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentIconColor)
                                    }
                                    .padding(.horizontal, 14)
                                    .frame(height: 52)
                                    .frame(maxWidth: .infinity)
                                    .background(themedCardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // 4. Campo Billetera a Debitar
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Billetera a Debitar")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentTextColor)
                                    .contrastTextOutline()
                                
                                Menu {
                                    ForEach(viewModel.wallets) { w in
                                        Button {
                                            withAnimation(nil) {
                                                selectedWalletId = w.id
                                            }
                                        } label: {
                                            HStack {
                                                Text(w.name)
                                                if selectedWalletId == w.id {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    let currentWallet = viewModel.wallets.first(where: { $0.id == selectedWalletId })
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(Color(hex: currentWallet?.colorHex ?? "#38BDF8"))
                                            .frame(width: 14, height: 14)
                                        
                                        Text(currentWallet?.name ?? "Billetera")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(Color.white)
                                            .contrastTextOutline()
                                            .lineLimit(1)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentIconColor)
                                    }
                                    .padding(.horizontal, 14)
                                    .frame(height: 52)
                                    .frame(maxWidth: .infinity)
                                    .background(themedCardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // 5. Frecuencia y Fechas
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Frecuencia y Vencimiento")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentTextColor)
                                    .contrastTextOutline()
                                
                                // Selector interactivo de Frecuencia
                                HStack(spacing: 8) {
                                    ForEach(FixedExpenseFrequency.allCases, id: \.self) { freq in
                                        let isSel = frequency == freq
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.18)) {
                                                frequency = freq
                                            }
                                        } label: {
                                            Text(freq.displayName)
                                                .font(.system(size: 13, weight: isSel ? .bold : .medium))
                                                .foregroundStyle(isSel ? Color.white : Color.white.opacity(0.6))
                                                .contrastTextOutline()
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 38)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .fill(isSel ? (activeTheme == .electricBlack ? Color.white.opacity(0.25) : activeTheme.primary.opacity(0.4)) : Color.clear)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(4)
                                .frame(height: 48)
                                .frame(maxWidth: .infinity)
                                .background(themedCardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                
                                // Opciones dependientes de la frecuencia
                                if frequency == .weekly {
                                    Menu {
                                        ForEach(1...7, id: \.self) { day in
                                            Button {
                                                withAnimation(nil) {
                                                    dayOfWeek = day
                                                }
                                            } label: {
                                                HStack {
                                                    Text(FixedExpenseDateHelper.daysOfWeekNames[day - 1])
                                                    if dayOfWeek == day {
                                                        Image(systemName: "checkmark")
                                                    }
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text("Día de cobro:")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(Color.white.opacity(0.8))
                                                .contrastTextOutline()
                                            
                                            Spacer()
                                            
                                            Text(FixedExpenseDateHelper.daysOfWeekNames[dayOfWeek - 1])
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(Color.white)
                                                .contrastTextOutline()
                                            
                                            Image(systemName: "chevron.up.chevron.down")
                                                .font(.system(size: 12))
                                                .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentIconColor)
                                        }
                                        .padding(.horizontal, 14)
                                        .frame(height: 52)
                                        .frame(maxWidth: .infinity)
                                        .background(themedCardBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                if frequency == .monthly || frequency == .yearly {
                                    let maxDays = frequency == .yearly ? FixedExpenseDateHelper.getMaxSelectableDaysForYearlyMonth(monthOfYear) : 31
                                    Menu {
                                        ForEach(1...maxDays, id: \.self) { day in
                                            Button {
                                                withAnimation(nil) {
                                                    dayOfMonth = day
                                                }
                                            } label: {
                                                HStack {
                                                    Text("Día \(day)")
                                                    if dayOfMonth == day {
                                                        Image(systemName: "checkmark")
                                                    }
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text("Día del mes:")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(Color.white.opacity(0.8))
                                                .contrastTextOutline()
                                            
                                            Spacer()
                                            
                                            Text("Día \(dayOfMonth)")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(Color.white)
                                                .contrastTextOutline()
                                            
                                            Image(systemName: "chevron.up.chevron.down")
                                                .font(.system(size: 12))
                                                .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentIconColor)
                                        }
                                        .padding(.horizontal, 14)
                                        .frame(height: 52)
                                        .frame(maxWidth: .infinity)
                                        .background(themedCardBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                if frequency == .yearly {
                                    Menu {
                                        ForEach(1...12, id: \.self) { m in
                                            Button {
                                                withAnimation(nil) {
                                                    monthOfYear = m
                                                }
                                            } label: {
                                                HStack {
                                                    Text(FixedExpenseDateHelper.monthsNames[m - 1])
                                                    if monthOfYear == m {
                                                        Image(systemName: "checkmark")
                                                    }
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text("Mes del cobro:")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(Color.white.opacity(0.8))
                                                .contrastTextOutline()
                                            
                                            Spacer()
                                            
                                            Text(FixedExpenseDateHelper.monthsNames[monthOfYear - 1])
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(Color.white)
                                                .contrastTextOutline()
                                            
                                            Image(systemName: "chevron.up.chevron.down")
                                                .font(.system(size: 12))
                                                .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentIconColor)
                                        }
                                        .padding(.horizontal, 14)
                                        .frame(height: 52)
                                        .frame(maxWidth: .infinity)
                                        .background(themedCardBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            // 6. Recordatorios y Notificaciones
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Recordatorios y Avisos")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentTextColor)
                                    .contrastTextOutline()
                                
                                VStack(spacing: 12) {
                                    Toggle(isOn: $notificationsEnabled) {
                                        Text("Activar recordatorios puntuales")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(Color.white)
                                            .contrastTextOutline()
                                    }
                                    .tint(activeTheme == .electricBlack ? Color.white : activeTheme.primary)
                                    
                                    if notificationsEnabled {
                                        Divider().background(Color.white.opacity(0.12))
                                        
                                        Menu {
                                            ForEach(FixedExpenseNotifyTiming.allCases, id: \.self) { t in
                                                Button {
                                                    withAnimation(nil) {
                                                        notifyTiming = t
                                                    }
                                                } label: {
                                                    HStack {
                                                        Text(t.displayName)
                                                        if notifyTiming == t {
                                                            Image(systemName: "checkmark")
                                                        }
                                                    }
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                Text("Avisarme:")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundStyle(Color.white.opacity(0.8))
                                                    .contrastTextOutline()
                                                
                                                Spacer()
                                                
                                                Text(notifyTiming.displayName)
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundStyle(Color.white)
                                                    .contrastTextOutline()
                                                
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentIconColor)
                                            }
                                            .padding(.horizontal, 14)
                                            .frame(height: 48)
                                            .frame(maxWidth: .infinity)
                                            .background(
                                                ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 10)
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(themedCardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            
                            // Mensaje de Error si existiese
                            if let errorMessage {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(AppColors.expenseRose)
                                    Text(errorMessage)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(AppColors.expenseRoseLight)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppColors.expenseBg.opacity(0.45))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: Color.black.opacity(0.3), radius: 4)
                            }
                        }
                        .padding(18)
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .scrollBounceBehavior(.basedOnSize)
                    
                    // Barra de Guardar fijada inferior (sin bordes, con sombreado)
                    VStack(spacing: 8) {
                        Button {
                            if expenseToEdit != nil {
                                if hasChanges {
                                    saveFixedExpense()
                                } else {
                                    dismiss()
                                }
                            } else {
                                saveFixedExpense()
                            }
                        } label: {
                            Text(expenseToEdit != nil ? (hasChanges ? "Actualizar" : "Listo") : "Guardar Gasto Fijo")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(activeTheme == .electricBlack ? Color.black : activeTheme.onPrimaryText)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: activeTheme == .electricBlack ? [Color.white, Color(hex: "#E2E8F0")] : activeTheme.gradient,
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                                .shadow(color: activeTheme.primary.opacity(0.45), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 14)
                    .background(Color.black.opacity(0.35))
                }
                
                // Notificación Flotante Superior
                if let toast = sheetToast {
                    VStack {
                        FloatingToastView(toast: toast, theme: activeTheme) {
                            withAnimation(.easeOut(duration: 0.25)) {
                                sheetToast = nil
                            }
                        }
                        .padding(.top, 6)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(200)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(expenseToEdit != nil ? "Editar Gasto Fijo" : "Nuevo Gasto Fijo")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.white)
                        .contrastTextOutline()
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .contrastTextOutline()
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if expenseToEdit != nil {
                        Button(hasChanges ? "Actualizar" : "Listo") {
                            if hasChanges {
                                saveFixedExpense()
                            } else {
                                dismiss()
                            }
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentTextColor)
                        .contrastTextOutline()
                    } else {
                        Button("Guardar") { saveFixedExpense() }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentTextColor)
                            .contrastTextOutline()
                    }
                }
            }
            .onAppear {
                if let expense = expenseToEdit {
                    name = expense.name
                    amountString = String(format: "%.2f", expense.amount)
                    category = expense.category
                    selectedWalletId = expense.walletId
                    frequency = expense.frequency
                    dayOfWeek = expense.dayOfWeek
                    dayOfMonth = expense.dayOfMonth
                    monthOfYear = expense.monthOfYear
                    notifyTiming = expense.notifyTiming
                    notificationsEnabled = expense.notificationsEnabled
                } else {
                    selectedWalletId = viewModel.activeWallet?.id ?? viewModel.wallets.first?.id ?? 1
                    if let firstAvailable = availableCategories.first?.name {
                        if !availableCategories.contains(where: { $0.name == category }) {
                            category = firstAvailable
                        }
                    }
                }
            }
        }
        .keyboardDismissArrow()
    }
    
    private func saveFixedExpense() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "El nombre no puede estar vacío."
            showSheetToast(title: "Campo Requerido", message: "Ingresa el nombre del gasto fijo.", isSuccess: false)
            return
        }
        
        // Validación de nombres duplicados (ignorando el que se está editando si aplica)
        let isDuplicate = viewModel.fixedExpenses.contains { other in
            if let expenseToEdit, other.id == expenseToEdit.id {
                return false
            }
            return other.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmedName.lowercased()
        }
        guard !isDuplicate else {
            errorMessage = "Ya existe un gasto fijo con ese nombre."
            showSheetToast(title: "Nombre Duplicado", message: "Ya tienes registrado un gasto fijo llamado '\(trimmedName)'.", isSuccess: false)
            return
        }
        
        let cleanAmount = amountString.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let amount = Double(cleanAmount), amount > 0 else {
            errorMessage = "Ingresa un monto válido mayor a 0."
            showSheetToast(title: "Monto Requerido", message: "Ingresa un monto válido mayor a 0.", isSuccess: false)
            return
        }
        
        if let expense = expenseToEdit {
            expense.name = trimmedName
            expense.amount = amount
            expense.category = category
            expense.walletId = selectedWalletId
            expense.frequency = frequency
            expense.dayOfWeek = dayOfWeek
            expense.dayOfMonth = dayOfMonth
            expense.monthOfYear = monthOfYear
            expense.notifyTiming = notifyTiming
            expense.notificationsEnabled = notificationsEnabled
            
            let (success, msg) = viewModel.updateFixedExpense(expense)
            if success {
                onSaved(trimmedName)
                dismiss()
            } else {
                errorMessage = msg
                showSheetToast(title: "Error", message: msg, isSuccess: false)
            }
        } else {
            let newExpense = FixedExpense(
                name: trimmedName,
                amount: amount,
                category: category,
                walletId: selectedWalletId,
                frequency: frequency,
                dayOfWeek: dayOfWeek,
                dayOfMonth: dayOfMonth,
                monthOfYear: monthOfYear,
                notifyTiming: notifyTiming,
                notificationsEnabled: notificationsEnabled
            )
            
            let (success, msg) = viewModel.addFixedExpense(newExpense)
            if success {
                onSaved(trimmedName)
                dismiss()
            } else {
                errorMessage = msg
                showSheetToast(title: "Error", message: msg, isSuccess: false)
            }
        }
    }
    
    private func showSheetToast(title: String, message: String, isSuccess: Bool = false) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            sheetToast = ExpenseViewModel.FloatingToastData(title: title, message: message, isSuccess: isSuccess)
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.25)) {
                    sheetToast = nil
                }
            }
        }
    }
}

// MARK: - Opciones de Ordenamiento para Gastos Fijos
public enum FixedExpensesSortOption: String, CaseIterable, Identifiable {
    case highestAmount = "Mayor a menor gasto"
    case lowestAmount = "Menor a mayor gasto"
    case alphabeticalAsc = "Alfabético (A - Z)"
    case alphabeticalDesc = "Alfabético (Z - A)"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .highestAmount: return "arrow.down.right"
        case .lowestAmount: return "arrow.up.right"
        case .alphabeticalAsc: return "textformat.abc"
        case .alphabeticalDesc: return "textformat.abc.dottedunderline"
        }
    }
}

// MARK: - Ventana Flotante de Resumen de Gastos Fijos
public struct FixedExpensesRankingSummarySheet: View {
    @Bindable var viewModel: ExpenseViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var sortOption: FixedExpensesSortOption = .highestAmount
    
    private var activeTheme: AppColorTheme {
        viewModel.activeTheme
    }
    
    private var sortedExpenses: [FixedExpense] {
        switch sortOption {
        case .highestAmount:
            return viewModel.fixedExpenses.sorted { $0.amount > $1.amount }
        case .lowestAmount:
            return viewModel.fixedExpenses.sorted { $0.amount < $1.amount }
        case .alphabeticalAsc:
            return viewModel.fixedExpenses.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .alphabeticalDesc:
            return viewModel.fixedExpenses.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        }
    }
    
    private var totalAmount: Double {
        viewModel.fixedExpenses.reduce(0.0) { $0 + $1.amount }
    }
    
    public init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                ThemedModalBackground(theme: activeTheme)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Tarjeta Principal: Monto Total de Gastos Fijos y Botón de Filtro/Orden
                        totalAmountCard
                        
                        // Lista Desglosada de Gastos Fijos
                        if sortedExpenses.isEmpty {
                            emptyStateView
                        } else {
                            rankedExpensesList
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Resumen de Gastos Fijos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .foregroundStyle(Color.white)
                    .contrastTextOutline()
                }
            }
        }
        .presentationDetents([.fraction(0.85), .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Tarjeta de Monto Total con Botón de Filtro/Orden
    private var totalAmountCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentIconColor)
                        
                        Text("TOTAL GASTOS FIJOS")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppColors.textMuted)
                            .tracking(0.6)
                    }
                    
                    Text("\(viewModel.financialSummary.currencySymbol) \(FormatHelper.formatCurrency(totalAmount))")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white)
                        .contrastTextOutline()
                }
                
                Spacer()
                
                // Botón con ícono de filtro para ordenar ascendente, descendente y alfabético
                Menu {
                    ForEach(FixedExpensesSortOption.allCases) { option in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                sortOption = option
                            }
                        } label: {
                            HStack {
                                Text(option.rawValue)
                                if sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        (activeTheme == .electricBlack ? Color.white : activeTheme.primary).opacity(0.25),
                                        (activeTheme == .electricBlack ? Color(hex: "#94A3B8") : activeTheme.primary).opacity(0.12)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                            .overlay(
                                Circle()
                                    .stroke(
                                        (activeTheme == .electricBlack ? Color.white : activeTheme.primary).opacity(0.40),
                                        lineWidth: 1.2
                                    )
                            )
                        
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentIconColor)
                    }
                }
                .accessibilityLabel("Filtrar y ordenar gastos fijos")
            }
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: sortOption.iconName)
                        .font(.system(size: 11, weight: .bold))
                    Text(sortOption.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentTextColor)
                .contrastTextOutline()
                
                Spacer()
                
                Text("\(sortedExpenses.count) gastos fijos")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(18)
        .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 18))
        .shadow(
            color: activeTheme == .electricBlack ? Color.white.opacity(0.08) : activeTheme.primary.opacity(0.25),
            radius: 8, x: 0, y: 3
        )
    }
    
    // MARK: - Lista de Gastos Fijos
    private var rankedExpensesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Desglose")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white)
                    .contrastTextOutline()
                
                Spacer()
                
                Text("Porcentaje")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.textMuted)
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 10) {
                ForEach(sortedExpenses, id: \.id) { expense in
                    FixedExpenseRankedRow(
                        expense: expense,
                        currencySymbol: viewModel.financialSummary.currencySymbol,
                        theme: activeTheme,
                        totalAmount: totalAmount
                    )
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(AppColors.textMuted)
            
            Text("No hay gastos fijos registrados")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.white)
            
            Text("Agrega gastos fijos para visualizarlos y consultar la suma total.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.vertical, 32)
    }
}

// MARK: - Fila de Gasto Fijo (Limpia, sin números de orden ni barra de nivel)
struct FixedExpenseRankedRow: View {
    let expense: FixedExpense
    let currencySymbol: String
    let theme: AppColorTheme
    let totalAmount: Double
    
    var body: some View {
        let catIcon = CategoryHelper.getCategoryIcon(name: expense.category, type: .expense)
        let catColor = CategoryHelper.getCategoryColor(name: expense.category, type: .expense)
        let percent = totalAmount > 0 ? (expense.amount / totalAmount) * 100.0 : 0.0
        
        HStack(spacing: 12) {
            // Ícono de categoría
            ZStack {
                Circle()
                    .fill(catColor.opacity(0.20))
                    .frame(width: 40, height: 40)
                Image(systemName: catIcon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(catColor)
            }
            
            // Nombre y periodicidad
            VStack(alignment: .leading, spacing: 3) {
                Text(expense.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(expense.category)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                    
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.textMuted)
                    
                    Text(expense.frequency.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme == .electricBlack ? Color.white : theme.accentTextColor)
                }
            }
            
            Spacer(minLength: 8)
            
            // Monto y porcentaje
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(currencySymbol) \(FormatHelper.formatCurrency(expense.amount))")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(AppColors.expenseRoseLight)
                
                Text(String(format: "%.1f%% del total", percent))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(14)
        .background(ThemedCardBackgroundView(theme: theme, cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.22), radius: 4, x: 0, y: 2)
    }
}
