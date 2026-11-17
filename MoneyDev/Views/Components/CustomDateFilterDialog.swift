import SwiftUI

public struct CustomDateFilterDialog: View {
    @Bindable var viewModel: ExpenseViewModel
    var isForStats: Bool
    @Environment(\.dismiss) private var dismiss
    
    @State private var startDate: Date
    @State private var endDate: Date
    
    private var activeTheme: AppColorTheme {
        viewModel.activeTheme
    }
    
    public init(viewModel: ExpenseViewModel, isForStats: Bool = false) {
        self.viewModel = viewModel
        self.isForStats = isForStats
        
        let today = Date()
        if isForStats, let range = viewModel.statsCustomRange {
            let s = Date(timeIntervalSince1970: Double(range.startMillis) / 1000.0)
            let e = Date(timeIntervalSince1970: Double(range.endMillis) / 1000.0)
            _startDate = State(initialValue: min(s, today))
            _endDate = State(initialValue: min(e, today))
        } else if !isForStats, let range = viewModel.customDateRange {
            let s = Date(timeIntervalSince1970: Double(range.startMillis) / 1000.0)
            let e = Date(timeIntervalSince1970: Double(range.endMillis) / 1000.0)
            _startDate = State(initialValue: min(s, today))
            _endDate = State(initialValue: min(e, today))
        } else {
            _startDate = State(initialValue: today)
            _endDate = State(initialValue: today)
        }
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                ThemedModalBackground(theme: activeTheme)
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Selecciona el Rango de Fechas")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.white)
                            .contrastTextOutline()
                        
                        VStack(spacing: 12) {
                            HStack {
                                DatePicker(
                                    "Desde",
                                    selection: $startDate,
                                    in: ...Date(),
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.compact)
                                .tint(activeTheme == .electricBlack ? Color.white : activeTheme.primary)
                                .foregroundStyle(Color.white)
                                .contrastTextOutline()
                            }
                            .padding(14)
                            .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 14))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        activeTheme == .electricBlack ? Color.white.opacity(0.14) : Color.white.opacity(0.08),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(
                                color: activeTheme == .electricBlack ? Color.white.opacity(0.10) : activeTheme.primary.opacity(0.20),
                                radius: 6, x: 0, y: 2
                            )
                            .onChange(of: startDate) { _, newStart in
                                if newStart > endDate {
                                    endDate = newStart
                                }
                            }
                            
                            HStack {
                                DatePicker(
                                    "Hasta",
                                    selection: $endDate,
                                    in: startDate...Date(),
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.compact)
                                .tint(activeTheme == .electricBlack ? Color.white : activeTheme.primary)
                                .foregroundStyle(Color.white)
                                .contrastTextOutline()
                            }
                            .padding(14)
                            .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 14))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        activeTheme == .electricBlack ? Color.white.opacity(0.14) : Color.white.opacity(0.08),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(
                                color: activeTheme == .electricBlack ? Color.white.opacity(0.10) : activeTheme.primary.opacity(0.20),
                                radius: 6, x: 0, y: 2
                            )
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        applyFilter()
                    } label: {
                        Text("Aplicar Filtro")
                            .font(.system(size: 16, weight: .black))
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
                            .shadow(color: activeTheme.primary.opacity(0.35), radius: 8, x: 0, y: 3)
                    }
                }
                .padding(20)
            }
            .navigationTitle(isForStats ? "Personalizar Estadísticas" : "Filtrar por Fecha")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)
                        .contrastTextOutline()
                }
            }
        }
        .presentationDetents([.fraction(0.48), .medium])
        .themedSheetContainer(theme: activeTheme)
    }
    
    private func applyFilter() {
        let today = Date()
        var validStart = min(startDate, today)
        var validEnd = min(endDate, today)
        
        if validStart > validEnd {
            validStart = validEnd
        }
        
        let cal = Calendar(identifier: .gregorian)
        let startOfDay = cal.startOfDay(for: validStart)
        let endOfDay = cal.date(bySettingHour: 23, minute: 59, second: 59, of: validEnd) ?? validEnd
        
        let startMillis = Int64(startOfDay.timeIntervalSince1970 * 1000)
        let endMillis = Int64(endOfDay.timeIntervalSince1970 * 1000)
        
        let df = DateFormatter()
        df.dateFormat = "dd/MM"
        let label = "\(df.string(from: validStart)) - \(df.string(from: validEnd))"
        
        if isForStats {
            viewModel.setStatsCustomPeriod(startMillis: startMillis, endMillis: endMillis, label: label)
        } else {
            viewModel.setCustomDateFilter(startMillis: startMillis, endMillis: endMillis, label: label)
        }
        dismiss()
    }
}
