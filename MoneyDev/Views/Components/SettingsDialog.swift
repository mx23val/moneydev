import SwiftUI

public struct SettingsDialog: View {
    @Bindable var viewModel: ExpenseViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingExportSheet: Bool = false
    @State private var exportItems: [Any] = []
    @State private var showingImportAlert: Bool = false
    @State private var importJsonString: String = ""
    @State private var alertMessage: String? = nil
    @State private var showAlert: Bool = false
    @State private var showConfirmClearAll: Bool = false
    @State private var showNotificationPermissionDialog: Bool = false
    @State private var showAprendeDialog: Bool = false
    
    public init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AppColors.midnightBlack.ignoresSafeArea()
                
                Form {
                    // SECCIÓN TEMA Y APARIENCIA
                    Section("Tema y Apariencia") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Color de Acento")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppColors.textSecondary)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 10)], spacing: 10) {
                                ForEach(AppColorTheme.allCases) { theme in
                                    let isSelected = viewModel.financialSummary.themeColorId == theme.id
                                    let isLocked = theme.isProOnly && !viewModel.isProUser
                                    
                                    Button {
                                        if isLocked {
                                            alertMessage = "Este color es exclusivo del Modo PRO. Activa tu código para usarlo."
                                            showAlert = true
                                        } else {
                                            viewModel.setThemeColor(theme.id)
                                        }
                                    } label: {
                                        VStack(spacing: 6) {
                                            ZStack {
                                                Circle()
                                                    .fill(
                                                        LinearGradient(colors: theme.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                                                    )
                                                    .frame(width: 32, height: 32)
                                                
                                                if isSelected {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 14, weight: .bold))
                                                        .foregroundStyle(.white)
                                                } else if isLocked {
                                                    Image(systemName: "lock.fill")
                                                        .font(.system(size: 12))
                                                        .foregroundStyle(.white)
                                                }
                                            }
                                            
                                            Text(theme.displayName.split(separator: " ").first.map(String.init) ?? "")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundStyle(isSelected ? .white : AppColors.textSecondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(isSelected ? AppColors.darkNavySurface : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .listRowBackground(AppColors.darkNavySurface)
                    
                    // SECCIÓN PREFERENCIAS DE SISTEMA
                    Section("Preferencias") {
                        Toggle(isOn: Binding(
                            get: { viewModel.financialSummary.soundsEnabled },
                            set: { viewModel.setSoundsEnabled($0) }
                        )) {
                            Label("Sonidos de movimientos", systemImage: "speaker.wave.2.fill")
                                .foregroundStyle(AppColors.textPrimary)
                        }
                        
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
                            Label("Recordatorio diario (9:00 AM)", systemImage: "bell.fill")
                                .foregroundStyle(AppColors.textPrimary)
                        }
                    }
                    .listRowBackground(AppColors.darkNavySurface)
                    
                    // SECCIÓN EDUCACIÓN FINANCIERA
                    Section("Educación Financiera") {
                        Button {
                            showAprendeDialog = true
                        } label: {
                            Label("Aprende con MoneyDev", systemImage: "book.fill")
                                .foregroundStyle(Color(hex: "#38BDF8"))
                        }
                    }
                    .listRowBackground(AppColors.darkNavySurface)
                    
                    // SECCIÓN COPIA DE SEGURIDAD (COMPATIBLE 1:1 CON ANDROID)
                    Section("Copia de Seguridad y Restauración") {
                        Button {
                            exportBackup()
                        } label: {
                            Label("Exportar Copia (.json)", systemImage: "square.and.arrow.up.fill")
                                .foregroundStyle(Color(hex: "#38BDF8"))
                        }
                        
                        Button {
                            showingImportAlert = true
                        } label: {
                            Label("Restaurar desde JSON", systemImage: "square.and.arrow.down.fill")
                                .foregroundStyle(Color(hex: "#34D399"))
                        }
                    }
                    .listRowBackground(AppColors.darkNavySurface)
                    
                    // ZONA DE PELIGRO
                    Section("Restablecimiento") {
                        Button(role: .destructive) {
                            showConfirmClearAll = true
                        } label: {
                            Label("Borrar todos los datos", systemImage: "trash.fill")
                                .foregroundStyle(AppColors.expenseRoseLight)
                        }
                    }
                    .listRowBackground(AppColors.darkNavySurface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Configuración")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Listo") {
                        viewModel.closeSettingsDialog()
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(Color(hex: "#38BDF8"))
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
            }
            .sheet(isPresented: $showAprendeDialog) {
                AprendeConMoneyDevDialog {
                    showAprendeDialog = false
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                ActivityViewController(activityItems: exportItems)
            }
            .alert("Restaurar Respaldo", isPresented: $showingImportAlert) {
                TextField("Pega el contenido JSON aquí", text: $importJsonString)
                Button("Restaurar", role: .none) {
                    processImport()
                }
                Button("Cancelar", role: .cancel) {
                    importJsonString = ""
                }
            } message: {
                Text("Pega el JSON exportado previamente desde MoneyDev (Android o iOS).")
            }
            .alert("¿Borrar todos los datos?", isPresented: $showConfirmClearAll) {
                Button("Borrar Todo", role: .destructive) {
                    viewModel.clearAllData()
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
    }
    
    private func exportBackup() {
        let jsonStr = viewModel.getExportDataJson()
        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("MoneyDev_Backup_\(Int(Date().timeIntervalSince1970)).json")
        try? jsonStr.write(to: tempUrl, atomically: true, encoding: .utf8)
        exportItems = [tempUrl]
        showingExportSheet = true
    }
    
    private func processImport() {
        let (success, error) = viewModel.importDataJson(importJsonString)
        importJsonString = ""
        if success {
            alertMessage = "¡Datos restaurados con éxito!"
        } else {
            alertMessage = error ?? "No se detectó el formato correcto. Por favor intente de nuevo."
        }
        showAlert = true
    }
}
