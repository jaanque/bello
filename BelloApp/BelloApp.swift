import SwiftUI

@main
struct BelloApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Attempt to generate recaps when the app's main content appears
                    // This is a simple trigger for now; more sophisticated triggers might be needed later.
                    RecapService.shared.generateWeeklyRecapIfNeeded()
                    RecapService.shared.generateMonthlyRecapIfNeeded()
                }
        }
    }
}
