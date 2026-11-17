import SwiftUI
import Charts

public struct CategoryStatsView: View {
    @Bindable var viewModel: ExpenseViewModel
    
    @State private var showingExportSheet: Bool = false
    @State private var exportItems: [Any] = []
    
    private var activeTheme: AppColorTheme {
        AppColorTheme.fromId(viewModel.financialSummary.themeColorId)
    }
    
    private var isIncome: Bool {
        viewModel.statsReportMode == .incomes
    }
    
    private var currentSummaries: [CategorySummary] {
        isIncome ? viewModel.incomeCategorySummaries : viewModel.expenseCategorySummaries
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
                // Selector Gastos / Ingresos
                HStack(spacing: 0) {
                    Button {
                        withAnimation(.spring) {
                            viewModel.setStatsReportMode(.expenses)
                        }
                    } label: {
                        Text("Gastos")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(viewModel.statsReportMode == .expenses ? .white : AppColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(viewModel.statsReportMode == .expenses ? AppColors.expenseRose : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    Button {
                        withAnimation(.spring) {
                            viewModel.setStatsReportMode(.incomes)
                        }
                    } label: {
                        Text("Ingresos")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(viewModel.statsReportMode == .incomes ? .white : AppColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(viewModel.statsReportMode == .incomes ? AppColors.incomeEmerald : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(4)
                .background(AppColors.darkNavySurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Chart Type and Period Controls
                HStack {
                    // Chart Type Toggle
                    Picker("Tipo de Gráfico", selection: Binding(
                        get: { viewModel.statsChartType },
                        set: { viewModel.setStatsChartType($0) }
                    )) {
                        ForEach(ChartType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 160)
                    
                    Spacer()
                    
                    // Period Picker Menu
                    Menu {
                        ForEach(ReportPeriod.allCases, id: \.self) { p in
                            Button {
                                viewModel.setStatsPeriod(p)
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
                            Text(viewModel.statsPeriod.displayName)
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppColors.darkNavySurface)
                        .foregroundStyle(activeTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppColors.cardBorderNavy, lineWidth: 1)
                        )
                    }
                }
                
                // Chart Card
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isIncome ? "Total Ingresos" : "Total Gastos")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppColors.textSecondary)
                            
                            Text("\(viewModel.financialSummary.currencySymbol) \(FormatHelper.formatCurrency(totalAmount))")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundStyle(isIncome ? AppColors.incomeEmeraldLight : AppColors.expenseRoseLight)
                        }
                        
                        Spacer()
                        
                        // Export Buttons (PDF / CSV)
                        HStack(spacing: 8) {
                            Button {
                                exportPdf()
                            } label: {
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(hex: "#38BDF8"))
                                    .frame(width: 36, height: 36)
                                    .background(AppColors.navySurfaceVariant)
                                    .clipShape(Circle())
                            }
                            
                            Button {
                                exportCsv()
                            } label: {
                                Image(systemName: "tablecells.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(hex: "#34D399"))
                                    .frame(width: 36, height: 36)
                                    .background(AppColors.navySurfaceVariant)
                                    .clipShape(Circle())
                            }
                        }
                    }
                    
                    if currentSummaries.isEmpty || totalAmount <= 0 {
                        VStack(spacing: 10) {
                            Image(systemName: "chart.pie.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(AppColors.textMuted)
                            Text("No hay movimientos registrados en este período")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .frame(height: 200)
                    } else {
                        if viewModel.statsChartType == .pie {
                            // Gráfico de Dona / Pie con SwiftUI Charts (iOS 17+)
                            Chart(currentSummaries) { cat in
                                SectorMark(
                                    angle: .value("Monto", cat.totalAmount),
                                    innerRadius: .ratio(0.60),
                                    angularInset: 1.5
                                )
                                .cornerRadius(5)
                                .foregroundStyle(Color(hex: CategoryHelper.getCategoryColorHex(name: cat.categoryName, type: cat.type)))
                            }
                            .frame(height: 220)
                            .chartLegend(.hidden)
                        } else {
                            // Gráfico de Barras
                            Chart(currentSummaries.prefix(6)) { cat in
                                BarMark(
                                    x: .value("Categoría", cat.categoryName),
                                    y: .value("Monto", cat.totalAmount)
                                )
                                .cornerRadius(6)
                                .foregroundStyle(Color(hex: CategoryHelper.getCategoryColorHex(name: cat.categoryName, type: cat.type)))
                            }
                            .frame(height: 220)
                            .chartXAxis {
                                AxisMarks(values: .automatic) { value in
                                    AxisValueLabel {
                                        if let str = value.as(String.self) {
                                            Text(str.prefix(6))
                                                .font(.system(size: 10))
                                                .foregroundStyle(AppColors.textSecondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(18)
                .background(AppColors.darkNavySurface)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(AppColors.cardBorderNavy, lineWidth: 1)
                )
                
                // Desglose detallado por categoría
                VStack(alignment: .leading, spacing: 12) {
                    Text("Desglose por Categoría")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                    
                    ForEach(currentSummaries) { cat in
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
                                
                                Text("\(cat.transactionCount) movimiento\(cat.transactionCount == 1 ? "" : "s")")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppColors.textMuted)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("\(viewModel.financialSummary.currencySymbol) \(FormatHelper.formatCurrency(cat.totalAmount))")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppColors.textPrimary)
                                
                                Text(String(format: "%.1f%%", cat.percentage * 100))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(color)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(AppColors.darkNavySurface.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.cardBorderNavy.opacity(0.5), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(16)
        }
        .sheet(isPresented: $showingExportSheet) {
            ActivityViewController(activityItems: exportItems)
        }
    }
    
    private func exportPdf() {
        if let pdfData = ReportExportHelper.generatePdfReport(
            periodTitle: viewModel.statsPeriod.displayName,
            isIncome: isIncome,
            categories: currentSummaries,
            transactions: viewModel.filteredTransactions,
            totalAmount: totalAmount,
            currencySymbol: viewModel.financialSummary.currencySymbol,
            walletName: viewModel.financialSummary.activeWalletName
        ) {
            let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("Reporte_MoneyDev.pdf")
            try? pdfData.write(to: tempUrl)
            exportItems = [tempUrl]
            showingExportSheet = true
        }
    }
    
    private func exportCsv() {
        if let csvUrl = ReportExportHelper.generateCsv(
            transactions: viewModel.filteredTransactions,
            walletName: viewModel.financialSummary.activeWalletName,
            currency: viewModel.financialSummary.currencySymbol
        ) {
            exportItems = [csvUrl]
            showingExportSheet = true
        }
    }
}

// UIActivityViewController Wrapper para compartir en iOS
public struct ActivityViewController: UIViewControllerRepresentable {
    public var activityItems: [Any]
    public var applicationActivities: [UIActivity]? = nil

    public func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
}
