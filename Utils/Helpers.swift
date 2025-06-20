import Foundation
import SwiftUI

// This file can contain utility functions, extensions, and constants
// that are used across the application.

// Example of a utility function:
func formatDate(date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

// Example of an extension:
extension Color {
    // static let customBlue = Color("CustomBlue") // Assuming CustomBlue is defined in Assets.xcassets
}

// Example of a constant:
// struct AppConstants {
//     static let defaultTimeout: TimeInterval = 30.0
// }
