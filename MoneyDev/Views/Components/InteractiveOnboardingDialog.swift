import SwiftUI

public struct InteractiveOnboardingDialog: View {
    @Bindable var viewModel: ExpenseViewModel
    
    @State private var currentPage: Int = 0
    @State private var initialBalanceString: String = ""
    
    private var activeTheme: AppColorTheme {
        viewModel.activeTheme
    }
    
    private var isFirstLaunch: Bool {
        !viewModel.isOnboardingCompleted
    }
    
    private var totalPages: Int {
        isFirstLaunch ? 5 : 4
    }
    
    public init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ZStack {
            ThemedModalBackground(theme: activeTheme)
            
            VStack(spacing: 24) {
                // Barra superior con botón opcional de cerrar si ya se configuró previamente
                HStack {
                    Spacer()
                    if !isFirstLaunch {
                        Button {
                            viewModel.closeTutorial()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(Color.white.opacity(0.85))
                                .contrastTextOutline()
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 16)
                    }
                }
                .frame(height: isFirstLaunch ? 8 : 32)
                
                // Indicador de Progreso / Páginas
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Capsule()
                            .fill(currentPage == index ? (activeTheme == .electricBlack ? Color.white : activeTheme.primary) : Color.white.opacity(0.25))
                            .frame(width: currentPage == index ? 24 : 8, height: 8)
                            .animation(.spring, value: currentPage)
                    }
                }
                .padding(.top, isFirstLaunch ? 16 : 0)
                
                TabView(selection: $currentPage) {
                    // Slide 1: Bienvenida & 100% Privado
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Circle()
                            .fill(activeTheme == .electricBlack ? Color.white.opacity(0.18) : activeTheme.primary.opacity(0.18))
                            .frame(width: 96, height: 96)
                            .overlay {
                                Image(systemName: "shield.checkerboard")
                                    .font(.system(size: 46, weight: .bold))
                                    .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.primary)
                            }
                        
