import SwiftUI

public struct MoneyDevNavigationDrawer: View {
    @Bindable var viewModel: ExpenseViewModel
    @Binding var isDrawerOpen: Bool
    var onAddWallet: (() -> Void)? = nil
    var onOpenContact: (() -> Void)? = nil
    
    @State private var isWalletsExpanded: Bool = true
    @State private var isNavExpanded: Bool = true
    @State private var isQuickActionsExpanded: Bool = true
    
    public init(
        viewModel: ExpenseViewModel,
        isDrawerOpen: Binding<Bool>,
        onAddWallet: (() -> Void)? = nil,
        onOpenContact: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self._isDrawerOpen = isDrawerOpen
        self.onAddWallet = onAddWallet
        self.onOpenContact = onOpenContact
    }
    
    // Estado de arrastre interactivo continuo 1:1 con el dedo
    @State private var dragOffset: CGFloat = 0
    private let drawerWidth: CGFloat = 300
    
    private var currentOffset: CGFloat {
        if isDrawerOpen {
            return min(15, dragOffset)
        } else {
            return -drawerWidth + max(0, dragOffset)
        }
    }
    
    private var progressFraction: CGFloat {
        let raw = (currentOffset + drawerWidth) / drawerWidth
        return max(0.0, min(1.0, raw))
    }
    
