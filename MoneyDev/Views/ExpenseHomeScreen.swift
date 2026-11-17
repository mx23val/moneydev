import SwiftUI

public struct ExpenseHomeScreen: View {
    @Bindable var viewModel: ExpenseViewModel
    
    @State private var isDrawerOpen: Bool = false
    @State private var isDirectVoiceOpen: Bool = false
    @State private var directVoiceDetent: PresentationDetent = .fraction(0.58)
    @State private var isCustomDateFilterOpen: Bool = false
    @State private var isSearchActive: Bool = false
    @State private var isWalletSwitchSheetOpen: Bool = false
    @State private var isStatsWalletSelectorOpen: Bool = false
    @State private var isAddWalletDialogOpen: Bool = false
    @State private var walletToEdit: Wallet? = nil
    @State private var isPeriodSelectorOpen: Bool = false
    @State private var isContactDialogOpen: Bool = false
    @State private var showNotificationRationale: Bool = false
    @State private var isFabExpanded: Bool = false
    @State private var transactionToDelete: Transaction? = nil
    @State private var isDirectMoneyBotVoiceOpen: Bool = false
    @FocusState private var isSearchFocused: Bool
    private var securityManager = AppSecurityManager.shared
    
    private var activeTheme: AppColorTheme {
        AppColorTheme.fromId(viewModel.financialSummary.themeColorId)
    }
    
