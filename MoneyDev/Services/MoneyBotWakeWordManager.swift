import Foundation
import Speech
import AVFoundation
import UIKit
import Observation

/// Escuchador pasivo ultra ligero en segundo plano para el comando de activación "Oye Moneybot"
/// Permite entrar al modo voz en manos libres desde la pantalla principal sin tocar la pantalla.
@Observable
public final class MoneyBotWakeWordManager: @unchecked Sendable {
    public static let shared = MoneyBotWakeWordManager()
    
    public var isListeningForWakeWord: Bool = false
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var isTapInstalled: Bool = false
    
    private var onWakeWordDetectedCallback: (() -> Void)?
    private var shouldKeepListening: Bool = false
    private var restartWorkItem: DispatchWorkItem? = nil
    
    private init() {
        setupLocale()
    }
    
    private func setupLocale() {
        let locales = [
            Locale(identifier: "es-PE"),
            Locale(identifier: "es-419"),
            Locale(identifier: "es-MX"),
            Locale(identifier: "es-ES"),
            Locale.current
        ]
        for loc in locales {
            if let recognizer = SFSpeechRecognizer(locale: loc), recognizer.isAvailable {
                self.speechRecognizer = recognizer
                return
            }
        }
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-PE")) ?? SFSpeechRecognizer()
    }
    
    // MARK: - Iniciar Escucha de "Oye Moneybot"
    public func startListening(onWakeWord: @escaping () -> Void) {
        guard !MoneyBotLiveVoiceSessionManager.shared.isLiveSessionActive else { return }
        
        self.onWakeWordDetectedCallback = onWakeWord
        self.shouldKeepListening = true
        
        // Si ya está escuchando, no duplicar
        if isListeningForWakeWord && audioEngine.isRunning {
            return
        }
        
        Task {
            let authorized = await checkPermissions()
            guard authorized else { return }
            
            await MainActor.run {
                self.startAudioEngineAndRecognition()
            }
        }
    }
    
    // MARK: - Detener Escucha
    public func stopListening() {
        shouldKeepListening = false
        restartWorkItem?.cancel()
        restartWorkItem = nil
        
        stopAudioEngineAndClean()
        
        Task { @MainActor in
            self.isListeningForWakeWord = false
        }
    }
    
    private func startAudioEngineAndRecognition() {
        guard shouldKeepListening else { return }
        guard !MoneyBotLiveVoiceSessionManager.shared.isLiveSessionActive else { return }
        
        stopAudioEngineAndClean()
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            scheduleRestart(delay: 2.0)
            return
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetoothHFP]
            )
            try audioSession.setActive(true)
            try? audioSession.overrideOutputAudioPort(.speaker)
        } catch {
            print("MoneyBotWakeWordManager: Error configurando audioSession: \(error.localizedDescription)")
            scheduleRestart(delay: 2.0)
            return
        }
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .search
        
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        
        self.recognitionRequest = request
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        guard recordingFormat.sampleRate > 0 else {
            scheduleRestart(delay: 2.0)
            return
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        isTapInstalled = true
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListeningForWakeWord = true
        } catch {
            print("MoneyBotWakeWordManager: Error iniciando audioEngine: \(error.localizedDescription)")
            stopAudioEngineAndClean()
            scheduleRestart(delay: 2.0)
            return
        }
        
        self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let transcription = result.bestTranscription.formattedString.lowercased()
                if self.isWakeWordMatch(transcription) {
                    self.handleWakeWordTriggered()
                    return
                }
            }
            
            if error != nil || (result?.isFinal ?? false) {
                self.stopAudioEngineAndClean()
                if self.shouldKeepListening {
                    self.scheduleRestart(delay: 1.0)
                }
            }
        }
    }
    
    private func isWakeWordMatch(_ text: String) -> Bool {
        let clean = text
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "[^a-z0-9 ]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let wakePhrases = [
            "oye moneybot",
            "oye money bot",
            "oye money",
            "oye mani bot",
            "oye manibot",
            "oye monei bot",
            "oye monybot",
            "hey moneybot",
            "hey money bot",
            "hola moneybot",
            "hola money bot"
        ]
        
        for phrase in wakePhrases {
            if clean.contains(phrase) {
                return true
            }
        }
        return false
    }
    
    private func handleWakeWordTriggered() {
        // Detener escucha de inmediato para ceder el micrófono
        stopListening()
        
        // Feedback háptico de éxito
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        DispatchQueue.main.async { [weak self] in
            self?.onWakeWordDetectedCallback?()
        }
    }
    
    private func scheduleRestart(delay: TimeInterval) {
        restartWorkItem?.cancel()
        guard shouldKeepListening else { return }
        
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, self.shouldKeepListening else { return }
            self.startAudioEngineAndRecognition()
        }
        self.restartWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
    
    private func stopAudioEngineAndClean() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        audioEngine.reset()
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
    }
    
    private func checkPermissions() async -> Bool {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let micStatus = AVAudioApplication.shared.recordPermission
        
        if speechStatus == .authorized && micStatus == .granted {
            return true
        }
        return false
    }
}
