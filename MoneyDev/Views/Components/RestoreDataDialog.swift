import SwiftUI
import UniformTypeIdentifiers

public struct RestoreDataDialog: View {
    @Bindable var viewModel: ExpenseViewModel
    let onDismiss: () -> Void
    
    @State private var showingFilePicker: Bool = false
    @State private var showingManualInput: Bool = false
    @State private var manualJsonText: String = ""
    @State private var statusMessage: String? = nil
    @State private var isSuccess: Bool = false
    @State private var showResultAlert: Bool = false
    
    private var activeTheme: AppColorTheme {
        viewModel.activeTheme
    }
    
    public init(viewModel: ExpenseViewModel, onDismiss: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                ThemedModalBackground(theme: activeTheme)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            Circle()
                                .fill(activeTheme.primary.opacity(0.18))
                                .frame(width: 50, height: 50)
                                .overlay {
                                    Image(systemName: "arrow.counterclockwise.circle.fill")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundStyle(activeTheme == .electricBlack ? Color(hex: "#38BDF8") : activeTheme.primary)
                                }
                            
                            Text("Restaurar Datos")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.textPrimary)
                                .contrastTextOutline()
                            
                            Text("Recupera tus transacciones, billeteras, gastos fijos y conversación de MoneyBot desde un archivo o código de respaldo.")
                                .font(.system(size: 13))
                                .foregroundStyle(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                                .contrastTextOutline(color: Color.black.opacity(0.6), radius: 2)
                        }
                        .padding(.top, 16)
                        
