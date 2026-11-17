import SwiftUI

public struct ProModeScreen: View {
    @Bindable var viewModel: ExpenseViewModel
    
    @State private var codeInput: String = ""
    @State private var alertMessage: String? = nil
    @State private var showAlert: Bool = false
    @State private var isSuccess: Bool = false
    
    public init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Banner
                VStack(spacing: 12) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#F59E0B"), Color(hex: "#D97706")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .overlay {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.white)
                        }
                    
                    Text("MoneyDev PRO")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                    
                    if viewModel.isProUser {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Color(hex: "#F59E0B"))
                            Text("Modo PRO Activado de por vida")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color(hex: "#F59E0B"))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color(hex: "#F59E0B").opacity(0.15))
                        .clipShape(Capsule())
                    } else {
                        Text("Desbloquea todo el potencial de tu gestión financiera")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 10)
                
                // Code input box (if not PRO yet)
                if !viewModel.isProUser {
                    VStack(spacing: 14) {
                        Text("Ingresa tu Código de Activación")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                        
                        TextField("XXX-XXX-XXX", text: $codeInput)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled(true)
                            .padding(14)
                            .background(AppColors.midnightBlack)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppColors.cardBorderNavy, lineWidth: 1)
                            )
                            .onChange(of: codeInput) { _, newValue in
                                formatProCode(newValue)
                            }
                        
                        Button {
                            activateCode()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "key.fill")
                                Text("Verificar y Activar")
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "#F59E0B"), Color(hex: "#EA580C")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(18)
                    .background(AppColors.darkNavySurface)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color(hex: "#F59E0B").opacity(0.4), lineWidth: 1)
                    )
                }
                
                // PRO Features Section
                VStack(alignment: .leading, spacing: 14) {
                    Text("Beneficios Exclusivos PRO")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                    
                    // Feature 1: Gastos Fijos
                    Button {
                        viewModel.openFixedExpensesDialog()
                    } label: {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(Color(hex: "#38BDF8").opacity(0.2))
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(Color(hex: "#38BDF8"))
                                }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text("Gastos Fijos y Recordatorios")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(AppColors.textPrimary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(AppColors.textMuted)
                                }
                                
                                Text("Registra pagos recurrentes con avisos de vencimiento")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppColors.textSecondary)
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
                    .buttonStyle(.plain)
                    
                    // Feature 2: Billeteras Ilimitadas
                    HStack(spacing: 14) {
                        Circle()
                            .fill(Color(hex: "#34D399").opacity(0.2))
                            .frame(width: 44, height: 44)
                            .overlay {
                                Image(systemName: "wallet.pass.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Color(hex: "#34D399"))
                            }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cuentas y Billeteras Ilimitadas")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(AppColors.textPrimary)
                            
                            Text("Crea más de 3 billeteras independientes con saldos propios")
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .padding(14)
                    .background(AppColors.darkNavySurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    
                    // Feature 3: Temas Exclusivos
                    HStack(spacing: 14) {
                        Circle()
                            .fill(Color(hex: "#A855F7").opacity(0.2))
                            .frame(width: 44, height: 44)
                            .overlay {
                                Image(systemName: "paintpalette.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Color(hex: "#A855F7"))
                            }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Temas de Color Neón Exclusivos")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(AppColors.textPrimary)
                            
                            Text("Desbloquea Verde, Gris, Rojo y Morado Eléctrico")
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .padding(14)
                    .background(AppColors.darkNavySurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(20)
        }
        .alert(isSuccess ? "¡Felicidades!" : "Código de Activación", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage ?? "")
        }
    }
    
    private func formatProCode(_ text: String) {
        let clean = text.uppercased().filter { $0 >= "A" && $0 <= "Z" }
        if clean.count <= 3 {
            codeInput = clean
        } else if clean.count <= 6 {
            let p1 = clean.prefix(3)
            let p2 = clean.dropFirst(3)
            codeInput = "\(p1)-\(p2)"
        } else {
            let p1 = clean.prefix(3)
            let p2 = clean.dropFirst(3).prefix(3)
            let p3 = clean.dropFirst(6).prefix(3)
            codeInput = "\(p1)-\(p2)-\(p3)"
        }
    }
    
    private func activateCode() {
        let (success, message) = viewModel.activateProWithCode(codeInput)
        isSuccess = success
        alertMessage = message
        showAlert = true
        if success {
            codeInput = ""
        }
    }
}
