import SwiftUI
import UIKit

struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    @Environment(\.dismiss) var dismiss // To dismiss the sheet after an action

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        // Optional: Exclude some activity types
        // controller.excludedActivityTypes = [ .postToFacebook, .postToTwitter ]

        // Handle completion for dismissing the sheet
        // This is important because UIActivityViewController doesn't always dismiss its parent automatically
        controller.completionWithItemsHandler = { (activityType, completed, returnedItems, error) in
            // Dismiss the sheet hosting this ActivityView
            // Important: Ensure this runs on the main thread if it involves UI changes outside of what UIKit handles
            DispatchQueue.main.async {
                self.dismiss()
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Nothing to update here
    }
}

// Preview (optional, might be hard to make it fully interactive in Xcode Previews)
struct ActivityView_Previews: PreviewProvider {
    static var previews: some View {
        // Example of how to use it if you had a button in another view
        // For the preview itself, it won't show much unless triggered
        VStack {
            Text("Tap button to show share sheet (won't work in static preview)")
            Button("Share Something") {
                // In a real view, you'd use a @State variable to present this
            }
            // .sheet(isPresented: .constant(true)) { // Example for previewing sheet
            //     ActivityView(activityItems: ["Check out this cool app!"])
            // }
        }

    }
}
