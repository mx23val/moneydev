import SwiftUI

public struct VoiceAssistantDialog: View {
    @Bindable var viewModel: ExpenseViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var showSpeechPermissionAlert: Bool = false
    @State private var selectedWalletScopeId: Int64? = nil
    @State private var speechService = SpeechRecognitionService.shared
    @State private var showClearConfirmation: Bool = false
    @State private var isLiveVoiceModeOpen: Bool = false
    @State private var showScrollToBottom: Bool = false
    @State private var unreadCountWhileScrolledUp: Int = 0
    @State private var isAutoScrollingToBottom: Bool = false
    @State private var messageToDelete: FinancialChatMessage? = nil
    @State private var currentVisibleDate: Date = Date()
    
    private let quickSuggestions = [
        "¿Cuánto saldo tengo?",
        "¿En qué categoría gasté más?",
        "Mayores gastos",
        "Consejos de ahorro"
    ]
    
    private var displayItems: [ChatMessageDisplayItem] {
        let calendar = Calendar.autoupdatingCurrent
        var items: [ChatMessageDisplayItem] = []
        items.reserveCapacity(viewModel.chatMessages.count)
        var previousDate: Date? = nil
        
        for message in viewModel.chatMessages {
            let showDivider: Bool
            if let prev = previousDate {
                showDivider = !calendar.isDate(message.timestamp, inSameDayAs: prev)
            } else {
                showDivider = true
            }
            previousDate = message.timestamp
            
            let dateStr = showDivider ? FormatHelper.formatChatDateFloating(message.timestamp) : ""
            let timeStr = FormatHelper.formatChatMessageTime(message.timestamp)
            
            let text = message.text
            let key: LocalizedStringKey
            if text.contains("***") {
                let clean = text
                    .replacingOccurrences(of: "****", with: "")
                    .replacingOccurrences(of: "***", with: "**")
                key = LocalizedStringKey(clean)
            } else {
                key = LocalizedStringKey(text)
            }
            
            items.append(
                ChatMessageDisplayItem(
                    id: message.id,
                    message: message,
                    showDayDivider: showDivider,
                    dividerDateString: dateStr,
                    formattedTime: timeStr,
                    formattedTextKey: key
                )
            )
        }
        return items
    }
    
    public init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                ThemedModalBackground(theme: viewModel.activeTheme)
                