                        // Opciones Principales
                        VStack(spacing: 12) {
                            // Opción 1: Elegir archivo de respaldo
                            Button {
                                showingFilePicker = true
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: "#00D2FF").opacity(0.2))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "folder.fill")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(Color(hex: "#00D2FF"))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Elegir archivo de respaldo")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(AppColors.textPrimary)
                                            .contrastTextOutline()
                                        Text("Importa un archivo guardado en tu dispositivo o nube")
                                            .font(.system(size: 12))
                                            .foregroundStyle(AppColors.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(AppColors.textMuted)
                                }
                                .padding(14)
                                .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 16))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                            
                            // Opción 2: Pegar desde el portapapeles
                            Button {
                                restoreFromClipboard()
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(AppColors.incomeEmerald.opacity(0.2))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "doc.on.clipboard.fill")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(AppColors.incomeEmeraldLight)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Pegar desde el portapapeles")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(AppColors.textPrimary)
                                            .contrastTextOutline()
                                        Text("Restaura al instante el respaldo copiado en la memoria")
                                            .font(.system(size: 12))
                                            .foregroundStyle(AppColors.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.down.doc.fill")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(AppColors.incomeEmeraldLight)
                                }
                                .padding(14)
                                .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 16))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                            
                            // Opción 3: Pegar y editar texto en ventana flotante
                            Button {
                                showingManualInput = true
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: "#A855F7").opacity(0.2))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "square.and.pencil")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(Color(hex: "#A855F7"))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Pegar y editar texto")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(AppColors.textPrimary)
                                            .contrastTextOutline()
                                        Text("Abre una ventana flotante para pegar o revisar el texto manualmente")
                                            .font(.system(size: 12))
                                            .foregroundStyle(AppColors.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(AppColors.textMuted)
                                }
                                .padding(14)
                                .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 16))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        
                        // Nota informativa
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(AppColors.textMuted)
                            Text("Al restaurar, se actualizarán tus datos con los del archivo sin duplicar transacciones existentes.")
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.textMuted)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 6)
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Restaurar Datos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") {
                        onDismiss()
                    }
                    .foregroundStyle(AppColors.textSecondary)
                    .contrastTextOutline()
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.json, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFilePicked(result)
            }
            .sheet(isPresented: $showingManualInput) {
                NavigationStack {
                    ZStack {
                        ThemedModalBackground(theme: activeTheme)
                        
                        VStack(spacing: 14) {
                            HStack {
                                Text("Pega el contenido de tu respaldo:")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppColors.textSecondary)
                                    .contrastTextOutline()
                                
                                Spacer()
                                
                                Button {
                                    if let clip = UIPasteboard.general.string, !clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        manualJsonText = clip
                                        let gen = UIImpactFeedbackGenerator(style: .light)
                                        gen.impactOccurred()
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.on.clipboard")
                                            .font(.system(size: 12, weight: .bold))
                                        Text("Pegar")
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                    .foregroundStyle(activeTheme == .electricBlack ? Color(hex: "#38BDF8") : activeTheme.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(activeTheme == .electricBlack ? Color(hex: "#262626") : activeTheme.primary.opacity(0.18))
                                    .clipShape(Capsule())
                                }
                            }
                            
                            ZStack(alignment: .topLeading) {
                                if manualJsonText.isEmpty {
                                    Text("Pega aquí el texto de tu copia de seguridad...")
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundStyle(AppColors.textMuted)
                                        .padding(14)
                                }
                                
                                TextEditor(text: $manualJsonText)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(AppColors.textPrimary)
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 14))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            
                            Button {
                                showingManualInput = false
                                restoreManualText()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.counterclockwise.circle.fill")
                                    Text("Restaurar Datos")
                                }
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(
                                    manualJsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                                    Color.white.opacity(0.5) :
                                    (activeTheme == .electricBlack ? Color.white : activeTheme.onPrimaryText)
                                )
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    manualJsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                                    Color.gray.opacity(0.3) :
                                    (activeTheme == .electricBlack ? Color(hex: "#262626") : activeTheme.primary)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(
                                            activeTheme == .electricBlack && !manualJsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                                            Color.white.opacity(0.4) : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                            }
                            .disabled(manualJsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(18)
                    }
                    .navigationTitle("Pegar y Editar Texto")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancelar") {
                                showingManualInput = false
                            }
                            .foregroundStyle(AppColors.textSecondary)
                            .contrastTextOutline()
                        }
                        if !manualJsonText.isEmpty {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Borrar") {
                                    manualJsonText = ""
                                }
                                .foregroundStyle(AppColors.expenseRoseLight)
                                .contrastTextOutline()
                            }
                        }
                    }
                }
                .keyboardDismissArrow()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .themedSheetContainer(theme: activeTheme)
                .ignoresSafeArea(.container, edges: .bottom)
            }
            .alert(isSuccess ? "¡Restauración Exitosa!" : (statusMessage?.contains("Modo PRO") == true ? "Copia de Seguridad PRO" : "Aviso de Restauración"), isPresented: $showResultAlert) {
                if !isSuccess && statusMessage?.contains("Modo PRO") == true {
                    Button("Activar Modo PRO") {
                        onDismiss()
                        viewModel.closeSettingsDialog()
                        viewModel.setActiveTab(2)
                    }
                    Button("Cancelar", role: .cancel) { }
                } else {
                    Button("Entendido") {
                        if isSuccess {
                            onDismiss()
                        }
                    }
                }
            } message: {
                Text(statusMessage ?? "")
            }
        }
        .presentationDetents([.fraction(0.65), .large])
        .presentationDragIndicator(.visible)
    }
    
    private func restoreFromClipboard() {
        guard let clip = UIPasteboard.general.string, !clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusMessage = "El portapapeles está vacío o no contiene una copia de seguridad."
            isSuccess = false
            showResultAlert = true
            return
        }
        
        let (success, error) = viewModel.importDataJson(clip)
        isSuccess = success
        if success {
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)
            statusMessage = "¡Tus datos han sido restaurados correctamente desde el portapapeles!"
        } else {
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.error)
            statusMessage = error ?? "El contenido copiado no corresponde a una copia de seguridad válida de MoneyDev."
        }
        showResultAlert = true
    }
    
    private func restoreManualText() {
        let text = manualJsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        let (success, error) = viewModel.importDataJson(text)
        isSuccess = success
        if success {
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)
            statusMessage = "¡Tus datos han sido restaurados correctamente!"
        } else {
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.error)
            statusMessage = error ?? "Formato de respaldo no válido."
        }
        showResultAlert = true
    }
    
    private func handleFilePicked(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let canAccess = url.startAccessingSecurityScopedResource()
            defer {
                if canAccess { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let data = try Data(contentsOf: url)
                guard let content = String(data: data, encoding: .utf8) else {
                    statusMessage = "El archivo no contiene texto legible."
                    isSuccess = false
                    showResultAlert = true
                    return
                }
                let (success, error) = viewModel.importDataJson(content)
                isSuccess = success
                if success {
                    let gen = UINotificationFeedbackGenerator()
                    gen.notificationOccurred(.success)
                    statusMessage = "¡Datos restaurados con éxito desde el archivo seleccionado!"
                } else {
                    let gen = UINotificationFeedbackGenerator()
                    gen.notificationOccurred(.error)
                    statusMessage = error ?? "El archivo no contiene una copia de seguridad válida de MoneyDev."
                }
                showResultAlert = true
            } catch {
                statusMessage = "Error al leer el archivo: \(error.localizedDescription)"
                isSuccess = false
                showResultAlert = true
            }
        case .failure(let error):
            statusMessage = "Error al seleccionar el archivo: \(error.localizedDescription)"
            isSuccess = false
            showResultAlert = true
        }
    }
}
