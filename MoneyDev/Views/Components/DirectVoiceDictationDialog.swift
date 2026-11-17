import SwiftUI

public struct DirectVoiceDictationDialog: View {
    @Bindable var viewModel: ExpenseViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var speechService = SpeechRecognitionService.shared
    @State private var spokenText: String = ""
    @State private var isProcessing: Bool = false
    @State private var statusMessage: String? = nil
    @State private var isSuccess: Bool = false
    
    // Detección automática de fin de voz (3 segundos de silencio)
    @State private var silenceTask: Task<Void, Never>? = nil
    @State private var silenceSecondsLeft: Int = 3
    @State private var isSilenceCountdownActive: Bool = false
    @Binding var currentDetent: PresentationDetent
    
    private var activeTheme: AppColorTheme {
        viewModel.activeTheme
    }
    
    public init(viewModel: ExpenseViewModel, currentDetent: Binding<PresentationDetent>? = nil) {
        self.viewModel = viewModel
        self._currentDetent = currentDetent ?? .constant(.fraction(0.58))
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                ThemedModalBackground(theme: activeTheme)
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 12) {
                            // Mic visualizer area
                            micVisualizerSection
                                .padding(.top, 6)
                                
                                // Header instructions
                                VStack(spacing: 4) {
                                    Text(speechService.isRecording ? "Escuchando..." : "Dictado por Voz")
                                        .font(.system(size: 20, weight: .black))
                                        .foregroundStyle(Color.white)
                                        .contrastTextOutline()
                                    
                                    Text(speechService.isRecording ? 
                                         "Di tu gasto o ingreso (ej: 'Gasté 25 soles en comida')" : 
                                         "Toca el micrófono para hablar o escribe tu movimiento.")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.85))
                                        .contrastTextOutline()
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 20)
                                }
                                
                                // Live Audio Waveform / Level Meter
                                if speechService.isRecording {
                                    audioWaveformBar
                                        .padding(.vertical, 2)
                                }
                                
                                // Banner indicador de fin de voz / cuenta regresiva de 3 segundos
                                if isSilenceCountdownActive && speechService.isRecording && !spokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    HStack(spacing: 8) {
                                        Image(systemName: "clock.badge.checkmark.fill")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(activeTheme.accentIconColor)
                                        
                                        Text("Silencio detectado... registrando en \(silenceSecondsLeft)s")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(Color.white)
                                            .contrastTextOutline()
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 16))
                                    .shadow(color: Color.black.opacity(0.35), radius: 4, x: 0, y: 2)
                                    .padding(.horizontal, 16)
                                    .transition(.opacity.combined(with: .scale))
                                }
                                
                                // Permission alert if denied
                                if speechService.permissionDenied {
                                    permissionDeniedCard
                                }
                                
                                // Transcribed / Input Box expandida verticalmente
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(speechService.isRecording ? "Transcripción en vivo:" : "Texto registrado:")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentTextColor)
                                            .contrastTextOutline()
                                        
                                        Spacer()
                                        
                                        Text("\(spokenText.count)/120")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(spokenText.count >= 120 ? Color(hex: "#FF453A") : AppColors.textMuted)
                                            .contrastTextOutline()
                                        
                                        if !spokenText.isEmpty {
                                            Button {
                                                spokenText = ""
                                                speechService.reset()
                                                statusMessage = nil
                                            } label: {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "trash.fill")
                                                        .font(.system(size: 11, weight: .bold))
                                                    Text("Borrar")
                                                        .font(.system(size: 12, weight: .bold))
                                                }
                                                .foregroundStyle(Color.white)
                                                .contrastTextOutline()
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 8))
                                                .clipShape(Capsule())
                                                .shadow(
                                                    color: activeTheme == .electricBlack ?
                                                        Color.white.opacity(0.12) :
                                                        activeTheme.primary.opacity(0.35),
                                                    radius: 4, x: 0, y: 1
                                                )
                                            }
                                            .padding(.leading, 6)
                                        }
                                    }
                                    
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "quote.opening")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(activeTheme.accentIconColor)
                                        
                                        TextField("Habla o escribe aquí...", text: $spokenText, axis: .vertical)
                                            .lineLimit(2...4)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(Color.white)
                                            .contrastTextOutline()
                                            .submitLabel(.done)
                                            .onSubmit {
                                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                            }
                                            .onChange(of: spokenText) { _, newValue in
                                                if newValue.contains("\n") {
                                                    spokenText = newValue.replacingOccurrences(of: "\n", with: "")
                                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                                    return
                                                }
                                                handleTextChange(newValue)
                                            }
                                    }
                                    .padding(12)
                                    .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 14))
                                    .shadow(color: Color.black.opacity(0.35), radius: 5, x: 0, y: 2)
                                }
                                .padding(.horizontal, 16)
                                .id("transcriptionBox")
                                
                                // Advertencia de 120 Caracteres Llamativa o Mensaje de Estado
                                if spokenText.count >= 120 {
                                    HStack(alignment: .center, spacing: 10) {
                                        Image(systemName: "exclamationmark.octagon.fill")
                                            .font(.system(size: 20, weight: .black))
                                            .foregroundStyle(Color(hex: "#FF453A"))
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("LÍMITE DE 120 CARACTERES ALCANZADO")
                                                .font(.system(size: 12, weight: .black))
                                                .foregroundStyle(Color(hex: "#FF453A"))
                                                .contrastTextOutline(color: Color.black.opacity(0.95), radius: 0.8)
                                            
                                            Text("Has llegado al límite. Presiona 'Cancelar' para reiniciar y registrar tu movimiento por partes.")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(Color.white)
                                                .contrastTextOutline(color: Color.black.opacity(0.95), radius: 0.8)
                                                .lineLimit(nil)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(hex: "#380D17"))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: Color(hex: "#FF453A").opacity(0.40), radius: 6, x: 0, y: 2)
                                    .padding(.horizontal, 16)
                                    .id("charLimitWarning")
                                } else if let statusMessage {
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(isSuccess ? AppColors.incomeEmeraldLight : AppColors.expenseRoseLight)
                                        
                                        Text(statusMessage)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(isSuccess ? AppColors.incomeEmeraldLight : AppColors.expenseRoseLight)
                                            .contrastTextOutline()
                                            .lineLimit(nil)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background((isSuccess ? AppColors.incomeEmerald : AppColors.expenseRose).opacity(0.22))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: Color.black.opacity(0.35), radius: 4, x: 0, y: 2)
                                    .padding(.horizontal, 16)
                                    .id("statusMessage")
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        .scrollIndicators(.hidden)
                    
                    // BOTÓN DE ACCIÓN FIJO EN LA BASE (Permanece en su lugar sin desplazarse hacia abajo)
                    VStack(spacing: 0) {
                        if spokenText.count >= 120 {
                            Button {
                                cancelAndResetDictation()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("Cancelar Dictado")
                                        .font(.system(size: 16, weight: .black))
                                }
                                .foregroundStyle(Color.white)
                                .contrastTextOutline()
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: "#EF4444"), Color(hex: "#DC2626")],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                                .shadow(color: Color(hex: "#EF4444").opacity(0.40), radius: 6, x: 0, y: 2)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 12)
                        } else if let statusMessage, !isSuccess {
                            // Cuando no se detecta ningún gasto, ingreso o movimiento válido, se muestra "Intentar de nuevo"
                            Button {
                                retryDictation()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 16, weight: .black))
                                    Text("Intentar de nuevo")
                                        .font(.system(size: 16, weight: .black))
                                }
                                .foregroundStyle(Color.white)
                                .contrastTextOutline()
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: "#F59E0B"), Color(hex: "#D97706")],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                                .shadow(color: Color(hex: "#F59E0B").opacity(0.45), radius: 7, x: 0, y: 2)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 12)
                        } else {
                            Button {
                                processInput()
                            } label: {
                                HStack(spacing: 8) {
                                    if isProcessing {
                                        ProgressView()
                                            .tint(activeTheme == .electricBlack ? Color.black : .white)
                                    } else {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                    Text(isProcessing ? "Interpretando..." : "Registrar Movimiento")
                                        .font(.system(size: 16, weight: .black))
                                }
                                .foregroundStyle(activeTheme == .electricBlack ? Color.black : activeTheme.onPrimaryText)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: activeTheme == .electricBlack ? [Color.white, Color(hex: "#E2E8F0")] : activeTheme.gradient,
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                                .shadow(color: activeTheme.primary.opacity(spokenText.isEmpty ? 0 : 0.4), radius: 8, x: 0, y: 3)
                            }
                            .disabled(isProcessing || spokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .opacity(spokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 12)
                        }
                    }
                    .background(
                        Color.black.opacity(0.25)
                    )
                }
            }
            .navigationTitle("Dictado Inteligente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") {
                        speechService.stopRecording()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.white)
                    .contrastTextOutline()
                }
            }
        }
        .presentationDetents([.fraction(0.58)], selection: $currentDetent)
        .presentationDragIndicator(.hidden)
        .themedSheetContainer(theme: activeTheme)
        .keyboardDismissBlueCheck()
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear {
            // El micrófono de la pantalla principal únicamente escucha al usuario, nunca habla
            TextToSpeechService.shared.stop(deactivateSession: false)
            startListeningAutomatically()
        }
        .onDisappear {
            silenceTask?.cancel()
            speechService.stopRecording()
            TextToSpeechService.shared.stop(deactivateSession: false)
        }
        .onChange(of: speechService.transcribedText) { _, newText in
            if !newText.isEmpty {
                handleTextChange(newText)
                resetSilenceTimer()
            }
        }
        .onChange(of: speechService.isRecording) { _, isRecording in
            if !isRecording {
                silenceTask?.cancel()
                isSilenceCountdownActive = false
            }
        }
    }
    
    // MARK: - Control de límite de 120 caracteres y auto-apagado
    private func handleTextChange(_ newText: String) {
        if !isSuccess && statusMessage != nil && newText != spokenText {
            statusMessage = nil
        }
        
        if newText.count >= 120 {
            spokenText = String(newText.prefix(120))
            if speechService.isRecording {
                speechService.stopRecording()
            }
            silenceTask?.cancel()
            isSilenceCountdownActive = false
            isSuccess = false
        } else {
            spokenText = newText
        }
    }
    
    // MARK: - Mic Visualizer Section (Con Ondas Expansivas al Detectar Sonido)
    private var micVisualizerSection: some View {
        Button {
            toggleRecording()
        } label: {
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let isVoiceDetected = speechService.isRecording && speechService.audioLevel > 0.025
                let voiceLevel = Double(speechService.audioLevel)
                let isCompact = !spokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                
                let baseSize: CGFloat = isCompact ? 52.0 : 64.0
                let haloSize: CGFloat = isCompact ? 76.0 : 92.0
                let midSize: CGFloat = isCompact ? 64.0 : 78.0
                let iconSize: CGFloat = isCompact ? 20.0 : 26.0
                let sectionHeight: CGFloat = isCompact ? 74.0 : 98.0
                
                ZStack {
                    // Ondas de audio circulares que se expanden hacia afuera alrededor del círculo central al detectar voz
                    ForEach(0..<3, id: \.self) { ringIndex in
                        let phase = (time * 1.5 + Double(ringIndex) * 0.33).truncatingRemainder(dividingBy: 1.0)
                        let ringSize = baseSize + CGFloat(phase * (isCompact ? 28.0 : 40.0) + voiceLevel * (isCompact ? 16.0 : 22.0))
                        let ringOpacity = isVoiceDetected ? (1.0 - phase) * 0.80 * min(1.0, voiceLevel * 3.5) : 0.0
                        
                        Circle()
                            .stroke(
                                speechService.isRecording ?
                                    (activeTheme == .electricBlack ? Color.white : Color(hex: "#FF416C")) :
                                    activeTheme.primary,
                                lineWidth: max(1.2, CGFloat(2.5 * (1.0 - phase * 0.5)))
                            )
                            .frame(width: ringSize, height: ringSize)
                            .opacity(ringOpacity)
                    }
                    
                    // Halo de expansión de nivel de audio
                    Circle()
                        .fill(activeTheme.primary.opacity(speechService.isRecording ? (isVoiceDetected ? 0.22 : 0.10) : 0.05))
                        .frame(
                            width: haloSize + CGFloat(voiceLevel * (isCompact ? 22 : 32)),
                            height: haloSize + CGFloat(voiceLevel * (isCompact ? 22 : 32))
                        )
                        .animation(.easeOut(duration: 0.15), value: speechService.audioLevel)
                    
                    // Círculo intermedio con resplandor
                    Circle()
                        .fill(activeTheme.primary.opacity(speechService.isRecording ? (isVoiceDetected ? 0.36 : 0.16) : 0.08))
                        .frame(width: midSize, height: midSize)
                    
                    // Core Button Circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: speechService.isRecording ?
                                [Color(hex: "#FF416C"), Color(hex: "#FF4B2B")] :
                                activeTheme.gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: baseSize, height: baseSize)
                        .shadow(
                            color: (speechService.isRecording ? Color(hex: "#FF4B2B") : activeTheme.primary).opacity(0.55),
                            radius: isCompact ? 7 : 10,
                            x: 0,
                            y: isCompact ? 2 : 3
                        )
                    
                    // Mic Icon
                    Image(systemName: speechService.isRecording ? "waveform" : "mic.fill")
                        .font(.system(size: iconSize, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(height: sectionHeight)
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isCompact)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Audio Waveform Level Meter (Se mueve ÚNICAMENTE al escuchar voz)
    private var audioWaveformBar: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let isVoiceDetected = speechService.isRecording && speechService.audioLevel > 0.025
            let voiceActivity = isVoiceDetected ? Double(speechService.audioLevel) : 0.0
            
            HStack(spacing: 5) {
                ForEach(0..<9, id: \.self) { index in
                    let factor = 1.0 - abs(Double(index - 4)) / 4.0
                    // La onda oscila dinámicamente sólo si detecta voz activa; en silencio permanece quieta
                    let waveOffset = isVoiceDetected ? sin(time * 8.0 + Double(index) * 0.8) * 7.0 * min(1.0, voiceActivity * 3.0) : 0.0
                    let dynamicLevel = voiceActivity * 22.0 * factor
                    let height = isVoiceDetected ? max(6.0, CGFloat(dynamicLevel + waveOffset + 8.0)) : 5.0
                    
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(
                            LinearGradient(
                                colors: activeTheme == .electricBlack ? [Color.white, Color(hex: "#94A3B8")] : activeTheme.gradient,
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 4.5, height: min(34.0, height))
                        .animation(.easeOut(duration: 0.12), value: speechService.audioLevel)
                }
            }
            .frame(height: 36)
        }
    }
    
    // MARK: - Permission Denied Card
    private var permissionDeniedCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(AppColors.expenseRoseLight)
                Text("Permiso de Micrófono o Voz Requerido")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
            }
            
            Text("Para dictar tus transacciones con la voz, habilita el acceso en los Ajustes de iOS.")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button("Abrir Ajustes") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(activeTheme.primary)
            .padding(.top, 4)
        }
        .padding(14)
        .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.35), radius: 5, x: 0, y: 2)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Actions
    private func startListeningAutomatically() {
        Task {
            await speechService.startRecording()
        }
    }
    
    private func toggleRecording() {
        if speechService.isRecording {
            speechService.stopRecording()
        } else {
            Task {
                await speechService.startRecording()
            }
        }
    }
    
    private func cancelAndResetDictation() {
        silenceTask?.cancel()
        isSilenceCountdownActive = false
        speechService.stopRecording()
        speechService.reset()
        spokenText = ""
        statusMessage = nil
        isSuccess = false
        isProcessing = false
        startListeningAutomatically()
    }
    
    private func retryDictation() {
        silenceTask?.cancel()
        isSilenceCountdownActive = false
        speechService.stopRecording()
        speechService.reset()
        spokenText = ""
        statusMessage = nil
        isSuccess = false
        isProcessing = false
        startListeningAutomatically()
    }
    
    private func resetSilenceTimer() {
        silenceTask?.cancel()
        let clean = spokenText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard speechService.isRecording && !clean.isEmpty && !isProcessing && spokenText.count < 120 else {
            isSilenceCountdownActive = false
            return
        }
        
        silenceSecondsLeft = 3
        isSilenceCountdownActive = true
        
        silenceTask = Task {
            for count in (1...3).reversed() {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                await MainActor.run {
                    self.silenceSecondsLeft = count - 1
                }
            }
            
            if !Task.isCancelled {
                await MainActor.run {
                    self.isSilenceCountdownActive = false
                    self.processInput()
                }
            }
        }
    }
    
    private func processInput() {
        silenceTask?.cancel()
        isSilenceCountdownActive = false
        
        let text = spokenText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        speechService.stopRecording()
        isProcessing = true
        statusMessage = nil
        
        Task {
            let (success, message) = await viewModel.processDirectVoiceTransaction(spokenText: text)
            await MainActor.run {
                self.isProcessing = false
                self.isSuccess = success
                self.statusMessage = message
                
                if success {
                    // Cerrar inmediatamente el diálogo flotante
                    dismiss()
                    // Disparar la notificación flotante superior tipo Toast con desvanecimiento a los 3 segundos
                    viewModel.showFloatingToast(
                        title: "¡Movimiento Registrado!",
                        message: message,
                        isSuccess: true,
                        duration: 3.0
                    )
                }
            }
        }
    }
}
