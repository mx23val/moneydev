import SwiftUI
import SwiftData

@main
struct MoneyDevApp: App {
    let modelContainer: ModelContainer
    @State private var viewModel: ExpenseViewModel
    
    init() {
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
    
    var body: some Scene {
        WindowGroup {
            ExpenseHomeScreen(viewModel: viewModel)
                .preferredColorScheme(.dark)
                .modelContainer(modelContainer)
                .task {
                    // Inicializar permisos de notificaciones si están activas
                    if viewModel.financialSummary.notificationsEnabled {
                        _ = await ReminderScheduler.requestNotificationPermission()
                        ReminderScheduler.scheduleDailyReminder()
                    }
                }
        }
    }
}
