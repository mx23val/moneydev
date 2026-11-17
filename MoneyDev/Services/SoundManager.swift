import Foundation
import AVFoundation

public final class SoundManager: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
    public static let shared = SoundManager()
    
    private var activePlayers: [AVAudioPlayer] = []
    private let lock = NSLock()
    
    private override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        DispatchQueue.global(qos: .utility).async {
            do {
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("SoundManager: No se pudo configurar AVAudioSession: \(error)")
            }
        }
    }
    
    public func playSoundForType(_ type: TransactionType, isSoundEnabled: Bool = true) {
        guard isSoundEnabled else { return }
        let soundName = (type == .income) ? "sound_ingreso" : "sound_gasto"
        playAudioFile(named: soundName)
    }
    
    public func playExpenseSound(isSoundEnabled: Bool = true) {
        playSoundForType(.expense, isSoundEnabled: isSoundEnabled)
    }
    
    public func playIncomeSound(isSoundEnabled: Bool = true) {
        playSoundForType(.income, isSoundEnabled: isSoundEnabled)
    }
    
    private func playAudioFile(named name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") ??
                        Bundle.main.url(forResource: "Resources/\(name)", withExtension: "mp3") else {
            // Intentar buscar en rutas alternativas de recursos locales
            let cwd = FileManager.default.currentDirectoryPath
            let altPath = (cwd as NSString).appendingPathComponent("MoneyDev-iOS/Resources/\(name).mp3")
            if FileManager.default.fileExists(atPath: altPath) {
                let altUrl = URL(fileURLWithPath: altPath)
                playFromUrl(altUrl)
            } else {
                print("SoundManager: Archivo \(name).mp3 no encontrado")
            }
            return
        }
        playFromUrl(url)
    }
    
    private func playFromUrl(_ url: URL) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.volume = 1.0
            player.prepareToPlay()
            
            lock.lock()
            activePlayers.append(player)
            lock.unlock()
            
            player.play()
        } catch {
            print("SoundManager: Error reproduciendo \(url.lastPathComponent): \(error)")
        }
    }
    
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        lock.lock()
        activePlayers.removeAll(where: { $0 === player })
        lock.unlock()
    }
}
