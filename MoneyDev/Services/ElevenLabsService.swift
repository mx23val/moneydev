import Foundation
import AVFoundation

// MARK: - Catálogo de Voces ElevenLabs

/// Voces naturales de ElevenLabs disponibles para MoneyBot en español.
/// Cada caso tiene un rawValue = Voice ID de ElevenLabs.
public enum ElevenLabsVoiceOption: String, CaseIterable, Identifiable {
    case sofia     = "EXAVITQu4vr4xnSDxMaL"  // Sarah — Femenina, cálida, natural
    case alonso    = "nPczCjzI2devNBz1zQrb"  // Brian — Masculina, profunda, firme
    case valentina = "hpp4J3VqNfWAUOO0d1Us"  // Bella — Femenina, expresiva y fluida en español
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .sofia:     return "Sofía"
        case .alonso:    return "Alonso"
        case .valentina: return "Valentina"
        }
    }
    
    public var tag: String {
        switch self {
        case .sofia:     return "✨ Femenina • Cálida"
        case .alonso:    return "🎙️ Masculina • Firme"
        case .valentina: return "🌸 Femenina • Expresiva"
        }
    }
}

// MARK: - ElevenLabsService

/// Singleton que reproduce texto mediante la API REST de ElevenLabs (TTS neural).
/// Si la API falla (créditos agotados, sin red, 401/429), lanza un error para que
/// el llamador aplique fallback al sintetizador nativo de Apple.
@Observable
public final class ElevenLabsService: NSObject, @unchecked Sendable, AVAudioPlayerDelegate {

    public static let shared = ElevenLabsService()

    // ── API Key ──────────────────────────────────────────────────────────────
    /// Clave privada de ElevenLabs. Vacía = ElevenLabs desactivado (usa Apple TTS de inmediato con 0 latencia).
    public var apiKey: String = ""

    // ── Voz activa ───────────────────────────────────────────────────────────
    private let voiceUserDefaultsKey = "key_elevenlabs_voice_id"

    /// Voz activa guardada en UserDefaults; por defecto .sofia.
    public var selectedVoice: ElevenLabsVoiceOption {
        get {
            let raw = UserDefaults.standard.string(forKey: voiceUserDefaultsKey) ?? ""
            if raw == "XB0fDUnXU5powFXDhCwa" || raw == "21m00Tcm4TlvDq8ikWAM" || raw == "camila" {
                return .valentina
            }
            if raw == "ErXwobaYiN019PkySvjV" {
                return .alonso
            }
            return ElevenLabsVoiceOption(rawValue: raw) ?? .sofia
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: voiceUserDefaultsKey)
        }
    }

    // ── Estado observable ────────────────────────────────────────────────────
    public var isSpeaking: Bool = false

    // ── Internos ─────────────────────────────────────────────────────────────
    private var audioPlayer: AVAudioPlayer?
    private var onFinishedCallback: (() -> Void)?
    private var activeTempURL: URL?
    /// Task de la petición HTTP en vuelo. Cancelarlo aborta la descarga antes de reproducir.
    private var speakTask: Task<Void, Never>?

    private override init() {
        super.init()
    }

    // MARK: - Speak

    /// Sintetiza `text` con ElevenLabs y lo reproduce como MP3.
    /// - Lanza si la API responde con error HTTP (401, 429, 5xx) o si hay problema de red.
    /// - Lanza si el binario recibido no es un MP3 válido.
    /// - Cancellable: si se llama stop() mientras la petición HTTP está en vuelo, se aborta limpiamente.
    public func speak(text: String, onFinished: (() -> Void)? = nil) async throws {
        // Cancelar petición / reproducción previa limpiamente
        speakTask?.cancel()
        speakTask = nil
        await MainActor.run {
            stopInternal()
            self.isSpeaking = true
        }

        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await MainActor.run { self.isSpeaking = false }
            throw URLError(.userAuthenticationRequired)
        }

        // ── Construir petición REST ──────────────────────────────────────────
        let voiceId = selectedVoice.rawValue
        let urlString = "https://api.elevenlabs.io/v1/text-to-speech/\(voiceId)?output_format=mp3_44100_128"
        guard let url = URL(string: urlString) else {
            await MainActor.run { self.isSpeaking = false }
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_multilingual_v2",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // ── Ejecutar la llamada ──────────────────────────────────────────────
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            await MainActor.run { self.isSpeaking = false }
            throw error
        }
        
        // Verificar cancelación después de la petición HTTP (por si stop() fue llamado durante la espera)
        if Task.isCancelled {
            await MainActor.run { self.isSpeaking = false }
            throw CancellationError()
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            await MainActor.run { self.isSpeaking = false }
            throw URLError(.badServerResponse)
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                self.apiKey = ""
            }
            await MainActor.run { self.isSpeaking = false }
            print("ElevenLabsService: HTTP \(httpResponse.statusCode) — activando fallback Apple TTS")
            throw URLError(.badServerResponse)
        }

        // ── Reproducir MP3 en memoria con modo .voiceChat alineado con el reconocimiento de voz ──
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let audioSession = AVAudioSession.sharedInstance()
                do {
                    if audioSession.category != .playAndRecord {
                        try audioSession.setCategory(
                            .playAndRecord,
                            mode: .default,
                            options: [.defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP]
                        )
                    }
                    try audioSession.setActive(true)
                    try? audioSession.overrideOutputAudioPort(.speaker)
                } catch {
                    print("ElevenLabsService: Error AVAudioSession: \(error.localizedDescription)")
                }
                continuation.resume()
            }
        }

        let player: AVAudioPlayer
        do {
            player = try AVAudioPlayer(data: data)
        } catch {
            await MainActor.run { self.isSpeaking = false }
            throw error
        }
        
        player.delegate = self
        player.volume = 1.0
        player.prepareToPlay()

        // Pre-roll para que el hardware de altavoz de iOS se active completamente sin comerse la primera sílaba
        try? await Task.sleep(nanoseconds: 100_000_000)

        await MainActor.run {
            self.onFinishedCallback = onFinished
            self.audioPlayer = player
            self.isSpeaking = true
            player.play()
        }
    }

    // MARK: - Stop

    /// Detiene la reproducción activa de inmediato, cancela la petición HTTP en vuelo y limpia el estado.
    public func stop() {
        speakTask?.cancel()
        speakTask = nil
        stopInternal()
    }

    private func stopInternal() {
        audioPlayer?.stop()
        audioPlayer = nil
        onFinishedCallback = nil
        isSpeaking = false
        cleanTempFile()
    }

    private func cleanTempFile() {
        if let url = activeTempURL {
            try? FileManager.default.removeItem(at: url)
            activeTempURL = nil
        }
    }

    // MARK: - AVAudioPlayerDelegate

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let callback = onFinishedCallback
        Task { @MainActor in
            // Breve margen acústico para vaciar buffers físicos del altavoz y evitar cortar la última palabra
            try? await Task.sleep(nanoseconds: 120_000_000)
            self.audioPlayer = nil
            self.isSpeaking = false
            self.onFinishedCallback = nil
            self.cleanTempFile()
            callback?()
        }
    }

    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("ElevenLabsService: Error de decodificación MP3 — \(error?.localizedDescription ?? "desconocido")")
        let callback = onFinishedCallback
        Task { @MainActor in
            self.audioPlayer = nil
            self.isSpeaking = false
            self.onFinishedCallback = nil
            self.cleanTempFile()
            // Notificamos que terminó para que el overlay siga su flujo (el llamador habrá hecho fallback ya)
            callback?()
        }
    }
}
