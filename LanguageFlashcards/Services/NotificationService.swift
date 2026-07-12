import Foundation
import UserNotifications

@MainActor
enum NotificationService {
    private static let studyReminderID = "daily-study-reminder"
    private static let dailySummaryID = "daily-summary"
    private static let birthdayID = "birthday-study-message"
    private static let growthIDPrefix = "growth-stage-"
    private static let anniversaryIDPrefix = "anniversary-"

    static func refresh(settings: AppSettings, decks: [FlashcardDeck], reviews: [StudyReview]) async {
        let authorized = await ensureAuthorizationIfNeeded(settings: settings)
        guard authorized else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [studyReminderID, dailySummaryID, birthdayID])

        if settings.studyReminderEnabled {
            scheduleStudyReminderIfNeeded(reviews: reviews)
        }

        if settings.dailySummaryEnabled {
            scheduleDailySummary(reviews: reviews)
        }

        if settings.anniversaryNotificationsEnabled {
            scheduleAnniversaries(settings: settings, decks: decks, reviews: reviews)
        }

        if settings.growthNotificationsEnabled {
            scheduleGrowthNotificationIfNeeded(settings: settings, reviews: reviews)
        }
    }

    private static func ensureAuthorizationIfNeeded(settings: AppSettings) async -> Bool {
        guard settings.studyReminderEnabled ||
              settings.dailySummaryEnabled ||
              settings.anniversaryNotificationsEnabled ||
              settings.growthNotificationsEnabled else {
            return false
        }

        let center = UNUserNotificationCenter.current()
        let status = await notificationAuthorizationStatus(center: center)

        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return await requestAuthorization(center: center)
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private static func scheduleStudyReminderIfNeeded(reviews: [StudyReview]) {
        let calendar = Calendar.current
        let hasStudiedToday = reviews.contains { calendar.isDateInToday($0.reviewedAt) }
        guard !hasStudiedToday, let reminderDate = nextDate(hour: 20, minute: 0) else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.studyReminder.title")
        content.body = String(localized: "notification.studyReminder.body")
        content.sound = .default
        schedule(content: content, date: reminderDate, identifier: studyReminderID)
    }

    private static func scheduleDailySummary(reviews: [StudyReview]) {
        guard let summaryDate = nextDate(hour: 22, minute: 0) else { return }
        let summary = LearningProgress.todaySummary(from: reviews)

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.dailySummary.title")
        content.body = String.localizedStringWithFormat(
            String(localized: "notification.dailySummary.body"),
            Int64(summary.total),
            Int64(summary.perfect),
            Int64(summary.unsure),
            Int64(summary.unknown)
        )
        content.sound = .default
        schedule(content: content, date: summaryDate, identifier: dailySummaryID)
    }

    private static func scheduleAnniversaries(settings: AppSettings, decks: [FlashcardDeck], reviews: [StudyReview]) {
        let center = UNUserNotificationCenter.current()
        let oldIDs = [30, 90, 180, 365].map { "\(anniversaryIDPrefix)\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: oldIDs)

        if let startDate = LearningProgress.startDate(decks: decks, reviews: reviews) {
            for days in [30, 90, 180, 365] {
                guard let date = Calendar.current.date(byAdding: .day, value: days, to: startDate), date > .now else { continue }
                let content = UNMutableNotificationContent()
                content.title = anniversaryTitle(days: days)
                content.body = String(localized: "notification.anniversary.body")
                content.sound = .default
                schedule(content: content, date: date, identifier: "\(anniversaryIDPrefix)\(days)")
            }
        }

        guard settings.hasBirthday else { return }
        if let birthdayDate = nextBirthday(from: settings.birthday) {
            let content = UNMutableNotificationContent()
            content.title = String(localized: "notification.birthday.title")
            content.body = String(localized: "notification.birthday.body")
            content.sound = .default
            schedule(content: content, date: birthdayDate, identifier: birthdayID)
        }
    }

    private static func scheduleGrowthNotificationIfNeeded(settings: AppSettings, reviews: [StudyReview]) {
        let streak = LearningProgress.consecutiveStudyDays(from: reviews)
        let stage = LearningProgress.currentStage(for: streak)
        guard stage.level > settings.lastNotifiedGrowthStage(), stage.level > 1 else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.growth.title")
        content.body = String.localizedStringWithFormat(
            String(localized: "notification.growth.body"),
            stage.localizedTitle
        )
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: "\(growthIDPrefix)\(stage.level)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
        settings.markGrowthStageNotified(stage.level)
    }

    private static func schedule(content: UNMutableNotificationContent, date: Date, identifier: String) {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private static func notificationAuthorizationStatus(center: UNUserNotificationCenter) async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    private static func requestAuthorization(center: UNUserNotificationCenter) async -> Bool {
        await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private static func nextDate(hour: Int, minute: Int) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute

        guard let today = calendar.date(from: components) else { return nil }
        if today > now {
            return today
        }
        return calendar.date(byAdding: .day, value: 1, to: today)
    }

    private static func nextBirthday(from birthday: Date) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        let birthdayComponents = calendar.dateComponents([.month, .day], from: birthday)
        var nextComponents = calendar.dateComponents([.year], from: now)
        nextComponents.month = birthdayComponents.month
        nextComponents.day = birthdayComponents.day
        nextComponents.hour = 9
        nextComponents.minute = 0

        guard let thisYear = calendar.date(from: nextComponents) else { return nil }
        if thisYear > now {
            return thisYear
        }
        return calendar.date(byAdding: .year, value: 1, to: thisYear)
    }

    private static func anniversaryTitle(days: Int) -> String {
        switch days {
        case 30:
            String(localized: "notification.anniversary.30.title")
        case 90:
            String(localized: "notification.anniversary.90.title")
        case 180:
            String(localized: "notification.anniversary.180.title")
        case 365:
            String(localized: "notification.anniversary.365.title")
        default:
            String(localized: "notification.anniversary.default.title")
        }
    }
}
