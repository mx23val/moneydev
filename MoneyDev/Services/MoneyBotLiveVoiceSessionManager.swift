import Foundation
import UIKit
import Observation
import AVFoundation
import ActivityKit
import UserNotifications

/// Administrador central de sesión en segundo plano para MoneyBot Live Voice.
/// Permite mantener activa la conversación con IA de forma ininterrumpida
/// cuando el usuario sale de la app o bloquea el dispositivo.
@Observable
public final class MoneyBotLiveVoiceSessionManager: @unchecked Sendable {
    public static let shared = MoneyBotLiveVoiceSessionManager()
    
    public var isLiveSessionActive: Bool = false
    public var isInBackground: Bool = false
    
    /// Último estado textual del Live Activity / Notificación
    public var lastStatusText: String = ""
    public var lastIsSpeaking: Bool = false
    
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var keepAliveTimer: DispatchSourceTimer? = nil
    private var renewalTimer: DispatchSourceTimer? = nil
    
    // Live Activity para Dynamic Island
    private var currentLiveActivity: Any? = nil
    
    private init() {
        setupAppStateNotifications()
    }
    
    private func setupAppStateNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDidEnterBackground()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWillEnterForeground()
        }
    }
    
    // MARK: - Iniciar Sesión Live
    public func startSession() {
        isLiveSessionActive = true
        lastStatusText = "Iniciando..."
        lastIsSpeaking = false
        
        beginBackgroundKeepAlive()
        startLiveActivity()
    }
    
    // MARK: - Finalizar Sesión Live
    public func endSession() {
        isLiveSessionActive = false
        lastStatusText = ""
        lastIsSpeaking = false
        stopBackgroundKeepAlive()
        endLiveActivity()
    }
    
    // MARK: - Actualizar Estado en Vivo (Escuchando / Hablando / Pensando)
    public func updateLiveState(statusText: String, isSpeaking: Bool) {
        guard isLiveSessionActive else { return }
        
        lastStatusText = statusText
        lastIsSpeaking = isSpeaking
        
        // Actualizar Dynamic Island + Lock Screen en tiempo real — sin notificación local
        if #available(iOS 16.1, *) {
            if let activity = currentLiveActivity as? Activity<MoneyBotActivityAttributes> {
                let updatedContentState = MoneyBotActivityAttributes.ContentState(
                    statusText: statusText,
                    isSpeaking: isSpeaking,
                    subtitle: isSpeaking
                        ? "Money está hablando contigo..."
                        : "Money te está escuchando..."
                )
                Task {
                    await activity.update(
                        ActivityContent<MoneyBotActivityAttributes.ContentState>(
                            state: updatedContentState,
                            staleDate: nil
                        )
                    )
                }
            }
        }
    }
    
    private func handleDidEnterBackground() {
        isInBackground = true
        if isLiveSessionActive {
            beginBackgroundKeepAlive()
            
            let currentStatus = lastStatusText.isEmpty ? "Escuchando..." : lastStatusText
            updateLiveState(statusText: currentStatus, isSpeaking: lastIsSpeaking)
            ensureAudioSessionActive()
        }
    }
    
    private func handleWillEnterForeground() {
        isInBackground = false
        if isLiveSessionActive {
            beginBackgroundKeepAlive()
        }
    }
    
    // MARK: - Live Activity (Dynamic Island & Lock Screen)
    private func startLiveActivity() {
        guard #available(iOS 16.1, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        endLiveActivity()
        
        let attributes = MoneyBotActivityAttributes(sessionTitle: "MoneyBot Live")
        let initialState = MoneyBotActivityAttributes.ContentState(
            statusText: "Iniciando...",
            isSpeaking: false,
            subtitle: "Money te está escuchando..."
        )
        
        do {
            let activity = try Activity<MoneyBotActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            self.currentLiveActivity = activity
        } catch {
            print("MoneyBotLiveVoiceSessionManager: Error al iniciar Live Activity: \(error.localizedDescription)")
        }
    }
    
    /// Finaliza la Live Activity. Usa semáforo si la app está siendo terminada
    /// para garantizar que el cierre se complete antes de que el proceso muera.
    private func endLiveActivity() {
        guard #available(iOS 16.1, *) else { return }
        guard let activity = currentLiveActivity as? Activity<MoneyBotActivityAttributes> else {
            currentLiveActivity = nil
            return
        }
        
        currentLiveActivity = nil
        
        Task { @MainActor in
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
    
    // MARK: - Keep Alive en Segundo Plano
    public func beginBackgroundKeepAlive() {
        guard isLiveSessionActive else { return }
        
        // Renovar background task
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "MoneyBotLiveVoiceKeepAlive") { [weak self] in
            guard let self = self else { return }
            if self.isLiveSessionActive {
                // La expiración del background task llega: renovar de inmediato
                DispatchQueue.main.async {
                    self.beginBackgroundKeepAlive()
                }
            } else {
                self.stopBackgroundKeepAlive()
            }
        }
        
        // Mantener sesión de audio activa para que iOS no suspenda el proceso
        ensureAudioSessionActive()
        
        // Timer de renovación periódica del background task (cada 20s)
        // para evitar que expire antes de que iOS nos notifique
        startRenewalTimer()
    }
    
    private func ensureAudioSessionActive() {
        // Si el bot está hablando activamente, NO tocar la sesión de audio bajo ninguna circunstancia
        // para evitar micro-cortes, caídas de buffer o entrecortes en la voz
        guard !TextToSpeechService.shared.isSpeaking, !ElevenLabsService.shared.isSpeaking else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard !TextToSpeechService.shared.isSpeaking, !ElevenLabsService.shared.isSpeaking else { return }
            let session = AVAudioSession.sharedInstance()
            do {
                if session.category != .playAndRecord {
                    try session.setCategory(
                        .playAndRecord,
                        mode: .default,
                        options: [.defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP]
                    )
                }
                try session.setActive(true)
                try? session.overrideOutputAudioPort(.speaker)
            } catch {
                print("MoneyBotLiveVoiceSessionManager: Error sesión audio: \(error.localizedDescription)")
            }
        }
    }
    
    private func startRenewalTimer() {
        renewalTimer?.cancel()
        renewalTimer = nil
        
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
        timer.schedule(deadline: .now() + 20.0, repeating: 20.0)
        timer.setEventHandler { [weak self] in
            guard let self = self, self.isLiveSessionActive else { return }
            self.ensureAudioSessionActive()
            DispatchQueue.main.async {
                self.beginBackgroundKeepAlive()
            }
        }
        timer.resume()
        self.renewalTimer = timer
    }
    
    public func stopBackgroundKeepAlive() {
        renewalTimer?.cancel()
        renewalTimer = nil
        
        keepAliveTimer?.cancel()
        keepAliveTimer = nil
        
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
}
