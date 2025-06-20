import Foundation
import Combine

class HomeViewModel: ObservableObject {
    @Published var videosForDisplayedMonth: [Video] = []
    @Published var displayedDate: Date = Date()
    @Published var selectedPlayableItem: PlayableVideoItem? = nil // Replaces selectedVideoURL

    @Published var weeklyRecap: RecapInfo? = nil
    @Published var monthlyRecap: RecapInfo? = nil

    // Record Button State
    @Published var canRecordToday: Bool = true
    @Published var recordButtonText: String = "Grabar video de hoy"
    @Published var timeUntilNextRecording: String = ""

    private var allVideos: [Video] = [] // To store all videos fetched once
    private let videoStorageService: VideoStorageService
    private var countdownTimer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()


    init(videoStorageService: VideoStorageService = .shared) {
        self.videoStorageService = videoStorageService
        // Initial check for recording state.
        // Note: This is called at ViewModel init. If HomeView appears later,
        // onAppear in HomeView might be a better place for the first call
        // or ensure this ViewModel is initialized closer to view appearance.
        updateRecordButtonState()
    }

    var displayedMonthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedDate)
    }

    func fetchAndFilterVideos() {
        // Fetch all videos from storage service first
        allVideos = videoStorageService.fetchDailyVideos()
        filterVideosForDisplayedMonth()
        fetchRecaps() // Fetch recaps when daily videos are fetched
        updateRecordButtonState() // Update recording state when videos are fetched/filtered
    }

    private func filterVideosForDisplayedMonth() {
        // Filter the fetched videos by the current displayedDate's month and year
        let calendar = Calendar.current
        let displayedMonthComponents = calendar.dateComponents([.year, .month], from: displayedDate)

        videosForDisplayedMonth = allVideos.filter { video in
            let videoMonthComponents = calendar.dateComponents([.year, .month], from: video.date)
            return videoMonthComponents.year == displayedMonthComponents.year && videoMonthComponents.month == displayedMonthComponents.month
        }
    }

    func changeMonth(by offset: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: offset, to: displayedDate) {
            displayedDate = newDate
            // After changing the month, re-filter the existing list of all videos.
            // No need to re-fetch from disk unless we expect external changes frequently.
            // For simplicity and to ensure we always have the latest, we can call fetchAndFilterVideos()
            // but for performance, filtering an existing array is better if data hasn't changed.
            // Let's assume for now that fetchDailyVideos is lightweight enough or data might change.
            fetchAndFilterVideos()
        }
    }

    func deleteVideo(_ video: Video) {
        if videoStorageService.deleteVideo(url: video.url) {
            // Successfully deleted, now refresh the list
            fetchAndFilterVideos()
        } else {
            // Handle deletion failure (e.g., show an alert to the user)
            print("Error: Could not delete video \(video.url.lastPathComponent)")
        }
    }

    // MARK: - Video Playback
    func selectVideoForPlayback(url: URL) { // Renamed and implementation changed
        self.selectedPlayableItem = PlayableVideoItem(url: url)
    }

    func deselectVideo() { // Name is fine, implementation changes
        self.selectedPlayableItem = nil
    }

    // MARK: - Recap Fetching
    func fetchRecaps() {
        let calendar = Calendar.current
        let today = Date()

        // Fetch Weekly Recap (Current or Previous Week)
        // Try current week first
        let currentYear = calendar.component(.yearForWeekOfYear, from: today)
        let currentWeekOfYear = calendar.component(.weekOfYear, from: today)

        var weeklyRecapURL = videoStorageService.fetchWeeklyRecapURL(forWeek: currentWeekOfYear, year: currentYear)
        var weekString = "\(currentWeekOfYear)"
        var yearString = "\(currentYear)"

        if weeklyRecapURL == nil {
            // If current week's recap doesn't exist, try previous week
            if let previousWeekDate = calendar.date(byAdding: .weekOfYear, value: -1, to: today) {
                let previousWeekYear = calendar.component(.yearForWeekOfYear, from: previousWeekDate)
                let previousWeekOfYear = calendar.component(.weekOfYear, from: previousWeekDate)
                weeklyRecapURL = videoStorageService.fetchWeeklyRecapURL(forWeek: previousWeekOfYear, year: previousWeekYear)
                weekString = "\(previousWeekOfYear)"
                yearString = "\(previousWeekYear)"
            }
        }

        if let url = weeklyRecapURL {
            self.weeklyRecap = RecapInfo(url: url, title: "Recap Semana \(weekString)", type: .weekly)
        } else {
            self.weeklyRecap = nil
        }

        // Fetch Monthly Recap (Previous Month)
        if let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: today) {
            let previousMonthYear = calendar.component(.year, from: previousMonthDate)
            let previousMonth = calendar.component(.month, from: previousMonthDate)

            let monthNameFormatter = DateFormatter()
            monthNameFormatter.dateFormat = "MMMM" // Full month name
            let previousMonthName = monthNameFormatter.string(from: previousMonthDate)

            if let url = videoStorageService.fetchMonthlyRecapURL(forMonth: previousMonth, year: previousMonthYear) {
                self.monthlyRecap = RecapInfo(url: url, title: "Recap \(previousMonthName) \(previousMonthYear)", type: .monthly)
            } else {
                self.monthlyRecap = nil
            }
        } else {
            self.monthlyRecap = nil
        }
    }

    // MARK: - Record Button State Management
    func updateRecordButtonState() {
        let recordedToday = videoStorageService.hasRecordedVideoToday()
        if recordedToday {
            self.canRecordToday = false
            startCountdownTimer()
        } else {
            self.canRecordToday = true
            self.recordButtonText = "Grabar video de hoy"
            self.timeUntilNextRecording = ""
            countdownTimer?.cancel() // Stop any existing timer
        }
        // After updating button state, also update notification scheduling
        NotificationService.shared.checkAndScheduleReminder()
    }

    private func startCountdownTimer() {
        countdownTimer?.cancel() // Ensure any existing timer is stopped

        // Calculate time until midnight
        let calendar = Calendar.current
        let now = Date()
        guard let midnight = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, second: 0), matchingPolicy: .nextTime) else {
            // Should not happen in normal circumstances
            self.recordButtonText = "No disponible"
            return
        }

        // Timer fires every second to update the countdown
        countdownTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                let remaining = calendar.dateComponents([.hour, .minute, .second], from: Date(), to: midnight)

                if let hour = remaining.hour, let minute = remaining.minute, let second = remaining.second {
                    if hour <= 0 && minute <= 0 && second <= 0 {
                        // Time is up, allow recording again
                        self.updateRecordButtonState() // This will reset to "can record"
                    } else {
                        self.timeUntilNextRecording = String(format: "Disponible en %02dh %02dm %02ds", hour, minute, second)
                        self.recordButtonText = self.timeUntilNextRecording
                    }
                } else {
                    // If components are nil, something is wrong, try to update state
                    self.updateRecordButtonState()
                }
            }
    }

    // Call this method when the ViewModel is about to be deinitialized
    // or when the view it's associated with disappears permanently.
    func cleanupTimer() {
        countdownTimer?.cancel()
    }
}