                VStack(spacing: 0) {
                    // Scope Selector Header (Billetera específica o Todas)
                    HStack {
                        HStack(spacing: 5) {
                            Image(systemName: "wallet.pass.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(viewModel.activeTheme == .electricBlack ? Color(hex: "#F59E0B") : viewModel.activeTheme.primary)
                            Text("Billetera:")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.85))
                                .contrastTextOutline()
                        }
                        
                        Menu {
                            Button {
                                selectedWalletScopeId = nil
                            } label: {
                                Label("Todas las billeteras", systemImage: selectedWalletScopeId == nil ? "checkmark" : "")
                            }
                            
                            ForEach(viewModel.wallets) { w in
                                Button {
                                    selectedWalletScopeId = w.id
                                } label: {
                                    Label(w.name, systemImage: selectedWalletScopeId == w.id ? "checkmark" : "")
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Text(selectedWalletScopeName)
                                    .font(.system(size: 12.5, weight: .bold))
                                    .lineLimit(1)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9.5, weight: .bold))
                            }
                            .foregroundStyle(walletScopeButtonTextColor)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(
                                        viewModel.activeTheme == .electricBlack ?
                                            Color(hex: "#1E1E24") :
                                            viewModel.activeTheme.primary
                                    )
                            )
                            .overlay(
                                Capsule()
                                    .stroke(walletScopeButtonStrokeColor, lineWidth: 1.0)
                            )
                            .shadow(
                                color: viewModel.activeTheme == .electricBlack ?
                                    Color.white.opacity(0.08) :
                                    viewModel.activeTheme.primary.opacity(0.35),
                                radius: 4, x: 0, y: 1
                            )
                        }
                        
                        Spacer()
                        
                        Button {
                            showClearConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.70))
                                .contrastTextOutline()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        viewModel.activeTheme == .electricBlack ?
                            Color(hex: "#101014") :
                            Color.black.opacity(0.25)
                    )
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(
                                viewModel.activeTheme == .electricBlack ?
                                    Color.white.opacity(0.14) :
                                    Color.clear
                            ),
                        alignment: .bottom
                    )
                    
                    // Messages List
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(displayItems) { item in
                                    if item.showDayDivider {
                                        dayDividerBadge(title: item.dividerDateString)
                                    }
                                    
                                    ChatBubbleView(
                                        item: item,
                                        activeTheme: viewModel.activeTheme,
                                        onCopy: {
                                            UIPasteboard.general.string = item.message.text
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            viewModel.showFloatingToast(title: "Copiado", message: "Mensaje copiado al portapapeles", isSuccess: true, duration: 2.0)
                                        },
                                        onDelete: {
                                            messageToDelete = item.message
                                        }
                                    )
                                    .id(item.id)
                                }
                                
                                if viewModel.isAiProcessing {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 5) {
                                            HStack(spacing: 5) {
                                                Image(systemName: "sparkles")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundStyle(viewModel.activeTheme == .electricBlack ? Color(hex: "#F59E0B") : viewModel.activeTheme.primary)
                                                Text("MoneyBot")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(viewModel.activeTheme == .electricBlack ? Color.white : viewModel.activeTheme.primary)
                                                    .contrastTextOutline()
                                            }
                                            
                                            MessengerTypingBubbleView(activeTheme: viewModel.activeTheme)
                                        }
                                        .frame(maxWidth: 300, alignment: .leading)
                                        
                                        Spacer()
                                    }
                                    .id("typing_indicator")
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.92, anchor: .bottomLeading).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                                }
                                
                                Color.clear
                                    .frame(height: 1)
                                    .id("bottom_anchor")
                            }
                            .padding(16)
                        }
                        .scrollIndicators(.automatic)
                        .overlay(alignment: .top) {
                            if !viewModel.chatMessages.isEmpty {
                                floatingDateHeader
                                    .padding(.top, 8)
                            }
                        }
                        .onScrollGeometryChange(for: Bool.self) { geo in
                            let contentHeight = geo.contentSize.height
                            let containerHeight = geo.containerSize.height
                            guard contentHeight > containerHeight + 40 else { return false }
                            let bottomOffset = geo.contentOffset.y + containerHeight
                            let distanceRemaining = contentHeight - bottomOffset
                            return distanceRemaining > 90
                        } action: { _, isScrolledUp in
                            guard !isInputFocused else { return }
                            if isAutoScrollingToBottom {
                                if !isScrolledUp {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                        showScrollToBottom = false
                                        unreadCountWhileScrolledUp = 0
                                    }
                                }
                                return
                            }
                            
                            if showScrollToBottom != isScrolledUp {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    showScrollToBottom = isScrolledUp
                                    if !isScrolledUp {
                                        unreadCountWhileScrolledUp = 0
                                    }
                                }
                            }
                        }
                        .overlay(alignment: .bottomTrailing) {
                            if showScrollToBottom {
                                scrollToBottomButton(proxy: proxy)
                                    .padding(.trailing, 16)
                                    .padding(.bottom, 10)
                                    .transition(
                                        .asymmetric(
                                            insertion: .scale(scale: 0.65).combined(with: .opacity),
                                            removal: .scale(scale: 0.65).combined(with: .opacity)
                                        )
                                    )
                            }
                        }
                        .onChange(of: viewModel.chatMessages.count) { _, _ in
                            guard let last = viewModel.chatMessages.last else { return }
                            currentVisibleDate = last.timestamp
                            
                            if last.isUser {
                                // El usuario envió mensaje o pulsó una sugerencia rápida:
                                // Acompañar siempre hacia abajo sin mostrar flecha
                                showScrollToBottom = false
                                unreadCountWhileScrolledUp = 0
                                triggerScrollToBottom(proxy: proxy)
                            } else {
                                // Mensaje recibido de MoneyBot
                                if !showScrollToBottom {
                                    // El usuario ya estaba al fondo viendo la conversación:
                                    // Desplazar automáticamente hacia el nuevo mensaje sin mostrar flecha ni badge
                                    showScrollToBottom = false
                                    unreadCountWhileScrolledUp = 0
                                    triggerScrollToBottom(proxy: proxy)
                                } else {
                                    // El usuario está arriba leyendo mensajes pasados:
                                    // No interrumpir su lectura, solo marcar el badge de mensaje no leído
                                    unreadCountWhileScrolledUp += 1
                                }
                            }
                        }
                        .onChange(of: viewModel.isAiProcessing) { _, isProcessing in
                            if isProcessing && !showScrollToBottom {
                                triggerScrollToBottom(proxy: proxy)
                            }
                        }
                        .onChange(of: viewModel.chatMessages.isEmpty) { _, isEmpty in
                            if isEmpty {
                                showScrollToBottom = false
                                unreadCountWhileScrolledUp = 0
                            }
                        }
                        .onChange(of: isInputFocused) { _, focused in
                            if focused {
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 120_000_000)
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        proxy.scrollTo("bottom_anchor", anchor: .bottom)
                                    }
                                }
                            }
                        }
                        .onAppear {
                            if let lastMsg = viewModel.chatMessages.last {
                                currentVisibleDate = lastMsg.timestamp
                            }
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 80_000_000)
                                proxy.scrollTo("bottom_anchor", anchor: .bottom)
                            }
                        }
                    }
                    
                    // Suggestions horizontal row
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickSuggestions, id: \.self) { sug in
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    if speechService.isRecording {
                                        speechService.stopRecording()
                                    }
                                    speechService.reset()
                                    inputText = ""
                                    viewModel.sendUserChatMessage(
                                        prompt: sug,
                                        targetWalletId: selectedWalletScopeId,
                                        scopeToAllWallets: selectedWalletScopeId == nil
                                    )
                                } label: {
                                    Text(sug)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.white)
                                        .contrastTextOutline()
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(
                                                    viewModel.activeTheme == .electricBlack ?
                                                        Color(hex: "#1A1A20") :
                                                        viewModel.activeTheme.primary.opacity(0.18)
                                                )
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(
                                                    viewModel.activeTheme == .electricBlack ?
                                                        Color.white.opacity(0.18) :
                                                        viewModel.activeTheme.primary.opacity(0.35),
                                                    lineWidth: 1.0
                                                )
                                        )
                                        .shadow(
                                            color: viewModel.activeTheme == .electricBlack ?
                                                Color.black.opacity(0.4) :
                                                Color.black.opacity(0.2),
                                            radius: 3, x: 0, y: 1
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    
                    // Input bar container con fondo y contraste dedicados
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkle.magnifyingglass")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(
                                        viewModel.activeTheme == .electricBlack ?
                                            Color(hex: "#F59E0B") :
                                            viewModel.activeTheme.accentIconColor
                                    )
                                
                                TextField("Pregúntale a MoneyBot...", text: $inputText)
                                    .focused($isInputFocused)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.white)
                                    .contrastTextOutline()
                                    .submitLabel(.send)
                                    .onSubmit {
                                        sendMessage()
                                    }
                                
                                if !inputText.isEmpty {
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        inputText = ""
                                        speechService.reset()
                                        isInputFocused = true
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color.white.opacity(0.6))
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(
                                        viewModel.activeTheme == .electricBlack ?
                                            Color(hex: "#1E1E24") :
                                            Color.white.opacity(0.08)
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(
                                        viewModel.activeTheme == .electricBlack ?
                                            Color.white.opacity(0.20) :
                                            viewModel.activeTheme.primary.opacity(0.25),
                                        lineWidth: 1.0
                                    )
                            )
                            .shadow(
                                color: viewModel.activeTheme == .electricBlack ?
                                    Color.black.opacity(0.50) :
                                    Color.clear,
                                radius: 4, x: 0, y: 2
                            )
                            
                            // Mic Button
                            micButton
                            
                            // Send Button
                            sendButton
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 12)
                    }
                    .background(
                        viewModel.activeTheme == .electricBlack ?
                            Color(hex: "#101014") :
                            Color.black.opacity(0.40)
                    )
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(
                                viewModel.activeTheme == .electricBlack ?
                                    Color.white.opacity(0.16) :
                                    Color.white.opacity(0.08)
                            ),
                        alignment: .top
                    )
                }
            }
            .navigationTitle("MoneyBot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") {
                        speechService.stopRecording()
                        viewModel.closeVoiceAssistant()
                        dismiss()
                    }
                    .foregroundStyle(AppColors.textSecondary)
                    .contrastTextOutline()
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        inputText = ""
                        speechService.reset()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isLiveVoiceModeOpen = true
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "waveform.badge.mic")
                                .font(.system(size: 13, weight: .bold))
                            Text("Modo Voz")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(viewModel.activeTheme == .electricBlack ? Color.white : viewModel.activeTheme.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(viewModel.activeTheme.primary.opacity(0.18))
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    viewModel.activeTheme == .electricBlack ?
                                        Color.white.opacity(0.25) :
                                        viewModel.activeTheme.primary.opacity(0.40),
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: viewModel.activeTheme.primary.opacity(0.25),
                            radius: 4, x: 0, y: 1
                        )
                    }
                    .accessibilityLabel("Abrir Modo Voz Gemini Live")
                }
            }
            .onAppear {
                if selectedWalletScopeId == nil {
                    selectedWalletScopeId = viewModel.activeWallet?.id ?? viewModel.financialSummary.activeWalletId
                }
            }
            .onDisappear {
                speechService.stopRecording()
                speechService.reset()
            }
            .onChange(of: speechService.transcribedText) { _, newText in
                guard !isLiveVoiceModeOpen else { return }
                let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                if speechService.isRecording && !trimmed.isEmpty {
                    inputText = trimmed
                }
            }
            .alert("Permisos necesarios", isPresented: $showSpeechPermissionAlert) {
                Button("Abrir Ajustes") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancelar", role: .cancel) { }
            } message: {
                Text("MoneyBot necesita autorización para el micrófono y reconocimiento de voz para transcribir lo que digas. Puedes activarlos en Ajustes.")
            }
            .alert("¿Borrar conversación?", isPresented: $showClearConfirmation) {
                Button("Borrar", role: .destructive) {
                    viewModel.clearChatHistory()
                }
                Button("Cancelar", role: .cancel) { }
            } message: {
                Text("¿Estás seguro de que deseas eliminar todo el historial de mensajes de MoneyBot? Esta acción no se puede deshacer.")
            }
            .fullScreenCover(isPresented: $isLiveVoiceModeOpen) {
                MoneyBotLiveVoiceOverlay(
                    viewModel: viewModel,
                    selectedWalletScopeId: selectedWalletScopeId,
                    selectedWalletScopeName: selectedWalletScopeName,
                    onClose: {
                        inputText = ""
                        speechService.reset()
                        isLiveVoiceModeOpen = false
                    }
                )
            }
            .confirmationDialog(
                "¿Eliminar mensaje?",
                isPresented: Binding(
                    get: { messageToDelete != nil },
                    set: { if !$0 { messageToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Eliminar para mí", role: .destructive) {
                    if let msg = messageToDelete {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            viewModel.deleteChatMessage(id: msg.id)
                        }
                        messageToDelete = nil
                    }
                }
                Button("Cancelar", role: .cancel) {
                    messageToDelete = nil
                }
            } message: {
                Text("Este mensaje se eliminará de tu conversación con MoneyBot.")
            }
            .overlay(alignment: .top) {
                if let toast = viewModel.floatingToast {
                    FloatingToastView(toast: toast, theme: viewModel.activeTheme) {
                        withAnimation {
                            viewModel.floatingToast = nil
                        }
                    }
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(999)
                }
            }
        }
    }
    
    private var micButton: some View {
        Button {
            toggleAssistantVoice()
        } label: {
            ZStack {
                Circle()
                    .fill(micBackgroundGradient)
                    .frame(width: 38, height: 38)
                    .overlay(
                        Circle()
                            .stroke(micBorderColor, lineWidth: speechService.isRecording ? 1.5 : 1.0)
                    )
                    .shadow(color: micShadowColor, radius: speechService.isRecording ? 8 : 4, x: 0, y: 2)
                
                Image(systemName: speechService.isRecording ? "waveform" : "mic.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .symbolEffect(.variableColor.iterative, isActive: speechService.isRecording)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(speechService.isRecording ? "Detener dictado por voz" : "Dictar por voz")
    }
    
    private var micBackgroundGradient: LinearGradient {
        if speechService.isRecording {
            return LinearGradient(colors: [Color(hex: "#EF4444"), Color(hex: "#DC2626")], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if viewModel.activeTheme == .electricBlack {
            return LinearGradient(colors: [Color(hex: "#27272E"), Color(hex: "#1E1E24")], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            return LinearGradient(colors: viewModel.activeTheme.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private var micBorderColor: Color {
        if speechService.isRecording {
            return Color.white.opacity(0.40)
        } else if viewModel.activeTheme == .electricBlack {
            return Color.white.opacity(0.24)
        } else {
            return Color.white.opacity(0.15)
        }
    }
    
    private var micShadowColor: Color {
        if speechService.isRecording {
            return Color.red.opacity(0.50)
        } else if viewModel.activeTheme == .electricBlack {
            return Color.white.opacity(0.08)
        } else {
            return viewModel.activeTheme.primary.opacity(0.35)
        }
    }
    
    private var sendButton: some View {
        let isPromptEmpty = inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return Button {
            sendMessage()
        } label: {
            ZStack {
                Circle()
                    .fill(sendBackgroundGradient(isEmpty: isPromptEmpty))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Circle()
                            .stroke(isPromptEmpty ? Color.white.opacity(0.08) : Color.white.opacity(0.25), lineWidth: 1.0)
                    )
                
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(
                        isPromptEmpty ?
                            Color.white.opacity(0.3) :
                            (viewModel.activeTheme == .electricBlack ? Color.black : viewModel.activeTheme.onPrimaryText)
                    )
            }
        }
        .disabled(isPromptEmpty)
    }
    
    private func sendBackgroundGradient(isEmpty: Bool) -> LinearGradient {
        if isEmpty {
            return LinearGradient(colors: [Color.white.opacity(0.10), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom)
        } else if viewModel.activeTheme == .electricBlack {
            return LinearGradient(colors: [Color.white, Color(hex: "#E2E8F0")], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            return LinearGradient(colors: viewModel.activeTheme.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private func toggleAssistantVoice() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        TextToSpeechService.shared.stop(deactivateSession: false)
        
        if speechService.isRecording {
            speechService.stopRecording()
        } else {
            // Dismiss keyboard to allow comfortable voice dictation
            isInputFocused = false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            
            Task {
                let authorized = await speechService.requestPermissions()
                guard authorized else {
                    await MainActor.run {
                        showSpeechPermissionAlert = true
                    }
                    return
                }
                
                await speechService.startRecording()
                if let err = speechService.errorMessage {
                    await MainActor.run {
                        viewModel.showFloatingToast(title: "Micrófono", message: err, isSuccess: false)
                    }
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
    
    /// Color del texto del selector de billeteras calculado para máximo contraste (WCAG AAA) sobre cada tema
    private var walletScopeButtonTextColor: Color {
        switch viewModel.activeTheme {
        case .electricGreen, .electricYellow:
            return Color(hex: "#05110E") // Máximo contraste nítido sobre fondo fluorescente brillante
        case .electricBlue:
            return Color(hex: "#040D18") // Contraste oscuro óptimo sobre celeste eléctrico
        case .electricGray:
            return Color(hex: "#0F172A") // Contraste oscuro óptimo sobre gris claro
        case .electricOrange:
            return Color(hex: "#120500") // Contraste oscuro óptimo sobre naranja
        case .electricBlack, .electricPurple, .electricPink, .electricRed:
            return Color.white // Blanco puro nítido sobre fondos oscuros o intensos
        }
    }
    
    /// Borde perimetral fino que refuerza la definición del botón sin interferir con la legibilidad
    private var walletScopeButtonStrokeColor: Color {
        switch viewModel.activeTheme {
        case .electricGreen, .electricYellow, .electricBlue, .electricOrange, .electricGray:
            return Color.black.opacity(0.15)
        case .electricBlack:
            return Color.white.opacity(0.25)
        default:
            return Color.white.opacity(0.25)
        }
    }
    
    private func sendMessage() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        // 1. Detener servicio de voz si estaba grabando
        if speechService.isRecording {
            speechService.stopRecording()
        }
        speechService.reset()
        
        // 2. Extraer texto limpio
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // 3. Limpiar inmediatamente el texto para que la caja quede completamente vacía
        inputText = ""
        
        // 4. Asegurar limpieza en el ciclo principal
        DispatchQueue.main.async {
            inputText = ""
        }
        
        // 5. Enviar mensaje a MoneyBot
        viewModel.sendUserChatMessage(
            prompt: text,
            targetWalletId: selectedWalletScopeId,
            scopeToAllWallets: selectedWalletScopeId == nil
        )
    }
    
    // MARK: - Botón Flotante Bajar al Fondo (Tipo Messenger)
    private func triggerScrollToBottom(proxy: ScrollViewProxy) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        // Ocultar inmediatamente el botón con animación limpia
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            showScrollToBottom = false
            unreadCountWhileScrolledUp = 0
        }
        
        isAutoScrollingToBottom = true
        
        // 1. Ejecución inmediata hacia el fondo
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            proxy.scrollTo("bottom_anchor", anchor: .bottom)
            if viewModel.isAiProcessing {
                proxy.scrollTo("typing_indicator", anchor: .bottom)
            } else if let lastId = viewModel.chatMessages.last?.id {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                proxy.scrollTo("bottom_anchor", anchor: .bottom)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isAutoScrollingToBottom = false
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                showScrollToBottom = false
                unreadCountWhileScrolledUp = 0
            }
        }
    }
    
    private func scrollToBottomButton(proxy: ScrollViewProxy) -> some View {
        Button {
            triggerScrollToBottom(proxy: proxy)
        } label: {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Circle()
                        .fill(scrollToBottomBackground)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(scrollToBottomBorderColor, lineWidth: 1.2)
                        )
                        .shadow(
                            color: scrollToBottomShadowColor,
                            radius: 6, x: 0, y: 3
                        )
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(scrollToBottomIconColor)
                }
                
                if unreadCountWhileScrolledUp > 0 {
                    Text(unreadCountWhileScrolledUp > 9 ? "9+" : "\(unreadCountWhileScrolledUp)")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(viewModel.activeTheme == .electricBlack ? Color.black : Color.white)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(
                            Capsule()
                                .fill(viewModel.activeTheme == .electricBlack ? Color(hex: "#F59E0B") : viewModel.activeTheme.primary)
                        )
                        .offset(x: 4, y: -4)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(BouncyButtonStyle())
        .accessibilityLabel("Bajar al mensaje más reciente")
    }
    
    private var scrollToBottomBackground: LinearGradient {
        if viewModel.activeTheme == .electricBlack {
            return LinearGradient(
                colors: [Color(hex: "#24242A"), Color(hex: "#18181D")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color(hex: "#16233B"), Color(hex: "#0E182A")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var scrollToBottomBorderColor: Color {
        if viewModel.activeTheme == .electricBlack {
            return Color.white.opacity(0.24)
        } else {
            return viewModel.activeTheme.primary.opacity(0.48)
        }
    }
    
    private var scrollToBottomShadowColor: Color {
        if viewModel.activeTheme == .electricBlack {
            return Color.black.opacity(0.65)
        } else {
            return viewModel.activeTheme.primary.opacity(0.35)
        }
    }
    
    private var scrollToBottomIconColor: Color {
        if viewModel.activeTheme == .electricBlack {
            return Color.white
        } else {
            return viewModel.activeTheme.primary
        }
    }
    
    // MARK: - Encabezado Flotante de Fecha (Estilo WhatsApp: Hoy, Ayer, Fecha Pasada)
    private var floatingDateHeader: some View {
        Text(FormatHelper.formatChatDateFloating(currentVisibleDate))
            .font(.system(size: 11.5, weight: .bold))
            .foregroundStyle(Color.white.opacity(0.95))
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.65))
                    .background(.ultraThinMaterial)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.40), radius: 5, x: 0, y: 2)
            .contrastTextOutline(color: Color.black.opacity(0.7), radius: 0.6)
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.22), value: currentVisibleDate)
    }
    
    private func dayDividerBadge(title: String) -> some View {
        HStack {
            Spacer()
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.42))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                )
                .contrastTextOutline(color: Color.black.opacity(0.7), radius: 0.5)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Bouncy Button Style
private struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Chat Display Item Model
public struct ChatMessageDisplayItem: Identifiable, Equatable {
    public let id: UUID
    public let message: FinancialChatMessage
    public let showDayDivider: Bool
    public let dividerDateString: String
    public let formattedTime: String
    public let formattedTextKey: LocalizedStringKey
    
    public static func == (lhs: ChatMessageDisplayItem, rhs: ChatMessageDisplayItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.message.text == rhs.message.text &&
        lhs.message.timestamp == rhs.message.timestamp &&
        lhs.message.isUser == rhs.message.isUser &&
        lhs.showDayDivider == rhs.showDayDivider
    }
}

// MARK: - Chat Bubble View
struct ChatBubbleView: View {
    let item: ChatMessageDisplayItem
    let activeTheme: AppColorTheme
    var onCopy: () -> Void = {}
    var onDelete: () -> Void = {}
    
    private var message: FinancialChatMessage { item.message }
    
    @ViewBuilder
    private var bubbleBackground: some View {
        if message.isUser {
            if activeTheme == .electricBlack {
                LinearGradient(
                    colors: [Color(hex: "#26262B"), Color(hex: "#1E1E22")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [
                        activeTheme.primary.opacity(0.35),
                        activeTheme.primary.opacity(0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        } else {
            if activeTheme == .electricBlack {
                LinearGradient(
                    colors: [Color(hex: "#18181D"), Color(hex: "#121216")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [
                        activeTheme.primary.opacity(0.14),
                        activeTheme.secondary.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
    
    private var textColor: Color {
        if message.isUser {
            return Color.white
        } else {
            return activeTheme == .electricBlack ? Color(hex: "#F4F4F5") : AppColors.textPrimary
        }
    }
    
    private var strokeColor: Color {
        if message.isUser {
            if activeTheme == .electricBlack {
                return Color.white.opacity(0.25)
            } else {
                return activeTheme.primary.opacity(0.70)
            }
        } else {
            if activeTheme == .electricBlack {
                return Color.white.opacity(0.16)
            } else {
                return Color.white.opacity(0.12)
            }
        }
    }
    
    private var shadowColor: Color {
        if message.isUser {
            if activeTheme == .electricBlack {
                return Color.white.opacity(0.06)
            } else {
                return activeTheme.primary.opacity(0.28)
            }
        } else if activeTheme == .electricBlack {
            return Color.black.opacity(0.70)
        } else {
            return Color.black.opacity(0.25)
        }
    }
    
    private var timeText: some View {
        Text(item.formattedTime)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.52))
            .contrastTextOutline(color: Color.black.opacity(0.7), radius: 0.5)
            .padding(.bottom, 2)
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if message.isUser {
                Spacer(minLength: 20)
                timeText
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 5) {
                if !message.isUser {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(activeTheme == .electricBlack ? Color(hex: "#F59E0B") : activeTheme.primary)
                        Text("MoneyBot")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.primary)
                            .contrastTextOutline()
                    }
                }
                
                Text(item.formattedTextKey)
                    .font(.system(size: 14.5, weight: message.isUser ? .semibold : .medium))
                    .foregroundStyle(textColor)
                    .contrastTextOutline(
                        color: Color.black.opacity(0.85),
                        radius: 0.8
                    )
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(strokeColor, lineWidth: 1.0)
                    )
                    .shadow(color: shadowColor, radius: activeTheme == .electricBlack ? 6 : 3, x: 0, y: 2)
                    .contextMenu {
                        Button {
                            onCopy()
                        } label: {
                            Label("Copiar texto", systemImage: "doc.on.doc")
                        }
                        
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Eliminar mensaje", systemImage: "trash")
                        }
                    }
            }
            .frame(maxWidth: 290, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser {
                timeText
                Spacer(minLength: 20)
            }
        }
    }
}

// MARK: - Messenger Typing Indicator (3 Bouncing Dots)
struct MessengerTypingBubbleView: View {
    let activeTheme: AppColorTheme
    
    @ViewBuilder
    private var bubbleBackground: some View {
        if activeTheme == .electricBlack {
            LinearGradient(
                colors: [Color(hex: "#18181D"), Color(hex: "#121216")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            LinearGradient(
                colors: [
                    activeTheme.primary.opacity(0.14),
                    activeTheme.secondary.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var strokeColor: Color {
        if activeTheme == .electricBlack {
            return Color.white.opacity(0.16)
        } else {
            return Color.white.opacity(0.12)
        }
    }
    
    private var shadowColor: Color {
        if activeTheme == .electricBlack {
            return Color.black.opacity(0.70)
        } else {
            return Color.black.opacity(0.25)
        }
    }
    
    private var dotColor: Color {
        if activeTheme == .electricBlack {
            return Color(hex: "#F59E0B")
        } else {
            return activeTheme.primary
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            MessengerBouncingDot(delay: 0.0, color: dotColor)
            MessengerBouncingDot(delay: 0.18, color: dotColor)
            MessengerBouncingDot(delay: 0.36, color: dotColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(bubbleBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(strokeColor, lineWidth: 1.0)
        )
        .shadow(color: shadowColor, radius: activeTheme == .electricBlack ? 6 : 3, x: 0, y: 2)
    }
}

struct MessengerBouncingDot: View {
    let delay: Double
    let color: Color
    @State private var isBouncing = false
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .offset(y: isBouncing ? -5.5 : 2.5)
            .opacity(isBouncing ? 1.0 : 0.35)
            .scaleEffect(isBouncing ? 1.15 : 0.85)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.48)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    isBouncing = true
                }
            }
    }
}
