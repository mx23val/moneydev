import SwiftUI

public struct DirectVoiceDictationDialog: View {
    @Bindable var viewModel: ExpenseViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var spokenText: String = ""
    @State private var isProcessing: Bool = false
    @State private var statusMessage: String? = nil
    @State private var isSuccess: Bool = false
    @State private var isPulsing: Bool = false
    
    public init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AppColors.midnightBlack.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    // Mic Pulse Circle Animation
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#38BDF8").opacity(0.15))
                            .frame(width: isPulsing ? 130 : 100, height: isPulsing ? 130 : 100)
                            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
                        
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#00D2FF"), Color(hex: "#1D4ED8")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .shadow(color: Color(hex: "#00D2FF").opacity(0.5), radius: 12)
                        
                        Image(systemName: "mic.fill")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .onAppear {
                        isPulsing = true
                    }
                    
                    VStack(spacing: 6) {
                        Text("Dictado por Voz Inteligente")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                        
                        Text("Di lo que gastaste o ganaste y MoneyDev lo registrará al instante.")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    // Text Input / Speech recognition fallback
                    VStack(spacing: 10) {
                        TextField("Ej: Gasté 25 soles en comida...", text: $spokenText)
                            .font(.system(size: 15))
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(14)
                            .background(AppColors.darkNavySurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(AppColors.cardBorderNavy, lineWidth: 1)
                            )
                        
                        // Example chips
                        HStack(spacing: 6) {
                            exampleChip("Gasté 35 en taxi")
                            exampleChip("Sueldo 2500")
                            exampleChip("Cena 60")
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    if let statusMessage {
                        HStack(spacing: 8) {
                            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(isSuccess ? AppColors.incomeEmeraldLight : AppColors.expenseRoseLight)
                            
                            Text(statusMessage)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(isSuccess ? AppColors.incomeEmeraldLight : AppColors.expenseRoseLight)
                        }
                        .padding(12)
                        .background((isSuccess ? AppColors.incomeEmerald : AppColors.expenseRose).opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                    
                    // Button to process
                    Button {
                        processInput()
                    } label: {
                        HStack(spacing: 8) {
                            if isProcessing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            Text(isProcessing ? "Procesando..." : "Registrar Ahora")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#00D2FF"), Color(hex: "#1D4ED8")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isProcessing || spokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("Dictado Inteligente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func exampleChip(_ text: String) -> some View {
        Button {
            spokenText = text
        } label: {
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppColors.darkNavySurface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppColors.cardBorderNavy, lineWidth: 1))
        }
    }
    
    private func processInput() {
        let text = spokenText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        isProcessing = true
        statusMessage = nil
        
        Task {
            let (success, message) = await viewModel.processDirectVoiceTransaction(spokenText: text)
            isProcessing = false
            isSuccess = success
            statusMessage = message
            
            if success {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                dismiss()
            }
        }
    }
}
