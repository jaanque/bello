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
    func generateRecap(videos: [Video], outputURL: URL) async throws -> URL {
        if videos.isEmpty {
            throw RecapError.noVideosForPeriod
        }

        // Check if file already exists at outputURL
        if fileManager.fileExists(atPath: outputURL.path) {
            // This check is more for direct calls to generateRecap.
            // The generateWeekly/MonthlyRecapIfNeeded methods should handle this before calling.
            print("Recap file already exists at \(outputURL.path). Generation skipped by generateRecap itself.")
            throw RecapError.fileExists(outputURL)
        }

        let composition = AVMutableComposition()
        var insertTime = CMTime.zero

        for video in videos {
            let asset = AVURLAsset(url: video.url)
            do {
                // Check for video tracks
                guard let assetVideoTrack = try await asset.loadTrackContents(withMediaType: .video).first else {
                    print("Warning: No video track found in \(video.url.lastPathComponent). Skipping this video.")
                    continue
                }
                // Check for audio tracks (optional, but good to include if present)
                let assetAudioTrack = try await asset.loadTrackContents(withMediaType: .audio).first

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
                // Or, rethrow the error to fail the entire recap generation:
                // throw RecapError.underlyingError(error)
                continue
            }
        }

        // Check if any tracks were actually added
        if composition.tracks.isEmpty {
            throw RecapError.compositionFailed("No valid video tracks found in the provided videos.")
        }

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw RecapError.exportFailed("Could not create AVAssetExportSession.")
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        // Perform export asynchronously
        await exportSession.export()

        // Check export status
        switch exportSession.status {
        case .completed:
            return outputURL
        case .failed:
            let error = exportSession.error ?? RecapError.exportFailed("Unknown export error")
            throw RecapError.underlyingError(error)
        case .cancelled:
            throw RecapError.exportFailed("Export was cancelled.")
        default:
            throw RecapError.exportFailed("Export status: \(exportSession.status.rawValue)")
        }
    }

    // MARK: - Recap Generation Triggers & Naming

    func generateWeeklyRecapIfNeeded(for targetDate: Date = Date()) async throws {
        let calendar = Calendar.current
        let year = calendar.component(.yearForWeekOfYear, from: targetDate)
        let weekOfYear = calendar.component(.weekOfYear, from: targetDate)

        do {
            try await generateRecapForWeek(weekOfYear: weekOfYear, year: year, type: .current)
            print("Successfully generated current weekly recap for \(year)-W\(weekOfYear).")
        } catch RecapError.noVideosForPeriod {
            print("No videos for current week (\(year)-W\(weekOfYear)), trying last week.")
            if let previousWeekDate = calendar.date(byAdding: .weekOfYear, value: -1, to: targetDate) {
                let prevYear = calendar.component(.yearForWeekOfYear, from: previousWeekDate)
                let prevWeekOfYear = calendar.component(.weekOfYear, from: previousWeekDate)
                try await generateRecapForWeek(weekOfYear: prevWeekOfYear, year: prevYear, type: .previous)
                print("Successfully generated previous weekly recap for \(prevYear)-W\(prevWeekOfYear).")
            }
        } catch RecapError.fileExists(let url) {
            print("Weekly recap already exists: \(url.path)")
        } catch {
            // Other errors rethrown
            throw error
        }
    }

    enum RecapWeekType { case current, previous }

    private func generateRecapForWeek(weekOfYear: Int, year: Int, type: RecapWeekType) async throws {
        guard let documentsDirectory = videoStorageService.getVideosDirectory() else {
            throw RecapError.compositionFailed("Could not get documents directory.")
        }
        let weekString = String(format: "%04d-W%02d", year, weekOfYear)
        let outputURL = documentsDirectory.appendingPathComponent("recap_week_\(weekString).mp4")

        if fileManager.fileExists(atPath: outputURL.path) {
            throw RecapError.fileExists(outputURL)
        }

        let videosForWeek = getVideos(forWeek: weekOfYear, year: year)
        if videosForWeek.isEmpty {
            throw RecapError.noVideosForPeriod
        }

        print("Attempting to generate \(type) weekly recap for \(weekString) with \(videosForWeek.count) videos.")
        _ = try await generateRecap(videos: videosForWeek, outputURL: outputURL)
    }

    func generateMonthlyRecapIfNeeded(for targetDate: Date = Date()) async throws {
        let calendar = Calendar.current
        guard let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: targetDate) else {
            print("Error: Could not calculate previous month from targetDate.")
            // Or throw an error
            throw RecapError.compositionFailed("Could not calculate previous month.")
        }

        let year = calendar.component(.year, from: previousMonthDate)
        let month = calendar.component(.month, from: previousMonthDate)

        let monthString = String(format: "%04d-%02d", year, month)
        guard let documentsDirectory = videoStorageService.getVideosDirectory() else {
            throw RecapError.compositionFailed("Could not access documents directory.")
        }
        let outputURL = documentsDirectory.appendingPathComponent("recap_month_\(monthString).mp4")

        if fileManager.fileExists(atPath: outputURL.path) {
            print("Monthly recap for \(monthString) already exists: \(outputURL.path)")
            // No error needed here, just means it's done.
            // Or throw RecapError.fileExists(outputURL) if caller needs to know.
            // For "IfNeeded" semantics, not throwing an error for pre-existence is fine.
            return
        }

        let videosForMonth = getVideos(forMonth: month, year: year)
        if videosForMonth.isEmpty {
            print("No videos found for month \(monthString) to generate recap.")
            // No error needed here either for "IfNeeded".
            return
        }

        print("Attempting to generate monthly recap for \(monthString) with \(videosForMonth.count) videos.")
        _ = try await generateRecap(videos: videosForMonth, outputURL: outputURL)
        print("Successfully generated monthly recap: \(outputURL.path)")
    }

    // MARK: - Date Helpers (Can be expanded or moved to a dedicated DateUtil)

    // Calendar.current.component(.weekOfYear, from: date) is good for week number.
    // Calendar.current.component(.yearForWeekOfYear, from: date) for year of that week.
    // For previous month, Calendar.current.date(byAdding: .month, value: -1, to: date) is good.
}

// Extension to make Video struct's URL assets awaitable for track loading
extension AVURLAsset {
    func loadTrackContents(withMediaType mediaType: AVMediaType) async throws -> [AVAssetTrack] {
        try await self.load(.tracks).filter { $0.mediaType == mediaType }
    }
}
