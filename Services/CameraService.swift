import Foundation
import AVFoundation
import UIKit // For CALayer, though we might refine this dependency later

class CameraService: NSObject, AVCaptureFileOutputRecordingDelegate {

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer? // To keep a reference

    private var recordingCompletionHandler: ((URL?, Error?) -> Void)?

    // MARK: - Permissions
    func checkPermissions(completion: @escaping (Bool) -> Void) {
        var allPermissionsGranted = true
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break // Already authorized
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if !granted {
                    allPermissionsGranted = false
                }
            }
        default:
            allPermissionsGranted = false // Denied or restricted
        }

        // If video permission was denied or not determined yet, it might affect microphone prompt
        // For simplicity, we request microphone access after video.
        // A more robust implementation might handle these concurrently or guide the user.
        if allPermissionsGranted {
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                break
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    if !granted {
                        allPermissionsGranted = false
                    }
                    completion(allPermissionsGranted)
                }
                return // Return early as this is async
            default:
                allPermissionsGranted = false
            }
        }
        completion(allPermissionsGranted)
    }

    // MARK: - Camera Setup
    func setupCamera(previewView: UIView) {
        captureSession = AVCaptureSession()
        guard let session = captureSession else { return }

        session.beginConfiguration()

        // Video Input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoDeviceInput) else {
            print("Error: Could not create video device input.")
            session.commitConfiguration()
            return
        }
        session.addInput(videoDeviceInput)

        // Audio Input
        guard let audioDevice = AVCaptureDevice.default(for: .audio),
              let audioDeviceInput = try? AVCaptureDeviceInput(device: audioDevice),
              session.canAddInput(audioDeviceInput) else {
            print("Error: Could not create audio device input.")
            // Proceed without audio if necessary, or handle error
            session.commitConfiguration()
            return
        }
        session.addInput(audioDeviceInput)

        // Video Output
        videoOutput = AVCaptureMovieFileOutput()
        guard let output = videoOutput, session.canAddOutput(output) else {
            print("Error: Could not create video output.")
            session.commitConfiguration()
            return
        }
        session.addOutput(output)

        // Limit recording duration to 10 seconds
        output.maxRecordedDuration = CMTimeMake(value: 10, timescale: 1)


        session.commitConfiguration()

        // Preview Layer
        let avPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        avPreviewLayer.videoGravity = .resizeAspectFill
        avPreviewLayer.frame = previewView.bounds // Use bounds of the passed UIView
        previewView.layer.addSublayer(avPreviewLayer)
        self.previewLayer = avPreviewLayer // Keep reference

        // Start session (can be moved to a separate startSession method if needed)
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    func updatePreviewLayerFrame(bounds: CGRect) {
        previewLayer?.frame = bounds
    }


    // MARK: - Recording
    func startRecording(completion: @escaping (URL?, Error?) -> Void) {
        guard let videoOutput = self.videoOutput, !videoOutput.isRecording else {
            completion(nil, CameraError.alreadyRecording)
            return
        }

        self.recordingCompletionHandler = completion

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss" // Corrected format
        let dateString = dateFormatter.string(from: Date())
        let fileName = "\(dateString).mp4"

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videoFileURL = documentsPath.appendingPathComponent(fileName)

        videoOutput.startRecording(to: videoFileURL, recordingDelegate: self)
    }

    func stopRecording() {
        guard let videoOutput = self.videoOutput, videoOutput.isRecording else {
            // If not recording, perhaps call completion with an error or handle silently
            // For now, let's assume it implies the recording finished due to max duration.
            // If startRecording was never called, recordingCompletionHandler would be nil.
            if let completion = recordingCompletionHandler {
                 completion(nil, CameraError.notRecording)
                 recordingCompletionHandler = nil // Reset handler
            }
            return
        }
        videoOutput.stopRecording() // Delegate method fileOutput(_:didFinishRecordingTo:from:error:) will be called
    }

    // MARK: - AVCaptureFileOutputRecordingDelegate
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Error recording video: \(error.localizedDescription)")
            recordingCompletionHandler?(nil, error)
        } else {
            print("Video recorded successfully to: \(outputFileURL.path)")
            recordingCompletionHandler?(outputFileURL, nil)
        }
        recordingCompletionHandler = nil // Reset handler in both cases
    }
}

// MARK: - Custom Errors
enum CameraError: Error, LocalizedError {
    case alreadyRecording
    case notRecording
    case permissionsDenied
    case setupFailed(String)

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
        }
    }
}
