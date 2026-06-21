import Foundation
import SwiftUI

enum CardSidePreference: String, CaseIterable, Identifiable {
    case languageOne
    case languageTwo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .languageOne:
            "第1言語"
        case .languageTwo:
            "第2言語"
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
            "システム"
        case .light:
            "ライト"
        case .dark:
            "ダーク"
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

@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let displaySide = "displaySide"
        static let muteAudio = "muteAudio"
        static let sessionCardCount = "sessionCardCount"
        static let fontScale = "fontScale"
        static let appearance = "appearance"
        static let geminiModel = "geminiModel"
    }

    @Published var displaySide: CardSidePreference {
        didSet { defaults.set(displaySide.rawValue, forKey: Keys.displaySide) }
    }

    @Published var muteAudio: Bool {
        didSet { defaults.set(muteAudio, forKey: Keys.muteAudio) }
    }

    @Published var sessionCardCount: Int {
        didSet { defaults.set(max(1, sessionCardCount), forKey: Keys.sessionCardCount) }
    }

    @Published var fontScale: Double {
        didSet { defaults.set(fontScale, forKey: Keys.fontScale) }
    }

    @Published var appearance: AppearancePreference {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    @Published var geminiModel: String {
        didSet { defaults.set(geminiModel, forKey: Keys.geminiModel) }
    }

    @Published var geminiAPIKey: String {
        didSet { KeychainService.saveGeminiAPIKey(geminiAPIKey) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.displaySide = CardSidePreference(rawValue: defaults.string(forKey: Keys.displaySide) ?? "") ?? .languageOne
        self.muteAudio = defaults.bool(forKey: Keys.muteAudio)
        let savedCount = defaults.integer(forKey: Keys.sessionCardCount)
        self.sessionCardCount = savedCount == 0 ? 10 : savedCount
        let savedScale = defaults.double(forKey: Keys.fontScale)
        self.fontScale = savedScale == 0 ? 1.0 : savedScale
        self.appearance = AppearancePreference(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .system
        self.geminiModel = defaults.string(forKey: Keys.geminiModel) ?? "gemini-3.5-flash"
        self.geminiAPIKey = KeychainService.loadGeminiAPIKey()
    }
}

