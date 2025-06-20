import Foundation
import AVFoundation

// Custom Errors for RecapService
enum RecapError: Error, LocalizedError {
    case noVideosForPeriod
    case compositionFailed(String)
    case exportFailed(String)
    case underlyingError(Error)
    case fileExists(URL)

    var errorDescription: String? {
        switch self {
        case .noVideosForPeriod:
            return "No videos were found for the specified period to generate a recap."
        case .compositionFailed(let reason):
            return "Video composition failed: \(reason)"
        case .exportFailed(let reason):
            return "Video export failed: \(reason)"
        case .underlyingError(let error):
            return "An underlying error occurred: \(error.localizedDescription)"
        case .fileExists(let url):
            return "A recap file already exists at \(url.path)."
        }
    }
}

class RecapService {
    static let shared = RecapService()
    private let videoStorageService: VideoStorageService
    private let fileManager = FileManager.default

    init(videoStorageService: VideoStorageService = .shared) {
        self.videoStorageService = videoStorageService
    }

    // MARK: - Video Fetching Logic

    /// Fetches daily videos for a specific week and year.
    /// Week numbers are based on ISO 8601 standard (Monday as first day).
    func getVideos(forWeek weekOfYear: Int, year: Int) -> [Video] {
        let allDailyVideos = videoStorageService.fetchDailyVideos()
        let calendar = Calendar.current // Using current calendar, often ISO 8601 for week numbers

        return allDailyVideos.filter { video in
            let videoDateComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: video.date)
            return videoDateComponents.yearForWeekOfYear == year && videoDateComponents.weekOfYear == weekOfYear
        }.sorted { $0.date < $1.date } // Ensure chronological order for composition
    }

    /// Fetches daily videos for a specific month and year.
    func getVideos(forMonth month: Int, year: Int) -> [Video] {
        let allDailyVideos = videoStorageService.fetchDailyVideos()
        let calendar = Calendar.current

        return allDailyVideos.filter { video in
            let videoDateComponents = calendar.dateComponents([.year, .month], from: video.date)
            return videoDateComponents.year == year && videoDateComponents.month == month
        }.sorted { $0.date < $1.date } // Ensure chronological order
    }

    // MARK: - Recap Video Composition

    /// Generates a recap video from an array of Video objects.
    func generateRecap(videos: [Video], outputURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        if videos.isEmpty {
            completion(.failure(RecapError.noVideosForPeriod))
            return
        }

        // Check if file already exists at outputURL
        if fileManager.fileExists(atPath: outputURL.path) {
            // This check is more for direct calls to generateRecap.
            // The generateWeekly/MonthlyRecapIfNeeded methods should handle this before calling.
            print("Recap file already exists at \(outputURL.path). Generation skipped by generateRecap itself.")
            completion(.failure(RecapError.fileExists(outputURL)))
            return
        }

        let composition = AVMutableComposition()
        var insertTime = CMTime.zero

        for video in videos {
            let asset = AVURLAsset(url: video.url)
            do {
                // Check for video tracks
                guard let assetVideoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                    print("Warning: No video track found in \(video.url.lastPathComponent). Skipping this video.")
                    continue
                }
                // Check for audio tracks (optional, but good to include if present)
                let assetAudioTrack = try await asset.loadTracks(withMediaType: .audio).first

                // Add video track
                let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
                try videoTrack?.insertTimeRange(CMTimeRangeMake(start: .zero, duration: assetVideoTrack.timeRange.duration),
                                               of: assetVideoTrack,
                                               at: insertTime)

                // Add audio track if present
                if let assetAudioTrack = assetAudioTrack {
                    let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                    try audioTrack?.insertTimeRange(CMTimeRangeMake(start: .zero, duration: assetAudioTrack.timeRange.duration), // Use audio track's duration if different
                                                   of: assetAudioTrack,
                                                   at: insertTime)
                }

                // Update insert time for the next asset, using the video track's duration
                insertTime = CMTimeAdd(insertTime, try await asset.load(.duration)) // Use overall asset duration

            } catch {
                print("Error processing asset \(video.url.lastPathComponent): \(error.localizedDescription)")
                // Decide if one bad asset should fail the whole recap or just be skipped.
                // For now, let's skip and continue. If all fail, it'll result in an empty/short video or error later.
                continue
            }
        }

        // Check if any tracks were actually added
        if composition.tracks.isEmpty {
            completion(.failure(RecapError.compositionFailed("No valid video tracks found in the provided videos.")))
            return
        }

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            completion(.failure(RecapError.exportFailed("Could not create AVAssetExportSession.")))
            return
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    completion(.success(outputURL))
                case .failed:
                    let error = exportSession.error ?? RecapError.exportFailed("Unknown export error")
                    completion(.failure(RecapError.underlyingError(error)))
                case .cancelled:
                    completion(.failure(RecapError.exportFailed("Export was cancelled.")))
                default:
                    completion(.failure(RecapError.exportFailed("Export status: \(exportSession.status.rawValue)")))
                }
            }
        }
    }

    // MARK: - Recap Generation Triggers & Naming

    func generateWeeklyRecapIfNeeded(for targetDate: Date = Date()) {
        let calendar = Calendar.current // Ensure this matches week definition used in getVideos

        // Let's define "last completed week" as the week ending before the start of the current week.
        // Or, for simplicity now, "current week" and if no videos, it won't generate.
        // Product spec: "visible if existe recap para la semana actual o pasada"
        // Let's try for the week of the targetDate first.

        let year = calendar.component(.yearForWeekOfYear, from: targetDate)
        let weekOfYear = calendar.component(.weekOfYear, from: targetDate)

        generateRecapForWeek(weekOfYear: weekOfYear, year: year, type: .current) { result in
            // Handle result - e.g. log success or failure
             switch result {
            case .success(let url):
                print("Successfully generated current weekly recap: \(url.path)")
            case .failure(RecapError.fileExists(let url)):
                print("Current weekly recap already exists: \(url.path)")
            case .failure(RecapError.noVideosForPeriod):
                print("No videos for current week (\(year)-W\(weekOfYear)), trying last week.")
                // If current week had no videos or failed, try previous week
                if let previousWeekDate = calendar.date(byAdding: .weekOfYear, value: -1, to: targetDate) {
                    let prevYear = calendar.component(.yearForWeekOfYear, from: previousWeekDate)
                    let prevWeekOfYear = calendar.component(.weekOfYear, from: previousWeekDate)
                    self.generateRecapForWeek(weekOfYear: prevWeekOfYear, year: prevYear, type: .previous) { prevResult in
                         switch prevResult {
                        case .success(let url):
                            print("Successfully generated previous weekly recap: \(url.path)")
                        case .failure(RecapError.fileExists(let url)):
                            print("Previous weekly recap already exists: \(url.path)")
                        case .failure(let error):
                            print("Failed to generate previous weekly recap: \(error.localizedDescription)")
                        }
                    }
                }
            case .failure(let error):
                print("Failed to generate current weekly recap: \(error.localizedDescription)")
            }
        }
    }

    enum RecapWeekType { case current, previous }

    private func generateRecapForWeek(weekOfYear: Int, year: Int, type: RecapWeekType, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let documentsDirectory = videoStorageService.getVideosDirectory() else {
            completion(.failure(RecapError.compositionFailed("Could not get documents directory.")))
            return
        }
        let weekString = String(format: "%04d-W%02d", year, weekOfYear)
        let outputURL = documentsDirectory.appendingPathComponent("recap_week_\(weekString).mp4")

        if fileManager.fileExists(atPath: outputURL.path) {
            completion(.failure(RecapError.fileExists(outputURL)))
            return
        }

        let videosForWeek = getVideos(forWeek: weekOfYear, year: year)
        if videosForWeek.isEmpty {
            completion(.failure(RecapError.noVideosForPeriod))
            return
        }

        print("Attempting to generate \(type) weekly recap for \(weekString) with \(videosForWeek.count) videos.")
        generateRecap(videos: videosForWeek, outputURL: outputURL, completion: completion)
    }


    func generateMonthlyRecapIfNeeded(for targetDate: Date = Date()) {
        let calendar = Calendar.current

        // "Visible sólo si existe recap para el mes anterior"
        // So, we always aim to generate for the *previous* month.
        guard let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: targetDate) else {
            print("Error: Could not calculate previous month from targetDate.")
            return
        }

        let year = calendar.component(.year, from: previousMonthDate)
        let month = calendar.component(.month, from: previousMonthDate)

        let monthString = String(format: "%04d-%02d", year, month)
        guard let documentsDirectory = videoStorageService.getVideosDirectory() else {
            print("Recap Error: Could not access documents directory.")
            // Consider a completion handler if this needs to be communicated
            return
        }
        let outputURL = documentsDirectory.appendingPathComponent("recap_month_\(monthString).mp4")

        if fileManager.fileExists(atPath: outputURL.path) {
            print("Monthly recap for \(monthString) already exists: \(outputURL.path)")
            // Call completion if this method had one: completion(.failure(RecapError.fileExists(outputURL)))
            return
        }

        let videosForMonth = getVideos(forMonth: month, year: year)
        if videosForMonth.isEmpty {
            print("No videos found for month \(monthString) to generate recap.")
            // Call completion if this method had one: completion(.failure(RecapError.noVideosForPeriod))
            return
        }

        print("Attempting to generate monthly recap for \(monthString) with \(videosForMonth.count) videos.")
        generateRecap(videos: videosForMonth, outputURL: outputURL) { result in
            // Handle result - e.g. log success or failure
            switch result {
            case .success(let url):
                print("Successfully generated monthly recap: \(url.path)")
            case .failure(RecapError.fileExists(_)):
                 // This case should ideally be caught above, but good to have the enum case
                print("Monthly recap for \(monthString) already existed (checked again inside generateRecap).")
            case .failure(let error):
                print("Failed to generate monthly recap for \(monthString): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Date Helpers (Can be expanded or moved to a dedicated DateUtil)

    // Calendar.current.component(.weekOfYear, from: date) is good for week number.
    // Calendar.current.component(.yearForWeekOfYear, from: date) for year of that week.
    // For previous month, Calendar.current.date(byAdding: .month, value: -1, to: date) is good.
}

// Extension to make Video struct's URL assets awaitable for track loading
extension AVURLAsset {
    func loadTracks(withMediaType mediaType: AVMediaType) async throws -> [AVAssetTrack] {
        try await self.load(.tracks).filter { $0.mediaType == mediaType }
    }
}
