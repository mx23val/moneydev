import SwiftUI
import Charts

public struct CategoryStatsView: View {
    @Bindable var viewModel: ExpenseViewModel
    
    @State private var isPreviewSheetOpen: Bool = false
    @State private var isCustomDateFilterOpen: Bool = false
    @State private var capturedImage: UIImage? = nil
    @State private var alertMessage: String? = nil
    @State private var showAlert: Bool = false
    @State private var selectedCategorySummary: CategorySummary? = nil
    @State private var selectedBarCategory: String? = nil
    @State private var selectedAngleValue: Double? = nil
    
    private func categoryForAngle(_ angle: Double) -> CategorySummary? {
        var accumulated: Double = 0.0
        for cat in currentSummaries {
            accumulated += cat.totalAmount
            if angle <= accumulated {
                return cat
            }
        }
        return currentSummaries.last
    }
    
    private func dynamicCategoryLabel(_ str: String, count: Int, containerWidth: CGFloat) -> String {
        let availableWidth = max(200, containerWidth - 36)
        let perBarWidth = availableWidth / CGFloat(max(1, count))
        let capacity = max(5, Int(perBarWidth / 6.6))
        if str.count <= capacity {
            return str
        } else {
            let prefixCount = max(3, capacity - 1)
            return "\(str.prefix(prefixCount))..."
        }
    }
    
    private var activeTheme: AppColorTheme {
        AppColorTheme.fromId(viewModel.financialSummary.themeColorId)
    }
    
    private var isIncome: Bool {
        viewModel.statsReportMode == .incomes
    }
    
    private var currentSummaries: [CategorySummary] {
        switch viewModel.statsReportMode {
        case .expenses:
            return viewModel.expenseCategorySummaries
        case .incomes:
            return viewModel.incomeCategorySummaries
        case .comparative:
            // Combinar o mostrar gastos por defecto para la lista
            return viewModel.expenseCategorySummaries
        }
    }
    
    private var totalAmount: Double {
        currentSummaries.reduce(0.0) { $0 + $1.totalAmount }
    }
    
