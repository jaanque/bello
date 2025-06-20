import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    private let notificationCenter = UNUserNotificationCenter.current()
    private let videoStorageService: VideoStorageService

    private let dailyReminderIdentifier = "bello-daily-record-reminder"

    init(videoStorageService: VideoStorageService = .shared) {
        self.videoStorageService = videoStorageService
    }

    /// Requests permission to send notifications.
    /// Calls the completion handler with true if permission is granted, false otherwise.
    func requestPermission(completion: @escaping (Bool) -> Void) {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error requesting notification permission: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                completion(granted)
            }
        }
    }

    /// Schedules a daily reminder notification for 8 PM if no video has been recorded today.
    /// If a video has been recorded today, it ensures any pending reminder for today is cancelled.
    /// This method relies on a daily repeating trigger.
    func scheduleDailyReminder() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }
            guard settings.authorizationStatus == .authorized else {
                print("Notification permission not granted. Cannot schedule reminders.")
                // Optionally, call requestPermission here or handle it upstream
                return
            }

            // If a video was recorded today, we don't need to schedule (or we should cancel for today).
            // However, a daily repeating notification will fire tomorrow regardless unless we cancel ALL.
            // The logic for "don't show if recorded today" is better handled by cancelling
            // the specific pending notification for today if one exists and was scheduled non-repeating,
            // OR by having the app re-evaluate on foregrounding.
            // For a single daily repeating notification, we schedule it once.
            // If a video is recorded, we can cancel it and reschedule it for the *next* day at 8 PM
            // or just let it fire and the user sees it (which might be okay if they recorded *after* 8 PM).

            // Simpler model: schedule a daily repeating notification.
            // If a video is recorded today, we cancel it. This means it won't fire *tonight*.
            // When the app becomes active tomorrow, this method will run again. If no video recorded *tomorrow*, it schedules again.
            // This avoids complex rescheduling for "next day".

            if self.videoStorageService.hasRecordedVideoToday() {
                print("Video recorded today. Cancelling today's reminder.")
                self.cancelDailyReminder() // Cancels the repeating notification. Will be rescheduled if app opens tomorrow and no video.
                // To ensure it's set for *tomorrow* if cancelled today, we might need to schedule a non-repeating one for tomorrow.
                // OR, a better approach: use checkAndScheduleReminder which is called on app active.
                return
            }

            // If we reach here, no video recorded today AND permission granted.
            let content = UNMutableNotificationContent()
            content.title = "Bello"
            content.body = "¡No olvides grabar tu recuerdo de hoy!"
            content.sound = .default

            var dateComponents = DateComponents()
            dateComponents.hour = 20 // 8 PM
            dateComponents.minute = 0
            // Trigger that repeats daily at the specified time
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

            let request = UNNotificationRequest(identifier: self.dailyReminderIdentifier, content: content, trigger: trigger)

            self.notificationCenter.add(request) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Error scheduling daily reminder: \(error.localizedDescription)")
                    } else {
                        print("Daily reminder scheduled successfully for 8 PM daily.")
                    }
                }
            }
        }
    }

    /// Cancels the specific daily reminder notification.
    func cancelDailyReminder() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [dailyReminderIdentifier])
        print("Cancelled pending daily reminder (if any).")
    }

    /// Checks notification permission and then schedules or cancels the daily reminder.
    /// This is the main method to call from app lifecycle events.
    func checkAndScheduleReminder() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }

            switch settings.authorizationStatus {
            case .notDetermined:
                print("Notification permission not determined. Requesting permission...")
                self.requestPermission { granted in
                    if granted {
                        print("Permission granted. Scheduling reminder.")
                        self.scheduleOrCancelBasedOnRecordingStatus()
                    } else {
                        print("Permission denied. Cannot schedule reminders.")
                    }
                }
            case .authorized:
                print("Notification permission authorized. Scheduling/Cancelling reminder based on status.")
                self.scheduleOrCancelBasedOnRecordingStatus()
            case .denied:
                print("Notification permission denied. Cannot schedule reminders.")
            case .provisional: // Handle if you use provisional authorization
                print("Notification permission provisional. Scheduling/Cancelling reminder based on status.")
                self.scheduleOrCancelBasedOnRecordingStatus()
            case .ephemeral: // Handle if you use app clips
                 print("Notification permission ephemeral.")
            @unknown default:
                print("Unknown notification authorization status.")
            }
        }
    }

    private func scheduleOrCancelBasedOnRecordingStatus() {
        if videoStorageService.hasRecordedVideoToday() {
            // Video recorded today. We want to CANCEL any upcoming notification for today.
            // And ensure it's set for tomorrow. A daily repeating trigger handles "tomorrow" automatically
            // IF it wasn't cancelled. If it was cancelled, it needs to be re-added.
            // So, if recorded today, cancel. It will be re-added by this function tomorrow if app is opened.
            print("Video recorded today. Cancelling active daily reminder.")
            cancelDailyReminder()
            // Re-schedule it for next occurrences (effectively, next day if it's a daily repeating one)
            // This ensures that if a user records at 10 AM, the 8 PM notification for that day is cancelled,
            // but the repeating request ensures it's set for tomorrow 8 PM.
            // However, `cancelDailyReminder` removes ALL future instances of a repeating notification.
            // So we MUST re-schedule it for the future.
            // A robust way:
            // 1. Cancel all.
            // 2. Schedule a new repeating one (scheduleDailyReminder does this).
            // The `scheduleDailyReminder` method itself has a check for `hasRecordedVideoToday`.
            // This creates a slight conflict.

            // Revised logic for scheduleOrCancelBasedOnRecordingStatus:
            // Always remove any existing. This simplifies state.
            // Then, if no video recorded today, add it.
            // This means on app open, if I recorded at 10 AM, it will cancel, then re-add.
            // The `scheduleDailyReminder`'s internal check for `hasRecordedVideoToday` will prevent
            // it from being added if I recorded. This is the correct interaction.
            self.scheduleDailyReminder() // This will check hasRecordedVideoToday internally.

        } else {
            // No video recorded today. Schedule the reminder.
            print("No video recorded today. Scheduling daily reminder.")
            self.scheduleDailyReminder()
        }
    }
}
