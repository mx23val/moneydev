import Foundation
import UIKit
import SwiftUI
import AVFoundation
import Observation

/// Controlador singleton de la sesión de voz en vivo de MoneyBot.
/// Centraliza toda la lógica de conversación para que sobreviva
/// a los cambios de ciclo de vida de las vistas (background, pantalla bloqueada, etc.)
@Observable
public final class MoneyBotLiveVoiceController: @unchecked Sendable {
    public static let shared = MoneyBotLiveVoiceController()
    
    // MARK: - Estado público observable
    public var isSessionActive: Bool = false
    public var orbState: MoneyBotOrbState = .thinking
    public var statusTitle: String = "Iniciando..."
    public var isMicMuted: Bool = false
    public var isProcessingQuery: Bool = false
    public var lastUserSpeech: String = ""
    
    // Referencia débil al ViewModel (se asigna cuando se inicia la sesión)
    public weak var viewModel: ExpenseViewModel?
    public var selectedWalletScopeId: Int64? = nil
    public var selectedWalletScopeName: String = "Billetera Principal"
    
    // MARK: - Servicios internos
    private let speechService = SpeechRecognitionService.shared
    private let ttsService = TextToSpeechService.shared
    private let sessionManager = MoneyBotLiveVoiceSessionManager.shared
    
    // MARK: - Timers y control de flujo
    private var silenceTimer: DispatchSourceTimer? = nil
    private var lastSpeechTimestamp: Date = Date()
    private var lastTranscriptionChangeTimestamp: Date = Date()
    private var currentWatchdogId: UUID = UUID()
    private var transcriptionObserverTask: Task<Void, Never>? = nil
    private var audioLevelObserverTask: Task<Void, Never>? = nil
    // Umbral de amplitud de audio para considerar voz humana activa vs ruido ambiental
    // RMS x 45: El ruido ambiental de una habitación suele estar entre 0.008 y 0.022.
    // La voz humana (incluso en tono suave, tranquilo o pausado) ronda 0.030 a 0.35+.
    private let activeVoiceThreshold: Float = 0.030
    
    private let welcomeGreeting = "Hola, Soy Moneybot, tu asistente con inteligencia artificial destinado a registrar todos tus movimientos. ¿En qué te puedo ayudar?"
    
    // Prevención de eco acústico del bot y bucles infinitos
    private var lastBotSpokenText: String = ""
    private var lastBotSpeechFinishedTime: Date = Date.distantPast
    
    private init() {
        setupNotificationObservers()
    }
    
    // MARK: - Observadores del sistema
    private func setupNotificationObservers() {
        // Cuando regresamos al primer plano
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWillEnterForeground()
        }
        
