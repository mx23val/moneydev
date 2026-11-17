import SwiftUI

public struct CustomDateFilterDialog: View {
    @Bindable var viewModel: ExpenseViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    
    public init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AppColors.midnightBlack.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Selecciona el Rango de Fechas")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                        
                        DatePicker("Desde", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .padding(10)
                            .background(AppColors.darkNavySurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        DatePicker("Hasta", selection: $endDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .padding(10)
                            .background(AppColors.darkNavySurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Spacer()
                    
                    Button {
                        applyFilter()
                    } label: {
                        Text("Aplicar Filtro")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color(hex: "#38BDF8"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(20)
            }
            .navigationTitle("Filtrar por Fecha")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .presentationDetents([.fraction(0.5)])
    }
    
    private func applyFilter() {
        let cal = Calendar(identifier: .gregorian)
        let startOfDay = cal.startOfDay(for: startDate)
        let endOfDay = cal.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        
        let startMillis = Int64(startOfDay.timeIntervalSince1970 * 1000)
        let endMillis = Int64(endOfDay.timeIntervalSince1970 * 1000)
        
        let df = DateFormatter()
        df.dateFormat = "dd/MM"
        let label = "\(df.string(from: startDate)) - \(df.string(from: endDate))"
        
        viewModel.setCustomDateFilter(startMillis: startMillis, endMillis: endMillis, label: label)
        dismiss()
    }
}