    public init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Selector de 3 Opciones: Gastos / Ingresos / Comparativo
                HStack(spacing: 0) {
                    modeButton(
                        title: "Gastos",
                        mode: .expenses,
                        selectedColor: AppColors.expenseRose
                    )
                    
                    modeButton(
                        title: "Ingresos",
                        mode: .incomes,
                        selectedColor: AppColors.incomeEmerald
                    )
                    
                    modeButton(
                        title: "Comparativo",
                        mode: .comparative,
                        selectedColor: activeTheme.primary
                    )
                }
                .padding(4)
                .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 12))
                .shadow(
                    color: Color.black.opacity(0.3),
                    radius: 4,
                    x: 0,
                    y: 2
                )
                
                // Controles de Tipo de Gráfico y Período
                HStack {
                    if viewModel.statsReportMode != .comparative {
                        // Selector Dona / Barras
                        Picker("Tipo de Gráfico", selection: Binding(
                            get: { viewModel.statsChartType },
                            set: { newType in
                                withAnimation(.easeInOut(duration: 0.28)) {
                                    viewModel.setStatsChartType(newType)
                                }
                            }
                        )) {
                            ForEach(ChartType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 160)
                    } else {
                        // Etiqueta de Modo Comparativo
                        HStack(spacing: 6) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 13, weight: .bold))
                            Text("Salud Financiera")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(activeTheme.accentTextColor)
                        .contrastTextOutline()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 10))
                        .shadow(
                            color: Color.black.opacity(0.2),
                            radius: 3,
                            x: 0,
                            y: 1
                        )
                    }
                    
                    Spacer()
                    
                    // Selector de Período
                    Menu {
                        ForEach(ReportPeriod.allCases, id: \.self) { p in
                            Button {
                                if p == .customRange {
                                    isCustomDateFilterOpen = true
                                } else {
                                    viewModel.setStatsPeriod(p)
                                }
                            } label: {
                                HStack {
                                    Text(p.displayName)
                                    if viewModel.statsPeriod == p {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12, weight: .bold))
                            Text(viewModel.statsPeriod == .customRange && viewModel.statsCustomRange != nil ? (viewModel.statsCustomRange?.label ?? "Personalizado") : viewModel.statsPeriod.displayName)
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 10))
                        .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentTextColor)
                        .contrastTextOutline()
                        .shadow(
                            color: Color.black.opacity(0.25),
                            radius: 3,
                            x: 0,
                            y: 1.5
                        )
                    }
                }
                
                // Barra de Botones de Acción (Vista Previa, Descargar en Fotos, Compartir)
                HStack {
                    Text(viewModel.statsReportMode == .comparative ? "Balance & Salud Financiera" : (isIncome ? "Reporte de Ingresos" : "Reporte de Gastos"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        // Vista Previa de la Captura
                        Button {
                            handlePreview()
                        } label: {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(activeTheme.accentIconColor)
                                .frame(width: 36, height: 36)
                                .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 18))
                                .clipShape(Circle())
                                .shadow(
                                    color: Color.black.opacity(0.25),
                                    radius: 3,
                                    x: 0,
                                    y: 1.5
                                )
                        }
                        
                        // Descargar Imagen en el Dispositivo
                        Button {
                            handleDownload()
                        } label: {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(AppColors.incomeEmeraldLight)
                                .frame(width: 36, height: 36)
                                .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 18))
                                .clipShape(Circle())
                                .shadow(
                                    color: Color.black.opacity(0.25),
                                    radius: 3,
                                    x: 0,
                                    y: 1.5
                                )
                        }
                        
                        // Compartir (Nativo y a prueba de fallos)
                        Button {
                            handleShare()
                        } label: {
                            Image(systemName: "square.and.arrow.up.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color(hex: "#F59E0B"))
                                .frame(width: 36, height: 36)
                                .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 18))
                                .clipShape(Circle())
                                .shadow(
                                    color: Color.black.opacity(0.25),
                                    radius: 3,
                                    x: 0,
                                    y: 1.5
                                )
                        }
                    }
                }
                
                if viewModel.statsReportMode == .comparative {
                    // SECCIÓN COMPARATIVO
                    comparativeSectionContent
                        .id("stats_comparative_section")
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    // SECCIÓN GASTOS O INGRESOS INDIVIDUAL
                    VStack(spacing: 20) {
                        singleModeStatsCard
                        categoriesBreakdownList
                    }
                    .id("stats_individual_section_\(viewModel.statsReportMode.rawValue)")
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .padding(16)
            .padding(.bottom, 110)
            .animation(.easeInOut(duration: 0.28), value: viewModel.statsChartType)
            .animation(.easeInOut(duration: 0.28), value: viewModel.statsReportMode)
            .onChange(of: viewModel.statsReportMode) { _, _ in
                selectedCategorySummary = nil
                selectedBarCategory = nil
                selectedAngleValue = nil
            }
            .onChange(of: viewModel.statsChartType) { _, _ in
                selectedCategorySummary = nil
                selectedBarCategory = nil
                selectedAngleValue = nil
            }
        }
        .sheet(isPresented: $isPreviewSheetOpen) {
            StatsCapturePreviewDialog(
                cardView: makeCaptureCardView(),
                theme: activeTheme,
                onSave: { img in
                    saveImageToPhotos(img)
                },
                onShare: { img in
                    ShareSheetPresenter.present(items: [img])
                },
                onDismiss: {
                    isPreviewSheetOpen = false
                }
            )
            .themedSheetContainer(theme: activeTheme)
        }
        .sheet(isPresented: $isCustomDateFilterOpen) {
            CustomDateFilterDialog(viewModel: viewModel, isForStats: true)
                .themedSheetContainer(theme: activeTheme)
        }
        .alert("Aviso", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage ?? "")
        }
    }
    
    // MARK: - Botón de Modo
    private func modeButton(title: String, mode: StatsReportMode, selectedColor: Color) -> some View {
        let isSelected = viewModel.statsReportMode == mode
        
        let bgColor: Color = {
            guard isSelected else { return Color.clear }
            if mode == .comparative {
                return activeTheme == .electricBlack ? Color(hex: "#1E293B") : activeTheme.primary
            }
            return selectedColor
        }()
        
        let textColor: Color = {
            guard isSelected else { return AppColors.textSecondary }
            if mode == .comparative {
                return activeTheme.onPrimaryText
            }
            return .white
        }()
        
        return Button {
            withAnimation(.easeInOut(duration: 0.28)) {
                viewModel.setStatsReportMode(mode)
            }
        } label: {
            Group {
                if isSelected {
                    Text(title)
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(textColor)
                } else {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(textColor)
                        .contrastTextOutline(color: Color.black.opacity(0.6), radius: 0.5)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: isSelected ? Color.black.opacity(0.35) : Color.clear, radius: 4, x: 0, y: 2)
        }
    }
    
    // MARK: - Tarjeta de Gráfico Individual (Gastos o Ingresos)
    private var singleModeStatsCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isIncome ? "Total Ingresos" : "Total Gastos")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                    
                    Text("\(viewModel.financialSummary.currencySymbol) \(FormatHelper.formatCurrency(totalAmount))")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(isIncome ? AppColors.incomeEmeraldLight : AppColors.expenseRoseLight)
                }
                
                Spacer()
            }
            
            if currentSummaries.isEmpty || totalAmount <= 0 {
                VStack(spacing: 10) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(AppColors.textMuted)
                    Text("No hay movimientos registrados en este período")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(height: 200)
            } else {
                // Ventana Flotante de Detalle al Tocar Gráfico (Barra o Dona)
                if let selected = selectedCategorySummary {
                    let catIcon = CategoryHelper.getCategoryIcon(name: selected.categoryName, type: selected.type)
                    let catColor = Color(hex: CategoryHelper.getCategoryColorHex(name: selected.categoryName, type: selected.type))
                    
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(catColor.opacity(0.25))
                                .frame(width: 36, height: 36)
                            Image(systemName: catIcon)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(catColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selected.categoryName)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.white)
                                .contrastTextOutline()
                                .lineLimit(1)
                            
                            Text("\(selected.transactionCount) movimiento\(selected.transactionCount == 1 ? "" : "s")")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppColors.textMuted)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(viewModel.financialSummary.currencySymbol) \(FormatHelper.formatCurrency(selected.totalAmount))")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentTextColor)
                                .contrastTextOutline()
                            
                            Text(String(format: "%.1f%%", selected.percentage * 100))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(catColor)
                        }
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.12)) {
                                selectedCategorySummary = nil
                                selectedBarCategory = nil
                                selectedAngleValue = nil
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.white.opacity(0.65))
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 4)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 14)
                    )
                    .shadow(color: Color.black.opacity(0.45), radius: 6, x: 0, y: 2)
                    .transition(.scale(scale: 0.98).combined(with: .opacity))
                }
                
                if viewModel.statsChartType == .pie {
                    Chart(currentSummaries) { cat in
                        SectorMark(
                            angle: .value("Monto", cat.totalAmount),
                            innerRadius: .ratio(0.58),
                            angularInset: selectedCategorySummary?.categoryName == cat.categoryName ? 2.5 : 1.2
                        )
                        .cornerRadius(5)
                        .foregroundStyle(Color(hex: CategoryHelper.getCategoryColorHex(name: cat.categoryName, type: cat.type)))
                        .opacity(selectedCategorySummary == nil || selectedCategorySummary?.categoryName == cat.categoryName ? 1.0 : 0.35)
                    }
                    .frame(height: 220)
                    .chartLegend(.hidden)
                    .chartAngleSelection(value: $selectedAngleValue)
                    .onChange(of: selectedAngleValue) { _, newAngle in
                        guard let newAngle else { return }
                        if let newCat = categoryForAngle(newAngle), newCat.categoryName != selectedCategorySummary?.categoryName {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                selectedCategorySummary = newCat
                            }
                        }
                    }
                    .id("chart_pie_\(viewModel.statsReportMode.rawValue)")
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
                } else {
                    let displayedItems = Array(currentSummaries.prefix(6))
                    GeometryReader { chartGeo in
                        Chart(displayedItems) { cat in
                            BarMark(
                                x: .value("Categoría", cat.categoryName),
                                y: .value("Monto", cat.totalAmount)
                            )
                            .cornerRadius(6)
                            .foregroundStyle(Color(hex: CategoryHelper.getCategoryColorHex(name: cat.categoryName, type: cat.type)))
                            .opacity(selectedCategorySummary == nil || selectedCategorySummary?.categoryName == cat.categoryName ? 1.0 : 0.35)
                        }
                        .chartXSelection(value: $selectedBarCategory)
                        .onChange(of: selectedBarCategory) { _, newCat in
                            guard let newCat else { return }
                            if newCat != selectedCategorySummary?.categoryName {
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    selectedCategorySummary = currentSummaries.first(where: { $0.categoryName == newCat })
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic) { value in
                                AxisValueLabel {
                                    if let catName = value.as(String.self) {
                                        Text(dynamicCategoryLabel(catName, count: displayedItems.count, containerWidth: chartGeo.size.width))
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(Color.white)
                                            .contrastTextOutline()
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: 220)
                    .id("chart_bar_\(viewModel.statsReportMode.rawValue)")
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
                }
            }
        }
        .padding(18)
        .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 18))
        .shadow(
            color: Color.black.opacity(0.35),
            radius: 8,
            x: 0,
            y: 4
        )
    }
    
    // MARK: - Desglose de Categorías
    private var categoriesBreakdownList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Desglose por Categoría")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
                .contrastTextOutline()
            
            ForEach(currentSummaries) { cat in
                let isSelected = selectedCategorySummary?.id == cat.id
                Button {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        if isSelected {
                            selectedCategorySummary = nil
                            selectedBarCategory = nil
                            selectedAngleValue = nil
                        } else {
                            selectedCategorySummary = cat
                            selectedBarCategory = cat.categoryName
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        let icon = CategoryHelper.getCategoryIcon(name: cat.categoryName, type: cat.type)
                        let color = Color(hex: CategoryHelper.getCategoryColorHex(name: cat.categoryName, type: cat.type))
                        
                        Circle()
                            .fill(color.opacity(0.2))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Image(systemName: icon)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(color)
                            }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(cat.categoryName)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppColors.textPrimary)
                                .contrastTextOutline()
                            
                            Text("\(cat.transactionCount) movimiento\(cat.transactionCount == 1 ? "" : "s")")
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.textMuted)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("\(viewModel.financialSummary.currencySymbol) \(FormatHelper.formatCurrency(cat.totalAmount))")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.textPrimary)
                                .contrastTextOutline()
                            
                            Text(String(format: "%.1f%%", cat.percentage * 100))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(color)
                                .contrastTextOutline()
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 12)
                    )
                    .shadow(
                        color: isSelected ? Color.black.opacity(0.4) : Color.black.opacity(0.2),
                        radius: 4,
                        x: 0,
                        y: 2
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - SECCIÓN COMPARATIVO (Ingresos vs Gastos y Métricas de Salud Financiera)
    private var comparativeSectionContent: some View {
        VStack(spacing: 18) {
            let totalIncome = viewModel.statsTotalIncome
            let totalExpense = viewModel.statsTotalExpense
            let net = viewModel.statsNetBalance
            let savingsRate = viewModel.statsSavingsRate
            let expenseRatio = viewModel.statsExpenseRatio
            
            // 1. Tarjeta Resumen Dual: Ingresos vs Gastos + Balance Neto
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    // Caja Ingresos
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(AppColors.incomeEmerald.opacity(0.2))
                                .frame(width: 22, height: 22)
                                .overlay {
                                    Image(systemName: "arrow.down.left")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(AppColors.incomeEmerald)
                                }
                            Text("Total Ingresos")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        
                        Text("+\(viewModel.financialSummary.currencySymbol) \(FormatHelper.formatCurrency(totalIncome))")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(AppColors.incomeEmeraldLight)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 14))
                    .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)
                    
                    // Caja Gastos
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(AppColors.expenseRose.opacity(0.2))
                                .frame(width: 22, height: 22)
                                .overlay {
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(AppColors.expenseRose)
                                }
                            Text("Total Gastos")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        
                        Text("-\(viewModel.financialSummary.currencySymbol) \(FormatHelper.formatCurrency(totalExpense))")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(AppColors.expenseRoseLight)
                            .contrastTextOutline()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 14))
                    .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)
                }
                
                Divider().background(Color.white.opacity(0.12))
                
                // Resultado Neto: Superávit o Déficit
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(net >= 0 ? "Superávit del Período" : "Déficit del Período")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(net >= 0 ? AppColors.incomeEmeraldLight : AppColors.expenseRoseLight)
                            .contrastTextOutline()
                        
                        Text("\(viewModel.financialSummary.currencySymbol) \(FormatHelper.formatCurrency(net))")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(net >= 0 ? .white : AppColors.expenseRoseLight)
                            .contrastTextOutline()
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Image(systemName: net >= 0 ? "arrow.up.forward.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                        Text(net >= 0 ? "Superávit" : "Déficit")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(net >= 0 ? AppColors.incomeEmeraldLight : AppColors.expenseRoseLight)
                    .contrastTextOutline()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((net >= 0 ? AppColors.incomeEmerald : AppColors.expenseRose).opacity(0.18))
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.2), radius: 3)
                }
            }
            .padding(16)
            .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 18))
            .shadow(
                color: Color.black.opacity(0.35),
                radius: 8,
                x: 0,
                y: 4
            )
            
            // 2. Gráfico Comparativo Visual: Ingresos vs Gastos
            VStack(alignment: .leading, spacing: 14) {
                Text("Comparativa Visual")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .contrastTextOutline()
                
                if totalIncome <= 0 && totalExpense <= 0 {
                    Text("No hay movimientos registrados para comparar en este período.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.vertical, 12)
                } else {
                    // Barras Comparativas con Swift Charts
                    Chart {
                        BarMark(
                            x: .value("Flujo", "Ingresos"),
                            y: .value("Monto", totalIncome)
                        )
                        .cornerRadius(6)
                        .foregroundStyle(AppColors.incomeEmerald)
                        .annotation(position: .top) {
                            Text("\(FormatHelper.formatCurrency(totalIncome))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppColors.incomeEmeraldLight)
                                .contrastTextOutline()
                        }
                        
                        BarMark(
                            x: .value("Flujo", "Gastos"),
                            y: .value("Monto", totalExpense)
                        )
                        .cornerRadius(6)
                        .foregroundStyle(AppColors.expenseRose)
                        .annotation(position: .top) {
                            Text("\(FormatHelper.formatCurrency(totalExpense))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppColors.expenseRoseLight)
                                .contrastTextOutline()
                        }
                    }
                    .frame(height: 180)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .id("comparative_flow_chart")
                    
                    // Barra de Proporción del Ingreso Consumido
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Consumo del Ingreso: \(String(format: "%.1f%%", min(100.0, expenseRatio)))")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColors.textSecondary)
                            Spacer()
                            Text(savingsRate >= 0 ? "Ahorro: \(String(format: "%.1f%%", savingsRate))" : "Exceso: +\(String(format: "%.1f%%", abs(savingsRate)))")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(savingsRate >= 0 ? AppColors.incomeEmeraldLight : AppColors.expenseRoseLight)
                                .contrastTextOutline()
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(AppColors.incomeEmerald.opacity(0.35))
                                    .frame(width: geo.size.width, height: 12)
                                
                                let proportion = totalIncome > 0 ? min(1.0, max(0.0, totalExpense / totalIncome)) : (totalExpense > 0 ? 1.0 : 0.0)
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [AppColors.expenseRose, AppColors.expenseRoseLight],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * proportion, height: 12)
                            }
                        }
                        .frame(height: 12)
                    }
                    .padding(.top, 6)
                }
            }
            .padding(16)
            .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 18))
            .shadow(
                color: Color.black.opacity(0.35),
                radius: 8,
                x: 0,
                y: 4
            )
            
            // 3. Tarjeta de Salud Financiera & Diagnóstico
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(hex: viewModel.financialHealthBadgeColorHex))
                        Text("Salud Financiera")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                            .contrastTextOutline()
                    }
                    
                    Spacer()
                    
                    Text("\(viewModel.financialHealthScore)/100 - \(viewModel.financialHealthBadgeTitle)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .contrastTextOutline()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: viewModel.financialHealthBadgeColorHex))
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.2), radius: 3)
                }
                
                // Métricas clave en cuadrícula
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    // Métrica 1: Tasa de Ahorro
                    healthMetricCard(
                        title: "Tasa de Ahorro",
                        value: String(format: "%.1f%%", savingsRate),
                        status: savingsRate >= 20 ? "Excelente (>20%)" : (savingsRate >= 10 ? "Saludable" : (savingsRate >= 0 ? "Ajustado" : "En Déficit")),
                        statusColor: savingsRate >= 20 ? AppColors.incomeEmeraldLight : (savingsRate >= 10 ? Color(hex: "#38BDF8") : (savingsRate >= 0 ? Color(hex: "#F59E0B") : AppColors.expenseRoseLight)),
                        icon: "leaf.fill"
                    )
                    
                    // Métrica 2: Ratio de Consumo
                    healthMetricCard(
                        title: "Ratio de Gastos",
                        value: String(format: "%.1f%%", expenseRatio),
                        status: expenseRatio <= 70 ? "Bajo Consumo" : (expenseRatio <= 90 ? "Moderado" : "Consumo Alto"),
                        statusColor: expenseRatio <= 70 ? AppColors.incomeEmeraldLight : (expenseRatio <= 90 ? Color(hex: "#F59E0B") : AppColors.expenseRoseLight),
                        icon: "flame.fill"
                    )
                    
                    // Métrica 3: Gastos Fijos
                    healthMetricCard(
                        title: "Gastos Fijos",
                        value: "\(viewModel.financialSummary.currencySymbol) \(FormatHelper.formatCurrency(viewModel.statsFixedExpensesTotal))",
                        status: totalIncome > 0 ? "\(String(format: "%.0f%%", viewModel.statsFixedExpenseBurden)) de ingresos" : "Comprometido",
                        statusColor: viewModel.statsFixedExpenseBurden <= 50 ? AppColors.incomeEmeraldLight : Color(hex: "#F59E0B"),
                        icon: "calendar.badge.clock"
                    )
                    
                    // Métrica 4: Regla 50/30/20
                    healthMetricCard(
                        title: "Regla 50/30/20",
                        value: viewModel.statsFixedExpenseBurden <= 50 ? "En Regla" : "Desviado",
                        status: "Meta Fijo ≤ 50%",
                        statusColor: viewModel.statsFixedExpenseBurden <= 50 ? AppColors.incomeEmeraldLight : Color(hex: "#F59E0B"),
                        icon: "chart.pie.fill"
                    )
                }
                
                // Tarjeta de Consejo Inteligente
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(activeTheme.accentIconColor)
                    
                    Text(viewModel.financialHealthAdvice)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineSpacing(3)
                }
                .padding(12)
                .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 12))
                .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)
            }
            .padding(16)
            .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 18))
            .shadow(
                color: Color.black.opacity(0.35),
                radius: 8,
                x: 0,
                y: 4
            )
            
            // 4. Categorías Principales Comparadas
            VStack(alignment: .leading, spacing: 12) {
                Text("Categorías Más Relevantes")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .contrastTextOutline()
                
                if let topExpense = viewModel.expenseCategorySummaries.first {
                    topCategoryCard(
                        title: "Mayor Gasto:",
                        category: topExpense.categoryName,
                        amount: topExpense.totalAmount,
                        color: AppColors.expenseRose,
                        isExpense: true
                    )
                }
                
                if let topIncome = viewModel.incomeCategorySummaries.first {
                    topCategoryCard(
                        title: "Mayor Ingreso:",
                        category: topIncome.categoryName,
                        amount: topIncome.totalAmount,
                        color: AppColors.incomeEmerald,
                        isExpense: false
                    )
                }
            }
        }
    }
    
    private func healthMetricCard(title: String, value: String, status: String, statusColor: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(statusColor)
            }
            
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .contrastTextOutline()
                .lineLimit(1)
            
            Text(status)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(statusColor)
                .contrastTextOutline()
                .lineLimit(1)
        }
        .padding(10)
        .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 12))
        .shadow(
            color: Color.black.opacity(0.2),
            radius: 3,
            x: 0,
            y: 1
        )
    }
    
    private func topCategoryCard(title: String, category: String, amount: Double, color: Color, isExpense: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppColors.textMuted)
                Text(category)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .contrastTextOutline()
            }
            Spacer()
            Text("\(isExpense ? "-" : "+")\(viewModel.financialSummary.currencySymbol) \(FormatHelper.formatCurrency(amount))")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .contrastTextOutline()
        }
        .padding(12)
        .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 12))
        .shadow(
            color: Color.black.opacity(0.25),
            radius: 3,
            x: 0,
            y: 1.5
        )
    }
    
    // MARK: - Generación y Captura de Imagen
    private func makeCaptureCardView() -> StatsCaptureCardView {
        StatsCaptureCardView(
            periodTitle: viewModel.statsPeriod.displayName,
            walletName: viewModel.financialSummary.activeWalletName,
            isIncome: isIncome,
            currencySymbol: viewModel.financialSummary.currencySymbol,
            totalAmount: totalAmount,
            chartType: viewModel.statsChartType,
            summaries: currentSummaries,
            mode: viewModel.statsReportMode,
            totalIncome: viewModel.statsTotalIncome,
            totalExpense: viewModel.statsTotalExpense,
            savingsRate: viewModel.statsSavingsRate,
            healthScore: viewModel.financialHealthScore,
            healthBadgeTitle: viewModel.financialHealthBadgeTitle,
            themeColorHex: activeTheme.accentHex,
            theme: activeTheme
        )
    }
    
    @MainActor
    private func generateCaptureImage() -> UIImage? {
        let captureCard = makeCaptureCardView()
        return StatsCaptureCardView.renderImage(from: captureCard)
    }
    
    private func handlePreview() {
        isPreviewSheetOpen = true
    }
    
    private func handleDownload() {
        guard let img = generateCaptureImage() else {
            alertMessage = "No se pudo generar la captura de estadísticas."
            showAlert = true
            return
        }
        saveImageToPhotos(img)
    }
    
    private func saveImageToPhotos(_ img: UIImage) {
        PhotoLibrarySaver.shared.save(image: img) { success, error in
            DispatchQueue.main.async {
                if success {
                    alertMessage = "¡Imagen guardada en tu galería de Fotos con éxito! 📸"
                } else {
                    alertMessage = error ?? "No se pudo guardar la imagen en Fotos."
                }
                showAlert = true
            }
        }
    }
    
    private func handleShare() {
        guard let img = generateCaptureImage() else {
            alertMessage = "No se pudo generar la captura para compartir."
            showAlert = true
            return
        }
        ShareSheetPresenter.present(items: [img])
    }
}
