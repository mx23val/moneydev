import SwiftUI
import Charts
import UIKit

// MARK: - Tarjeta de Captura de Estadísticas con Gráficos y Leyenda
public struct StatsCaptureCardView: View {
    let periodTitle: String
    let walletName: String
    let mode: StatsReportMode
    let currencySymbol: String
    let totalAmount: Double
    let chartType: ChartType
    let summaries: [CategorySummary]
    let totalIncome: Double
    let totalExpense: Double
    let savingsRate: Double
    let healthScore: Int
    let healthBadgeTitle: String
    let themeColorHex: String
    public var theme: AppColorTheme
    
    public init(
        periodTitle: String,
        walletName: String,
        isIncome: Bool,
        currencySymbol: String,
        totalAmount: Double,
        chartType: ChartType,
        summaries: [CategorySummary],
        mode: StatsReportMode = .expenses,
        totalIncome: Double = 0.0,
        totalExpense: Double = 0.0,
        savingsRate: Double = 0.0,
        healthScore: Int = 50,
        healthBadgeTitle: String = "Saludable",
        themeColorHex: String = "#38BDF8",
        theme: AppColorTheme = .electricBlue
    ) {
        self.periodTitle = periodTitle
        self.walletName = walletName
        self.mode = mode
        self.currencySymbol = currencySymbol
        self.totalAmount = totalAmount
        self.chartType = chartType
        self.summaries = summaries
        self.totalIncome = totalIncome
        self.totalExpense = totalExpense
        self.savingsRate = savingsRate
        self.healthScore = healthScore
        self.healthBadgeTitle = healthBadgeTitle
        self.themeColorHex = themeColorHex
        self.theme = theme
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Encabezado
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    let activeIconName = AppIconManager.isProIconActive() ? "icon_pro" : "icon_basic"
                    if let uiImage = UIImage(named: activeIconName) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 34, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 1)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: AppIconManager.isProIconActive() ?
                                            [Color(hex: "#F59E0B"), Color(hex: "#78350F")] :
                                            [Color(hex: themeColorHex), Color(hex: themeColorHex).opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 34, height: 34)
                            
