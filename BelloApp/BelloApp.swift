import SwiftUI

@main
struct BelloApp: App {
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Initial setup when the app's main view appears
                    // Request permission early if not determined.
                    // Subsequent calls from scenePhase will handle rescheduling.
                    NotificationService.shared.checkAndScheduleReminder()

                    // Recap generation can also be triggered here or more selectively
                    RecapService.shared.generateWeeklyRecapIfNeeded()
                    RecapService.shared.generateMonthlyRecapIfNeeded()
                }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                print("App became active. Checking and scheduling reminder.")
                NotificationService.shared.checkAndScheduleReminder()
            }
            // else if newPhase == .background {
                // Optional: Perform cleanup or save state if needed
            // }
        }
    }
}
