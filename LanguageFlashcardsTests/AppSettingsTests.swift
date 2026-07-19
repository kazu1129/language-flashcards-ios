import Foundation
import Testing
@testable import LanguageFlashcards

@Suite("プレミアム課金判定")
struct AppSettingsTests {
    // 狙い: 検証用上書き撤去後、プレミアム解放が本来の購入状態だけで決まることを担保する。
    @MainActor
    @Test("isPremiumは購入状態だけで決まる")
    func premiumStatusFollowsSubscriptionTier() {
        let suiteName = "AppSettingsTests.SubscriptionTier.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)

        settings.subscriptionTier = .free
        #expect(!settings.isPremium)

        settings.subscriptionTier = .premium
        #expect(settings.isPremium)
    }
}