                            Image(systemName: AppIconManager.isProIconActive() ? "crown.fill" : "dollarsign.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("MoneyDev")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Reporte Financiero")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(hex: "#94A3B8"))
                    }
                }
                
                Spacer()
                
                let badgeText: String = {
                    switch mode {
                    case .expenses: return "GASTOS"
                    case .incomes: return "INGRESOS"
                    case .comparative: return "COMPARATIVO"
                    }
                }()
                let badgeColor: Color = {
                    switch mode {
                    case .expenses: return Color(hex: "#F43F5E")
                    case .incomes: return Color(hex: "#10B981")
                    case .comparative: return Color(hex: themeColorHex)
                    }
                }()
                
                Text(badgeText)
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(badgeColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(badgeColor.opacity(0.15))
                    .clipShape(Capsule())
            }
            
            Divider().background(Color(hex: "#1E293B"))
            
            // Meta información
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 11))
                    Text(walletName)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Color(hex: "#CBD5E1"))
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                    Text(periodTitle)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Color(hex: themeColorHex))
            }
            
            if mode == .comparative {
                // 1. Caja Comparativa Resumen: Ingresos vs Gastos + Superávit / Déficit
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.left")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color(hex: "#10B981"))
                                Text("Total Ingresos")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color(hex: "#94A3B8"))
                            }
                            Text("+\(currencySymbol) \(FormatHelper.formatCurrency(totalIncome))")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#34D399"))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(theme == .electricBlack ? Color.white.opacity(0.07) : Color.black.opacity(0.35))
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 1)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color(hex: "#F43F5E"))
                                Text("Total Gastos")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color(hex: "#94A3B8"))
                                    .contrastTextOutline()
                            }
                            Text("-\(currencySymbol) \(FormatHelper.formatCurrency(totalExpense))")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#FB7185"))
                                .contrastTextOutline()
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(theme == .electricBlack ? Color.white.opacity(0.07) : Color.black.opacity(0.35))
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 1)
                    }
                    
                    Divider().background(Color(hex: "#1E293B"))
                    
                    let net = totalIncome - totalExpense
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(net >= 0 ? "Superávit del Período" : "Déficit del Período")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(net >= 0 ? Color(hex: "#10B981") : Color(hex: "#F43F5E"))
                                .contrastTextOutline()
                            Text("\(currencySymbol) \(FormatHelper.formatCurrency(net))")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .contrastTextOutline()
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: net >= 0 ? "arrow.up.forward.circle.fill" : "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                Text(net >= 0 ? "Superávit" : "Déficit")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(net >= 0 ? Color(hex: "#10B981") : Color(hex: "#F43F5E"))
                            .contrastTextOutline()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((net >= 0 ? Color(hex: "#10B981") : Color(hex: "#F43F5E")).opacity(0.18))
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(14)
                .background(ThemedCardBackgroundView(theme: theme, cornerRadius: 14))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 2)
                
                // 2. Gráfico Comparativo Visual: Ingresos vs Gastos
                VStack(alignment: .leading, spacing: 12) {
                    Text("Comparativa Visual")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white)
                        .contrastTextOutline()
                    
                    if totalIncome <= 0 && totalExpense <= 0 {
                        Text("No hay movimientos registrados para comparar en este período.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "#94A3B8"))
                            .contrastTextOutline()
                            .padding(.vertical, 8)
                    } else {
                        Chart {
                            BarMark(
                                x: .value("Flujo", "Ingresos"),
                                y: .value("Monto", totalIncome)
                            )
                            .cornerRadius(6)
                            .foregroundStyle(Color(hex: "#10B981"))
                            .annotation(position: .top) {
                                Text("\(currencySymbol)\(FormatHelper.formatCurrency(totalIncome))")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color(hex: "#34D399"))
                                    .contrastTextOutline()
                            }
                            
                            BarMark(
                                x: .value("Flujo", "Gastos"),
                                y: .value("Monto", totalExpense)
                            )
                            .cornerRadius(6)
                            .foregroundStyle(Color(hex: "#F43F5E"))
                            .annotation(position: .top) {
                                Text("\(currencySymbol)\(FormatHelper.formatCurrency(totalExpense))")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color(hex: "#FB7185"))
                                    .contrastTextOutline()
                            }
                        }
                        .frame(height: 155)
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        
                        // Barra de Proporción del Ingreso Consumido
                        let expenseRatio = totalIncome > 0 ? (totalExpense / totalIncome) * 100.0 : (totalExpense > 0 ? 100.0 : 0.0)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text("Consumo del Ingreso: \(String(format: "%.1f%%", min(100.0, expenseRatio)))")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color(hex: "#CBD5E1"))
                                    .contrastTextOutline()
                                Spacer()
                                Text(savingsRate >= 0 ? "Ahorro: \(String(format: "%.1f%%", savingsRate))" : "Exceso: +\(String(format: "%.1f%%", abs(savingsRate)))")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(savingsRate >= 0 ? Color(hex: "#34D399") : Color(hex: "#FB7185"))
                                    .contrastTextOutline()
                            }
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(hex: "#10B981").opacity(0.35))
                                        .frame(width: geo.size.width, height: 10)
                                    
                                    let proportion = totalIncome > 0 ? min(1.0, max(0.0, totalExpense / totalIncome)) : (totalExpense > 0 ? 1.0 : 0.0)
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: "#F43F5E"), Color(hex: "#FB7185")],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * proportion, height: 10)
                                }
                            }
                            .frame(height: 10)
                        }
                    }
                }
                .padding(14)
                .background(ThemedCardBackgroundView(theme: theme, cornerRadius: 14))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 2)
                
                // 3. Tarjeta de Diagnóstico y Salud Financiera
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.text.square.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(theme == .electricBlack ? Color.white : Color(hex: themeColorHex))
                            Text("Salud Financiera")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.white)
                                .contrastTextOutline()
                        }
                        Spacer()
                        Text("\(healthScore)/100 - \(healthBadgeTitle)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(theme == .electricBlack ? Color.white : Color(hex: themeColorHex))
                            .contrastTextOutline()
                    }
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "percent")
                                .font(.system(size: 10, weight: .bold))
                            Text("Tasa Ahorro: \(String(format: "%.1f%%", savingsRate))")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(savingsRate >= 10 ? Color(hex: "#34D399") : Color(hex: "#F59E0B"))
                        .contrastTextOutline()
                        
                        Spacer()
                        
                        let statusDesc: String = savingsRate >= 20 ? "Ahorro Óptimo" : (savingsRate >= 0 ? "Presupuesto Saludable" : "Alerta de Gasto")
                        Text(statusDesc)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white)
                            .contrastTextOutline()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                .padding(14)
                .background(ThemedCardBackgroundView(theme: theme, cornerRadius: 14))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 2)
            } else {
                // Modo Gastos o Ingresos: Caja del Total
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode == .incomes ? "Total Ingresos del Período" : "Total Gastos del Período")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color(hex: "#CBD5E1"))
                            .contrastTextOutline()
                        
                        Text("\(currencySymbol) \(FormatHelper.formatCurrency(totalAmount))")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(mode == .incomes ? Color(hex: "#34D399") : Color(hex: "#FB7185"))
                            .contrastTextOutline()
                    }
                    Spacer()
                }
                .padding(14)
                .background(ThemedCardBackgroundView(theme: theme, cornerRadius: 14))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 2)
                
                // Gráfico de Categorías (Solo en modo Gastos o Ingresos)
                if !summaries.isEmpty && totalAmount > 0 {
                    if chartType == .pie {
                        Chart(summaries) { cat in
                            SectorMark(
                                angle: .value("Monto", cat.totalAmount),
                                innerRadius: .ratio(0.55),
                                angularInset: 1.5
                            )
                            .cornerRadius(4)
                            .foregroundStyle(Color(hex: CategoryHelper.getCategoryColorHex(name: cat.categoryName, type: cat.type)))
                        }
                        .frame(height: 190)
                        .chartLegend(.hidden)
                    } else {
                        Chart(summaries.prefix(6)) { cat in
                            BarMark(
                                x: .value("Categoría", cat.categoryName),
                                y: .value("Monto", cat.totalAmount)
                            )
                            .cornerRadius(6)
                            .foregroundStyle(Color(hex: CategoryHelper.getCategoryColorHex(name: cat.categoryName, type: cat.type)))
                        }
                        .frame(height: 190)
                        .chartXAxis {
                            AxisMarks(values: .automatic) { value in
                                AxisValueLabel {
                                    if let str = value.as(String.self) {
                                        let displayedCount = max(1, summaries.prefix(6).count)
                                        let charCapacity = max(5, Int(280.0 / CGFloat(displayedCount) / 6.6))
                                        let labelText = str.count <= charCapacity ? str : "\(str.prefix(max(3, charCapacity - 1)))..."
                                        Text(labelText)
                                            .font(.system(size: 9.5, weight: .bold))
                                            .foregroundStyle(Color.white.opacity(0.95))
                                            .contrastTextOutline()
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Leyenda Completa de Categorías (Solo en modo Gastos o Ingresos)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Leyenda y Categorías")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white)
                        .contrastTextOutline()
                    
                    ForEach(summaries.prefix(6)) { cat in
                        let color = Color(hex: CategoryHelper.getCategoryColorHex(name: cat.categoryName, type: cat.type))
                        let icon = CategoryHelper.getCategoryIcon(name: cat.categoryName, type: cat.type)
                        
                        HStack(spacing: 10) {
                            Circle()
                                .fill(color)
                                .frame(width: 10, height: 10)
                            
                            Image(systemName: icon)
                                .font(.system(size: 11))
                                .foregroundStyle(color)
                                .frame(width: 16)
                            
                            Text(cat.categoryName)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .contrastTextOutline()
                            
                            Spacer()
                            
                            Text("\(currencySymbol) \(FormatHelper.formatCurrency(cat.totalAmount))")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#F8FAFC"))
                                .contrastTextOutline()
                            
                            Text(String(format: "(%.1f%%)", cat.percentage * 100))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(color)
                                .contrastTextOutline()
                                .frame(width: 52, alignment: .trailing)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(theme == .electricBlack ? Color.white.opacity(0.06) : Color.black.opacity(0.35))
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1)
                    }
                }
            }
            
            // Footer
            HStack {
                Text("📊 Generado con MoneyDev")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(hex: "#94A3B8"))
                    .contrastTextOutline()
                Spacer()
                Text(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none))
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: "#94A3B8"))
                    .contrastTextOutline()
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(width: 390)
        .background(
            ZStack {
                Color.black
                LinearGradient(
                    colors: theme == .electricBlack ?
                        [Color(hex: "#09090C"), Color(hex: "#020204"), Color.black] :
                        [
                            theme.primary.opacity(0.18),
                            theme.secondary.opacity(0.08),
                            Color(hex: "#060913"),
                            Color.black
                        ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.35),
                            (theme == .electricBlack ? Color.white : theme.primary).opacity(0.35),
                            Color.white.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        )
    }
    
    // MARK: - Generación de Imagen de la Tarjeta en Calidad Nativa
    @MainActor
    public static func renderImage(from cardView: StatsCaptureCardView) -> UIImage? {
        let exportView = cardView
            .environment(\.colorScheme, .dark)
        
        let renderer = ImageRenderer(content: exportView)
        renderer.scale = UIScreen.main.scale
        renderer.proposedSize = ProposedViewSize(width: 390, height: nil)
        renderer.isOpaque = false
        
        if let uiImg = renderer.uiImage {
            return uiImg
        }
        
        // Fallback dinámico midiendo el tamaño real intrínseco
        let controller = UIHostingController(rootView: exportView.ignoresSafeArea())
        controller.overrideUserInterfaceStyle = .dark
        let view = controller.view!
        view.backgroundColor = .clear
        
        let targetWidth: CGFloat = 390
        let fittingSize = controller.sizeThatFits(in: CGSize(width: targetWidth, height: .greatestFiniteMagnitude))
        let targetHeight = max(fittingSize.height, 450)
        let targetSize = CGSize(width: targetWidth, height: targetHeight)
        view.bounds = CGRect(origin: .zero, size: targetSize)
        
        let uiRenderer = UIGraphicsImageRenderer(size: targetSize)
        return uiRenderer.image { ctx in
            view.layer.render(in: ctx.cgContext)
        }
    }
}

// MARK: - Diálogo Modal de Vista Previa de la Captura
public struct StatsCapturePreviewDialog: View {
    let cardView: StatsCaptureCardView
    public var theme: AppColorTheme = .electricBlue
    let onSave: (UIImage) -> Void
    let onShare: (UIImage) -> Void
    let onDismiss: () -> Void
    
    @State private var renderedImage: UIImage? = nil
    @State private var isRendering: Bool = true
    
    public init(
        cardView: StatsCaptureCardView,
        theme: AppColorTheme = .electricBlue,
        onSave: @escaping (UIImage) -> Void,
        onShare: @escaping (UIImage) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.cardView = cardView
        self.theme = theme
        self.onSave = onSave
        self.onShare = onShare
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                ThemedModalBackground(theme: theme)
                
                VStack(spacing: 16) {
                    ScrollView {
                        VStack(spacing: 16) {
                            Text("Vista Previa de la Captura")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.white)
                                .contrastTextOutline()
                                .padding(.top, 8)
                            
                            // Visualización 1:1 exacta de la imagen renderizada final
                            if let img = renderedImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                    .shadow(color: Color.black.opacity(0.60), radius: 14, x: 0, y: 6)
                                    .shadow(color: (theme == .electricBlack ? Color.white.opacity(0.08) : theme.primary.opacity(0.25)), radius: 8, x: 0, y: 2)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 8)
                            } else {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity, minHeight: 380)
                            }
                        }
                    }
                    
                    // Barra de Acciones: Descargar y Compartir
                    HStack(spacing: 12) {
                        Button {
                            let img = renderedImage ?? StatsCaptureCardView.renderImage(from: cardView)
                            if let img {
                                onSave(img)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.to.line.circle.fill")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Guardar en Fotos")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .contrastTextOutline()
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "#10B981"), Color(hex: "#059669")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .shadow(color: Color(hex: "#10B981").opacity(0.4), radius: 6, x: 0, y: 3)
                        }
                        
                        Button {
                            let img = renderedImage ?? StatsCaptureCardView.renderImage(from: cardView)
                            if let img {
                                onShare(img)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up.fill")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Compartir")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundStyle(theme == .electricBlack ? Color.black : theme.onPrimaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: theme == .electricBlack ? [Color.white, Color(hex: "#E2E8F0")] : theme.gradient,
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .shadow(color: theme.primary.opacity(0.4), radius: 6, x: 0, y: 3)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            .navigationTitle("Captura de Estadísticas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") {
                        onDismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.white)
                    .contrastTextOutline()
                }
            }
            .task {
                if renderedImage == nil {
                    renderedImage = StatsCaptureCardView.renderImage(from: cardView)
                    isRendering = false
                }
            }
        }
        .themedSheetContainer(theme: theme)
    }
}

// MARK: - Helper de Guardado de Imagen en Fotos
public final class PhotoLibrarySaver: NSObject {
    public static let shared = PhotoLibrarySaver()
    
    private var completion: ((Bool, String?) -> Void)?
    
    public func save(image: UIImage, completion: @escaping (Bool, String?) -> Void) {
        self.completion = completion
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error {
            completion?(false, error.localizedDescription)
        } else {
            completion?(true, nil)
        }
    }
}
