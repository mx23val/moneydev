import SwiftUI

public struct VoiceAssistantDialog: View {
    @Bindable var viewModel: ExpenseViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var inputText: String = ""
    @State private var selectedWalletScopeId: Int64? = nil
    
    private let quickSuggestions = [
        "¿Cuánto saldo tengo?",
        "¿En qué categoría gasté más?",
        "Mayores gastos",
        "Consejos de ahorro",
        "Gasté 25 en almuerzo",
        "Me pagaron 1500 de sueldo"
    ]
    
    public init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AppColors.midnightBlack.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Scope Selector Header (Billetera específica o Todas)
                    HStack {
                        Text("Consultando:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                        
                        Menu {
                            Button {
                                selectedWalletScopeId = nil
                            } label: {
                                HStack {
                                    Text("Todas las billeteras")
                                    if selectedWalletScopeId == nil { Image(systemName: "checkmark") }
                                }
                            }
                            
                            ForEach(viewModel.wallets) { w in
                                Button {
                                    selectedWalletScopeId = w.id
                                } label: {
                                    HStack {
                                        Text(w.name)
                                        if selectedWalletScopeId == w.id { Image(systemName: "checkmark") }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(selectedWalletScopeName)
                                    .font(.system(size: 12, weight: .bold))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(Color(hex: "#38BDF8"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.darkNavySurface)
                            .clipShape(Capsule())
                        }
                        
                        Spacer()
                        
                        Button {
                            viewModel.clearChatHistory()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                                .foregroundStyle(AppColors.textMuted)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppColors.darkNavySurface.opacity(0.5))
                    
                    // Messages List
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.chatMessages) { message in
                                    ChatBubbleView(message: message)
                                        .id(message.id)
                                }
                                
                                if viewModel.isAiProcessing {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .tint(Color(hex: "#38BDF8"))
                                        Text("MoneyBot está pensando...")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(AppColors.textSecondary)
                                    }
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id("thinking")
                                }
                            }
                            .padding(16)
                        }
                        .onChange(of: viewModel.chatMessages.count) { _, _ in
                            if let last = viewModel.chatMessages.last {
                                withAnimation {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    // Suggestions horizontal row
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickSuggestions, id: \.self) { sug in
                                Button {
                                    viewModel.sendUserChatMessage(prompt: sug, targetWalletId: selectedWalletScopeId)
                                } label: {
                                    Text(sug)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(AppColors.textPrimary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(AppColors.darkNavySurface)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(AppColors.cardBorderNavy, lineWidth: 1))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    
                    // Input bar
                    HStack(spacing: 10) {
                        TextField("Pregúntale a MoneyBot...", text: $inputText)
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(AppColors.darkNavySurface)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(AppColors.cardBorderNavy, lineWidth: 1)
                            )
                            .onSubmit {
                                sendMessage()
                            }
                        
                        Button {
                            sendMessage()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(
                                    inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                                    AppColors.textMuted : Color(hex: "#38BDF8")
                                )
                        }
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppColors.midnightBlack)
                }
            }
            .navigationTitle("MoneyBot • Asistente IA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") {
                        viewModel.closeVoiceAssistant()
                        dismiss()
                    }
                    .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }
    
    private var selectedWalletScopeName: String {
        if let id = selectedWalletScopeId, let w = viewModel.wallets.first(where: { $0.id == id }) {
            return w.name
        }
        return "Todas las billeteras"
    }
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        viewModel.sendUserChatMessage(prompt: text, targetWalletId: selectedWalletScopeId)
    }
}

// MARK: - Chat Bubble View
struct ChatBubbleView: View {
    let message: FinancialChatMessage
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                if !message.isUser {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "#38BDF8"))
                        Text("MoneyBot")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(hex: "#38BDF8"))
                    }
                }
                
                Text(message.text)
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.isUser ?
                        Color(hex: "#1D4ED8") :
                        (message.isRegisteredMovement ? AppColors.incomeEmerald.opacity(0.25) : AppColors.darkNavySurface)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                message.isRegisteredMovement ? AppColors.incomeEmerald.opacity(0.6) : AppColors.cardBorderNavy,
                                lineWidth: 1
                            )
                    )
            }
            .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser { Spacer() }
        }
    }
}
