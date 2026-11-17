import SwiftUI
import SwiftData

@main
struct MoneyDevApp: App {
    let modelContainer: ModelContainer
    @State private var viewModel: ExpenseViewModel
    
    init() {
        Self.performCleanInstallPurgeIfNeeded()
        
        do {
            let schema = Schema([
                Wallet.self,
                Transaction.self,
                UserProfile.self,
                FixedExpense.self
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            self.modelContainer = container
            
            let repo = ExpenseRepository(modelContainer: container)
            _viewModel = State(initialValue: ExpenseViewModel(repository: repo))
        } catch {
            fatalError("No se pudo inicializar ModelContainer de SwiftData: \(error)")
        }
    }
    
    /// Detecta si es una instalación limpia/reinstalación y purga caché y Keychain
    private static func performCleanInstallPurgeIfNeeded() {
        let installKey = "key_moneydev_installed_run"
        if !UserDefaults.standard.bool(forKey: installKey) {
            // 1. Purgar credenciales huérfanas en Keychain
            let secClasses = [kSecClassGenericPassword, kSecClassInternetPassword, kSecClassCertificate, kSecClassKey, kSecClassIdentity]
            for secClass in secClasses {
                let query = [kSecClass as String: secClass]
                SecItemDelete(query as CFDictionary)
            }
            
            // 2. Limpiar Cachés de red
            URLCache.shared.removeAllCachedResponses()
            
            // 3. Limpiar directorio Caches temporal
            if let cacheUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
                try? FileManager.default.removeItem(at: cacheUrl)
                try? FileManager.default.createDirectory(at: cacheUrl, withIntermediateDirectories: true)
            }
            
            // 4. Marcar como instalado
            UserDefaults.standard.set(true, forKey: installKey)
        }
    }
    
    @Environment(\.scenePhase) private var scenePhase
    private var securityManager = AppSecurityManager.shared
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if !viewModel.financialSummary.hasCompletedOnboarding {
                        InteractiveOnboardingDialog(viewModel: viewModel)
                    } else {
                        ExpenseHomeScreen(viewModel: viewModel)
                    }
                }
                .opacity(securityManager.isLockEnabled && securityManager.isAppLocked ? 0 : 1)
                .allowsHitTesting(!(securityManager.isLockEnabled && securityManager.isAppLocked))
                
                // Pantalla de Bloqueo Bancario (Exclusiva y 100% Ocupante)
                if securityManager.isLockEnabled && securityManager.isAppLocked {
                    AppLockScreenView(viewModel: viewModel)
                        .transition(.opacity)
                        .zIndex(999)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: viewModel.financialSummary.hasCompletedOnboarding)
            .animation(.easeInOut(duration: 0.18), value: securityManager.isAppLocked)
            .preferredColorScheme(.dark)
            .modelContainer(modelContainer)
            .onOpenURL { url in
                handleIncomingDeepLink(url)
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    securityManager.appDidEnterBackground()
                case .active:
                    Task { @MainActor in
                        await AppIconManager.synchronizeAppIcon()
                    }
                    securityManager.appDidBecomeActive {
                        if !MoneyBotLiveVoiceSessionManager.shared.isLiveSessionActive {
                            viewModel.resetNavigationToHomeAndDismissAll()
                        }
                        viewModel.refreshData()
                    }
                default:
                    break
                }
            }
            .task {
                await AppIconManager.synchronizeAppIcon()
                
                // Solicitar permisos de notificaciones proactivamente al instalar la app
                // para que MoneyBot Live Voice no muestre un diálogo redundante después.
                _ = await ReminderScheduler.requestNotificationPermission()
                
                // Inicializar recordatorios si están activos
                if viewModel.financialSummary.notificationsEnabled {
                    ReminderScheduler.updateDailyReminders(
                        transactions: viewModel.transactions,
                        notificationsEnabled: true
                    )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MoneyDev.AppIconDidChange"))) { _ in
                if viewModel.financialSummary.notificationsEnabled {
                    ReminderScheduler.updateDailyReminders(
                        transactions: viewModel.transactions,
                        notificationsEnabled: true
                    )
                }
            }
        }
    }
    
    private func handleIncomingDeepLink(_ url: URL) {
        guard url.scheme == "moneydev" else { return }
        
        let host = url.host ?? ""
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let walletIdStr = components?.queryItems?.first(where: { $0.name == "walletId" || $0.name == "id" })?.value
        let walletId = walletIdStr.flatMap { Int64($0) }
        
        if let walletId = walletId {
            viewModel.selectWallet(walletId)
            viewModel.targetDictationWalletId = walletId
        }
        
        switch host {
        case "voice-dictation", "dictate":
            viewModel.shouldOpenVoiceDictation = true
        case "live-voice":
            viewModel.shouldOpenLiveVoice = true
        case "wallet":
            viewModel.activeTab = 0
        default:
            break
        }
    }
}
