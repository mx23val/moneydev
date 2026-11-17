import SwiftUI

public struct InteractiveOnboardingDialog: View {
    @Bindable var viewModel: ExpenseViewModel
    
    @State private var currentPage: Int = 0
    @State private var initialBalanceString: String = ""
    
    public init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ZStack {
            AppColors.slateBlack.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Page Indicator
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Capsule()
                            .fill(currentPage == index ? Color(hex: "#38BDF8") : AppColors.cardBorderNavy)
                            .frame(width: currentPage == index ? 24 : 8, height: 8)
                            .animation(.spring, value: currentPage)
                    }
                }
                .padding(.top, 20)
                
                TabView(selection: $currentPage) {
                    // Slide 1: Welcome & Offline-first
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Circle()
                            .fill(Color(hex: "#38BDF8").opacity(0.2))
                            .frame(width: 90, height: 90)
                            .overlay {
                                Image(systemName: "shield.checkerboard")
                                    .font(.system(size: 44, weight: .bold))
                                    .foregroundStyle(Color(hex: "#38BDF8"))
                            }
                        
                        VStack(spacing: 8) {
                            Text("Bienvenido a MoneyDev")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundStyle(AppColors.textPrimary)
                            
                            Text("Tus finanzas personales 100% privadas, seguras y almacenadas localmente en tu dispositivo.")
                                .font(.system(size: 14))
                                .foregroundStyle(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        
                        Spacer()
                    }
                    .tag(0)
                    
                    // Slide 2: IA & Voice Dictation
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#00D2FF"), Color(hex: "#1D4ED8")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 90, height: 90)
                            .overlay {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        
                        VStack(spacing: 8) {
                            Text("Registro por Voz & MoneyBot")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(AppColors.textPrimary)
                            
                            Text("Simplemente dile a MoneyDev lo que gastaste: 'Gasté 25 soles en taxi' y se registrará automáticamente.")
                                .font(.system(size: 14))
                                .foregroundStyle(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        
                        Spacer()
                    }
                    .tag(1)
                    
                    // Slide 3: Initial Balance Setup
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Circle()
                            .fill(AppColors.incomeEmerald.opacity(0.2))
                            .frame(width: 90, height: 90)
                            .overlay {
                                Image(systemName: "banknote.fill")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundStyle(AppColors.incomeEmeraldLight)
                            }
                        
                        VStack(spacing: 8) {
                            Text("Comencemos con tu Saldo")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(AppColors.textPrimary)
                            
                            Text("¿Con cuánto dinero comienzas en tu billetera principal?")
                                .font(.system(size: 14))
                                .foregroundStyle(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        HStack(spacing: 6) {
                            Text("S/")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#38BDF8"))
                            
                            TextField("0.00", text: $initialBalanceString)
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
                        .padding(.horizontal, 32)
                        
                        Spacer()
                    }
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Bottom Button Row
                HStack {
                    if currentPage > 0 {
                        Button {
                            withAnimation { currentPage -= 1 }
                        } label: {
                            Text("Atrás")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppColors.textSecondary)
                                .frame(width: 90, height: 48)
                                .background(AppColors.darkNavySurface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    
                    Button {
                        if currentPage < 2 {
                            withAnimation { currentPage += 1 }
                        } else {
                            finishOnboarding()
                        }
                    } label: {
                        Text(currentPage == 2 ? "¡Empezar a Usar!" : "Siguiente")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "#00D2FF"), Color(hex: "#1D4ED8")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }
    
    private func finishOnboarding() {
        let clean = initialBalanceString.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        let amount = Double(clean) ?? 0.0
        viewModel.completeOnboarding(initialBalance: amount)
    }
}
