import SwiftUI

public struct InitialBalanceDialog: View {
    @Bindable var viewModel: ExpenseViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var balanceInput: String = ""
    @State private var selectedCurrency: String = "S/"
    
    private let currencies = ["S/", "$", "€", "MXN", "COP", "CLP", "ARS"]
    
    public init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AppColors.midnightBlack.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: "#38BDF8").opacity(0.2))
                            .frame(width: 60, height: 60)
                            .overlay {
                                Image(systemName: "banknote.fill")
                                    .font(.system(size: 26))
                                    .foregroundStyle(Color(hex: "#38BDF8"))
                            }
                        
                        Text("Configura tu Saldo Inicial")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                        
                        Text("Ingresa el dinero actual con el que comienzas en tu billetera.")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 10)
                    
                    // Currency selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Símbolo de Moneda")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(currencies, id: \.self) { curr in
                                    Button {
                                        selectedCurrency = curr
                                    } label: {
                                        Text(curr)
                                            .font(.system(size: 14, weight: selectedCurrency == curr ? .bold : .medium))
                                            .foregroundStyle(selectedCurrency == curr ? .white : AppColors.textPrimary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(selectedCurrency == curr ? Color(hex: "#38BDF8") : AppColors.darkNavySurface)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                    
                    // Balance input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Monto Inicial")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                        
                        HStack(spacing: 6) {
                            Text(selectedCurrency)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#38BDF8"))
                            
                            TextField("0.00", text: $balanceInput)
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundStyle(AppColors.textPrimary)
                                .keyboardType(.decimalPad)
                        }
                        .padding(14)
                        .background(AppColors.darkNavySurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppColors.cardBorderNavy, lineWidth: 1)
                        )
                    }
                    
                    Spacer()
                    
                    Button {
                        save()
                    } label: {
                        Text("Guardar Saldo")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(hex: "#38BDF8"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(20)
            }
            .navigationTitle("Saldo Inicial")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") {
                        viewModel.closeSetBalanceDialog()
                        dismiss()
                    }
                    .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func save() {
        let clean = balanceInput.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        let amount = Double(clean) ?? 0.0
        viewModel.saveInitialBalance(amount: amount, currency: selectedCurrency)
        dismiss()
    }
}
