import SwiftUI
import UniformTypeIdentifiers

public struct SettingsDialog: View {
    @Bindable var viewModel: ExpenseViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var isThemeExpanded: Bool = false
    @State private var showingBackupExportDialog: Bool = false
    @State private var showingRestoreDialog: Bool = false
    @State private var alertMessage: String? = nil
    @State private var showAlert: Bool = false
    @State private var showConfirmClearAll: Bool = false
    @State private var showNotificationPermissionDialog: Bool = false
    @State private var showingContactDialog: Bool = false
    @State private var showingAppLockDialog: Bool = false
    @State private var selectedAppIcon: String = AppIconManager.currentIcon
    @State private var activeHighlight: ExpenseViewModel.SettingsHighlightTarget? = nil
    @State private var isPulsingGold: Bool = false
    
    private var activeTheme: AppColorTheme {
        viewModel.activeTheme
    }
    
    public init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            ThemedModalBackground(theme: activeTheme)
            
            ScrollViewReader { scrollProxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // 1. SECCIÓN TEMA Y APARIENCIA (Menú Flotante sin Desplazar Contenido)
                        themeSectionCard
                        
                        // 2. SECCIÓN ÍCONO DE LA APLICACIÓN
                        iconSectionCard
                        
                        // 3. SECCIÓN PREFERENCIAS DE SISTEMA
                        preferencesSectionCard
                        
                        // 4. SECCIÓN SEGURIDAD Y BLOQUEO
                        securitySectionCard
                        
                        // 5. SECCIÓN COPIA DE SEGURIDAD
                        backupSectionCard
                        
                        // 6. SECCIÓN SOPORTE Y CONTACTO
                        supportSectionCard
                        
                        // 7. ZONA DE PELIGRO: RESTABLECIMIENTO
                        dangerSectionCard
                        
                        // Espaciador inferior para no quedar tapado por la barra flotante TabBar
                        Color.clear.frame(height: 80)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
                .scrollDisabled(isThemeExpanded)
                .onAppear {
                    if let target = viewModel.settingsHighlightTarget {
                        triggerHighlight(target, proxy: scrollProxy)
                    }
                }
                .onChange(of: viewModel.settingsHighlightTarget) { _, newTarget in
                    if let newTarget {
                        triggerHighlight(newTarget, proxy: scrollProxy)
                    }
                }
            }
            