        // Cuando vamos a background
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDidEnterBackground()
        }
        
        // Pantalla desbloqueada
        NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenUnlocked()
        }
        
        // CRÍTICO: Cuando la app se termina (matar desde recientes),
        // finalizar la Live Activity para que no quede colgada en la isla dinámica.
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, self.isSessionActive else { return }
            // Llamada síncrona: terminar sesión y Live Activity antes de que el proceso muera.
            self.sessionManager.endSession()
            self.speechService.stopRecording(deactivateSession: true)
            self.ttsService.stop(deactivateSession: true)
        }
        
        // Resultado de reconocimiento finalizado — procesar de inmediato
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MoneyBotLiveVoice.SpeechFinalResult"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let text = notification.userInfo?["text"] as? String else { return }
            let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { return }
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard self.isSessionActive, !self.isProcessingQuery, !self.isMicMuted else { return }
                guard self.orbState != .speaking, !self.ttsService.isSpeaking, !self.speechService.isPausedForSpeech else { return }
                
                self.stopSilenceMonitor()
                self.processUserSpeech(query: clean)
            }
        }
    }
    
    private func handleWillEnterForeground() {
        guard isSessionActive && !isMicMuted else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard self.isSessionActive else { return }
            if !self.ttsService.isSpeaking && !self.speechService.isRecording && !self.isMicMuted && !self.isProcessingQuery {
                self.switchToListening()
            }
        }
    }
    
    private func handleDidEnterBackground() {
        guard isSessionActive else { return }
        sessionManager.beginBackgroundKeepAlive()
        // El sessionManager ya maneja el RestartRecognitionInBackground
    }
    
    private func handleScreenUnlocked() {
        guard isSessionActive && !isMicMuted && !isProcessingQuery else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard self.isSessionActive else { return }
            if !self.ttsService.isSpeaking && !self.speechService.isRecording && !self.isMicMuted && !self.isProcessingQuery {
                self.switchToListening()
            }
        }
    }
    
    // MARK: - Iniciar / Detener Sesión
    @MainActor
    public func startSession(viewModel: ExpenseViewModel, walletId: Int64?, walletName: String) async {
        guard !isSessionActive else { return }
        
        self.viewModel = viewModel
        self.selectedWalletScopeId = walletId
        self.selectedWalletScopeName = walletName
        self.isSessionActive = true
        self.isMicMuted = false
        self.isProcessingQuery = false
        self.statusTitle = "Iniciando..."
        self.orbState = .thinking
        
        UIApplication.shared.isIdleTimerDisabled = true
        sessionManager.startSession()
        
        // Iniciar loop de observación de transcripción
        startObservingTranscription()
        
        // Verificar permisos
        let hasPerms = await speechService.requestPermissions()
        guard hasPerms, isSessionActive else {
            statusTitle = "Permisos requeridos"
            return
        }
        
        // Breve espera para entrada fluida
        try? await Task.sleep(nanoseconds: 200_000_000)
        guard isSessionActive else { return }
        
        // Saludar al usuario
        statusTitle = "MoneyBot"
        orbState = .speaking
        sessionManager.updateLiveState(statusText: "Hablando...", isSpeaking: true)
        
        lastBotSpokenText = welcomeGreeting
        speechService.pauseListeningForBotSpeech()
        
        let watchdogId = UUID()
        currentWatchdogId = watchdogId
        
        ttsService.speak(text: welcomeGreeting) {
            Task { @MainActor in
                guard self.currentWatchdogId == watchdogId, self.isSessionActive else { return }
                self.lastBotSpeechFinishedTime = Date()
                // Breve disipación acústica de 80ms para pasar de inmediato a escuchar al usuario
                try? await Task.sleep(nanoseconds: 80_000_000)
                guard self.currentWatchdogId == watchdogId, self.isSessionActive else { return }
                self.switchToListening()
            }
        }
    }
    
    @MainActor
    public func endSession() {
        guard isSessionActive else { return }
        
        // CRÍTICO: Terminar la sesión del manager PRIMERO.
        // Esto establece isLiveSessionActive = false, lo que hace que TODAS
        // las tareas async pendientes (renovación de recognition, restart observers, etc.)
        // lean la bandera y salgan sin reactivar el engine.
        sessionManager.endSession()
        
        isSessionActive = false
        UIApplication.shared.isIdleTimerDisabled = false
        stopObservingTranscription()
        currentWatchdogId = UUID() // Invalidar watchdogs activos
        isProcessingQuery = false
        stopSilenceMonitor()
        
        // Detener audio con deactivateSession: true (detiene engine, quita tap, desactiva sesión)
        ttsService.stop(deactivateSession: false) // No desactivar aquí, speechService lo hará
        speechService.stopRecording(deactivateSession: true) // Esto desactiva la AVAudioSession
        
        orbState = .thinking
        statusTitle = ""
        viewModel = nil
        lastBotSpokenText = ""
        lastBotSpeechFinishedTime = Date.distantPast
    }
    
    // MARK: - Observación de transcripción y nivel de audio
    private func startObservingTranscription() {
        transcriptionObserverTask?.cancel()
        transcriptionObserverTask = Task { @MainActor in
            var lastText = ""
            var lastLevel: Float = 0
            while !Task.isCancelled && isSessionActive {
                // Polling ultrarrápido cada 50ms para detectar cambios de transcripción y nivel de voz
                try? await Task.sleep(nanoseconds: 50_000_000)
                guard self.isSessionActive else { break }
                
                let newText = speechService.transcribedText
                if newText != lastText {
                    lastText = newText
                    self.handleNewTranscription(newText)
                }
                
                let newLevel = speechService.audioLevel
                if newLevel >= self.activeVoiceThreshold && !self.ttsService.isSpeaking && !ElevenLabsService.shared.isSpeaking && self.orbState != .speaking && !self.speechService.isPausedForSpeech {
                    self.lastSpeechTimestamp = Date()
                }
                if abs(newLevel - lastLevel) > 0.005 {
                    lastLevel = newLevel
                    self.handleAudioLevelChange(newLevel)
                }
            }
        }
    }
    
    private func stopObservingTranscription() {
        transcriptionObserverTask?.cancel()
        transcriptionObserverTask = nil
        audioLevelObserverTask?.cancel()
        audioLevelObserverTask = nil
    }
    
    // MARK: - Filtro de Eco Acústico y Anti-Bucle
    private func isAcousticEcho(transcript: String) -> Bool {
        // La protección acústica física ya se ejecuta en el tap de audio real-time descartando buffers
        // durante el habla del bot (speechService.pauseListeningForBotSpeech). No borrar palabras del usuario.
        return false
    }
    
    // MARK: - Flujo de Conversación
    
    @MainActor
    public func switchToListening() {
        guard isSessionActive else { return }
        
        // SEGURIDAD CRÍTICA: Si el bot sigue hablando (ElevenLabs o Apple TTS), NUNCA cambiar a modo escucha.
        // MoneyBot debe terminar completamente de hablar antes de encender el micrófono.
        guard !ttsService.isSpeaking && !ElevenLabsService.shared.isSpeaking else {
            print("MoneyBotLiveVoiceController: Bot sigue hablando; se ignora switchToListening()")
            return
        }
        
        isProcessingQuery = false
        guard !isMicMuted else {
            orbState = .thinking
            statusTitle = "Micrófono en pausa"
            return
        }
        
        currentWatchdogId = UUID()
        // Transición instantánea: activar estado de escucha sin demoras ni parpadeos
        statusTitle = "Te escucho..."
        orbState = .listening(audioLevel: 0.0)
        sessionManager.updateLiveState(statusText: "Escuchando...", isSpeaking: false)
        lastSpeechTimestamp = Date()
        lastTranscriptionChangeTimestamp = Date()
        
        Task { @MainActor in
            guard !self.isProcessingQuery, !self.isMicMuted, self.isSessionActive else { return }
            guard !self.ttsService.isSpeaking && !ElevenLabsService.shared.isSpeaking else { return }
            
            // Reanudar la captura del micrófono de inmediato
            await self.speechService.resumeListeningAfterBotSpeech()
            guard !self.isProcessingQuery, !self.isMicMuted, self.isSessionActive else { return }
            
            if UIApplication.shared.applicationState == .active {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            
            self.startSilenceMonitor()
        }
    }
    
    private func handleNewTranscription(_ text: String) {
        guard !ttsService.isSpeaking && !ElevenLabsService.shared.isSpeaking, !isProcessingQuery, !isMicMuted, !speechService.isPausedForSpeech, orbState != .speaking else { return }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        
        // Registrar actividad de voz y transcripción sin borrar ninguna palabra
        lastTranscriptionChangeTimestamp = Date()
        lastSpeechTimestamp = Date()
    }
    
    private func handleAudioLevelChange(_ level: Float) {
        guard !ttsService.isSpeaking && !ElevenLabsService.shared.isSpeaking, !isProcessingQuery, !isMicMuted, !speechService.isPausedForSpeech, orbState != .speaking else { return }
        if level >= activeVoiceThreshold {
            lastSpeechTimestamp = Date()
        }
        orbState = .listening(audioLevel: level)
    }
    
    // MARK: - Monitor de Silencio
    private func startSilenceMonitor() {
        stopSilenceMonitor()
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
        timer.schedule(deadline: .now() + 0.05, repeating: 0.05)
        timer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.checkSilenceAndProcess()
            }
        }
        timer.resume()
        silenceTimer = timer
    }
    
    private func stopSilenceMonitor() {
        silenceTimer?.cancel()
        silenceTimer = nil
    }
    
    private func checkSilenceAndProcess() {
        guard isSessionActive, !isProcessingQuery, !ttsService.isSpeaking, !ElevenLabsService.shared.isSpeaking, !isMicMuted, !speechService.isPausedForSpeech, orbState != .speaking else { return }
        guard speechService.isRecording else { return }
        
        let spoken = speechService.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty else { return }
        
        let now = Date()
        let timeSinceSpeech = now.timeIntervalSince(lastSpeechTimestamp)
        let timeSinceTranscript = now.timeIntervalSince(lastTranscriptionChangeTimestamp)
        
        // Si el usuario está hablando activamente por encima del umbral en este instante,
        // o emitió voz hace menos de 600ms, no interrumpir bajo ningún concepto
        if speechService.audioLevel >= activeVoiceThreshold || timeSinceSpeech < 0.60 {
            return
        }
        
        let lowerWords = spoken.lowercased().components(separatedBy: CharacterSet.whitespacesAndNewlines).filter { !$0.isEmpty }
        let lastWord = lowerWords.last ?? ""
        
        // Palabras conectores, pronombres clíticos/átonos, preposiciones y auxiliares que indican
        // que la oración está a medio terminar y el usuario seguirá hablando (ej: "me", "estoy", "para", "en").
        let danglingWords: Set<String> = [
            // Pronombres personales y clíticos (NUNCA son una oración completa por sí solos)
            "me", "te", "se", "nos", "os", "le", "les", "lo", "la", "los", "las",
            "yo", "tu", "tú", "él", "el", "ella", "ellos", "ellas", "usted", "ustedes",
            // Posesivos y demostrativos
            "mi", "mis", "tu", "tus", "su", "sus", "nuestro", "nuestra", "nuestros", "nuestras",
            "este", "esta", "estos", "estas", "ese", "esa", "esos", "esas", "aquel", "aquella",
            // Conectores, conjunciones y relativos
            "y", "e", "o", "u", "ni", "que", "pero", "porque", "mas", "sino", "aunque",
            "si", "como", "cuando", "donde", "mientras", "ya", "pues", "así",
            // Preposiciones y contracciones
            "a", "al", "en", "de", "del", "con", "sin", "para", "por", "hacia",
            "desde", "hasta", "sobre", "entre", "tras", "contra", "bajo", "según",
            // Artículos
            "un", "una", "unos", "unas",
            // Verbos auxiliares / incompletos comunes al inicio de una frase
            "es", "son", "era", "fui", "fue", "estoy", "está", "estan", "están",
            "he", "has", "ha", "hemos", "han", "tengo", "tiene", "tenemos",
            "quiero", "quisiera", "puedo", "podrías", "voy", "vamos"
        ]
        
        let isDangling = danglingWords.contains(lastWord)
        let isVeryShort = lowerWords.count <= 2
        
        // Umbral adaptativo inteligente:
        // - Si termina en palabra inconclusa/conector/pronombre ("me", "estoy", "para", "en"):
        //   dar 2.2s de margen para que el usuario jamás sea cortado en la primera palabra ("me...").
        // - Si es una frase muy corta (1 o 2 palabras, ej: "hola", "saldo"): dar 1.8s.
        // - Si es una oración completa (3+ palabras terminadas en sustantivo, adjetivo o verbo): dar 1.5s de silencio natural.
        let requiredSilence: TimeInterval = isDangling ? 2.2 : (isVeryShort ? 1.8 : 1.5)
        
        // Criterio 1: Silencio confirmado (sin nuevas palabras por `requiredSilence`, sin audio en este instante y >600ms de calma acústica)
        let isSilenceConfirmed = timeSinceTranscript >= requiredSilence
            && timeSinceSpeech >= 0.60
            && speechService.audioLevel < activeVoiceThreshold
            
        // Criterio 2: Fallback de seguridad si el reconocedor ya no añade texto tras `requiredSilence + 0.5s`
        let isFallbackTimeout = timeSinceTranscript >= (requiredSilence + 0.5)
        
        if isSilenceConfirmed || isFallbackTimeout {
            stopSilenceMonitor()
            processUserSpeech(query: spoken)
        }
    }
    
    // MARK: - Procesamiento de Respuesta de MoneyBot
    @MainActor
    private func processUserSpeech(query: String) {
        guard !isProcessingQuery, isSessionActive else { return }
        
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        
        isProcessingQuery = true
        lastUserSpeech = clean
        
        stopSilenceMonitor()
        // Pausar escucha inmediatamente para no capturar sonidos mientras se procesa
        speechService.pauseListeningForBotSpeech()
        
        orbState = .thinking
        statusTitle = "Procesando..."
        sessionManager.updateLiveState(statusText: "Procesando...", isSpeaking: false)
        
        if UIApplication.shared.applicationState == .active {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        
        guard let vm = viewModel else {
            switchToListening()
            return
        }
        
        let targetWalletId = selectedWalletScopeId
        let scopeAll = selectedWalletScopeId == nil
        
        sessionManager.beginBackgroundKeepAlive()
        
        let initialBotMessageCount = vm.chatMessages.filter { !$0.isUser }.count
        
        vm.sendUserChatMessage(
            prompt: query,
            targetWalletId: targetWalletId,
            scopeToAllWallets: scopeAll,
            playAudioEffects: false
        )
        
        Task { @MainActor in
            var waitTicks = 0
            // Monitorear respuesta de la IA con sondeo de 40ms para máxima rapidez de respuesta (hasta 30s)
            while waitTicks < 750 {
                try? await Task.sleep(nanoseconds: 40_000_000)
                waitTicks += 1
                guard self.isSessionActive else { return }
                
                let currentCount = vm.chatMessages.filter { !$0.isUser }.count
                if currentCount > initialBotMessageCount && !vm.isAiProcessing {
                    break
                }
            }
            
            guard self.isSessionActive else { return }
            
            let finalBotMessages = vm.chatMessages.filter { !$0.isUser }
            if finalBotMessages.count > initialBotMessageCount, let lastBotMessage = finalBotMessages.last {
                self.speakBotResponse(lastBotMessage.text)
            } else {
                self.speakBotResponse("Listo, he procesado tu solicitud.")
            }
        }
    }
    
    @MainActor
    private func speakBotResponse(_ text: String) {
        guard isSessionActive else { return }
        orbState = .speaking
        statusTitle = "MoneyBot"
        sessionManager.updateLiveState(statusText: "Hablando...", isSpeaking: true)
        
        stopSilenceMonitor()
        // Pausar y silenciar el reconocimiento antes de emitir sonido por el altavoz
        speechService.pauseListeningForBotSpeech()
        sessionManager.beginBackgroundKeepAlive()
        
        lastBotSpokenText = text
        
        let watchdogId = UUID()
        currentWatchdogId = watchdogId
        
        // MoneyBot puede hablar cualquier longitud de texto sin límite de tiempo artificial.
        // Al finalizar completamente de reproducir el audio por altavoz, pasará a modo escucha.
        ttsService.speak(text: text) {
            Task { @MainActor in
                guard self.currentWatchdogId == watchdogId, self.isSessionActive else { return }
                self.lastBotSpeechFinishedTime = Date()
                self.switchToListening()
            }
        }
    }
    
    // MARK: - Interacción Táctil
    @MainActor
    public func handleOrbTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        switch orbState {
        case .speaking:
            ttsService.stop()
            switchToListening()
        case .listening:
            let spoken = speechService.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !spoken.isEmpty {
                stopSilenceMonitor()
                processUserSpeech(query: spoken)
            }
        case .thinking:
            break
        }
    }
    
    @MainActor
    public func toggleMute() {
        isMicMuted.toggle()
        if isMicMuted {
            isProcessingQuery = false
            stopSilenceMonitor()
            speechService.pauseListeningForBotSpeech()
            ttsService.stop()
            orbState = .thinking
            statusTitle = "Micrófono en pausa"
        } else {
            switchToListening()
        }
    }
    
    @MainActor
    public func previewAndSelectElevenLabsVoice(_ voice: ElevenLabsVoiceOption) {
        stopSilenceMonitor()
        speechService.stopRecording()
        speechService.reset()
        ttsService.stop()
        
        orbState = .speaking
        statusTitle = "Probando voz \(voice.displayName)..."
        
        ttsService.previewElevenLabsVoice(voice) {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 60_000_000)
                self.switchToListening()
            }
        }
    }
}
