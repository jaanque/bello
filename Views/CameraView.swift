import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var cameraService = CameraService()
    @State private var isRecording = false
    @State private var showPermissionsAlert = false
    @State private var lastRecordedURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        VStack {
            if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
            }

            if let url = lastRecordedURL {
                Text("Last recording: \(url.lastPathComponent)")
                    .padding()
                // In a real app, you might offer to play this or share it.
            }

            CameraPreview(cameraService: cameraService)
                .frame(height: 300) // Adjust as needed
                .onAppear {
                    cameraService.checkPermissions { granted in
                        if granted {
                            // Setup camera once permissions are confirmed
                            // The previewView for setupCamera will be the underlying UIView of CameraPreview
                        } else {
                            showPermissionsAlert = true
                            errorMessage = "Camera and/or microphone permissions denied."
                        }
                    }
                }
                .alert("Permissions Denied", isPresented: $showPermissionsAlert) {
                    Button("OK", role: .cancel) { }
                    // Optionally, add a button to open app settings
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        Button("Open Settings") {
                            UIApplication.shared.open(url)
                        }
                    }
                } message: {
                    Text("Bello needs access to your camera and microphone to record videos. Please enable access in Settings.")
                }


            Button(action: {
                toggleRecording()
            }) {
                Text(isRecording ? "Stop Recording" : "Start Recording")
                    .padding()
                    .background(isRecording ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
        }
        .navigationTitle("Record Video")
    }

    private func toggleRecording() {
        if isRecording {
            cameraService.stopRecording()
            // isRecording will be set to false in the completion handler of startRecording
            // or if stopRecording is called explicitly before max duration
        } else {
            errorMessage = nil // Clear previous errors
            lastRecordedURL = nil // Clear previous URL
            cameraService.startRecording { url, error in
                DispatchQueue.main.async { // Ensure UI updates on main thread
                    self.isRecording = false // Recording stopped (either success, error, or max duration)
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        print("Recording failed: \(error)")
                    } else if let url = url {
                        self.lastRecordedURL = url
                        print("Recording finished, URL: \(url.path)")
                    } else {
                        // This case might happen if stopRecording was called but no URL/error (e.g. max duration reached and handled by delegate)
                        // Or if something unexpected happened in CameraService
                        print("Recording stopped with no URL and no error.")
                    }
                }
            }
            // Only set isRecording to true if startRecording itself doesn't throw an immediate error.
            // The actual recording state is managed by AVFoundation.
            // For UI purposes, we can set it to true here, and the completion will set it to false.
            self.isRecording = true
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var cameraService: CameraService // Use ObservedObject for reference types

    func makeUIView(context: Context) -> UIView {
        let uiView = UIView(frame: .zero) // Frame will be managed by SwiftUI layout
        cameraService.setupCamera(previewView: uiView)
        return uiView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Update the preview layer's frame if the view's bounds change
        cameraService.updatePreviewLayerFrame(bounds: uiView.bounds)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        // Optional: Clean up resources if needed when the view is removed
        // For example, stop the camera session if it's not managed elsewhere.
        // cameraService.stopSession() // You'd need to implement this in CameraService
    }
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { // Wrap in NavigationView for title
            CameraView()
        }
    }
}
