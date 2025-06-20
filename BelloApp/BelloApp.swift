import SwiftUI

@main
struct BelloApp: App {
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Initial setup when the app's main view appears
                    NotificationService.shared.checkAndScheduleReminder()

                    Task {
                        do {
                            try await RecapService.shared.generateWeeklyRecapIfNeeded()
                            try await RecapService.shared.generateMonthlyRecapIfNeeded()
                            print("Recap generation check completed on app appear.")
                        } catch {
                            print("Error generating recaps on app appear: \(error.localizedDescription)")
                        }
                    }
                }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                print("App became active. Checking and scheduling reminder.")
                NotificationService.shared.checkAndScheduleReminder()

                Task {
                    do {
                        try await RecapService.shared.generateWeeklyRecapIfNeeded()
                        try await RecapService.shared.generateMonthlyRecapIfNeeded()
                        print("Recap generation check completed on app active.")
                    } catch {
                        print("Error generating recaps on app active: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
