import Foundation
import Speech
import AVFoundation
import Observation
import UIKit

/// Servicio de reconocimiento de voz con VAD (Voice Activity Detection) integrado en el tap de audio.
/// La detección de silencio ocurre en el hilo de audio real-time de AVAudioEngine,
/// que iOS NUNCA puede limitar, garantizando funcionamiento en background y pantalla bloqueada.
@Observable
public final class SpeechRecognitionService: @unchecked Sendable {
    public static let shared = SpeechRecognitionService()
    
    // MARK: - Estado público
    public var isRecording: Bool = false
    public var isPausedForSpeech: Bool = false
    public var transcribedText: String = ""
    public var errorMessage: String? = nil
    public var audioLevel: Float = 0.0
    public var permissionDenied: Bool = false
    public var isAuthorized: Bool = false
    
    // MARK: - Engine y reconocimiento
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var isTapInstalled: Bool = false
    private var lastAudioLevelUpdateTime: TimeInterval = 0
    
    // MARK: - VAD (Voice Activity Detection) — corre en el hilo de audio real-time
    // Estos valores se leen/escriben desde el tap de audio (RT thread) y desde código async.
    // Son primitivos, lo que los hace seguros para acceso concurrente sin lock.
    private var vadFirstVoiceTime: Date? = nil      // Cuando comenzó el usuario a hablar
    private var vadLastVoiceTime: Date = Date.distantPast  // Último momento con audio significativo
    private let vadVoiceThreshold: Float = 0.012    // Umbral calibrado de alta sensibilidad para captar voz humana suave y a distancia
    public var vadSilenceSeconds: TimeInterval = 6.0 // Margen de seguridad amplio para no cortar jamás la voz del usuario
    private let vadMinSpeechSeconds: TimeInterval = 0.3 // Mínimo de voz requerida
    private var isFinalizing: Bool = false  // true = nosotros llamamos endAudio() intencionalmente
    
    // Acumulación de texto entre renovaciones automáticas de Apple (evita que se pierda el inicio de la oración)
    private var accumulatedPrefix: String = ""
    
    // MARK: - Control de ciclo de vida
    private var isStartingRecording: Bool = false
    private var isRenewingTask: Bool = false
    private var retryCount: Int = 0
    private let maxRetries: Int = 12
    private var renewalTimer: DispatchSourceTimer? = nil
    
    public init() {
        setupSystemObservers()
    }
    
    // MARK: - Permisos
    
    public func requestPermissions() async -> Bool {
        if isAuthorized && !permissionDenied { return true }
        
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let micGranted: Bool
        if #available(iOS 17.0, *) {
            micGranted = AVAudioApplication.shared.recordPermission == .granted
        } else {
            micGranted = AVAudioSession.sharedInstance().recordPermission == .granted
        }
        
        if speechStatus == .authorized && micGranted {
            await MainActor.run { self.isAuthorized = true; self.permissionDenied = false }
            return true
        }
        
        let authorized = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        guard authorized else {
            await MainActor.run { self.permissionDenied = true; self.isAuthorized = false }
            return false
        }
        
