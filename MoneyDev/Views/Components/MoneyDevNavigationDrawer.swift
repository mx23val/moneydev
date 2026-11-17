import SwiftUI

public struct MoneyDevNavigationDrawer: View {
    @Bindable var viewModel: ExpenseViewModel
    @Binding var isDrawerOpen: Bool
    
    @State private var isCreatingWallet: Bool = false
    @State private var newWalletName: String = ""
    @State private var newWalletInitialBalance: String = ""
    @State private var newWalletColorHex: String = "#00D2FF"
    
    private let availableColors = ["#00D2FF", "#00FF87", "#FF7A00", "#A855F7", "#FF3B30", "#CBD5E1"]
    
    public init(viewModel: ExpenseViewModel, isDrawerOpen: Binding<Bool>) {
        self.viewModel = viewModel
        self._isDrawerOpen = isDrawerOpen
    }
    
    public var body: some View {
        ZStack(alignment: .leading) {
            // Fondo semitransparente con tap para cerrar
            if isDrawerOpen {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut) {
                            isDrawerOpen = false
                        }
                    }
                
                // Panel deslizante lateral
                VStack(alignment: .leading, spacing: 0) {
                    // Header con Marca
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.system(size: 28, weight: .black))
                                .foregroundStyle(Color(hex: "#38BDF8"))
                            
                            VStack(alignment: .leading, spacing: 0) {
                                Text("MoneyDev")
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                    .foregroundStyle(AppColors.textPrimary)
                                
                                Text("Finanzas Personales")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            
                            Spacer()
                            
                            if viewModel.isProUser {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(Color(hex: "#F59E0B"))
                            }
                        }
                    }
                    .padding(20)
                    .background(AppColors.darkNavySurface)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // SECCIÓN BILLETERAS
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("MIS BILLETERAS (\(viewModel.wallets.count))")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(AppColors.textMuted)
                                    
                                    Spacer()
                                    
                                    Button {
                                        isCreatingWallet.toggle()
                                    } label: {
                                        Image(systemName: isCreatingWallet ? "minus" : "plus")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Color(hex: "#38BDF8"))
                                    }
                                }
                                
                                if isCreatingWallet {
                                    VStack(spacing: 8) {
                                        TextField("Nombre (ej: BCP, Efectivo)", text: $newWalletName)
                                            .font(.system(size: 13))
                                            .foregroundStyle(AppColors.textPrimary)
                                            .padding(10)
                                            .background(AppColors.darkNavySurface)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        
                                        TextField("Saldo inicial (0.00)", text: $newWalletInitialBalance)
                                            .font(.system(size: 13))
                                            .keyboardType(.decimalPad)
                                            .foregroundStyle(AppColors.textPrimary)
                                            .padding(10)
                                            .background(AppColors.darkNavySurface)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        
                                        HStack {
                                            ForEach(availableColors, id: \.self) { c in
                                                Circle()
                                                    .fill(Color(hex: c))
                                                    .frame(width: 22, height: 22)
                                                    .overlay(
                                                        Circle().stroke(Color.white, lineWidth: newWalletColorHex == c ? 2 : 0)
                                                    )
                                                    .onTapGesture { newWalletColorHex = c }
                                            }
                                        }
                                        
                                        Button {
                                            createWallet()
                                        } label: {
                                            Text("Guardar Billetera")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(.white)
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 36)
                                                .background(Color(hex: "#38BDF8"))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                    }
                                    .padding(10)
                                    .background(AppColors.navySurfaceVariant.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                
                                ForEach(viewModel.wallets) { w in
                                    let isActive = (viewModel.activeWallet?.id ?? 1) == w.id
                                    let bal = viewModel.walletBalances[w.id] ?? 0.0
                                    
                                    Button {
                                        viewModel.selectWallet(w.id)
                                        withAnimation { isDrawerOpen = false }
                                    } label: {
                                        HStack(spacing: 10) {
                                            Circle()
                                                .fill(Color(hex: w.colorHex))
                                                .frame(width: 10, height: 10)
                                            
                                            Text(w.name)
                                                .font(.system(size: 14, weight: isActive ? .bold : .medium))
                                                .foregroundStyle(isActive ? .white : AppColors.textPrimary)
                                            
                                            Spacer()
                                            
                                            Text("\(w.currencySymbol) \(FormatHelper.formatCurrency(bal))")
                                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                .foregroundStyle(isActive ? Color(hex: "#38BDF8") : AppColors.textSecondary)
                                            
                                            if isActive {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(Color(hex: "#38BDF8"))
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(isActive ? AppColors.darkNavySurface : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            Divider().background(AppColors.cardBorderNavy)
                            
                            // SECCIÓN ACCIONES PRINCIPALES
                            VStack(alignment: .leading, spacing: 6) {
                                Text("NAVEGACIÓN")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(AppColors.textMuted)
                                
                                drawerItem(title: "Movimientos", icon: "list.bullet.rectangle.fill", isSelected: viewModel.activeTab == 0) {
                                    viewModel.setActiveTab(0)
                                    withAnimation { isDrawerOpen = false }
                                }
                                
                                drawerItem(title: "Estadísticas y Reportes", icon: "chart.pie.fill", isSelected: viewModel.activeTab == 2) {
                                    viewModel.setActiveTab(2)
                                    withAnimation { isDrawerOpen = false }
                                }
                                
                                drawerItem(title: "Transferir entre Cuentas", icon: "arrow.left.arrow.right", isSelected: false) {
                                    withAnimation { isDrawerOpen = false }
                                    viewModel.openTransferDialog()
                                }
                                
                                drawerItem(title: "Gastos Fijos", icon: "calendar.badge.clock", isSelected: false) {
                                    withAnimation { isDrawerOpen = false }
                                    viewModel.openFixedExpensesDialog()
                                }
                                
                                drawerItem(title: "Modo PRO", icon: "crown.fill", isSelected: viewModel.activeTab == 1, accentColor: Color(hex: "#F59E0B")) {
                                    viewModel.setActiveTab(1)
                                    withAnimation { isDrawerOpen = false }
                                }
                                
                                drawerItem(title: "Configuración", icon: "gearshape.fill", isSelected: false) {
                                    withAnimation { isDrawerOpen = false }
                                    viewModel.openSettingsDialog()
                                }
                            }
                        }
                        .padding(16)
                    }
                    
                    // Footer con versión
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MoneyDev v1.1.3 (iOS)")
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.textMuted)
                        Text("Privacidad total • 100% Offline")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.textMuted.opacity(0.7))
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.darkNavySurface.opacity(0.5))
                }
                .frame(width: 300)
                .frame(maxHeight: .infinity)
                .background(AppColors.midnightBlack)
                .transition(.move(edge: .leading))
            }
        }
    }
    
    private func drawerItem(title: String, icon: String, isSelected: Bool, accentColor: Color = Color(hex: "#38BDF8"), action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isSelected ? accentColor : AppColors.textSecondary)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? .white : AppColors.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? AppColors.darkNavySurface : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    
    private func createWallet() {
        let name = newWalletName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let initBal = Double(newWalletInitialBalance.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        
        viewModel.createWallet(name: name, initialBalance: initBal, colorHex: newWalletColorHex)
        newWalletName = ""
        newWalletInitialBalance = ""
        isCreatingWallet = false
    }
}
