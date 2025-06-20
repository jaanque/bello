import Foundation
import AVFoundation
import UIKit // For CALayer
import Combine // For ObservableObject and @Published

class CameraService: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {

    // MARK: - Published Properties
    @Published var isRecording: Bool = false
    @Published var arePermissionsGranted: Bool = false
    @Published var lastSavedURL: URL? = nil
    @Published var cameraError: CameraError? = nil

    // MARK: - Private Properties
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer? // To keep a reference for frame updates

    private var recordingCompletionHandler: ((URL?, Error?) -> Void)?

    // MARK: - Permissions
    func checkPermissions() { // Removed completion handler, will update @Published property
        var videoGranted = false
        var audioGranted = false

        let group = DispatchGroup()

        group.enter()
        AVCaptureDevice.requestAccess(for: .video) { granted in
            videoGranted = granted
            group.leave()
        }

        group.enter()
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            audioGranted = granted
            group.leave()
        }

        group.notify(queue: .main) {
            self.arePermissionsGranted = videoGranted && audioGranted
            if !self.arePermissionsGranted {
                self.cameraError = .permissionsDenied
                print("Permissions denied. Video: \(videoGranted), Audio: \(audioGranted)")
            } else {
                print("Permissions granted.")
                // It's good practice to clear errors if permissions are now granted
                if case .permissionsDenied = self.cameraError {
                     self.cameraError = nil
                }
            }
        }
    }

    // Call this at init or when view appears to set initial permission state
    func getInitialPermissionStatus() {
        let videoStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        self.arePermissionsGranted = (videoStatus == .authorized) && (audioStatus == .authorized)
        if !arePermissionsGranted && (videoStatus == .denied || audioStatus == .denied || videoStatus == .restricted || audioStatus == .restricted) {
             self.cameraError = .permissionsDenied
        }
    }


    // MARK: - Camera Setup
    func setupCamera(previewView: UIView) {
        guard arePermissionsGranted else {
            print("Error: Cannot setup camera without permissions.")
            // self.cameraError = .permissionsDenied // This might be set by checkPermissions already
            return
        }

        captureSession = AVCaptureSession()
        guard let session = captureSession else {
            cameraError = .setupFailed("Failed to create AVCaptureSession.")
            return
        }

        session.beginConfiguration()

        // Video Input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoDeviceInput) else {
            print("Error: Could not create video device input.")
            session.commitConfiguration()
            cameraError = .setupFailed("Could not create video device input.")
            return
        }
        session.addInput(videoDeviceInput)

        // Audio Input
        guard let audioDevice = AVCaptureDevice.default(for: .audio),
              let audioDeviceInput = try? AVCaptureDeviceInput(device: audioDevice),
              session.canAddInput(audioDeviceInput) else {
            print("Error: Could not create audio device input.")
            session.commitConfiguration()
            cameraError = .setupFailed("Could not create audio device input. Audio might not be recorded.")
            // Depending on requirements, may proceed without audio or fully fail.
            // For now, proceeding without audio input if it fails.
            // If audio is critical, return here.
            // The audio input is already added by the guard statement if successful.
            // The following 'if let' block was redundant and contained the force unwrap.
        }
        // else {
        //    // This means audioDevice was non-nil, audioDeviceInput was created, and session.canAddInput was true
        //    // and session.addInput(audioDeviceInput) was already called by the guard.
        //    // No further action needed here for adding the input.
        // }


        // Video Output
        videoOutput = AVCaptureMovieFileOutput()
        guard let output = videoOutput, session.canAddOutput(output) else {
            print("Error: Could not create video output.")
            session.commitConfiguration()
            cameraError = .setupFailed("Could not create video output.")
            return
        }
        session.addOutput(output)

        // Limit recording duration to 10 seconds
        output.maxRecordedDuration = CMTimeMake(value: 10, timescale: 1)

        session.commitConfiguration()

        // Preview Layer - ensure it's created on the main thread if it interacts with UI directly
        DispatchQueue.main.async {
            let avPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
            avPreviewLayer.videoGravity = .resizeAspectFill
            avPreviewLayer.frame = previewView.bounds // Use bounds of the passed UIView
            // Remove old preview layer if any
            self.previewLayer?.removeFromSuperlayer()
            previewView.layer.addSublayer(avPreviewLayer)
            self.previewLayer = avPreviewLayer // Keep reference
        }


        // Start session (can be moved to a separate startSession method if needed)
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    func updatePreviewLayerFrame(bounds: CGRect) {
        DispatchQueue.main.async { // Ensure UI updates are on main thread
            self.previewLayer?.frame = bounds
        }
    }

    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession?.stopRunning()
        }
    }


    // MARK: - Recording
    func startRecording(completion: @escaping (URL?, Error?) -> Void) {
        guard let videoOutput = self.videoOutput else {
            cameraError = .setupFailed("Video output not available.")
            completion(nil, cameraError)
            return
        }

        guard !videoOutput.isRecording else {
            cameraError = .alreadyRecording
            completion(nil, cameraError)
            return
        }

        self.recordingCompletionHandler = completion
        self.cameraError = nil // Clear previous errors

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = dateFormatter.string(from: Date())
        let fileName = "\(dateString).mp4"

        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            cameraError = .setupFailed("Could not access documents directory.")
            completion(nil, cameraError)
            return
        }
        let videoFileURL = documentsPath.appendingPathComponent(fileName)

        videoOutput.startRecording(to: videoFileURL, recordingDelegate: self)
        self.isRecording = true // Update published property
    }

    func stopRecording() {
        guard let videoOutput = self.videoOutput, videoOutput.isRecording else {
            // This case should ideally not be hit if UI is synced with isRecording state.
            // If it is, it implies an issue or recording stopped due to max duration.
            // The delegate method will handle the completion handler.
            if !isRecording { // If our state already reflects not recording
                 recordingCompletionHandler?(nil, CameraError.notRecording)
                 recordingCompletionHandler = nil
            } else {
                // If videoOutput.isRecording is false but self.isRecording is true,
                // it means AVFoundation stopped it (e.g. max duration).
                // The delegate method will be called.
            }
            // self.isRecording = false; // Delegate will set this
            return
        }
        videoOutput.stopRecording() // Delegate method fileOutput(_:didFinishRecordingTo:from:error:) will be called
    }

    // MARK: - AVCaptureFileOutputRecordingDelegate
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async { // Ensure published properties are updated on main thread
            self.isRecording = false
            if let error = error {
                print("Error recording video: \(error.localizedDescription)")
                self.cameraError = .underlyingError(error) // Publish the error
                self.recordingCompletionHandler?(nil, self.cameraError)
            } else {
                print("Video recorded successfully to: \(outputFileURL.path)")
                self.lastSavedURL = outputFileURL // Publish the URL
                self.recordingCompletionHandler?(outputFileURL, nil)
            }
            self.recordingCompletionHandler = nil // Reset handler in both cases
        }
    }
}

// MARK: - Custom Errors
// CameraError enum was already defined, ensure it includes .underlyingError if not present
enum CameraError: Error, LocalizedError {
    case alreadyRecording
    case notRecording
    case permissionsDenied
    case setupFailed(String)
    case underlyingError(Error) // Ensure this case is present

    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Camera is already recording."
        case .notRecording:
            return "Camera is not currently recording."
        case .permissionsDenied:
            return "Camera and/or Microphone permissions were denied."
        case .setupFailed(let reason):
            return "Camera setup failed: \(reason)"
        case .underlyingError(let error):
            return "An error occurred during camera operation: \(error.localizedDescription)"
        }
    }
}
