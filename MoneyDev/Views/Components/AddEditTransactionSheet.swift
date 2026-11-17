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
    @State private var isTitleMissing: Bool = false
    @State private var showCreateCategoryModal: Bool = false
    @State private var newCategoryName: String = ""
    @State private var newCategoryError: String? = nil
    @State private var categoryToDelete: CategoryItem? = nil
    @State private var showDeleteCategoryConfirmation: Bool = false
    @State private var categoriesRefreshId: UUID = UUID()
    @State private var showDiscardConfirmation: Bool = false
    @FocusState private var isNotesFocused: Bool
    
    public init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
        let editing = viewModel.editingTransaction
        let defaultType = editing?.type ?? viewModel.addTransactionType
        
        _selectedType = State(initialValue: defaultType)
        _amountString = State(initialValue: editing != nil ? String(format: "%.2f", editing!.amount) : "")
        _title = State(initialValue: editing?.title ?? "")
        let initialCategory = CategoryHelper.resolveCategory(nameOrKeyword: editing?.category ?? (defaultType == .income ? "Salario" : "Alimentación"), type: defaultType)
        _selectedCategory = State(initialValue: initialCategory)
        _notes = State(initialValue: editing?.notes ?? "")
        _selectedDate = State(initialValue: editing != nil ? Date(timeIntervalSince1970: Double(editing!.dateMillis) / 1000.0) : Date())
    }
    
    private var availableCategories: [CategoryItem] {
        _ = categoriesRefreshId
        return CategoryHelper.allCategories(for: selectedType)
    }
    
    private var activeTheme: AppColorTheme {
        AppColorTheme.fromId(viewModel.financialSummary.themeColorId)
    }
    
    private var isEditing: Bool {
        viewModel.editingTransaction != nil
    }
    
    private var hasUnsavedChanges: Bool {
        if let original = viewModel.editingTransaction {
            // Modo Edición: verificar si se actualizó algún apartado
            let cleanAmountStr = amountString.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
            let currentAmount = Double(cleanAmountStr) ?? 0.0
            let originalAmount = original.amount
            let amountChanged = abs(currentAmount - originalAmount) > 0.001
            
            let titleChanged = title.trimmingCharacters(in: .whitespacesAndNewlines) != original.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let notesChanged = notes.trimmingCharacters(in: .whitespacesAndNewlines) != original.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let categoryChanged = selectedCategory != original.category
            let typeChanged = selectedType != original.type
            
            let originalDate = Date(timeIntervalSince1970: Double(original.dateMillis) / 1000.0)
            let dateChanged = !Calendar.current.isDate(selectedDate, inSameDayAs: originalDate)
            
            return amountChanged || titleChanged || notesChanged || categoryChanged || typeChanged || dateChanged
        } else {
            // Modo Creación: verificar si se configuró un número o se escribió algo
            let cleanAmountStr = amountString.trimmingCharacters(in: .whitespaces)
            let hasAmount = !cleanAmountStr.isEmpty && (Double(cleanAmountStr.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
            let hasTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasNotes = !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            
            return hasAmount || hasTitle || hasNotes
        }
    }
    
    private var themedCardBackground: some View {
        ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 14)
    }
    
    public var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ThemedModalBackground(theme: activeTheme)
                
                VStack(spacing: 0) {
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            VStack(spacing: 20) {
                        // Switch Gasto / Ingreso (Solo editable al crear nuevo movimiento)
                        if isEditing {
                            // Modo Edición / Detalle: Título del movimiento y tipo
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(selectedType == .income ? AppColors.incomeEmerald.opacity(0.2) : AppColors.expenseRose.opacity(0.2))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: selectedType == .income ? "arrow.down.left" : "minus")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(selectedType == .income ? AppColors.incomeEmeraldLight : AppColors.expenseRoseLight)
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(title.isEmpty ? (viewModel.editingTransaction?.title ?? "Movimiento") : title)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(Color.white)
                                        .lineLimit(1)
                                    
                                    Text(selectedType == .income ? "Ingreso" : "Gasto")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(selectedType == .income ? AppColors.incomeEmeraldLight : AppColors.expenseRoseLight)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(themedCardBackground)
                        } else {
                            // Modo Creación: Selector interactivo Gasto vs Ingreso
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
                                        .frame(height: 42)
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
                                        .frame(height: 42)
                                        .background(selectedType == .income ? AppColors.incomeEmerald : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                            .padding(4)
                            .background(themedCardBackground)
                        }
                        
                        // Amount Input Display
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Monto")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentTextColor)
                                .contrastTextOutline()
                            
                            HStack(spacing: 6) {
                                Text(viewModel.financialSummary.currencySymbol)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(selectedType == .income ? AppColors.incomeEmeraldLight : AppColors.expenseRoseLight)
                                    .contrastTextOutline()
                                
                                TextField("0.00", text: $amountString)
                                    .font(.system(size: 36, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.white)
                                    .contrastTextOutline()
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.leading)
                                    .onChange(of: amountString) { _, newValue in
                                        amountString = FormatHelper.validateMoneyInput(newValue)
                                    }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .themedInputField(theme: activeTheme, cornerRadius: 14)
                        }
                        
                        // Title / Concept Input
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("Concepto o Título")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentTextColor)
                                    .contrastTextOutline()
                                
                                Text("*(Obligatorio)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(isTitleMissing ? AppColors.expenseRoseLight : AppColors.expenseRose.opacity(0.85))
                                    .contrastTextOutline()
                                
                                Spacer()
                                Text("\(title.count)/30")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(AppColors.textMuted)
                            }
                            
                            TextField("Ej: Almuerzo, Taxi, Cine, Sueldo", text: $title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .submitLabel(.done)
                                .onSubmit {
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                }
                                .padding(14)
                                .themedInputField(
                                    theme: activeTheme,
                                    cornerRadius: 14,
                                    borderColor: isTitleMissing ? AppColors.expenseRoseLight : nil
                                )
                                .onChange(of: title) { _, newValue in
                                    if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        isTitleMissing = false
                                    }
                                    if newValue.count > 30 {
                                        title = String(newValue.prefix(30))
                                    }
                                }
                            
                            if isTitleMissing {
                                Text("El concepto o título es obligatorio.")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AppColors.expenseRoseLight)
                                    .padding(.leading, 4)
                            }
                        }
                        
                        // Selector de Categoría (Dropdown flotante superpuesto sin desplazar campos inferiores)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Categoría")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentTextColor)
                                .contrastTextOutline()
                            
                            Menu {
                                ForEach(availableCategories) { cat in
                                    if CategoryHelper.isCustomCategory(cat) {
                                        Menu {
                                            Button {
                                                selectedCategory = cat.name
                                            } label: {
                                                Label("Seleccionar", systemImage: "checkmark")
                                            }
                                            Button(role: .destructive) {
                                                categoryToDelete = cat
                                                showDeleteCategoryConfirmation = true
                                            } label: {
                                                Label("Eliminar categoría", systemImage: "trash")
                                            }
                                        } label: {
                                            HStack {
                                                Image(systemName: cat.iconSymbol)
                                                Text(cat.name)
                                                if selectedCategory.caseInsensitiveCompare(cat.name) == .orderedSame {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    } else {
                                        Button {
                                            selectedCategory = cat.name
                                        } label: {
                                            HStack {
                                                Image(systemName: cat.iconSymbol)
                                                Text(cat.name)
                                                if selectedCategory.caseInsensitiveCompare(cat.name) == .orderedSame {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                Divider()
                                
                                Button {
                                    showCreateCategoryModal = true
                                } label: {
                                    Label("Crear nueva categoría", systemImage: "plus.circle")
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    let catIcon = CategoryHelper.getCategoryIcon(name: selectedCategory, type: selectedType)
                                    let catColor = CategoryHelper.getCategoryColor(name: selectedCategory, type: selectedType)
                                    
                                    ZStack {
                                        Circle()
                                            .fill(catColor.opacity(0.20))
                                            .frame(width: 34, height: 34)
                                        Image(systemName: catIcon)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(catColor)
                                    }
                                    
                                    Text(selectedCategory)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(Color.white)
                                        .contrastTextOutline()
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentIconColor)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(themedCardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        
                        // Date Picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Fecha")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentTextColor)
                            
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
                            .background(themedCardBackground)
                        }
                        
                        // Notes Input
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Notas o Detalles (Opcional)")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentTextColor)
                                    .contrastTextOutline()
                                Spacer()
                                Text("\(notes.count)/90")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(AppColors.textMuted)
                            }
                            
                            TextField("Detalles adicionales...", text: $notes, axis: .vertical)
                                .lineLimit(2...4)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.white)
                                .focused($isNotesFocused)
                                .submitLabel(.done)
                                .onSubmit {
                                    isNotesFocused = false
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                }
                                .padding(14)
                                .themedInputField(theme: activeTheme, cornerRadius: 14)
                                .onChange(of: notes) { _, newValue in
                                    if newValue.contains("\n") {
                                        notes = newValue.replacingOccurrences(of: "\n", with: "")
                                        isNotesFocused = false
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                        return
                                    }
                                    if newValue.count > 90 {
                                        notes = String(newValue.prefix(90))
                                    }
                                }
                        }
                        .id("notesSectionAnchor")
                        
                        // Espacio sutil al enfocar las notas para que se deslice lo justo y necesario
                        // quedando perfectamente visible todo el texto de 90 caracteres sin subir de más
                        if isNotesFocused {
                            Color.clear
                                .frame(height: 140)
                        } else {
                            Color.clear
                                .frame(height: 16)
                        }
                        }
                        .padding(20)
                    }
                    .onChange(of: isNotesFocused) { _, focused in
                        if focused {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    scrollProxy.scrollTo("notesSectionAnchor", anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                    
                    // Barra de Guardar fijada inferior que se auto-eleva sobre el teclado
                    VStack(spacing: 8) {
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
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background(Color.black.opacity(0.35))
                }
                .zIndex(1)
                
                // Notificación Flotante Superior
                if let toast = viewModel.floatingToast {
                    VStack {
                        FloatingToastView(toast: toast, theme: activeTheme) {
                            viewModel.dismissFloatingToast()
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
                    Text(viewModel.editingTransaction != nil ? "Editar Movimiento" : "Nuevo Movimiento")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.white)
                        .contrastTextOutline()
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        if hasUnsavedChanges {
                            showDiscardConfirmation = true
                        } else {
                            viewModel.closeAddEditSheet()
                            dismiss()
                        }
                    }
                    .foregroundStyle(Color.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showCreateCategoryModal) {
            CreateCategoryDialog(
                theme: activeTheme,
                selectedType: selectedType,
                onCreated: { newCat in
                    categoriesRefreshId = UUID()
                    selectedCategory = newCat.name
                    showCreateCategoryModal = false
                    viewModel.showFloatingToast(
                        title: "Categoría Creada",
                        message: "Se añadió '\(newCat.name)' correctamente.",
                        isSuccess: true,
                        duration: 3.0
                    )
                },
                onDismiss: {
                    showCreateCategoryModal = false
                }
            )
            .themedSheetContainer(theme: activeTheme)
        }
        .alert(
            "¿Estás seguro de cerrar?",
            isPresented: $showDiscardConfirmation
        ) {
            Button("Continuar editando", role: .cancel) { }
            Button("Cerrar", role: .destructive) {
                viewModel.closeAddEditSheet()
                dismiss()
            }
        } message: {
            Text(
                isEditing
                    ? "Los cambios no se actualizarán."
                    : "No se guardarán los datos registrados."
            )
        }
        .alert("¿Eliminar categoría?", isPresented: $showDeleteCategoryConfirmation, presenting: categoryToDelete) { cat in
            Button("Eliminar", role: .destructive) {
                deleteCategory(cat)
            }
            Button("Cancelar", role: .cancel) {
                categoryToDelete = nil
            }
        } message: { cat in
            Text("¿Estás seguro de que deseas eliminar la categoría '\(cat.name)'? Esta acción no se puede deshacer.")
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
        .keyboardDismissArrow()
        .presentationDetents([.fraction(0.98), .large])
    }
    
    private func deleteCategory(_ cat: CategoryItem) {
        let success = CategoryHelper.deleteCustomCategory(name: cat.name, type: cat.type)
        if success {
            categoriesRefreshId = UUID()
            if selectedCategory.caseInsensitiveCompare(cat.name) == .orderedSame {
                selectedCategory = (selectedType == .income ? "Salario" : "Alimentación")
            }
            viewModel.showFloatingToast(
                title: "Categoría Eliminada",
                message: "Se eliminó '\(cat.name)' correctamente.",
                isSuccess: true,
                duration: 3.0
            )
        }
        categoryToDelete = nil
    }
    
    private func handleSave() {
        let cleanAmountStr = amountString.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let amount = Double(cleanAmountStr), amount > 0 else {
            errorMessage = nil
            viewModel.showFloatingToast(
                title: "Monto Requerido",
                message: "Ingresa un monto válido mayor a 0.",
                isSuccess: false,
                duration: 3.5
            )
            return
        }
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            isTitleMissing = true
            errorMessage = nil
            return
        }
        isTitleMissing = false
        
        let finalTitle = trimmedTitle
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
            viewModel.showFloatingToast(title: "Error al Guardar", message: msg ?? "No se pudo registrar el movimiento.", isSuccess: false, duration: 4.0)
        }
    }
}
