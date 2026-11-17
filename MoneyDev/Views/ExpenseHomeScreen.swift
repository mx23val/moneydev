import SwiftUI

public struct ExpenseHomeScreen: View {
    @Bindable var viewModel: ExpenseViewModel
    
    @State private var isDrawerOpen: Bool = false
    @State private var isDirectVoiceOpen: Bool = false
    @State private var isCustomDateFilterOpen: Bool = false
    @State private var isSearchActive: Bool = false
    @State private var isWalletSwitchSheetOpen: Bool = false
    @State private var isAddWalletDialogOpen: Bool = false
    @State private var walletToEdit: Wallet? = nil
    @State private var isPeriodSelectorOpen: Bool = false
    @State private var showNotificationRationale: Bool = false
    
    private var activeTheme: AppColorTheme {
        AppColorTheme.fromId(viewModel.financialSummary.themeColorId)
    }
    
    public init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ZStack {
            AppColors.slateBlack.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top App Bar
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.spring) {
                            isDrawerOpen = true
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(width: 40, height: 40)
                            .background(AppColors.darkNavySurface)
                            .clipShape(Circle())
                    }
                    
                    // Brand or Active Wallet Badge (Clickable Quick Switch)
                    Button {
                        isWalletSwitchSheetOpen = true
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: viewModel.activeWallet?.colorHex ?? "#00D2FF"))
                                .frame(width: 10, height: 10)
                            
                            Text(viewModel.financialSummary.activeWalletName)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(AppColors.textPrimary)
                                .lineLimit(1)
                            
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppColors.darkNavySurface)
                        .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    // Search toggle button
                    Button {
                        withAnimation {
                            isSearchActive.toggle()
                        }
                    } label: {
                        Image(systemName: isSearchActive ? "xmark" : "magnifyingglass")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(width: 40, height: 40)
                            .background(AppColors.darkNavySurface)
                            .clipShape(Circle())
                    }
                    
                    // Settings button
                    Button {
                        viewModel.openSettingsDialog()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(width: 40, height: 40)
                            .background(AppColors.darkNavySurface)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
                
                // Search Input Field (when expanded)
                if isSearchActive {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(AppColors.textMuted)
                        
                        TextField("Buscar concepto, categoría, nota...", text: Binding(
                            get: { viewModel.searchQuery },
                            set: { viewModel.setSearchQuery($0) }
                        ))
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.textPrimary)
                        
                        if !viewModel.searchQuery.isEmpty {
                            Button {
                                viewModel.setSearchQuery("")
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(AppColors.textMuted)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppColors.darkNavySurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // Tab Selection Segmented Bar
                HStack(spacing: 8) {
                    tabButton(title: "Movimientos", icon: "list.bullet", tabIndex: 0)
                    tabButton(title: "Modo PRO", icon: "crown.fill", tabIndex: 1, accent: Color(hex: "#F59E0B"))
                    tabButton(title: "Estadísticas", icon: "chart.pie.fill", tabIndex: 2)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                
                // Tab Content
                TabView(selection: Binding(
                    get: { viewModel.activeTab },
                    set: { viewModel.setActiveTab($0) }
                )) {
                    // TAB 0: MOVIMIENTOS
                    movementsTabContent
                        .tag(0)
                    
                    // TAB 1: MODO PRO
                    ProModeScreen(viewModel: viewModel)
                        .tag(1)
                    
                    // TAB 2: ESTADÍSTICAS Y REPORTES
                    CategoryStatsView(viewModel: viewModel)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            
            // Drawer Lateral Izquierdo
            MoneyDevNavigationDrawer(viewModel: viewModel, isDrawerOpen: $isDrawerOpen)
            
            // Overlays para diálogos de transferencia
            if let transferResult = viewModel.transferSuccessResult {
                Color.black.opacity(0.6).ignoresSafeArea()
                TransferSuccessDialog(result: transferResult) {
                    viewModel.dismissTransferSuccessDialog()
                }
            }
            
            if let selectedTransfer = viewModel.selectedTransferMovement {
                Color.black.opacity(0.6).ignoresSafeArea()
                TransferMovementDetailsDialog(transaction: selectedTransfer, currencySymbol: viewModel.financialSummary.currencySymbol) {
                    viewModel.closeTransferMovementDetails()
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.isAddEditSheetOpen },
            set: { _ in viewModel.closeAddEditSheet() }
        )) {
            AddEditTransactionSheet(viewModel: viewModel)
        }
        .sheet(isPresented: Binding(
            get: { viewModel.isVoiceAssistantOpen },
            set: { _ in viewModel.closeVoiceAssistant() }
        )) {
            VoiceAssistantDialog(viewModel: viewModel)
        }
        .sheet(isPresented: $isDirectVoiceOpen) {
            DirectVoiceDictationDialog(viewModel: viewModel)
        }
        .sheet(isPresented: Binding(
            get: { viewModel.isTransferDialogOpen },
            set: { _ in viewModel.closeTransferDialog() }
        )) {
            TransferMoneyDialog(viewModel: viewModel)
        }
        .sheet(isPresented: Binding(
            get: { viewModel.isFixedExpensesDialogOpen },
            set: { _ in viewModel.closeFixedExpensesDialog() }
        )) {
            FixedExpensesDialog(viewModel: viewModel)
        }
        .sheet(isPresented: Binding(
            get: { viewModel.isSettingsDialogOpen },
            set: { _ in viewModel.closeSettingsDialog() }
        )) {
            SettingsDialog(viewModel: viewModel)
        }
        .sheet(isPresented: Binding(
            get: { viewModel.isSetBalanceDialogOpen },
            set: { _ in viewModel.closeSetBalanceDialog() }
        )) {
            InitialBalanceDialog(viewModel: viewModel)
        }
        .sheet(isPresented: $isCustomDateFilterOpen) {
            CustomDateFilterDialog(viewModel: viewModel)
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
        }
        .sheet(item: $walletToEdit) { wallet in
            EditWalletDialog(
                wallet: wallet,
                canDelete: viewModel.wallets.count > 1 && !wallet.isDefault,
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
        }
        .sheet(isPresented: $isPeriodSelectorOpen) {
            let periodOptions: [PeriodOptionItem<DateFilter>] = [
                PeriodOptionItem(value: .all, title: "Todos los períodos", subtitle: "Todos los registros históricos", iconSymbol: "calendar"),
                PeriodOptionItem(value: .customRange, title: "Filtrar por fecha", subtitle: "Rango personalizado de fechas o meses", iconSymbol: "calendar.badge.clock", isCustomFilter: true),
                PeriodOptionItem(value: .today, title: "Hoy", subtitle: "Movimientos registrados hoy", iconSymbol: "sun.max.fill"),
                PeriodOptionItem(value: .yesterday, title: "Ayer", subtitle: "Movimientos registrados ayer", iconSymbol: "clock.arrow.circlepath"),
                PeriodOptionItem(value: .thisWeek, title: "Esta semana", subtitle: "Movimientos de la semana en curso", iconSymbol: "calendar.badge.exclamationmark"),
                PeriodOptionItem(value: .thisMonth, title: "Este mes", subtitle: "Movimientos del mes en curso", iconSymbol: "calendar")
            ]
            PeriodSelectorDialog(
                title: "Filtrar por Período",
                options: periodOptions,
                selectedOption: viewModel.selectedDateFilter,
                onSelectOption: { chosen in
                    viewModel.setDateFilter(chosen)
                },
                onSelectCustomRange: {
                    isCustomDateFilterOpen = true
                },
                onDismiss: { isPeriodSelectorOpen = false }
            )
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
        }
        .task {
            if viewModel.financialSummary.notificationsEnabled {
                let hasPerm = await ReminderScheduler.checkNotificationPermission()
                if !hasPerm {
                    showNotificationRationale = true
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { !viewModel.financialSummary.hasCompletedOnboarding || viewModel.isTutorialOpen },
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
    }
    
    // MARK: - Movements Tab Content
    private var movementsTabContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Tarjeta de Balance Principal
                BalanceHeaderCard(
                    viewModel: viewModel,
                    onTransferClick: { viewModel.openTransferDialog() },
                    onAddExpenseClick: { viewModel.openAddTransaction(defaultType: .expense) },
                    onAddIncomeClick: { viewModel.openAddTransaction(defaultType: .income) },
                    onVoiceClick: { isDirectVoiceOpen = true }
                )
                
                // Botón Tarjeta Asistente MoneyBot
                VoiceAssistantCard {
                    viewModel.openVoiceAssistant()
                }
                
                // Filtros por Tipo (Todos / Gastos / Ingresos)
                HStack(spacing: 8) {
                    ForEach(FilterType.allCases, id: \.self) { filter in
                        let isSelected = viewModel.selectedFilter == filter
                        Button {
                            viewModel.setFilter(filter)
                        } label: {
                            Text(filter.rawValue)
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? .white : AppColors.textSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(isSelected ? activeTheme.primary : AppColors.darkNavySurface)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(isSelected ? activeTheme.primary : AppColors.cardBorderNavy, lineWidth: 1)
                                )
                        }
                    }
                    Spacer()
                }
                
                // Filtros por Fecha (Horizontal Scroll Chips + Period Selector)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button {
                            isPeriodSelectorOpen = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Período")
                                    .font(.system(size: 12, weight: .bold))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(viewModel.selectedDateFilter != .all ? activeTheme.primary : AppColors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppColors.darkNavySurface)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(viewModel.selectedDateFilter != .all ? activeTheme.primary : AppColors.cardBorderNavy, lineWidth: 1)
                            )
                        }
                        ForEach(DateFilter.allCases, id: \.self) { df in
                            let isSelected = viewModel.selectedDateFilter == df
                            Button {
                                if df == .customRange {
                                    isCustomDateFilterOpen = true
                                } else {
                                    viewModel.setDateFilter(df)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    if df == .customRange {
                                        Image(systemName: "calendar")
                                            .font(.system(size: 11))
                                    }
                                    Text(df == .customRange && viewModel.customDateRange != nil ? viewModel.customDateRange!.label : df.label)
                                        .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                }
                                .foregroundStyle(isSelected ? activeTheme.primary : AppColors.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(AppColors.darkNavySurface)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(isSelected ? activeTheme.primary : AppColors.cardBorderNavy, lineWidth: 1)
                                )
                            }
                        }
                    }
                }
                
                // Lista de Movimientos
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Movimientos (\(viewModel.filteredTransactions.count))")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                        
                        Spacer()
                    }
                    
                    if viewModel.filteredTransactions.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tray.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(AppColors.textMuted)
                            
                            Text("No se encontraron movimientos")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(AppColors.textPrimary)
                            
                            Text("Agrega tu primer gasto o ingreso usando los botones superiores o el dictado por voz.")
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.filteredTransactions) { tx in
                                TransactionItemCard(
                                    transaction: tx,
                                    currencySymbol: viewModel.financialSummary.currencySymbol,
                                    isHidden: viewModel.isBalanceHidden
                                ) {
                                    viewModel.openEditTransaction(tx)
                                } onDelete: {
                                    viewModel.deleteTransaction(tx)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
    
    private func tabButton(title: String, icon: String, tabIndex: Int, accent: Color? = nil) -> some View {
        let isSelected = viewModel.activeTab == tabIndex
        let color = accent ?? activeTheme.primary
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.setActiveTab(tabIndex)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
            }
            .foregroundStyle(isSelected ? .white : AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(isSelected ? color : AppColors.darkNavySurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? color : AppColors.cardBorderNavy, lineWidth: 1)
            )
        }
    }
}