            // Fondo oscuro para cerrar si toca afuera
            if isThemeExpanded {
                activeTheme.appBackgroundGradient[2].opacity(0.72)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.84)) {
                            isThemeExpanded = false
                        }
                    }
                    .zIndex(45)
                
                // Menú Flotante de Selección de Color en Primer Plano (No desplaza el contenido)
                VStack {
                    ThemeInlineDropdownPickerView(
                        viewModel: viewModel,
                        isThemeExpanded: $isThemeExpanded,
                        alertMessage: $alertMessage,
                        showAlert: $showAlert,
                        activeTheme: activeTheme
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 92)
                    Spacer()
                }
                .zIndex(50)
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
        .sheet(isPresented: $showNotificationPermissionDialog) {
            NotificationPermissionDialog(
                onAccept: {
                    showNotificationPermissionDialog = false
                    Task {
                        let granted = await ReminderScheduler.requestNotificationPermission()
                        await MainActor.run {
                            viewModel.setNotificationsEnabled(granted)
                        }
                    }
                },
                onDismiss: {
                    showNotificationPermissionDialog = false
                }
            )
            .presentationDetents([.fraction(0.48)])
            .themedSheetContainer(theme: activeTheme)
        }
        .sheet(isPresented: $showingBackupExportDialog) {
            BackupJsonExportDialog(viewModel: viewModel) {
                showingBackupExportDialog = false
            }
            .themedSheetContainer(theme: activeTheme)
        }
        .sheet(isPresented: $showingRestoreDialog) {
            RestoreDataDialog(viewModel: viewModel) {
                showingRestoreDialog = false
            }
            .themedSheetContainer(theme: activeTheme)
        }
        .sheet(isPresented: $showingAppLockDialog) {
            AppLockSetupDialog(viewModel: viewModel)
                .themedSheetContainer(theme: activeTheme)
        }
        .sheet(isPresented: $showingContactDialog) {
            ContactDialog(theme: activeTheme) {
                showingContactDialog = false
            }
            .themedSheetContainer(theme: activeTheme)
        }
        .alert("¿Borrar todos los datos?", isPresented: $showConfirmClearAll) {
            Button("Borrar Todo", role: .destructive) {
                viewModel.clearAllData()
                dismiss()
            }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Esta acción eliminará todas las transacciones, gastos fijos y reseteará tus billeteras a 0. No se puede deshacer.")
        }
        .alert("Aviso", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage ?? "")
        }
    }
    
    // MARK: - 1. Tarjeta de Tema y Apariencia
    private var themeSectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TEMA Y APARIENCIA")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppColors.textMuted)
                .padding(.leading, 4)
            
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                withAnimation(.spring(response: 0.22, dampingFraction: 0.84)) {
                    isThemeExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: activeTheme.gradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(activeTheme == .electricBlack ? 0.6 : 0.25), lineWidth: 1.2)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Color del Tema")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppColors.textPrimary)
                        
                        Text(activeTheme.displayName)
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(activeTheme.accentIconColor)
                        .frame(width: 28, height: 28)
                        .background(activeTheme.accentIconColor.opacity(0.12))
                        .clipShape(Circle())
                        .rotationEffect(.degrees(isThemeExpanded ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 14))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.16), radius: 3, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        activeHighlight == .theme && isPulsingGold ? Color(hex: "#F59E0B") : Color.clear,
                        lineWidth: activeHighlight == .theme && isPulsingGold ? 2.5 : 0
                    )
            )
            .id("settings_theme_section")
        }
    }
    
    // MARK: - 2. Tarjeta de Ícono de la Aplicación
    private var iconSectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ÍCONO DE LA APLICACIÓN")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppColors.textMuted)
                .padding(.leading, 4)
            
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Personalización del Ícono")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    if viewModel.isProUser {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 11))
                            Text("MODO PRO ACTIVO")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(Color(hex: "#F59E0B"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#F59E0B").opacity(0.15))
                        .clipShape(Capsule())
                    }
                }
                
                HStack(spacing: 16) {
                    settingsIconCard(
                        title: "Modo Básico",
                        iconType: AppIconManager.iconBasic,
                        imageName: "icon_basic",
                        fallbackColors: [Color(hex: "#00D2FF"), Color(hex: "#1D4ED8")],
                        isPro: false
                    )
                    
                    settingsIconCard(
                        title: "Modo PRO",
                        iconType: AppIconManager.iconPro,
                        imageName: "icon_pro",
                        fallbackColors: [Color(hex: "#F59E0B"), Color(hex: "#78350F")],
                        isPro: true
                    )
                }
            }
            .padding(16)
            .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 14))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.16), radius: 3, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        activeHighlight == .appIcon && isPulsingGold ? Color(hex: "#F59E0B") : Color.clear,
                        lineWidth: activeHighlight == .appIcon && isPulsingGold ? 2.5 : 0
                    )
            )
            .id("settings_icon_section")
        }
    }
    
    // MARK: - 3. Tarjeta de Preferencias
    private var preferencesSectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PREFERENCIAS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppColors.textMuted)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                Toggle(isOn: Binding(
                    get: { viewModel.financialSummary.soundsEnabled },
                    set: { viewModel.setSoundsEnabled($0) }
                )) {
                    HStack(spacing: 12) {
                        themedRowIcon(systemName: "speaker.wave.2.fill")
                        Text("Sonidos de movimientos")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                }
                .tint(activeTheme.toggleTint)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider().background(AppColors.cardBorderNavy)
                
                Toggle(isOn: Binding(
                    get: { viewModel.financialSummary.notificationsEnabled },
                    set: { newValue in
                        if newValue {
                            Task {
                                let hasPerm = await ReminderScheduler.checkNotificationPermission()
                                await MainActor.run {
                                    if hasPerm {
                                        viewModel.setNotificationsEnabled(true)
                                    } else {
                                        showNotificationPermissionDialog = true
                                    }
                                }
                            }
                        } else {
                            viewModel.setNotificationsEnabled(false)
                        }
                    }
                )) {
                    HStack(spacing: 12) {
                        themedRowIcon(systemName: "bell.fill")
                        Text("Recordatorio diario")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                }
                .tint(activeTheme.toggleTint)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 14))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.16), radius: 3, x: 0, y: 2)
            .id("settings_currency_section")
        }
    }
    
    // MARK: - 4. Tarjeta de Seguridad
    private var securitySectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SEGURIDAD")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppColors.textMuted)
                .padding(.leading, 4)
            
            Button {
                showingAppLockDialog = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppSecurityManager.shared.isLockEnabled ? AppColors.incomeEmerald.opacity(0.18) : AppColors.navySurfaceVariant)
                            .frame(width: 32, height: 32)
                        Image(systemName: AppSecurityManager.shared.isLockEnabled ? "lock.shield.fill" : "lock.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppSecurityManager.shared.isLockEnabled ? AppColors.incomeEmeraldLight : activeTheme.accentIconColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bloquear app")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColors.textPrimary)
                        
                        Text(AppSecurityManager.shared.securitySubtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textMuted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 14))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.16), radius: 3, x: 0, y: 2)
            .id("settings_security_section")
        }
    }
    
    // MARK: - 5. Tarjeta de Copia de Seguridad
    private var backupSectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COPIA DE SEGURIDAD")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppColors.textMuted)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                Button {
                    showingBackupExportDialog = true
                } label: {
                    HStack(spacing: 12) {
                        themedRowIcon(systemName: "arrow.down.doc.fill")
                        Text("Guardar datos")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.textMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider().background(AppColors.cardBorderNavy)
                
                Button {
                    showingRestoreDialog = true
                } label: {
                    HStack(spacing: 12) {
                        themedRowIcon(systemName: "arrow.counterclockwise.circle.fill")
                        Text("Restaurar datos")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.textMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 14))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.16), radius: 3, x: 0, y: 2)
            .id("settings_backup_section")
        }
    }
    
    // MARK: - 6. Tarjeta de Soporte y Contacto
    private var supportSectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SOPORTE Y CONTACTO")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppColors.textMuted)
                .padding(.leading, 4)
            
            Button {
                showingContactDialog = true
            } label: {
                HStack(spacing: 12) {
                    themedRowIcon(systemName: "envelope.fill")
                    Text("Contacto")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textMuted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 14))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.16), radius: 3, x: 0, y: 2)
            .id("settings_support_section")
        }
    }
    
    // MARK: - 7. Tarjeta de Restablecimiento
    private var dangerSectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RESTABLECIMIENTO")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppColors.textMuted)
                .padding(.leading, 4)
            
            Button(role: .destructive) {
                showConfirmClearAll = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(AppColors.expenseRoseLight.opacity(0.18))
                            .frame(width: 28, height: 28)
                        Image(systemName: "trash.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppColors.expenseRoseLight)
                    }
                    Text("Borrar todos los datos")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.expenseRoseLight)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 14))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.16), radius: 3, x: 0, y: 2)
            .id("settings_danger_section")
        }
    }
    
