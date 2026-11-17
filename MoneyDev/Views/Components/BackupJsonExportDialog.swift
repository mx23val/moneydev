import SwiftUI

public struct BackupJsonExportDialog: View {
    @Bindable var viewModel: ExpenseViewModel
    let onDismiss: () -> Void
    
    @State private var jsonString: String = ""
    @State private var isCopied: Bool = false
    
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
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // Header con icono y título
                        VStack(spacing: 10) {
                            let iconAccent = activeTheme == .electricBlack ? Color.white : activeTheme.primary
                            Circle()
                                .fill(iconAccent.opacity(0.18))
                                .frame(width: 52, height: 52)
                                .overlay {
                                    Image(systemName: "folder.badge.gearshape")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundStyle(iconAccent)
                                }
                            
                            VStack(spacing: 5) {
                                Text("Guardar Copia de Seguridad")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppColors.textPrimary)
                                
                                Text("Exporta un respaldo completo y seguro de tus transacciones, billeteras, gastos fijos y configuraciones.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppColors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                            }
                        }
                        .padding(.top, 14)
                        
                        // Tarjeta de Resumen de Contenido del Respaldo (Sin volcado de código JSON)
                        VStack(spacing: 12) {
                            HStack {
                                Label("Contenido del respaldo", systemImage: "checkmark.seal.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentTextColor)
                                
                                Spacer()
                                
                                if !jsonString.isEmpty {
                                    Text("\(jsonString.utf8.count) bytes")
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                            }
                            
                            Divider().background(Color.white.opacity(0.12))
                            
                            HStack(spacing: 8) {
                                metricBadge(title: "Movimientos", count: viewModel.transactions.count, icon: "list.bullet.rectangle.portrait.fill")
                                metricBadge(title: "Billeteras", count: viewModel.wallets.count, icon: "creditcard.fill")
                                metricBadge(title: "Gastos Fijos", count: viewModel.fixedExpenses.count, icon: "calendar.badge.clock")
                                if viewModel.financialSummary.isProUser && !viewModel.chatMessages.isEmpty {
                                    metricBadge(title: "Chat IA", count: viewModel.chatMessages.count, icon: "sparkles")
                                }
                            }
                        }
                        .padding(16)
                        .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 16))
                        .padding(.horizontal, 20)
                        
                        // Botones inferiores: Copiar y Compartir
                        HStack(spacing: 12) {
                            // Botón Copiar al Portapapeles
                            Button {
                                copyToClipboard()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                                        .font(.system(size: 15, weight: .bold))
                                    Text(isCopied ? "¡Copiado!" : "Copiar Respaldo")
                                        .font(.system(size: 15, weight: .bold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(isCopied ? AppColors.incomeEmerald : AppColors.darkNavySurface)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            
                            // Botón Compartir Archivo
                            Button {
                                shareBackupFile()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.up.fill")
                                        .font(.system(size: 15, weight: .bold))
                                    Text("Compartir")
                                        .font(.system(size: 15, weight: .bold))
                                }
                                .foregroundStyle(activeTheme == .electricBlack ? Color.black : Color.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(
                                        colors: activeTheme == .electricBlack ? [Color.white, Color(hex: "#CBD5E1")] : activeTheme.gradient,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: (activeTheme == .electricBlack ? Color.white : activeTheme.primary).opacity(0.35), radius: 6, x: 0, y: 2)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Guardar Datos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") {
                        onDismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.primary)
                }
            }
            .onAppear {
                jsonString = viewModel.getExportDataJson()
            }
        }
        .presentationDetents([.height(440)])
        .presentationDragIndicator(.visible)
    }
    
    private func metricBadge(title: String, count: Int, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(activeTheme == .electricBlack ? Color(hex: "#38BDF8") : activeTheme.primary)
            Text("\(count)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = jsonString
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                isCopied = false
            }
        }
    }
    
    private func shareBackupFile() {
        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("MoneyDev_Backup_\(Int(Date().timeIntervalSince1970)).json")
        do {
            try jsonString.write(to: tempUrl, atomically: true, encoding: .utf8)
            ShareSheetPresenter.present(items: [tempUrl])
        } catch {
            UIPasteboard.general.string = jsonString
        }
    }
}