    public init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        rootContent
            .ignoresSafeArea(.keyboard)
            .animation(.easeInOut(duration: 0.45), value: activeTheme)
            .sheet(isPresented: $isContactDialogOpen) {
                ContactDialog(theme: activeTheme) {
                    isContactDialogOpen = false
                }
                .themedSheetContainer(theme: activeTheme)
            }
            .fullScreenCover(isPresented: $isDirectMoneyBotVoiceOpen) {
                MoneyBotLiveVoiceOverlay(
                    viewModel: viewModel,
                    selectedWalletScopeId: viewModel.activeWallet?.id ?? viewModel.financialSummary.activeWalletId,
                    selectedWalletScopeName: viewModel.activeWallet?.name ?? "Billetera Principal",
                    onClose: {
                        isDirectMoneyBotVoiceOpen = false
                    },
                    onOpenChat: {
                        isDirectMoneyBotVoiceOpen = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            viewModel.openVoiceAssistant()
                        }
                    }
                )
            }
            .onChange(of: viewModel.shouldOpenLiveVoice) { _, shouldOpen in
                if shouldOpen {
                    isDirectMoneyBotVoiceOpen = true
                    viewModel.shouldOpenLiveVoice = false
                }
            }
            .onAppear {
                // Sesión de voz se activa manualmente desde el FAB
            }
            .onDisappear {
            }
            .onChange(of: isDirectMoneyBotVoiceOpen) { _, _ in
            }
            .onChange(of: viewModel.activeTab) { _, _ in
            }
            .onChange(of: isDirectVoiceOpen) { _, _ in
            }
            .onChange(of: securityManager.isAppLocked) { _, isLocked in
                if isLocked {
                    // Si el usuario bloquea el móvil durante el modo voz, NO destruimos la sesión en vivo
                    if !MoneyBotLiveVoiceSessionManager.shared.isLiveSessionActive {
                        isDirectMoneyBotVoiceOpen = false
                    }
                    isStatsWalletSelectorOpen = false
                }
            }
            .modifier(ExpenseHomePrimarySheetsModifier(
                viewModel: viewModel,
                isDirectVoiceOpen: $isDirectVoiceOpen,
                directVoiceDetent: $directVoiceDetent,
                isCustomDateFilterOpen: $isCustomDateFilterOpen,
                isWalletSwitchSheetOpen: $isWalletSwitchSheetOpen,
                isAddWalletDialogOpen: $isAddWalletDialogOpen,
                walletToEdit: $walletToEdit,
                isPeriodSelectorOpen: $isPeriodSelectorOpen,
                showNotificationRationale: $showNotificationRationale,
                isDrawerOpen: $isDrawerOpen,
                isSearchActive: $isSearchActive,
                isFabExpanded: $isFabExpanded,
                transactionToDelete: $transactionToDelete,
                activeTheme: activeTheme
            ))
            .keyboardDismissArrow()
    }
    

    
    @ViewBuilder
    private var rootContent: some View {
        ZStack(alignment: .bottom) {
            ThemedModalBackground(theme: activeTheme)
            
            VStack(spacing: 0) {
                topAppBar
                mainTabContent
            }
            .brightness(isFabExpanded ? -0.15 : 0)
            .animation(.easeInOut(duration: 0.25), value: isFabExpanded)
            .allowsHitTesting(!isFabExpanded)
            
            moneyBotFloatingVoiceShortcut
                .opacity(isFabExpanded ? 0.30 : 1.0)
                .allowsHitTesting(!isFabExpanded)
                .animation(.easeInOut(duration: 0.25), value: isFabExpanded)
            
            if isFabExpanded {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            isFabExpanded = false
                        }
                    }
                    .transition(.opacity)
            }
            
            bottomDockBar
            navigationDrawer
            transferSuccessOverlay
            searchOverlay
            floatingToastOverlay
        }
    }
    
    @ViewBuilder
    private var bottomDockBar: some View {
        BottomNavigationBarWithFab(
            viewModel: viewModel,
            isFabExpanded: $isFabExpanded,
            onAddExpenseClick: {
                viewModel.openAddTransaction(defaultType: .expense)
            },
            onAddIncomeClick: {
                viewModel.openAddTransaction(defaultType: .income)
            },
            onVoiceClick: {
                isDirectVoiceOpen = true
            },
            onSettingsClick: {
                viewModel.openSettingsDialog()
            }
        )
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    @ViewBuilder
    private var navigationDrawer: some View {
        MoneyDevNavigationDrawer(
            viewModel: viewModel,
            isDrawerOpen: $isDrawerOpen,
            onAddWallet: {
                isAddWalletDialogOpen = true
            },
            onOpenContact: {
                isContactDialogOpen = true
            }
        )
        .ignoresSafeArea()
    }
    


    private var transferSuccessOverlay: some View {
        Group {
            if let transferResult = viewModel.transferSuccessResult {
                ZStack {
                    Color.black.opacity(0.80)
                        .background(.ultraThinMaterial.opacity(0.6))
                        .ignoresSafeArea()
                        .onTapGesture {
                            viewModel.dismissTransferSuccessDialog()
                        }
                    TransferSuccessDialog(result: transferResult, theme: activeTheme) {
                        viewModel.dismissTransferSuccessDialog()
                    }
                    .padding(20)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
                .transition(.opacity)
                .zIndex(140)
            }
        }
    }

    private var searchOverlay: some View {
        Group {
            if isSearchActive {
                ZStack(alignment: .top) {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            isSearchFocused = false
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isSearchActive = false
                            }
                        }
                    
                    VStack(spacing: 16) {
                        // Campo de búsqueda principal ampliado
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(activeTheme.accentIconColor)
                            
                            TextField("Buscar concepto, nota...", text: Binding(
                                get: { viewModel.searchQuery },
                                set: { viewModel.setSearchQuery($0) }
                            ), prompt: Text("Buscar concepto, nota...").foregroundStyle(AppColors.textMuted))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppColors.textPrimary)
                            .focused($isSearchFocused)
                            .submitLabel(.search)
                            .onSubmit {
                                isSearchFocused = false
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isSearchActive = false
                                }
                            }
                            
                            // Botón único X: si hay texto borra lo escrito; si está vacío cierra la búsqueda
                            Button {
                                if !viewModel.searchQuery.isEmpty {
                                    viewModel.setSearchQuery("")
                                } else {
                                    isSearchFocused = false
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isSearchActive = false
                                    }
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(AppColors.textSecondary)
                                    .frame(width: 32, height: 32)
                                    .background(AppColors.navySurfaceVariant)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .themedInputField(theme: activeTheme, cornerRadius: 14)
                        
                        // Selector de Ámbito: [Todos | Gastos | Ingresos]
                        HStack(spacing: 10) {
                            ForEach([FilterType.all, FilterType.expense, FilterType.income], id: \.self) { filterType in
                                let isSelected = viewModel.selectedFilter == filterType
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        viewModel.setFilter(filterType)
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        if filterType == .expense {
                                            Image(systemName: "arrow.down.right")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(
                                                    isSelected ?
                                                        (activeTheme == .electricBlack ? Color(hex: "#FB7185") : activeTheme.onPrimaryText) :
                                                        AppColors.expenseRoseLight
                                                )
                                        } else if filterType == .income {
                                            Image(systemName: "arrow.up.right")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(
                                                    isSelected ?
                                                        (activeTheme == .electricBlack ? Color(hex: "#34D399") : activeTheme.onPrimaryText) :
                                                        AppColors.incomeEmeraldLight
                                                )
                                        }
                                        
                                        Text(filterType.rawValue)
                                            .font(.system(size: 14, weight: isSelected ? .bold : .semibold))
                                            .foregroundStyle(isSelected ? activeTheme.onPrimaryText : AppColors.textPrimary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 9)
                                    .background(isSelected ? (activeTheme == .electricBlack ? Color.white.opacity(0.25) : activeTheme.primary.opacity(0.35)) : AppColors.darkNavySurface)
                                    .clipShape(Capsule())
                                    .shadow(color: Color.black.opacity(0.25), radius: 3)
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }
                        
                        if !viewModel.searchQuery.isEmpty {
                            HStack {
                                Text("\(viewModel.isMovementsHidden ? "***" : "\(viewModel.filteredTransactions.count)") movimiento(s) en \(viewModel.selectedFilter.rawValue.lowercased())")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(activeTheme.accentTextColor)
                                    .contrastTextOutline()
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 18)
                    .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 20))
                    .shadow(color: Color.black.opacity(0.75), radius: 24, x: 0, y: 10)
                    .padding(.horizontal, 16)
                    .padding(.top, 56)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        )
                    )
                }
                .transition(.opacity)
                .zIndex(180)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        isSearchFocused = true
                    }
                }
            }
        }
    }

    private var floatingToastOverlay: some View {
        Group {
            if let toast = viewModel.floatingToast, !viewModel.isTransferDialogOpen && !viewModel.isAddEditSheetOpen && !viewModel.isFixedExpensesDialogOpen {
                VStack {
                    FloatingToastView(toast: toast, theme: activeTheme) {
                        viewModel.dismissFloatingToast()
                    }
                    .padding(.top, 4)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(200)
            }
        }
    }
    
    // MARK: - Top App Bar
    @ViewBuilder
    private var topAppBar: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    isDrawerOpen = true
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(activeTheme.accentIconColor)
                    .frame(width: 38, height: 38)
                    .background(themedTopControlBackground(cornerRadius: 19))
            }
            .buttonStyle(.plain)
            
            // 1. En pestaña Movimientos (tab 0): SIN título de movimientos
            if viewModel.activeTab == 0 {
                walletQuickSelectorButton
                editWalletButton
                
                Spacer()
                
                // Botón de búsqueda (Lupa temático con sombreado)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSearchActive.toggle()
                    }
                } label: {
                    Image(systemName: isSearchActive ? "xmark" : "magnifyingglass")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(activeTheme.accentIconColor)
                        .frame(width: 38, height: 38)
                        .background(themedTopControlBackground(cornerRadius: 19))
                }
                .buttonStyle(.plain)
            } else if viewModel.activeTab == 1 {
                // 2. En pestaña Estadísticas (tab 1): Título y selector de billetera flotante justo a su lado
                Text("Estadísticas")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                
                statsWalletSelectorButton
                
                Spacer()
            } else if viewModel.activeTab == 2 {
                // 3. En pestaña Modo PRO (tab 2): Título SIN selector de billeteras
                Text("Modo PRO")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                
                Spacer()
            } else if viewModel.activeTab == 3 {
                // 4. En pestaña Ajustes (tab 3): Título SIN selector de billeteras
                Text("Ajustes")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: viewModel.activeTab)
    }
    
    private var editWalletButton: some View {
        Button {
            if let active = viewModel.activeWallet {
                walletToEdit = active
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "pencil")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(activeTheme.accentIconColor)
                
                Text("Editar")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white)
                    .contrastTextOutline()
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(themedTopControlBackground(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Main Tab Content (Preservación de Vistas y Alto Rendimiento 120 FPS)
    @ViewBuilder
    private var mainTabContent: some View {
        ZStack {
            // Pestaña 0: Movimientos SIEMPRE en jerarquía para preservar la posición exacta del scroll
            movementsTabContent
                .opacity(viewModel.activeTab == 0 ? 1.0 : 0.0)
                .allowsHitTesting(viewModel.activeTab == 0)
                .zIndex(viewModel.activeTab == 0 ? 1 : 0)
            
            // Pestañas 1, 2, 3: Se renderizan instantáneamente a 120 FPS sin sobrecargar la GPU ni competir en paralelo
            Group {
                switch viewModel.activeTab {
                case 1:
                    CategoryStatsView(viewModel: viewModel)
                case 2:
                    ProModeScreen(viewModel: viewModel)
                case 3:
                    SettingsDialog(viewModel: viewModel)
                default:
                    EmptyView()
                }
            }
            .zIndex(viewModel.activeTab != 0 ? 2 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Movements Tab Content (Tarjeta y Períodos Fijos, Solo Movimientos Desplazables)
    private var movementsTabContent: some View {
        VStack(spacing: 12) {
            // SECCIÓN FIJA SUPERIOR (Inmóvil, no se desplaza con el scroll)
            VStack(spacing: 12) {
                // Guía Visual de Búsqueda Activa (Encima del Saldo Principal)
                if !viewModel.searchQuery.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(activeTheme.accentIconColor)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text("Búsqueda:")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppColors.textMuted)
                                
                                Text("\"\(viewModel.searchQuery)\"")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(activeTheme.accentTextColor)
                                    .lineLimit(1)
                            }
                            
                            Text("en \(viewModel.selectedFilter.rawValue) • \(viewModel.isMovementsHidden ? "***" : "\(viewModel.filteredTransactions.count)") movimiento\(viewModel.filteredTransactions.count == 1 ? "" : "s")")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        // Botón X para cerrar búsqueda y restaurar todos los movimientos por defecto
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.setSearchQuery("")
                                viewModel.setFilter(.all)
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppColors.textSecondary)
                                .frame(width: 30, height: 30)
                                .background(AppColors.navySurfaceVariant)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 16))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(
                        color: activeTheme == .electricBlack ?
                            Color.white.opacity(0.12) :
                            activeTheme.primary.opacity(0.25),
                        radius: 6, x: 0, y: 2
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
                
                // Tarjeta de Balance Principal
                BalanceHeaderCard(
                    viewModel: viewModel,
                    onTransferClick: { viewModel.openTransferDialog() },
                    onAddExpenseClick: { viewModel.openAddTransaction(defaultType: .expense) },
                    onAddIncomeClick: { viewModel.openAddTransaction(defaultType: .income) }
                )
                
                // Dos Bloques Anchos que abarcan todo el ancho de la pantalla (Tipo y Período)
                HStack(spacing: 10) {
                    // 1. Bloque "Todos" (Filtro por Tipo: Todos, Ingresos, Gastos)
                    Menu {
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.setFilter(.all)
                            }
                        } label: {
                            Label("Todos", systemImage: viewModel.selectedFilter == .all ? "checkmark" : "")
                        }
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.setFilter(.income)
                            }
                        } label: {
                            Label("Ingresos", systemImage: viewModel.selectedFilter == .income ? "checkmark" : "")
                        }
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.setFilter(.expense)
                            }
                        } label: {
                            Label("Gastos", systemImage: viewModel.selectedFilter == .expense ? "checkmark" : "")
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.selectedFilter == .expense {
                                Image(systemName: "arrow.down.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentIconColor)
                            } else if viewModel.selectedFilter == .income {
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentIconColor)
                            } else {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color.white)
                            }
                            
                            Text(filterTypeLabel)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(viewModel.selectedFilter != .all ? (activeTheme == .electricBlack ? Color.white : activeTheme.accentTextColor) : AppColors.textPrimary)
                                .contrastTextOutline()
                                .lineLimit(1)
                            
                            Spacer(minLength: 4)
                            
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .frame(maxWidth: .infinity)
                        .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 12))
                        .shadow(
                            color: Color.black.opacity(0.3),
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                    }
                    
                    // 2. Bloque "Periodo" (Filtro por Período / Fecha)
                    Menu {
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.setDateFilter(.all)
                            }
                        } label: {
                            Label("Todos los períodos", systemImage: viewModel.selectedDateFilter == .all ? "checkmark" : "")
                        }
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.setDateFilter(.today)
                            }
                        } label: {
                            Label("Hoy", systemImage: viewModel.selectedDateFilter == .today ? "checkmark" : "")
                        }
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.setDateFilter(.yesterday)
                            }
                        } label: {
                            Label("Ayer", systemImage: viewModel.selectedDateFilter == .yesterday ? "checkmark" : "")
                        }
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.setDateFilter(.thisWeek)
                            }
                        } label: {
                            Label("Esta semana", systemImage: viewModel.selectedDateFilter == .thisWeek ? "checkmark" : "")
                        }
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.setDateFilter(.thisMonth)
                            }
                        } label: {
                            Label("Este mes", systemImage: viewModel.selectedDateFilter == .thisMonth ? "checkmark" : "")
                        }
                        
                        Divider()
                        
                        Button {
                            isCustomDateFilterOpen = true
                        } label: {
                            Label("Filtrar por fecha...", systemImage: viewModel.selectedDateFilter == .customRange ? "calendar.badge.clock" : "calendar")
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(viewModel.selectedDateFilter != .all ? activeTheme.accentIconColor : AppColors.textSecondary)
                            
                            Text(periodLabel)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(viewModel.selectedDateFilter != .all ? (activeTheme == .electricBlack ? Color.white : activeTheme.accentTextColor) : AppColors.textPrimary)
                                .contrastTextOutline()
                                .lineLimit(1)
                            
                            Spacer(minLength: 4)
                            
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .frame(maxWidth: .infinity)
                        .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 12))
                        .shadow(
                            color: Color.black.opacity(0.3),
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                    }
                }
                
                // Cabecera Fija de Movimientos con botón Ocultar/Mostrar
                HStack {
                    Text(viewModel.isMovementsHidden ? "Movimientos (***)" : "Movimientos (\(viewModel.filteredTransactions.count))")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .contrastTextOutline()
                    
                    Spacer()
                    
                    // Botón Independiente para Ocultar / Mostrar Movimientos
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            viewModel.toggleHideMovements()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: viewModel.isMovementsHidden ? "eye.fill" : "eye.slash.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text(viewModel.isMovementsHidden ? "Mostrar" : "Ocultar")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(viewModel.isMovementsHidden ? activeTheme.accentIconColor : AppColors.textSecondary)
                        .contrastTextOutline()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 16))
                        .clipShape(Capsule())
                        .shadow(
                            color: Color.black.opacity(0.3),
                            radius: 3
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // SECCIÓN DESPLAZABLE (Únicamente los movimientos se desplazan de arriba a abajo)
            ScrollViewReader { scrollProxy in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 10) {
                        // Ancla invisible superior para scroll automático
                        Color.clear
                            .frame(height: 0)
                            .id("movements_top_anchor")
                        
                        if viewModel.isMovementsHidden {
                            // Estado Oculto: Recuadro oscuro sofisticado con alto contraste y texto 100% nítido
                            VStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(activeTheme.primary.opacity(0.18))
                                        .frame(width: 68, height: 68)
                                    
                                    Image(systemName: "eye.slash.fill")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundStyle(activeTheme.accentIconColor)
                                        .contrastTextOutline()
                                }
                                
                                VStack(spacing: 5) {
                                    Text("Movimientos ocultos")
                                        .font(.system(size: 19, weight: .black, design: .rounded))
                                        .foregroundStyle(Color.white)
                                        .contrastTextOutline()
                                    
                                    Text("Tus movimientos y saldos están protegidos")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                                
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        viewModel.toggleHideMovements()
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "eye.fill")
                                            .font(.system(size: 14, weight: .bold))
                                        Text("Mostrar movimientos")
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                    .foregroundStyle(Color.white)
                                    .contrastTextOutline()
                                    .padding(.horizontal, 22)
                                    .padding(.vertical, 11)
                                    .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 20))
                                    .clipShape(Capsule())
                                    .shadow(color: activeTheme == .electricBlack ? Color.white.opacity(0.12) : activeTheme.primary.opacity(0.35), radius: 8)
                                }
                                .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 36)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        } else if viewModel.filteredTransactions.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "tray.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(AppColors.textMuted)
                                
                                Text("No se encontraron movimientos")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(AppColors.textPrimary)
                                
                                Text("Agrega tu primer gasto o ingreso usando los botones superiores o el menú inferior.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppColors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            ForEach(viewModel.filteredTransactions) { tx in
                                TransactionItemCard(
                                    transaction: tx,
                                    currencySymbol: viewModel.financialSummary.currencySymbol,
                                    isHidden: false,
                                    theme: activeTheme
                                ) {
                                    viewModel.openEditTransaction(tx)
                                } onDelete: {
                                    transactionToDelete = tx
                                }
                                .equatable()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 110)
                }
                .scrollIndicators(.visible)
                .scrollIndicatorsFlash(onAppear: true)
                .scrollIndicatorsFlash(trigger: viewModel.filteredTransactions.count)
                .onChange(of: viewModel.scrollToTopTrigger) { _, _ in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        scrollProxy.scrollTo("movements_top_anchor", anchor: .top)
                    }
                }
            }
        }
    }
    
    private var walletQuickSelectorButton: some View {
        Button {
            isWalletSwitchSheetOpen = true
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: viewModel.activeWallet?.colorHex ?? "#00D2FF"))
                    .frame(width: 8, height: 8)
                
                Text(viewModel.financialSummary.activeWalletName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white)
                    .contrastTextOutline()
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .contrastTextOutline()
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(themedTopControlBackground(cornerRadius: 18))
        }
    }
    
    private var statsWalletSelectorButton: some View {
        Button {
            isStatsWalletSelectorOpen = true
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: viewModel.activeWallet?.colorHex ?? "#00D2FF"))
                    .frame(width: 8, height: 8)
                
                Text(viewModel.financialSummary.activeWalletName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white)
                    .contrastTextOutline()
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .contrastTextOutline()
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(themedTopControlBackground(cornerRadius: 18))
        }
        .popover(isPresented: $isStatsWalletSelectorOpen, arrowEdge: .top) {
            StatsLiquidGlassWalletPicker(viewModel: viewModel) {
                isStatsWalletSelectorOpen = false
            }
            .presentationCompactAdaptation(.popover)
            .presentationBackground(.ultraThinMaterial)
        }
    }

    /// Controles superiores integrados al tema: profundidad por degradado y borde,
    /// no por sombras que se proyecten sobre el fondo.
    private func themedTopControlBackground(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return shape
            .fill(
                LinearGradient(
                    colors: [
                        activeTheme.primary.opacity(0.24),
                        activeTheme.appBackgroundGradient[1].opacity(0.84),
                        activeTheme.primary.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                shape.stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.23), activeTheme.primary.opacity(0.34), Color.white.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
            }
    }
    
    
    private var filterTypeLabel: String {
        switch viewModel.selectedFilter {
        case .all:
            return "Todos"
        case .income:
            return "Ingresos"
        case .expense:
            return "Gastos"
        }
    }
    
    private var periodLabel: String {
        switch viewModel.selectedDateFilter {
        case .all:
            return "Periodo"
        case .today:
            return "Hoy"
        case .yesterday:
            return "Ayer"
        case .thisWeek:
            return "Esta semana"
        case .thisMonth:
            return "Este mes"
        case .customRange:
            return viewModel.customDateRange?.label ?? "Fecha"
        }
    }
    
    // MARK: - Acceso Directo Flotante al Modo Voz de MoneyBot (Cristal Líquido Oscuro Estilo Meta AI)
    @ViewBuilder
    private var moneyBotFloatingVoiceShortcut: some View {
        if viewModel.activeTab == 0 && viewModel.isProUser && !isFabExpanded && !isSearchActive {
            HStack {
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        isDirectMoneyBotVoiceOpen = true
                    }
                } label: {
                    ZStack {
                        // 0. Base de cristal líquido con desenfoque de material nativo
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 48, height: 48)
                        
                        // 1. Tonalidad oscura profunda (botón más oscuro estilo grafito / obsidiana)
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#1E2638").opacity(0.85),
                                        Color(hex: "#111827").opacity(0.92),
                                        Color(hex: "#090D16").opacity(0.97)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                        
                        // 2. Tinte líquido translúcido sutil del color del tema activo
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        (activeTheme == .electricBlack ? Color.white : activeTheme.primary).opacity(0.24),
                                        Color.clear
                                    ]),
                                    center: .topLeading,
                                    startRadius: 2,
                                    endRadius: 36
                                )
                            )
                            .frame(width: 48, height: 48)
                        
                        // 3. Resplandor especular superior vítreo (Liquid Glass specular reflection)
                        VStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.50),
                                            Color.white.opacity(0.12),
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 42, height: 20)
                                .padding(.top, 2)
                            Spacer()
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                        
                        // 4. Borde fino biselado de cristal líquido con luminosidad
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.72),
                                        (activeTheme == .electricBlack ? Color.white : activeTheme.primary).opacity(0.42),
                                        Color.white.opacity(0.18),
                                        Color.white.opacity(0.06)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.1
                            )
                            .frame(width: 48, height: 48)
                        
                        // 5. Ícono de Inteligencia Artificial (sparkles nítido con halo luminoso)
                        Image(systemName: "sparkles")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(Color.white)
                            .shadow(color: (activeTheme == .electricBlack ? Color.white : activeTheme.primary).opacity(0.55), radius: 6, x: 0, y: 0)
                    }
                    .compositingGroup()
                    .shadow(color: Color.black.opacity(0.55), radius: 8, x: 0, y: 4)
                    .shadow(color: (activeTheme == .electricBlack ? Color.white.opacity(0.10) : activeTheme.primary).opacity(0.25), radius: 7, x: 0, y: 1)
                }
                .contentShape(Circle())
                .buttonStyle(MetaAiFloatingShortcutButtonStyle())
                .accessibilityLabel("Abrir Modo Voz de MoneyBot")
                .padding(.trailing, 20)
                .padding(.bottom, 78) // Flotante en la parte superior de la navbar al lado derecho
            }
            .transition(.asymmetric(
                insertion: .scale(scale: 0.7, anchor: .bottomTrailing).combined(with: .opacity),
                removal: .scale(scale: 0.7, anchor: .bottomTrailing).combined(with: .opacity)
            ))
            .zIndex(15)
        }
    }
}