        let mic: Bool
        if #available(iOS 17.0, *) {
            mic = await AVAudioApplication.requestRecordPermission()
        } else {
            mic = await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        }
        await MainActor.run { self.isAuthorized = mic; self.permissionDenied = !mic }
        return mic
    }
    
    // MARK: - Obtener mejor reconocedor disponible
    
    private func getBestRecognizer() -> SFSpeechRecognizer? {
        if let r = speechRecognizer, r.isAvailable { return r }
        
        let candidates = [
            Locale(identifier: "es-419"),  // Español Latinoamérica
            Locale(identifier: "es-PE"),  // Perú
            Locale(identifier: "es-MX"),  // México
            Locale(identifier: "es-US"),
            Locale(identifier: "es-ES"),
            Locale.current
        ]
        
        for loc in candidates {
            if let r = SFSpeechRecognizer(locale: loc), r.isAvailable {
                speechRecognizer = r
                return r
            }
        }
        
        // Último recurso
        let fallback = SFSpeechRecognizer(locale: Locale(identifier: "es-419"))
        speechRecognizer = fallback
        return fallback
    }
    
    // MARK: - Activar sesión de audio
    
    @discardableResult
    private func activateAudioSession() -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            try? session.overrideOutputAudioPort(.speaker)
            if session.isInputGainSettable {
                try? session.setInputGain(1.0)
            }
            return true
        } catch {
            print("SpeechRecognitionService: Error activando audio session: \(error)")
            return false
        }
    }
    
    // MARK: - Iniciar grabación (engine + recognition task)
    
    // MARK: - Iniciar grabación (engine + recognition task)
    
    public func startRecording() async {
        guard !isStartingRecording else { return }
        isStartingRecording = true
        defer { isStartingRecording = false }
        
        isPausedForSpeech = false
        
        // Detener todo lo previo limpiamente
        stopRecognitionTask()
        
        let authorized = await requestPermissions()
        guard authorized else { return }
        
        guard let recognizer = getBestRecognizer() else {
            await MainActor.run { self.errorMessage = "Reconocimiento de voz no disponible." }
            return
        }
        
        await MainActor.run {
            self.transcribedText = ""
            self.errorMessage = nil
            self.audioLevel = 0.0
        }
        
        // Activar sesión de audio en hilo secundario para evitar SessionCore.mm:631 y bloqueo de UI
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.activateAudioSession()
                continuation.resume()
            }
        }
        
        do {
            // Instalar tap en el engine (activa el LED naranja del micrófono)
            // Solo si no está ya instalado y corriendo
            if !isTapInstalled || !audioEngine.isRunning {
                try installTap()
            }
            
            // Crear el recognition request
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.taskHint = .dictation
            // NO forzar requiresOnDeviceRecognition = true para evitar error cuando los modelos offline no están instalados
            request.requiresOnDeviceRecognition = false
            if #available(iOS 16.0, *) {
                request.addsPunctuation = false
            }
            
            self.recognitionRequest = request
            
            // Iniciar engine si no está corriendo
            if !audioEngine.isRunning {
                audioEngine.prepare()
                try audioEngine.start()
            }
            
            // Resetear estado VAD
            vadFirstVoiceTime = nil
            vadLastVoiceTime = Date.distantPast
            isFinalizing = false
            retryCount = 0
            
            // Marcar como grabando ANTES de conectar el task
            await MainActor.run { self.isRecording = true }
            
            // Conectar el recognition task
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                self?.handleResult(result: result, error: error)
            }
            
            // Programar renovación periódica del task (antes del límite de ~60s de iOS)
            scheduleRenewal()
            
        } catch {
            setRecordingState(false)
            await MainActor.run { self.errorMessage = "Error al iniciar micrófono: \(error.localizedDescription)" }
            // Si falla y estamos en sesión live, reintentar
            scheduleRetry()
        }
    }
    
    // MARK: - Pausar y Reanudar para habla de MoneyBot (evita retroalimentación acústica)
    
    public func resetAccumulatedPrefix() {
        accumulatedPrefix = ""
    }
    
    public func pauseListeningForBotSpeech() {
        isPausedForSpeech = true
        accumulatedPrefix = ""
        setRecordingState(false)
        stopRecognitionTask()
        if Thread.isMainThread {
            self.transcribedText = ""
            self.audioLevel = 0.0
        } else {
            DispatchQueue.main.async {
                self.transcribedText = ""
                self.audioLevel = 0.0
            }
        }
    }
    
    public func resumeListeningAfterBotSpeech() async {
        guard !TextToSpeechService.shared.isSpeaking && !ElevenLabsService.shared.isSpeaking else {
            print("SpeechRecognitionService: Intento de reanudar escucha mientras MoneyBot habla — ignorado")
            return
        }
        isPausedForSpeech = false
        accumulatedPrefix = ""
        await MainActor.run {
            self.transcribedText = ""
            self.audioLevel = 0.0
        }
        if audioEngine.isRunning && isTapInstalled {
            await startRecognitionTaskOnly()
        } else {
            await startRecording()
        }
    }
    
    /// Conecta una nueva tarea de reconocimiento de forma ultrarrápida reutilizando el engine ya activo
    private func startRecognitionTaskOnly() async {
        stopRecognitionTask()
        guard let recognizer = getBestRecognizer() else { return }
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.requiresOnDeviceRecognition = false
        if #available(iOS 16.0, *) {
            request.addsPunctuation = false
        }
        self.recognitionRequest = request
        
        vadFirstVoiceTime = nil
        vadLastVoiceTime = Date.distantPast
        isFinalizing = false
        
        await MainActor.run { self.isRecording = true }
        
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            self?.handleResult(result: result, error: error)
        }
        scheduleRenewal()
    }
    
    // MARK: - Instalar tap en el AVAudioEngine
    // El tap corre en un hilo de audio real-time que iOS NO puede suspender.
    // Aquí implementamos el VAD que detecta cuándo el usuario terminó de hablar.
    
    private func installTap() throws {
        if audioEngine.isRunning { audioEngine.stop() }
        let inputNode = audioEngine.inputNode
        if isTapInstalled {
            inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        audioEngine.reset()
        
        let hwFormat = inputNode.outputFormat(forBus: 0)
        let format: AVAudioFormat
        if hwFormat.sampleRate > 0 && hwFormat.channelCount > 0 {
            format = hwFormat
        } else {
            format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) ?? hwFormat
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            // CRÍTICO: Si el bot está hablando o la escucha está pausada para el habla del bot,
            // descartar TODO el audio del micrófono de inmediato para que jamás escuche su propia voz
            // ni actualice audioLevel/VAD.
            if self.isPausedForSpeech || !self.isRecording || TextToSpeechService.shared.isSpeaking || ElevenLabsService.shared.isSpeaking {
                return
            }
            
            // Alimentar el buffer al recognition request (si hay uno activo)
            self.recognitionRequest?.append(buffer)
            
            // ─── Calcular nivel de audio (RMS) con ganancia natural para voz humana ─────
            let frameCount = Int(buffer.frameLength)
            guard frameCount > 0, let channelData = buffer.floatChannelData?[0] else { return }
            var sumSq: Float = 0
            for i in 0..<frameCount { let s = channelData[i]; sumSq += s * s }
            let rms = sqrt(sumSq / Float(frameCount))
            // Sensibilidad amplificada para micrófono de iPhone: capta con alta nitidez tanto voz suave como fuerte y a distancia
            let normalized = min(max(rms * 45.0, 0.0), 1.0)
            
            // Actualizar nivel de audio para la UI del orbe (~30fps)
            let now = ProcessInfo.processInfo.systemUptime
            if now - self.lastAudioLevelUpdateTime >= 0.033 {
                self.lastAudioLevelUpdateTime = now
                Task { @MainActor [weak self] in
                    guard let self = self, self.isRecording, !self.isPausedForSpeech else { return }
                    self.audioLevel = normalized
                }
            }
            
            // ─── Detección de presencia de voz continua (actualiza timestamps) ──────
            guard MoneyBotLiveVoiceSessionManager.shared.isLiveSessionActive else { return }
            guard self.isRecording && !self.isPausedForSpeech else { return }
            
            let wallNow = Date()
            if normalized >= self.vadVoiceThreshold {
                self.vadLastVoiceTime = wallNow
                if self.vadFirstVoiceTime == nil {
                    self.vadFirstVoiceTime = wallNow
                }
            }
        }
        isTapInstalled = true
    }
    
    // MARK: - Manejar resultado del recognition task
    
    private func handleResult(result: SFSpeechRecognitionResult?, error: Error?) {
        // Ignorar de inmediato si estamos en pausa para habla del bot o el bot está hablando activamente
        if isPausedForSpeech || TextToSpeechService.shared.isSpeaking || ElevenLabsService.shared.isSpeaking {
            return
        }
        
        if let result = result {
            guard !isPausedForSpeech, !TextToSpeechService.shared.isSpeaking, !ElevenLabsService.shared.isSpeaking else { return }
            
            let rawSpoken = SpeechRecognitionService.normalizeText(result.bestTranscription.formattedString)
            let spoken: String = {
                if self.accumulatedPrefix.isEmpty {
                    return rawSpoken
                } else if rawSpoken.isEmpty {
                    return self.accumulatedPrefix
                } else {
                    return "\(self.accumulatedPrefix) \(rawSpoken)"
                }
            }()
            let clean = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
            
            Task { @MainActor in
                guard !self.isPausedForSpeech, self.isRecording else { return }
                if self.transcribedText != clean {
                    self.transcribedText = clean
                }
            }
            
            // Si el reconocedor detectó texto, actualizamos de inmediato la presencia de voz en VAD
            if !clean.isEmpty {
                self.vadLastVoiceTime = Date()
                if self.vadFirstVoiceTime == nil {
                    self.vadFirstVoiceTime = Date()
                }
            }
            
            if result.isFinal {
                isFinalizing = false
                guard !self.isPausedForSpeech, !TextToSpeechService.shared.isSpeaking, !ElevenLabsService.shared.isSpeaking else { return }
                
                if !clean.isEmpty {
                    self.accumulatedPrefix = clean
                    if MoneyBotLiveVoiceSessionManager.shared.isLiveSessionActive && !isPausedForSpeech && isRecording {
                        Task {
                            guard MoneyBotLiveVoiceSessionManager.shared.isLiveSessionActive, !self.isPausedForSpeech, self.isRecording else { return }
                            await self.renewTask()
                        }
                    }
                } else {
                    // Finalización sin texto: renovar silenciosamente para seguir escuchando
                    if MoneyBotLiveVoiceSessionManager.shared.isLiveSessionActive && !isPausedForSpeech && isRecording {
                        Task {
                            guard MoneyBotLiveVoiceSessionManager.shared.isLiveSessionActive, !self.isPausedForSpeech, self.isRecording else { return }
                            await self.renewTask()
                        }
                    }
                }
            }
        }
        
        if let error = error {
            let nsError = error as NSError
            isFinalizing = false
            
            guard MoneyBotLiveVoiceSessionManager.shared.isLiveSessionActive else { return }
            // Si estamos en pausa intencional por TTS o no estamos grabando: ignorar error de cancelación
            if isPausedForSpeech || !isRecording { return }
            
            // Códigos de cancelación esperados al pausar o resetear (20 = request cancelled, 216 = task cancelled, 1 = cancelled, 204 = ended)
            if nsError.code == 20 || nsError.code == 216 || nsError.code == 1 || nsError.code == 204 { return }
            
            // Si hubo un error o finalización transitoria de Apple (por ejemplo, pausa breve o reconfiguración de audio),
            // guardamos el texto acumulado para no perderlo y renovamos la tarea silenciosamente.
            // NUNCA disparamos SpeechFinalResult aquí: el usuario puede seguir hablando su oración,
            // y solo debe procesarse cuando se cumplan exactamente los 4.0 segundos de silencio continuo.
            let pendingSpoken = self.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !pendingSpoken.isEmpty {
                self.accumulatedPrefix = pendingSpoken
            }
            
            // Renovar tras breve pausa solo si seguimos grabando activamente
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard MoneyBotLiveVoiceSessionManager.shared.isLiveSessionActive, !self.isPausedForSpeech, self.isRecording else { return }
                guard !self.isStartingRecording && !self.isRenewingTask else { return }
                guard self.retryCount < self.maxRetries else {
                    print("SpeechRecognitionService: Max reintentos alcanzado, reiniciando engine")
                    self.retryCount = 0
                    await self.startRecording()
                    return
                }
                self.retryCount += 1
                
                let delay = min(UInt64(200_000_000) * UInt64(pow(2.0, Double(min(self.retryCount - 1, 3)))), 2_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
                guard MoneyBotLiveVoiceSessionManager.shared.isLiveSessionActive, !self.isPausedForSpeech, self.isRecording else { return }
                
                if self.audioEngine.isRunning && self.isTapInstalled {
                    await self.renewTask()
                } else {
                    await self.startRecording()
                }
            }
        }
    }
    
    // MARK: - Renovar recognition task sin detener el engine
    // El engine y tap siguen activos (LED naranja permanece encendido).
    
    private func renewTask() async {
        guard !isRenewingTask, !isPausedForSpeech, isRecording,
              !TextToSpeechService.shared.isSpeaking,
              !ElevenLabsService.shared.isSpeaking else { return }
        isRenewingTask = true
        defer { isRenewingTask = false }
        
        guard MoneyBotLiveVoiceSessionManager.shared.isLiveSessionActive, !isPausedForSpeech, isRecording else { return }
        guard let recognizer = getBestRecognizer() else { return }
        
        let oldRequest = recognitionRequest
        let oldTask = recognitionTask
        
        // Nuevo request creado inmediatamente para no perder ningún buffer de audio entrante
        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true
        newRequest.taskHint = .dictation
        newRequest.requiresOnDeviceRecognition = false
        if #available(iOS 16.0, *) { newRequest.addsPunctuation = false }
        
        self.recognitionRequest = newRequest
        
        // Resetear VAD para nuevo ciclo
        vadFirstVoiceTime = nil
        vadLastVoiceTime = Date.distantPast
        isFinalizing = false
        
        await MainActor.run { self.isRecording = true }
        
        recognitionTask = recognizer.recognitionTask(with: newRequest) { [weak self] result, error in
            self?.handleResult(result: result, error: error)
        }
        
        // Cerrar limpiamente el task anterior sin bloquear el tap de audio
        oldRequest?.endAudio()
        oldTask?.cancel()
        
        scheduleRenewal()
    }
    
    // MARK: - Renovación periódica (antes del límite de ~60s de iOS)
    
    private func scheduleRenewal() {
        renewalTimer?.cancel()
        renewalTimer = nil
        guard MoneyBotLiveVoiceSessionManager.shared.isLiveSessionActive, !isPausedForSpeech, isRecording else { return }
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now() + 50.0)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            guard MoneyBotLiveVoiceSessionManager.shared.isLiveSessionActive, !self.isPausedForSpeech, self.isRecording else { return }
            guard !self.isFinalizing else { return } // No renovar si estamos finalizando por VAD
            Task { await self.renewTask() }
        }
        timer.resume()
        renewalTimer = timer
    }
    
    // MARK: - Retry tras fallo
    
    private func scheduleRetry() {
        guard MoneyBotLiveVoiceSessionManager.shared.isLiveSessionActive, !isPausedForSpeech else { return }
        guard retryCount < maxRetries else { return }
        retryCount += 1
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard MoneyBotLiveVoiceSessionManager.shared.isLiveSessionActive, !self.isPausedForSpeech else { return }
            await self.startRecording()
        }
    }
    
    // MARK: - Detener solo el recognition task (mantiene engine/LED activos)
    
    private func stopRecognitionTask() {
        renewalTimer?.cancel()
        renewalTimer = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isFinalizing = false
        vadFirstVoiceTime = nil
        vadLastVoiceTime = Date.distantPast
    }
    
    // MARK: - API pública: Detener grabación
    
    public func stopRecording(deactivateSession: Bool = false) {
        isPausedForSpeech = true
        setRecordingState(false)
        stopRecognitionTask()
        
        // Detener el engine solo si la sesión live terminó o se pide explícitamente
        let stopEngine = deactivateSession
            || !MoneyBotLiveVoiceSessionManager.shared.isLiveSessionActive
        
        if stopEngine {
            if audioEngine.isRunning { audioEngine.stop() }
            if isTapInstalled {
                audioEngine.inputNode.removeTap(onBus: 0)
                isTapInstalled = false
            }
            audioEngine.reset()
            if deactivateSession {
                DispatchQueue.global(qos: .userInitiated).async {
                    try? AVAudioSession.sharedInstance().setActive(false)
                }
            }
        }
        // Si NO detenemos el engine: el tap sigue activo pero los buffers se descartan
    }
    
    public func reset(deactivateSession: Bool = false) {
        stopRecording(deactivateSession: deactivateSession)
        accumulatedPrefix = ""
        if Thread.isMainThread {
            transcribedText = ""
            errorMessage = nil
            audioLevel = 0.0
        } else {
            DispatchQueue.main.async {
                self.transcribedText = ""
                self.errorMessage = nil
                self.audioLevel = 0.0
            }
        }
    }
    
    private func setRecordingState(_ value: Bool) {
        if Thread.isMainThread {
            isRecording = value
            if !value { audioLevel = 0.0 }
        } else {
            DispatchQueue.main.async {
                self.isRecording = value
                if !value { self.audioLevel = 0.0 }
            }
        }
    }
    
    // MARK: - Normalización de texto fonético
    
    public static func normalizeText(_ text: String) -> String {
        var result = text
        let replacements: [(String, String)] = [
            (#"(?i)\b(?:jeeiph|jeeip|jeiph|jeip|jeeph|jeph|yeiph|yeip|yepe|jape|jaip|yapp|yappe|yap|iape|llape)\b"#, "Yape"),
            (#"(?i)\b(?:ya\s+pe|ia\s+pe)\b"#, "Yape"),
            (#"(?i)\b(?:plim|plin)\b"#, "Plin"),
            (#"(?i)\b(?:bcp|vcp)\b"#, "BCP"),
            (#"(?i)\b(?:bbva)\b"#, "BBVA"),
            (#"(?i)\b(?:scotiabank|scotia)\b"#, "Scotiabank"),
            (#"(?i)\b(?:interbank)\b"#, "Interbank")
        ]
        for (pattern, rep) in replacements {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                result = regex.stringByReplacingMatches(
                    in: result, range: NSRange(location: 0, length: result.utf16.count),
                    withTemplate: rep
                )
            }
        }
        return result
    }
    
    // Compatibilidad con código existente que usa el nombre anterior
    public static func normalizePhoneticSpokenText(_ text: String) -> String {
        return normalizeText(text)
    }
    
    // MARK: - Observadores del sistema
    
    private func setupSystemObservers() {
        // Notificación de reinicio en background (desde MoneyBotLiveVoiceSessionManager)
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MoneyBotLiveVoice.RestartRecognitionInBackground"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            guard MoneyBotLiveVoiceSessionManager.shared.isLiveSessionActive else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard MoneyBotLiveVoiceSessionManager.shared.isLiveSessionActive else { return }
                if self.audioEngine.isRunning && self.isTapInstalled {
                    // Engine vivo: solo renovar el task (mantiene LED)
                    await self.renewTask()
                } else {
                    // Engine detenido: reinicio completo
                    await self.startRecording()
                }
            }
        }
        
        // Cambio de configuración del engine (auriculares, Bluetooth, etc.)
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            guard MoneyBotLiveVoiceSessionManager.shared.isLiveSessionActive else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard MoneyBotLiveVoiceSessionManager.shared.isLiveSessionActive else { return }
                if !self.audioEngine.isRunning {
                    self.stopRecognitionTask()
                    await self.startRecording()
                }
            }
        }
        
        // Interrupción de audio (llamada, alarma)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            if type == .ended {
                if MoneyBotLiveVoiceSessionManager.shared.isLiveSessionActive {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        guard MoneyBotLiveVoiceSessionManager.shared.isLiveSessionActive else { return }
                        self.stopRecognitionTask()
                        await self.startRecording()
                    }
                }
            }
        }
        
        // Pantalla bloqueada → mantener keep-alive
        NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil,
            queue: .main
        ) { _ in
            if MoneyBotLiveVoiceSessionManager.shared.isLiveSessionActive {
                MoneyBotLiveVoiceSessionManager.shared.beginBackgroundKeepAlive()
            }
        }
    }
}