// MARK: - Menú Desplegable Flotante con Barra de Scroll Separada y Más Larga
private struct ThemeInlineDropdownPickerView: View {
    @Bindable var viewModel: ExpenseViewModel
    @Binding var isThemeExpanded: Bool
    @Binding var alertMessage: String?
    @Binding var showAlert: Bool
    let activeTheme: AppColorTheme
    
    @State private var themeScrollProgress: CGFloat = 0.0
    @State private var isDraggingThemeThumb: Bool = false
    
    private let dropdownH: CGFloat = 232
    private let trackH: CGFloat = 212
    private let thumbH: CGFloat = 82
    private var travelDist: CGFloat { trackH - thumbH }
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            HStack(spacing: 8) {
                // Columna 1: Contenedores de colores con anchura reducida y sin invadir la barra
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 5) {
                        ForEach(AppColorTheme.allCases) { theme in
                            let isSelected = viewModel.financialSummary.themeColorId == theme.id
                            let isLocked = theme.isProOnly && !viewModel.isProUser
                            
                            Button {
                                if isLocked {
                                    alertMessage = "Este color es exclusivo del Modo PRO. Activa tu código para usarlo."
                                    showAlert = true
                                } else {
                                    let generator = UISelectionFeedbackGenerator()
                                    generator.selectionChanged()
                                    viewModel.setThemeColor(theme.id)
                                    withAnimation(.spring(response: 0.22, dampingFraction: 0.84)) {
                                        isThemeExpanded = false
                                    }
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: theme.gradient,
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(theme == .electricBlack ? 0.7 : 0.25), lineWidth: 1)
                                        )
                                    
                                    Text(theme.displayName)
                                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                        .foregroundStyle(isSelected ? (theme == .electricBlack ? Color.white : theme.accentTextColor) : Color.white)
                                        .contrastTextOutline()
                                    
                                    Spacer()
                                    
                                    if isLocked {
                                        HStack(spacing: 3) {
                                            Image(systemName: "crown.fill")
                                                .font(.system(size: 9))
                                            Text("PRO")
                                                .font(.system(size: 8, weight: .bold))
                                        }
                                        .foregroundStyle(Color(hex: "#F59E0B"))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(hex: "#F59E0B").opacity(0.14))
                                        .clipShape(Capsule())
                                    } else if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .black))
                                            .foregroundStyle(theme == .electricBlack ? Color.white : theme.primary)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    isSelected ?
                                        (theme == .electricBlack ? Color.white.opacity(0.10) : theme.primary.opacity(0.10)) :
                                        Color.clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isSelected ? Color.white.opacity(0.20) : Color.clear, lineWidth: 0.7)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .id(theme.id)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.leading, 8)
                }
                .frame(height: dropdownH)
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    let maxDist = max(1, geo.contentSize.height - geo.containerSize.height)
                    return min(max(geo.contentOffset.y / maxDist, 0.0), 1.0)
                } action: { _, newProgress in
                    guard !isDraggingThemeThumb else { return }
                    themeScrollProgress = newProgress
                }
                
                // Columna 2: Barra desplazadora independiente, más larga y completamente separada
                VStack {
                    ZStack(alignment: .top) {
                        // Pista de la barra alargada
                        Capsule()
                            .fill(Color.white.opacity(0.16))
                            .frame(width: 4, height: trackH)
                        
                        // Indicador (Thumb) arrastrable alargado
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        activeTheme == .electricBlack ? Color.white : activeTheme.accentIconColor,
                                        activeTheme == .electricBlack ? Color(hex: "#CBD5E1") : (activeTheme.gradient.count > 1 ? activeTheme.gradient[1] : activeTheme.primary)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 5, height: thumbH)
                            .shadow(color: Color.black.opacity(0.60), radius: 3, x: 0, y: 1)
                            .offset(y: travelDist * themeScrollProgress)
                    }
                    .frame(width: 18, height: trackH)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                isDraggingThemeThumb = true
                                let clampedY = max(0, min(value.location.y - thumbH / 2, travelDist))
                                let newProgress = travelDist > 0 ? clampedY / travelDist : 0
                                themeScrollProgress = newProgress
                                
                                let allThemes = AppColorTheme.allCases
                                let targetIdx = Int(round(newProgress * CGFloat(allThemes.count - 1)))
                                let safeIdx = max(0, min(targetIdx, allThemes.count - 1))
                                let targetTheme = allThemes[safeIdx]
                                scrollProxy.scrollTo(targetTheme.id, anchor: .center)
                            }
                            .onEnded { _ in
                                isDraggingThemeThumb = false
                            }
                    )
                }
                .padding(.trailing, 8)
                .frame(height: dropdownH)
            }
            .onAppear {
                isDraggingThemeThumb = false
                let currentId = viewModel.financialSummary.themeColorId
                if let idx = AppColorTheme.allCases.firstIndex(where: { $0.id == currentId }) {
                    let allCount = AppColorTheme.allCases.count
                    themeScrollProgress = allCount > 1 ? CGFloat(idx) / CGFloat(allCount - 1) : 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        scrollProxy.scrollTo(currentId, anchor: .center)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .background(ThemedModalBackground(theme: activeTheme))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
    
    @ViewBuilder
    private func themedRowIcon(systemName: String) -> some View {
        let iconColor = activeTheme == .electricBlack ? Color.white : activeTheme.accentIconColor
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(iconColor.opacity(0.18))
                .frame(width: 28, height: 28)
            
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
        }
    }
    
    private func settingsIconCard(title: String, iconType: String, imageName: String, fallbackColors: [Color], isPro: Bool) -> some View {
        let isSelected = (selectedAppIcon == iconType) || (iconType == AppIconManager.iconBasic && (selectedAppIcon == "classic" || selectedAppIcon == "icon_basic")) || (iconType == AppIconManager.iconPro && (selectedAppIcon == "pro_gold" || selectedAppIcon == "icon_pro"))
        let isLocked = isPro && !viewModel.isProUser
        
        return Button {
            if isLocked {
                alertMessage = "El ícono Modo PRO es exclusivo del Modo PRO. Activa tu código en la pestaña Modo PRO para desbloquearlo."
                showAlert = true
            } else {
                let generator = UISelectionFeedbackGenerator()
                generator.selectionChanged()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.72)) {
                    selectedAppIcon = iconType
                }
                Task {
                    _ = await AppIconManager.setAppIcon(iconType)
                    ReminderScheduler.updateDailyReminders(
                        transactions: viewModel.transactions,
                        notificationsEnabled: viewModel.financialSummary.notificationsEnabled
                    )
                }
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    if let uiImg = UIImage(named: imageName) {
                        Image(uiImage: uiImg)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 68, height: 68)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient(colors: fallbackColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 68, height: 68)
                            .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 2)
                        
                        Image(systemName: isPro ? "crown.fill" : "dollarsign.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                    }
                    
                    if isLocked {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(Circle().fill(Color.black.opacity(0.65)))
                                    .offset(x: 4, y: -4)
                            }
                            Spacer()
                        }
                        .frame(width: 68, height: 68)
                    }
                }
                
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? .white : AppColors.textSecondary)
                    .contrastTextOutline()
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(
                ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 14)
                    .shadow(
                        color: Color.black.opacity(isSelected ? 0.20 : 0.14),
                        radius: isSelected ? 4 : 2,
                        x: 0,
                        y: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Efecto de Parpadeo Dorado al Navegar desde Modo PRO
    private func triggerHighlight(_ target: ExpenseViewModel.SettingsHighlightTarget, proxy: ScrollViewProxy) {
        activeHighlight = target
        let targetId = target == .theme ? "settings_theme_section" : "settings_icon_section"
        withAnimation(.easeInOut(duration: 0.35)) {
            proxy.scrollTo(targetId, anchor: .center)
        }
        withAnimation(.easeInOut(duration: 0.25).repeatCount(6, autoreverses: true)) {
            isPulsingGold = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation(.easeOut(duration: 0.25)) {
                isPulsingGold = false
                activeHighlight = nil
                viewModel.settingsHighlightTarget = nil
            }
        }
    }
}