    public var body: some View {
        ZStack(alignment: .leading) {
            // 1. Fondo y Panel: SOLO existen en la jerarquía si el menú está abierto o siendo arrastrado
            if isDrawerOpen || dragOffset > 0 {
                // Fondo atenuado semitransparente con tap para cerrar y arrastre para cerrar
                Color.black.opacity(isDrawerOpen ? 0.65 : 0.65 * Double(max(0, dragOffset) / drawerWidth))
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            isDrawerOpen = false
                            dragOffset = 0
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                if isDrawerOpen && value.translation.width < 0 {
                                    dragOffset = max(-drawerWidth, value.translation.width)
                                }
                            }
                            .onEnded { value in
                                handleClosingDragEnded(value: value)
                            }
                    )
                    .transition(.opacity)
                
                // Panel deslizante lateral (sigue el dedo en continuidad 1:1 de izquierda a derecha y viceversa)
                drawerPanelContent
                    .frame(width: drawerWidth)
                    .frame(maxHeight: .infinity)
                    .offset(x: isDrawerOpen ? min(15, dragOffset) : -drawerWidth + max(0, dragOffset))
                    .shadow(
                        color: Color.black.opacity(0.65),
                        radius: 20,
                        x: 5,
                        y: 0
                    )
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                if isDrawerOpen {
                                    if value.translation.width < 0 {
                                        dragOffset = max(-drawerWidth, value.translation.width)
                                    } else {
                                        dragOffset = min(15, value.translation.width * 0.15)
                                    }
                                }
                            }
                            .onEnded { value in
                                handleClosingDragEnded(value: value)
                            }
                    )
                    .transition(.move(edge: .leading))
            }
            
            // 2. Detector de arrastre desde el borde izquierdo (Solo en pestaña Movimientos cuando está cerrado)
            if viewModel.activeTab == 0 && !isDrawerOpen {
                HStack {
                    Color.clear
                        .frame(width: 38)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 8)
                                .onChanged { value in
                                    // Solo responder si el arrastre es predominantemente horizontal de izquierda a derecha
                                    if value.translation.width > 0 && abs(value.translation.width) > abs(value.translation.height) {
                                        if value.translation.width > drawerWidth {
                                            dragOffset = drawerWidth + (value.translation.width - drawerWidth) * 0.15
                                        } else {
                                            dragOffset = value.translation.width
                                        }
                                    }
                                }
                                .onEnded { value in
                                    handleOpeningDragEnded(value: value)
                                }
                        )
                    Spacer()
                }
                .padding(.top, 90)
                .padding(.bottom, 80)
                .ignoresSafeArea()
            }
        }
        .onChange(of: isDrawerOpen) { _, newValue in
            if !newValue {
                dragOffset = 0
            }
        }
    }
    
    private func handleOpeningDragEnded(value: DragGesture.Value) {
        let velocity = value.predictedEndTranslation.width
        if value.translation.width > 75 || velocity > 140 {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isDrawerOpen = true
                dragOffset = 0
            }
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isDrawerOpen = false
                dragOffset = 0
            }
        }
    }
    
    private func handleClosingDragEnded(value: DragGesture.Value) {
        let velocity = value.predictedEndTranslation.width
        if value.translation.width < -75 || velocity < -120 {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isDrawerOpen = false
                dragOffset = 0
            }
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isDrawerOpen = true
                dragOffset = 0
            }
        }
    }
    
    private var drawerPanelContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header con Marca e Ícono Activo de la Aplicación
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    appIconThumbnail
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MoneyDev")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(Color.white)
                            .contrastTextOutline()
                        
                        Text("Finanzas Personales")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    if viewModel.isProUser {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(hex: "#F59E0B"))
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 16)
            .background(Color.clear)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // 1. SECCIÓN: MIS BILLETERAS (Desplegable y retraíble con botón)
                    sectionCard {
                        sectionHeader(
                            title: "MIS BILLETERAS (\(viewModel.wallets.count))",
                            isExpanded: $isWalletsExpanded,
                            trailingButton: AnyView(
                                Button {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                        isDrawerOpen = false
                                    }
                                    onAddWallet?()
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 11, weight: .black))
                                        .foregroundStyle(Color.white)
                                        .frame(width: 24, height: 24)
                                        .background(viewModel.activeTheme.primary.opacity(0.24))
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.7))
                                        .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
                                }
                                .buttonStyle(.plain)
                            )
                        )
                        
                        if isWalletsExpanded {
                            VStack(spacing: 5) {
                                ForEach(viewModel.wallets) { w in
                                    let isActive = (viewModel.activeWallet?.id ?? 1) == w.id
                                    let bal = viewModel.walletBalances[w.id] ?? 0.0
                                    
                                    Button {
                                        viewModel.selectWallet(w.id)
                                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { isDrawerOpen = false }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(Color(hex: w.colorHex))
                                                .frame(width: 8, height: 8)
                                            
                                            Text(w.name)
                                                .font(.system(size: 13, weight: isActive ? .bold : .medium))
                                                .foregroundStyle(isActive ? Color.white : AppColors.textPrimary)
                                                .lineLimit(1)
                                            
                                            Spacer()
                                            
                                            Text("\(w.currencySymbol) \(FormatHelper.formatCurrency(bal))")
                                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                .foregroundStyle(isActive ? viewModel.activeTheme.accentTextColor : AppColors.textSecondary)
                                            
                                            if isActive {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundStyle(viewModel.activeTheme.accentIconColor)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(isActive ? viewModel.activeTheme.primary.opacity(0.28) : Color.white.opacity(0.04))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    
                    // 2. SECCIÓN: NAVEGACIÓN (Desplegable y retraíble)
                    sectionCard {
                        sectionHeader(
                            title: "NAVEGACIÓN",
                            isExpanded: $isNavExpanded
                        )
                        
                        if isNavExpanded {
                            VStack(spacing: 4) {
                                drawerItem(title: "Movimientos", icon: "list.bullet.rectangle.fill", isSelected: viewModel.activeTab == 0) {
                                    viewModel.setActiveTab(0)
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { isDrawerOpen = false }
                                }
                                
                                drawerItem(title: "Estadísticas", icon: "chart.pie.fill", isSelected: viewModel.activeTab == 1) {
                                    viewModel.setActiveTab(1)
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { isDrawerOpen = false }
                                }
                                
                                drawerItem(title: "Modo PRO", icon: "crown.fill", isSelected: viewModel.activeTab == 2, accentColor: Color(hex: "#F59E0B")) {
                                    viewModel.setActiveTab(2)
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { isDrawerOpen = false }
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    
                    // 3. SECCIÓN: ACCIONES RÁPIDAS (Desplegable y retraíble)
                    sectionCard {
                        sectionHeader(
                            title: "ACCIONES RÁPIDAS",
                            isExpanded: $isQuickActionsExpanded
                        )
                        
                        if isQuickActionsExpanded {
                            VStack(spacing: 4) {
                                drawerItem(title: "Ver guía y tutorial de uso", icon: "book.fill", isSelected: false, isAction: true) {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { isDrawerOpen = false }
                                    viewModel.openTutorial()
                                }
                                
                                drawerItem(title: "Transferir entre cuentas", icon: "arrow.left.arrow.right", isSelected: false, isAction: true) {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { isDrawerOpen = false }
                                    viewModel.openTransferDialog()
                                }
                                
                                drawerItem(title: "Registrar gastos fijos", icon: "calendar.badge.clock", isSelected: false, isAction: true) {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { isDrawerOpen = false }
                                    // Esperar el cierre del drawer evita competir por el mismo frame
                                    // con la presentación del sheet, que era la causa perceptible de lentitud.
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                                        viewModel.openFixedExpensesDialog()
                                    }
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    
                    // 4. SECCIÓN: MÁS (Fija y siempre visible, sin opción de retraer)
                    sectionCard {
                        HStack {
                            Text("MÁS")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(viewModel.activeTheme.accentIconColor)
                                .contrastTextOutline()
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        
                        VStack(spacing: 4) {
                            drawerItem(title: "Contacto", icon: "envelope.fill", isSelected: false) {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { isDrawerOpen = false }
                                onOpenContact?()
                            }
                            
                            drawerItem(title: "Ajustes", icon: "gearshape.fill", isSelected: viewModel.activeTab == 3) {
                                viewModel.setActiveTab(3)
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { isDrawerOpen = false }
                            }
                        }
                    }
                }
                .padding(14)
            }
            
            // Footer con versión y privacidad
            VStack(alignment: .leading, spacing: 4) {
                Text("MoneyDev v1.1.3 (iOS)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.textMuted)
                Text("Privacidad total • 100% Offline")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.textMuted.opacity(0.7))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.clear)
        }
        .padding(.top, 50) // Desplazado hacia abajo para despejar la barra de estado y no tapar la hora
        .frame(width: drawerWidth)
        .frame(maxHeight: .infinity)
        .background(ThemedModalBackground(theme: viewModel.activeTheme))
    }
    
    // Agrupación espacial sin tarjetas, bordes ni tonos independientes.
    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            content()
        }
        .padding(11)
    }
    
    // Encabezado de sección con botón de retraer/expandir con flecha al lado derecho
    private func sectionHeader(
        title: String,
        isExpanded: Binding<Bool>,
        trailingButton: AnyView? = nil
    ) -> some View {
        HStack(spacing: 8) {
            // Título de la sección (tappable para desplegar/contraer)
            Button {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.84)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack {
                    Text(title)
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(viewModel.activeTheme.accentIconColor)
                        .contrastTextOutline()
                    
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Botón extra a la derecha si existe (ej. botón '+' de billeteras)
            if let trailingButton {
                trailingButton
            }
            
            // Flecha a la derecha: apunta hacia abajo comprimida, hacia arriba desplegada
            Button {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.84)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(viewModel.activeTheme.accentIconColor)
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
    
    @ViewBuilder
    private var appIconThumbnail: some View {
        let iconName = AppIconManager.currentIcon
        if let uiImg = UIImage(named: iconName) {
            Image(uiImage: uiImg)
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: Color.black.opacity(0.4), radius: 3)
        } else {
            Image(systemName: AppIconManager.isProIconActive() ? "crown.fill" : "dollarsign.circle.fill")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(Color(hex: AppIconManager.isProIconActive() ? "#F59E0B" : "#38BDF8"))
        }
    }
    
    private func drawerItem(
        title: String,
        icon: String,
        isSelected: Bool,
        accentColor: Color? = nil,
        isAction: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let effectiveAccent = accentColor ?? viewModel.activeTheme.accentIconColor
        return Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isAction ? Color.white : (isSelected ? effectiveAccent : AppColors.textSecondary))
                    .frame(width: 22)
                
                Text(title)
                    .font(.system(size: 13, weight: isSelected || isAction ? .bold : .medium))
                    .foregroundStyle(isAction || isSelected ? Color.white : AppColors.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                isSelected ?
                    viewModel.activeTheme.primary.opacity(0.12) : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke((isSelected || isAction) ? Color.white.opacity(0.18) : Color.clear, lineWidth: 0.7)
            )
        }
        .buttonStyle(.plain)
    }
}
