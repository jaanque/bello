import Foundation
import UIKit // For UIDevice, if needed for future simulator checks, can be removed if not directly used

class VideoStorageService {

    static let shared = VideoStorageService() // Singleton for easy access if needed

    private let fileManager = FileManager.default
    private let dailyVideoFilenameRegex = #"^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.mp4$"
    private let recapVideoFilenameRegex = #"^recap_.*\.mp4$"


    // Date formatter for parsing filenames
    private lazy var filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        formatter.locale = Locale(identifier: "en_US_POSIX") // Important for consistency
        formatter.timeZone = TimeZone.current // Assuming filenames use local time
        return formatter
    }()

    // MARK: - Public Methods

    /// Fetches all daily video recordings from the documents directory.
    /// - Returns: An array of `Video` objects, sorted by date descending (newest first).
    func fetchDailyVideos() -> [Video] {
        guard let documentsDirectory = getVideosDirectory() else {
            print("Error: Could not access documents directory.")
            return []
        }

        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory,
                                                               includingPropertiesForKeys: nil,
                                                               options: .skipsHiddenFiles)

            var videos: [Video] = []
            for url in fileURLs {
                let filename = url.lastPathComponent

                // Check if it's a daily video and not a recap video
                if filename.range(of: dailyVideoFilenameRegex, options: .regularExpression) != nil &&
                   filename.range(of: recapVideoFilenameRegex, options: .regularExpression) == nil {

                    if let date = parseDateFrom(filename: filename) {
                        // For now, thumbnailURL can be nil or point to the video URL itself.
                        // A separate thumbnail generation step would update this.
                        let video = Video(url: url, date: date, thumbnailURL: nil)
                        videos.append(video)
                    } else {
                        print("Warning: Could not parse date from filename: \(filename)")
                    }
                }
            }

            // Sort videos by date, newest first
            videos.sort { $0.date > $1.date }

            return videos
        } catch {
            print("Error fetching videos from documents directory: \(error.localizedDescription)")
            return []
        }
    }

    /// Deletes a video file at the given URL.
    /// Ensures that only daily videos (not recaps) are deleted through this method.
    /// - Parameter url: The URL of the video file to delete.
    /// - Returns: True if deletion was successful or file didn't exist, false otherwise.
    func deleteVideo(url: URL) -> Bool {
        let filename = url.lastPathComponent

        // Extra check: ensure we are not deleting a recap video through this method.
        if filename.range(of: recapVideoFilenameRegex, options: .regularExpression) != nil {
            print("Error: Attempted to delete a recap video ('\(filename)') using a method intended for daily videos.")
            return false
        }

        // Ensure it looks like a daily video (optional check, as primary use is for URLs from fetchDailyVideos)
        // if filename.range(of: dailyVideoFilenameRegex, options: .regularExpression) == nil {
        //     print("Warning: Attempted to delete a file ('\(filename)') that does not match the daily video naming convention.")
        //     // Proceed with deletion if desired, or return false
        // }

        do {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
                print("Successfully deleted video: \(url.path)")
            } else {
                print("Video not found at path: \(url.path), nothing to delete.")
            }
            return true
        } catch {
            print("Error deleting video at \(url.path): \(error.localizedDescription)")
            return false
        }
    }

    /// Returns the URL for the app's documents directory.
    /// - Returns: The URL of the documents directory, or nil if it cannot be found.
    func getVideosDirectory() -> URL? {
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    // MARK: - Private Helper Methods

    /// Parses a Date from a filename string (e.g., "YYYY-MM-DD_HH-MM-SS.mp4").
    /// - Parameter filename: The filename to parse.
    /// - Returns: A `Date` object if parsing is successful, otherwise nil.
    private func parseDateFrom(filename: String) -> Date? {
        // Remove the .mp4 extension before parsing
        let namePart = filename.replacingOccurrences(of: ".mp4", with: "")
        return filenameDateFormatter.date(from: namePart)
    }

    // MARK: - (Future) Recap Video Handling
    // Example stubs for when recap functionality is added
    // func fetchRecapVideos() -> [RecapVideo] { return [] }
    // func deleteRecapVideo(url: URL) -> Bool { return false }


    // MARK: - Recap File Fetching

    /// Fetches the URL for a weekly recap video if it exists.
    /// - Parameters:
    ///   - weekOfYear: The week number (ISO 8601).
    ///   - year: The year for the week.
    /// - Returns: URL of the recap video file, or nil if not found.
    func fetchWeeklyRecapURL(forWeek weekOfYear: Int, year: Int) -> URL? {
        guard let documentsDirectory = getVideosDirectory() else { return nil }
        let weekString = String(format: "%04d-W%02d", year, weekOfYear)
        let recapFilename = "recap_week_\(weekString).mp4"
        let recapFileURL = documentsDirectory.appendingPathComponent(recapFilename)

        if fileManager.fileExists(atPath: recapFileURL.path) {
            return recapFileURL
        }
        return nil
    }

    /// Fetches the URL for a monthly recap video if it exists.
    /// - Parameters:
    ///   - month: The month number (1-12).
    ///   - year: The year.
    /// - Returns: URL of the recap video file, or nil if not found.
    func fetchMonthlyRecapURL(forMonth month: Int, year: Int) -> URL? {
        guard let documentsDirectory = getVideosDirectory() else { return nil }
        let monthString = String(format: "%04d-%02d", year, month)
        let recapFilename = "recap_month_\(monthString).mp4"
        let recapFileURL = documentsDirectory.appendingPathComponent(recapFilename)

        if fileManager.fileExists(atPath: recapFileURL.path) {
            return recapFileURL
        }
        return nil
    }

    /// Fetches all recap video URLs from the documents directory.
    /// - Returns: An array of URLs for recap videos.
    func fetchAllRecapVideoURLs() -> [URL] {
        guard let documentsDirectory = getVideosDirectory() else {
            print("Error: Could not access documents directory.")
            return []
        }

        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory,
                                                               includingPropertiesForKeys: nil,
                                                               options: .skipsHiddenFiles)

            return fileURLs.filter { url in
                let filename = url.lastPathComponent
                return filename.range(of: recapVideoFilenameRegex, options: .regularExpression) != nil
            }
        } catch {
            print("Error fetching recap videos from documents directory: \(error.localizedDescription)")
            return []
        }
    }

    /// Checks if a daily video has been recorded today.
    /// - Returns: True if a video was recorded today, false otherwise.
    func hasRecordedVideoToday() -> Bool {
        let allDailyVideos = fetchDailyVideos() // Reuses existing method
        let calendar = Calendar.current
        let today = Date()

        for video in allDailyVideos {
            if calendar.isDate(video.date, inSameDayAs: today) {
                return true
            }
        }
        return false
    }
}
