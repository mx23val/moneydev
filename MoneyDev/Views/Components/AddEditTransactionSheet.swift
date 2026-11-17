import SwiftUI

public struct AddEditTransactionSheet: View {
    @Bindable var viewModel: ExpenseViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedType: TransactionType
    @State private var amountString: String
    @State private var title: String
    @State private var selectedCategory: String
    @State private var notes: String
    @State private var selectedDate: Date
    @State private var errorMessage: String? = nil
    
    public init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
        let editing = viewModel.editingTransaction
        let defaultType = editing?.type ?? viewModel.addTransactionType
        
        _selectedType = State(initialValue: defaultType)
        _amountString = State(initialValue: editing != nil ? String(format: "%.2f", editing!.amount) : "")
        _title = State(initialValue: editing?.title ?? "")
        _selectedCategory = State(initialValue: editing?.category ?? (defaultType == .income ? "Salario" : "Alimentación"))
        _notes = State(initialValue: editing?.notes ?? "")
        _selectedDate = State(initialValue: editing != nil ? Date(timeIntervalSince1970: Double(editing!.dateMillis) / 1000.0) : Date())
    }
    
    private var availableCategories: [CategoryItem] {
        selectedType == .income ? CategoryHelper.incomeCategories : CategoryHelper.expenseCategories
    }
    
    private var activeTheme: AppColorTheme {
        AppColorTheme.fromId(viewModel.financialSummary.themeColorId)
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AppColors.midnightBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Switch Gasto / Ingreso
                        HStack(spacing: 0) {
                            Button {
                                withAnimation(.spring) {
                                    selectedType = .expense
                                    if !availableCategories.contains(where: { $0.name == selectedCategory }) {
                                        selectedCategory = "Alimentación"
                                    }
                                }
                            } label: {
                                Text("Gasto")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(selectedType == .expense ? .white : AppColors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(selectedType == .expense ? AppColors.expenseRose : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            
                            Button {
                                withAnimation(.spring) {
                                    selectedType = .income
                                    if !availableCategories.contains(where: { $0.name == selectedCategory }) {
                                        selectedCategory = "Salario"
                                    }
                                }
                            } label: {
                                Text("Ingreso")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(selectedType == .income ? .white : AppColors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(selectedType == .income ? AppColors.incomeEmerald : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding(4)
                        .background(AppColors.darkNavySurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Amount Input Display
                        VStack(spacing: 6) {
                            Text("Monto")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppColors.textSecondary)
                            
                            HStack(spacing: 4) {
                                Text(viewModel.financialSummary.currencySymbol)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(selectedType == .income ? AppColors.incomeEmeraldLight : AppColors.expenseRoseLight)
                                
                                TextField("0.00", text: $amountString)
                                    .font(.system(size: 38, weight: .black, design: .rounded))
                                    .foregroundStyle(AppColors.textPrimary)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(AppColors.darkNavySurface)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppColors.cardBorderNavy, lineWidth: 1)
                            )
                        }
                        
                        // Title / Concept Input
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Concepto o Título")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppColors.textSecondary)
                                Spacer()
                                Text("\(title.count)/30")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppColors.textMuted)
                            }
                            
                            TextField("Ej: Almuerzo, Taxi, Cine, Sueldo", text: $title)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(AppColors.textPrimary)
                                .padding(14)
                                .background(AppColors.darkNavySurface)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(AppColors.cardBorderNavy, lineWidth: 1)
                                )
                                .onChange(of: title) { _, newValue in
                                    if newValue.count > 30 {
                                        title = String(newValue.prefix(30))
                                    }
                                }
                        }
                        
                        // Category Selector (Grid)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Categoría")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppColors.textSecondary)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                                ForEach(availableCategories) { cat in
                                    let isSelected = cat.name == selectedCategory
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            selectedCategory = cat.name
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: cat.iconSymbol)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(isSelected ? .white : cat.color)
                                            
                                            Text(cat.name)
                                                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                                .foregroundStyle(isSelected ? .white : AppColors.textPrimary)
                                                .lineLimit(1)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(isSelected ? cat.color : AppColors.darkNavySurface)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(isSelected ? cat.color : AppColors.cardBorderNavy, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // Date Picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Fecha")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppColors.textSecondary)
                            
                            DatePicker(
                                "",
                                selection: $selectedDate,
                                in: ...Date(),
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.darkNavySurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(AppColors.cardBorderNavy, lineWidth: 1)
                            )
                        }
                        
                        // Notes Input
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Notas o Detalles (Opcional)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppColors.textSecondary)
                                Spacer()
                                Text("\(notes.count)/90")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppColors.textMuted)
                            }
                            
                            TextField("Detalles adicionales...", text: $notes)
                                .font(.system(size: 14))
                                .foregroundStyle(AppColors.textPrimary)
                                .padding(14)
                                .background(AppColors.darkNavySurface)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(AppColors.cardBorderNavy, lineWidth: 1)
                                )
                                .onChange(of: notes) { _, newValue in
                                    if newValue.count > 90 {
                                        notes = String(newValue.prefix(90))
                                    }
                                }
                        }
                        
                        // Error message if any
                        if let errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(AppColors.expenseRose)
                                Text(errorMessage)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppColors.expenseRoseLight)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.expenseBg.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        
                        // Save Button
                        Button {
                            handleSave()
                        } label: {
                            Text(viewModel.editingTransaction != nil ? "Guardar Cambios" : "Registrar Movimiento")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    selectedType == .income ? AppColors.incomeEmerald : AppColors.expenseRose
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.top, 10)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(viewModel.editingTransaction != nil ? "Editar Movimiento" : "Nuevo Movimiento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        viewModel.closeAddEditSheet()
                        dismiss()
                    }
                    .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .presentationDetents([.fraction(0.9), .large])
    }
    
    private func handleSave() {
        let cleanAmountStr = amountString.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let amount = Double(cleanAmountStr), amount > 0 else {
            errorMessage = "Ingresa un monto válido mayor a 0."
            return
        }
        
        let finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? selectedCategory : title
        let millis = Int64(selectedDate.timeIntervalSince1970 * 1000)
        
        let (success, msg) = viewModel.saveTransaction(
            title: finalTitle,
            amount: amount,
            type: selectedType,
            category: selectedCategory,
            notes: notes,
            dateMillis: millis
        )
        
        if success {
            dismiss()
        } else {
            errorMessage = msg ?? "Error al guardar el movimiento."
        }
    }
}