                        VStack(spacing: 8) {
                            Text("Bienvenido a MoneyDev")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundStyle(Color.white)
                                .contrastTextOutline()
                            
                            Text("Tu control de finanzas personales 100% privado, sin registros obligatorios ni servidores externos. Todos tus datos viven seguros en tu dispositivo.")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.white.opacity(0.85))
                                .contrastTextOutline()
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        
                        Spacer()
                    }
                    .tag(0)
                    
                    // Slide 2: Registro por Voz & Asistente IA (Condicional Pro vs Básico)
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: activeTheme == .electricBlack ? [Color(hex: "#334155"), Color(hex: "#0F172A")] : activeTheme.gradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 96, height: 96)
                            .overlay {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 44, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        
                        VStack(spacing: 8) {
                            if viewModel.isProUser {
                                Text("Registro por Voz & MoneyBot")
                                    .font(.system(size: 22, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.white)
                                    .contrastTextOutline()
                                
                                Text("Dicta tus movimientos con total naturalidad: 'Gasté 35 soles en almuerzo'. MoneyBot interpretará el monto, tipo y categoría al instante con IA.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.white.opacity(0.85))
                                    .contrastTextOutline()
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            } else {
                                Text("Registro por Voz")
                                    .font(.system(size: 22, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.white)
                                    .contrastTextOutline()
                                
                                Text("Dicta tus movimientos con total naturalidad: 'Gasté 35 soles en almuerzo'. La aplicación interpretará el monto, tipo y categoría al instante.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.white.opacity(0.85))
                                    .contrastTextOutline()
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                        }
                        
                        Spacer()
                    }
                    .tag(1)
                    
                    // Slide 3: Estadísticas, Comparativas y Salud Financiera
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Circle()
                            .fill(AppColors.incomeEmerald.opacity(0.18))
                            .frame(width: 96, height: 96)
                            .overlay {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 42, weight: .bold))
                                    .foregroundStyle(AppColors.incomeEmeraldLight)
                            }
                        
                        VStack(spacing: 8) {
                            Text("Comparativo & Salud Financiera")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(Color.white)
                                .contrastTextOutline()
                            
                            Text("Analiza Ingresos vs Gastos con gráficos comparativos, tasa de ahorro, evaluación 50/30/20 y recomendaciones inteligentes personalizadas.")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.white.opacity(0.85))
                                .contrastTextOutline()
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        
                        Spacer()
                    }
                    .tag(2)
                    
                    // Slide Gastos Fijos (Penúltima pestaña en primera instalación, o última pestaña si ya está configurado)
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: activeTheme == .electricBlack ?
                                        [Color(hex: "#38BDF8").opacity(0.25), Color(hex: "#0F172A")] :
                                        [activeTheme.primary.opacity(0.25), activeTheme.secondary.opacity(0.12)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 96, height: 96)
                            .overlay {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 42, weight: .bold))
                                    .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.primary)
                            }
                        
                        VStack(spacing: 8) {
                            Text("Gastos Fijos Programados")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(Color.white)
                                .contrastTextOutline()
                            
                            Text("Configura y monitorea tus pagos recurrentes como alquiler, suscripciones, educación y servicios. Recibe recordatorios oportunos para tener tus obligaciones bajo control.")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.white.opacity(0.85))
                                .contrastTextOutline()
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        
                        Spacer()
                    }
                    .tag(3)
                    
                    // Slide Saldo Inicial (Únicamente en primera instalación como última pestaña, tag 4)
                    if isFirstLaunch {
                        VStack(spacing: 20) {
                            Spacer()
                            
                            Circle()
                                .fill(activeTheme == .electricBlack ? Color.white.opacity(0.18) : activeTheme.primary.opacity(0.18))
                                .frame(width: 96, height: 96)
                                .overlay {
                                    Image(systemName: "banknote.fill")
                                        .font(.system(size: 42, weight: .bold))
                                        .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.primary)
                                }
                            
                            VStack(spacing: 8) {
                                Text("Comencemos con tu Saldo")
                                    .font(.system(size: 22, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.white)
                                    .contrastTextOutline()
                                
                                Text("¿Con cuánto dinero comienzas en tu billetera principal?")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.white.opacity(0.85))
                                    .contrastTextOutline()
                                    .multilineTextAlignment(.center)
                            }
                            
                            HStack(spacing: 6) {
                                Text(viewModel.financialSummary.currencySymbol)
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.primary)
                                    .contrastTextOutline()
                                
                                TextField("0.00", text: $initialBalanceString)
                                    .font(.system(size: 32, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.white)
                                    .keyboardType(.decimalPad)
                            }
                            .padding(14)
                            .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 14))
                            .shadow(color: activeTheme == .electricBlack ? Color.white.opacity(0.10) : activeTheme.primary.opacity(0.30), radius: 6, x: 0, y: 2)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal, 32)
                            
                            Spacer()
                        }
                        .tag(4)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Barra Inferior de Navegación
                HStack(spacing: 12) {
                    if currentPage > 0 {
                        Button {
                            withAnimation { currentPage -= 1 }
                        } label: {
                            Text("Atrás")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .contrastTextOutline()
                                .frame(width: 90, height: 48)
                                .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 12))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: Color.black.opacity(0.35), radius: 4, x: 0, y: 2)
                        }
                    }
                    
                    Button {
                        if currentPage < totalPages - 1 {
                            withAnimation { currentPage += 1 }
                        } else {
                            if isFirstLaunch {
                                finishOnboarding()
                            } else {
                                viewModel.closeTutorial()
                            }
                        }
                    } label: {
                        Text(currentPage == totalPages - 1 ? (isFirstLaunch ? "¡Empezar a Usar!" : "¡Entendido!") : "Siguiente")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(activeTheme == .electricBlack ? Color.black : Color.white)
                            .contrastTextOutline(color: activeTheme == .electricBlack ? Color.clear : Color.black.opacity(0.65), radius: 0.8)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                LinearGradient(
                                    colors: activeTheme == .electricBlack ?
                                        [Color.white, Color(hex: "#CBD5E1")] :
                                        activeTheme.gradient,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: activeTheme == .electricBlack ? Color.white.opacity(0.25) : activeTheme.primary.opacity(0.35), radius: 6, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .numpadDismissDoneButton()
        }
    }
    
    private func finishOnboarding() {
        let clean = initialBalanceString.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        let amount = Double(clean) ?? 0.0
        viewModel.completeOnboarding(initialBalance: amount)
    }
}