// MARK: - Botón Flotante Estilo Meta AI con Microinteracción
private struct MetaAiFloatingShortcutButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

// MARK: - Dedicated View Modifiers to Keep Type Checking Instantaneous

private struct ExpenseHomePrimarySheetsModifier: ViewModifier {
    @Bindable var viewModel: ExpenseViewModel
    @Binding var isDirectVoiceOpen: Bool
    @Binding var directVoiceDetent: PresentationDetent
    @Binding var isCustomDateFilterOpen: Bool
    @Binding var isWalletSwitchSheetOpen: Bool
    @Binding var isAddWalletDialogOpen: Bool
    @Binding var walletToEdit: Wallet?
    @Binding var isPeriodSelectorOpen: Bool
    @Binding var showNotificationRationale: Bool
    @Binding var isDrawerOpen: Bool
    @Binding var isSearchActive: Bool
    @Binding var isFabExpanded: Bool
    @Binding var transactionToDelete: Transaction?
    let activeTheme: AppColorTheme
    private var securityManager = AppSecurityManager.shared
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: Binding(
                get: { viewModel.isAddEditSheetOpen },
                set: { _ in viewModel.closeAddEditSheet() }
            )) {
                AddEditTransactionSheet(viewModel: viewModel)
                    .themedSheetContainer(theme: activeTheme)
            }
            .sheet(isPresented: Binding(
                get: { viewModel.isVoiceAssistantOpen },
                set: { _ in viewModel.closeVoiceAssistant() }
            )) {
                VoiceAssistantDialog(viewModel: viewModel)
                    .themedSheetContainer(theme: activeTheme)
            }
            .sheet(isPresented: $isDirectVoiceOpen) {
                DirectVoiceDictationDialog(viewModel: viewModel, currentDetent: $directVoiceDetent)
                    .presentationDetents([.fraction(0.58)], selection: $directVoiceDetent)
                    .presentationDragIndicator(.hidden)
                    .themedSheetContainer(theme: activeTheme)
            }
            .onChange(of: isDirectVoiceOpen) { _, isOpen in
                if !isOpen {
                    directVoiceDetent = .fraction(0.58)
                }
            }
            .onChange(of: viewModel.shouldOpenVoiceDictation) { _, shouldOpen in
                if shouldOpen {
                    isDirectVoiceOpen = true
                    viewModel.shouldOpenVoiceDictation = false
                }
            }
            .onChange(of: viewModel.activeTab) { _, newTab in
                if newTab != 0 && isSearchActive {
                    isSearchActive = false
                }
            }
            .onChange(of: securityManager.isAppLocked) { _, isLocked in
                if isLocked {
                    isDrawerOpen = false
                    isDirectVoiceOpen = false
                    isCustomDateFilterOpen = false
                    isSearchActive = false
                    isWalletSwitchSheetOpen = false
                    isAddWalletDialogOpen = false
                    walletToEdit = nil
                    isPeriodSelectorOpen = false
                    showNotificationRationale = false
                    isFabExpanded = false
                    transactionToDelete = nil
                    viewModel.resetNavigationToHomeAndDismissAll()
                }
            }
            .modifier(ExpenseHomeWalletSheetsModifier(
                viewModel: viewModel,
                isTransferDialogOpen: Binding(get: { viewModel.isTransferDialogOpen }, set: { _ in viewModel.closeTransferDialog() }),
                isFixedExpensesDialogOpen: Binding(get: { viewModel.isFixedExpensesDialogOpen }, set: { _ in viewModel.closeFixedExpensesDialog() }),
                isSetBalanceDialogOpen: Binding(get: { viewModel.isSetBalanceDialogOpen }, set: { _ in viewModel.closeSetBalanceDialog() }),
                isCustomDateFilterOpen: $isCustomDateFilterOpen,
                isWalletSwitchSheetOpen: $isWalletSwitchSheetOpen,
                isAddWalletDialogOpen: $isAddWalletDialogOpen,
                walletToEdit: $walletToEdit,
                isPeriodSelectorOpen: $isPeriodSelectorOpen,
                showNotificationRationale: $showNotificationRationale,
                transactionToDelete: $transactionToDelete,
                activeTheme: activeTheme
            ))
    }
}

