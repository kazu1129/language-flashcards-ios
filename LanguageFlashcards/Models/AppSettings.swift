import Foundation
import SwiftUI

enum CardSidePreference: String, CaseIterable, Identifiable {
    case languageOne
    case languageTwo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .languageOne:
            String(localized: "preference.cardSide.languageOne")
        case .languageTwo:
            String(localized: "preference.cardSide.languageTwo")
        }
    }
}

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            String(localized: "preference.appearance.system")
        case .light:
            String(localized: "preference.appearance.light")
        case .dark:
            String(localized: "preference.appearance.dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

enum SubscriptionTier: String, CaseIterable, Identifiable {
    case free
    case premium

    var id: String { rawValue }

    var title: String {
        switch self {
        case .free:
            String(localized: "subscriptionTier.free")
        case .premium:
            String(localized: "subscriptionTier.premium")
        }
    }

    var badgeText: String {
        switch self {
        case .free:
            "FREE"
        case .premium:
            "PREMIUM"
        }
    }
}

enum PremiumLimits {
    static let freeDecks = 3
    static let freeCards = 100
    static let freeOCRImportsPerMonth = 10
}

@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let displaySide = "displaySide"
        static let muteAudio = "muteAudio"
        static let sessionCardCount = "sessionCardCount"
        static let fontScale = "fontScale"
        static let appearance = "appearance"
        static let subscriptionTier = "subscriptionTier"
        static let showCharacterOnHome = "showCharacterOnHome"
        static let studyReminderEnabled = "studyReminderEnabled"
        static let dailySummaryEnabled = "dailySummaryEnabled"
        static let anniversaryNotificationsEnabled = "anniversaryNotificationsEnabled"
        static let growthNotificationsEnabled = "growthNotificationsEnabled"
        static let hasSeenFSRSOnboarding = "hasSeenFSRSOnboarding"
        static let hasBirthday = "hasBirthday"
        static let birthday = "birthday"
        static let lastNotifiedGrowthStage = "lastNotifiedGrowthStage"
        static let ocrUsageMonth = "ocrUsageMonth"
        static let ocrUsageCount = "ocrUsageCount"
    }

    @Published var displaySide: CardSidePreference {
        didSet { defaults.set(displaySide.rawValue, forKey: Keys.displaySide) }
    }

    @Published var muteAudio: Bool {
        didSet { defaults.set(muteAudio, forKey: Keys.muteAudio) }
    }

    @Published var sessionCardCount: Int {
        didSet {
            let clampedValue = Self.clampedSessionCardCount(sessionCardCount)
            guard sessionCardCount == clampedValue else {
                sessionCardCount = clampedValue
                return
            }
            defaults.set(clampedValue, forKey: Keys.sessionCardCount)
        }
    }

    @Published var fontScale: Double {
        didSet { defaults.set(fontScale, forKey: Keys.fontScale) }
    }

    @Published var appearance: AppearancePreference {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    @Published var subscriptionTier: SubscriptionTier {
        didSet { defaults.set(subscriptionTier.rawValue, forKey: Keys.subscriptionTier) }
    }

    @Published var showCharacterOnHome: Bool {
        didSet { defaults.set(showCharacterOnHome, forKey: Keys.showCharacterOnHome) }
    }

    @Published var studyReminderEnabled: Bool {
        didSet { defaults.set(studyReminderEnabled, forKey: Keys.studyReminderEnabled) }
    }

    @Published var dailySummaryEnabled: Bool {
        didSet { defaults.set(dailySummaryEnabled, forKey: Keys.dailySummaryEnabled) }
    }

    @Published var anniversaryNotificationsEnabled: Bool {
        didSet { defaults.set(anniversaryNotificationsEnabled, forKey: Keys.anniversaryNotificationsEnabled) }
    }

    @Published var growthNotificationsEnabled: Bool {
        didSet { defaults.set(growthNotificationsEnabled, forKey: Keys.growthNotificationsEnabled) }
    }

    @Published var hasSeenFSRSOnboarding: Bool {
        didSet { defaults.set(hasSeenFSRSOnboarding, forKey: Keys.hasSeenFSRSOnboarding) }
    }

    @Published var hasBirthday: Bool {
        didSet { defaults.set(hasBirthday, forKey: Keys.hasBirthday) }
    }

    @Published var birthday: Date {
        didSet { defaults.set(birthday.timeIntervalSince1970, forKey: Keys.birthday) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.displaySide = CardSidePreference(rawValue: defaults.string(forKey: Keys.displaySide) ?? "") ?? .languageOne
        self.muteAudio = defaults.bool(forKey: Keys.muteAudio)
        let savedCount = defaults.integer(forKey: Keys.sessionCardCount)
        self.sessionCardCount = savedCount == 0 ? 10 : Self.clampedSessionCardCount(savedCount)
        let savedScale = defaults.double(forKey: Keys.fontScale)
        self.fontScale = savedScale == 0 ? 1.0 : savedScale
        self.appearance = AppearancePreference(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .system
        self.subscriptionTier = SubscriptionTier(rawValue: defaults.string(forKey: Keys.subscriptionTier) ?? "") ?? .free
        self.showCharacterOnHome = defaults.object(forKey: Keys.showCharacterOnHome) as? Bool ?? true
        self.studyReminderEnabled = defaults.object(forKey: Keys.studyReminderEnabled) as? Bool ?? true
        self.dailySummaryEnabled = defaults.object(forKey: Keys.dailySummaryEnabled) as? Bool ?? true
        self.anniversaryNotificationsEnabled = defaults.object(forKey: Keys.anniversaryNotificationsEnabled) as? Bool ?? true
        self.growthNotificationsEnabled = defaults.object(forKey: Keys.growthNotificationsEnabled) as? Bool ?? true
        self.hasSeenFSRSOnboarding = defaults.bool(forKey: Keys.hasSeenFSRSOnboarding)
        self.hasBirthday = defaults.bool(forKey: Keys.hasBirthday)
        let savedBirthday = defaults.double(forKey: Keys.birthday)
        self.birthday = savedBirthday == 0 ? Date() : Date(timeIntervalSince1970: savedBirthday)
    }

    var isPremium: Bool {
        subscriptionTier == .premium
    }

    var totalFreeOCRRemainingThisMonth: Int {
        max(0, PremiumLimits.freeOCRImportsPerMonth - usageCount(forCountKey: Keys.ocrUsageCount, periodKey: Keys.ocrUsageMonth, currentPeriod: Self.monthKey()))
    }

    func canCreateDeck(existingDeckCount: Int) -> Bool {
        isPremium || existingDeckCount < PremiumLimits.freeDecks
    }

    func canAddCards(totalCardCount: Int, adding count: Int) -> Bool {
        isPremium || totalCardCount + count <= PremiumLimits.freeCards
    }

    func canUseOCRImport() -> Bool {
        isPremium || totalFreeOCRRemainingThisMonth > 0
    }

    func recordOCRImport() {
        guard !isPremium else { return }
        incrementUsage(forCountKey: Keys.ocrUsageCount, periodKey: Keys.ocrUsageMonth, currentPeriod: Self.monthKey())
    }

    func lastNotifiedGrowthStage() -> Int {
        defaults.integer(forKey: Keys.lastNotifiedGrowthStage)
    }

    func markGrowthStageNotified(_ level: Int) {
        defaults.set(level, forKey: Keys.lastNotifiedGrowthStage)
    }

    func resetForLogout() {
        subscriptionTier = .free
        hasSeenFSRSOnboarding = false
    }

    static func clampedSessionCardCount(_ value: Int) -> Int {
        min(max(value, 1), 100)
    }

    private func usageCount(forCountKey countKey: String, periodKey: String, currentPeriod: String) -> Int {
        if defaults.string(forKey: periodKey) != currentPeriod {
            defaults.set(currentPeriod, forKey: periodKey)
            defaults.set(0, forKey: countKey)
        }
        return defaults.integer(forKey: countKey)
    }

    private func incrementUsage(forCountKey countKey: String, periodKey: String, currentPeriod: String) {
        let count = usageCount(forCountKey: countKey, periodKey: periodKey, currentPeriod: currentPeriod)
        defaults.set(count + 1, forKey: countKey)
    }

    private static func dayKey(for date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func monthKey(for date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
}
