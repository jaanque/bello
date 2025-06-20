import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let videoURL: URL
    @Environment(\.dismiss) var dismiss // To handle dismissal if a custom button is added

    var body: some View {
        VStack {
            // The AVPlayerViewController needs a player, which we create with the URL
            VideoPlayer(player: AVPlayer(url: videoURL))
                .edgesIgnoringSafeArea(.all) // Make player full screen or extend to safe areas

            // Optional: Add a custom "Done" button if swipe-to-dismiss is not sufficient
            // Button("Done") {
            //     dismiss() // Dismiss the sheet
            // }
            // .padding()
        }
        .onAppear {
            // Optional: Configure audio session for playback if needed
            // For example, set category to .playback
            // try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            // try? AVAudioSession.sharedInstance().setActive(true)
        }
        .onDisappear {
            // Optional: Reset audio session or perform cleanup
            // try? AVAudioSession.sharedInstance().setActive(false)
        }
    }
}

// Preview Provider
struct VideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        // You need a valid video URL for the preview to work.
        // This could be a placeholder or a sample video in your bundle.
        // For now, let's assume a placeholder or handle the case where URL might be invalid.
        if let sampleURL = Bundle.main.url(forResource: "sampleVideo", withExtension: "mp4") {
            VideoPlayerView(videoURL: sampleURL)
        } else {
            Text("VideoPlayerView: No sample video found for preview.")
        }
    }
}