private struct ExpenseHomeWalletSheetsModifier: ViewModifier {
    @Bindable var viewModel: ExpenseViewModel
    @Binding var isTransferDialogOpen: Bool
    @Binding var isFixedExpensesDialogOpen: Bool
    @Binding var isSetBalanceDialogOpen: Bool
    @Binding var isCustomDateFilterOpen: Bool
    @Binding var isWalletSwitchSheetOpen: Bool
    @Binding var isAddWalletDialogOpen: Bool
    @Binding var walletToEdit: Wallet?
    @Binding var isPeriodSelectorOpen: Bool
    @Binding var showNotificationRationale: Bool
    @Binding var transactionToDelete: Transaction?
    let activeTheme: AppColorTheme
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isTransferDialogOpen) {
                TransferMoneyDialog(viewModel: viewModel)
                    .themedSheetContainer(theme: activeTheme)
            }
            .sheet(isPresented: $isFixedExpensesDialogOpen) {
                FixedExpensesDialog(viewModel: viewModel)
                    .themedSheetContainer(theme: activeTheme)
            }
            .sheet(isPresented: $isSetBalanceDialogOpen) {
                InitialBalanceDialog(viewModel: viewModel)
                    .themedSheetContainer(theme: activeTheme)
            }
            .sheet(isPresented: $isCustomDateFilterOpen) {
                CustomDateFilterDialog(viewModel: viewModel)
                    .themedSheetContainer(theme: activeTheme)
            }
            .sheet(isPresented: $isWalletSwitchSheetOpen) {
                WalletQuickSwitchSheet(
                    viewModel: viewModel,
                    onDismiss: { isWalletSwitchSheetOpen = false },
                    onAddNew: {
                        isWalletSwitchSheetOpen = false
                        isAddWalletDialogOpen = true
                    },
                    onEdit: { wallet in
                        isWalletSwitchSheetOpen = false
                        walletToEdit = wallet
                    }
                )
                .themedSheetContainer(theme: activeTheme)
            }
            .sheet(isPresented: $isAddWalletDialogOpen) {
                AddWalletDialog(
                    viewModel: viewModel,
                    onDismiss: { isAddWalletDialogOpen = false },
                    onConfirm: { name, initialBalance, currency, colorHex in
                        viewModel.createWallet(name: name, initialBalance: initialBalance, currency: currency, colorHex: colorHex)
                        isAddWalletDialogOpen = false
                    }
                )
                .themedSheetContainer(theme: activeTheme)
            }
            .sheet(item: $walletToEdit) { wallet in
                EditWalletDialog(
                    wallet: wallet,
                    theme: activeTheme,
                    canDelete: viewModel.wallets.count > 1 && !wallet.isDefault,
                    existingWallets: viewModel.wallets,
                    onDismiss: { walletToEdit = nil },
                    onSave: { name, initialBalance, currency, colorHex in
                        viewModel.updateWallet(walletId: wallet.id, name: name, initialBalance: initialBalance, currency: currency, colorHex: colorHex)
                        walletToEdit = nil
                    },
                    onDelete: {
                        viewModel.deleteWallet(walletId: wallet.id)
                        walletToEdit = nil
                    },
                    onClearTransactions: {
                        viewModel.clearWalletTransactionsOnly(walletId: wallet.id)
                        walletToEdit = nil
                    }
                )
                .themedSheetContainer(theme: activeTheme)
            }
            .sheet(isPresented: $isPeriodSelectorOpen) {
                PeriodSelectorDialog(
                    title: "Filtrar por Período",
                    options: [
                        PeriodOptionItem(value: .all, title: "Todos los períodos", subtitle: "Todos los registros históricos", iconSymbol: "calendar"),
                        PeriodOptionItem(value: .customRange, title: "Filtrar por fecha", subtitle: "Rango personalizado de fechas o meses", iconSymbol: "calendar.badge.clock", isCustomFilter: true),
                        PeriodOptionItem(value: .today, title: "Hoy", subtitle: "Movimientos registrados hoy", iconSymbol: "sun.max.fill"),
                        PeriodOptionItem(value: .yesterday, title: "Ayer", subtitle: "Movimientos registrados ayer", iconSymbol: "clock.arrow.circlepath"),
                        PeriodOptionItem(value: .thisWeek, title: "Esta semana", subtitle: "Movimientos de la semana en curso", iconSymbol: "calendar.badge.exclamationmark"),
                        PeriodOptionItem(value: .thisMonth, title: "Este mes", subtitle: "Movimientos del mes en curso", iconSymbol: "calendar")
                    ],
                    selectedOption: viewModel.selectedDateFilter,
                    onSelectOption: { chosen in
                        viewModel.setDateFilter(chosen)
                    },
                    onSelectCustomRange: {
                        isCustomDateFilterOpen = true
                    },
                    onDismiss: { isPeriodSelectorOpen = false }
                )
                .themedSheetContainer(theme: activeTheme)
            }
            .sheet(isPresented: $showNotificationRationale) {
                NotificationPermissionDialog(
                    onAccept: {
                        showNotificationRationale = false
                        Task {
                            let granted = await ReminderScheduler.requestNotificationPermission()
                            await MainActor.run {
                                viewModel.setNotificationsEnabled(granted)
                            }
                        }
                    },
                    onDismiss: {
                        showNotificationRationale = false
                    }
                )
                .presentationDetents([.fraction(0.48)])
                .themedSheetContainer(theme: activeTheme)
            }
            .sheet(isPresented: Binding(
                get: { viewModel.selectedTransferMovement != nil },
                set: { if !$0 { viewModel.closeTransferMovementDetails() } }
            )) {
                if let tx = viewModel.selectedTransferMovement {
                    TransferMovementDetailsDialog(
                        transaction: tx,
                        currencySymbol: viewModel.financialSummary.currencySymbol,
                        theme: viewModel.activeTheme,
                        onDismiss: { viewModel.closeTransferMovementDetails() }
                    )
                    .themedSheetContainer(theme: activeTheme)
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { viewModel.isTutorialOpen },
                set: { if !$0 { viewModel.closeTutorial() } }
            )) {
                InteractiveOnboardingDialog(viewModel: viewModel)
            }
            .alert("Billeteras Insuficientes", isPresented: Binding(
                get: { viewModel.needsMoreWalletsForTransfer },
                set: { _ in viewModel.closeNeedsMoreWalletsForTransfer() }
            )) {
                Button("Entendido", role: .cancel) { }
            } message: {
                Text("Para realizar una transferencia necesitas tener creadas al menos dos billeteras.")
            }
            .alert("¿Eliminar movimiento?", isPresented: Binding(
                get: { transactionToDelete != nil },
                set: { if !$0 { transactionToDelete = nil } }
            )) {
                Button("Eliminar", role: .destructive) {
                    if let tx = transactionToDelete {
                        viewModel.deleteTransaction(tx)
                        transactionToDelete = nil
                    }
                }
                Button("Cancelar", role: .cancel) {
                    transactionToDelete = nil
                }
            } message: {
                if let tx = transactionToDelete {
                    Text("¿Estás seguro de que deseas eliminar el movimiento \"\(tx.title)\"? Esta acción no se puede deshacer.")
                }
            }
    }
}
