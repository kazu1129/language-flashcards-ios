import Foundation
import Testing
@testable import LanguageFlashcards

@Suite("プレミアム検証用上書き")
struct AppSettingsTests {
    // 狙い: 無料状態でも検証用上書きによって全プレミアムゲートを開けることを保証する。
    @MainActor
    @Test("上書きONなら無料でもプレミアムになる")
    func overrideEnablesPremiumForFreeTier() {
        withSettings { settings in
            settings.subscriptionTier = .free
            settings.debugPremiumOverride = true

            #expect(settings.isPremium)
        }
    }

    // 狙い: 上書きOFFでは従来のsubscriptionTier判定を一切変えないことを保証する。
    @MainActor
    @Test("上書きOFFは従来の課金判定を素通しする")
    func disabledOverridePreservesSubscriptionTier() {
        withSettings { settings in
            settings.debugPremiumOverride = false
            settings.subscriptionTier = .free
            #expect(!settings.isPremium)

            settings.subscriptionTier = .premium
            #expect(settings.isPremium)
        }
    }

    // 狙い: TestFlightを再起動しても検証状態を維持できるよう、既存UserDefaults方式で永続化されることを固定する。
    @MainActor
    @Test("上書き状態はUserDefaultsへ永続化される")
    func overridePersists() {
        let suiteName = "AppSettingsTests.Persistence.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = AppSettings(defaults: defaults, premiumOverrideAvailable: true)
        first.debugPremiumOverride = true

        let reloaded = AppSettings(defaults: defaults, premiumOverrideAvailable: true)
        #expect(reloaded.debugPremiumOverride)
        #expect(reloaded.isPremium)
    }

    // 狙い: QuizViewが使う実ゲート式で、穴埋め・文字記入が上書きON時にロックされないことを保証する。
    @MainActor
    @Test("上書きONはプレミアムクイズ形式のロックを解除する")
    func overrideUnlocksPremiumQuizFormats() {
        withSettings { settings in
            settings.subscriptionTier = .free
            settings.debugPremiumOverride = true

            #expect(!(QuestionType.clozeExample.requiresPremium && !settings.isPremium))
            #expect(!(QuestionType.textInput.requiresPremium && !settings.isPremium))
        }
    }

    // 狙い: DEBUGとTestFlightだけを許可し、App Store本番相当では検証用入口が漏れないことを保証する。
    @MainActor
    @Test("表示判定はDEBUGまたはsandboxReceiptだけを許可する")
    func availabilityExcludesAppStoreBuilds() {
        #expect(PremiumOverrideAvailability.isAvailable(
            isDebugBuild: true,
            receiptLastPathComponent: nil
        ))
        #expect(PremiumOverrideAvailability.isAvailable(
            isDebugBuild: false,
            receiptLastPathComponent: "sandboxReceipt"
        ))
        #expect(!PremiumOverrideAvailability.isAvailable(
            isDebugBuild: false,
            receiptLastPathComponent: "receipt"
        ))
        #expect(!PremiumOverrideAvailability.isAvailable(
            isDebugBuild: false,
            receiptLastPathComponent: nil
        ))

        let suiteName = "AppSettingsTests.AppStore.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: "debugPremiumOverride")
        let appStoreSettings = AppSettings(
            defaults: defaults,
            premiumOverrideAvailable: false
        )
        #expect(!appStoreSettings.isPremium)
    }

    @MainActor
    private func withSettings(_ body: (AppSettings) -> Void) {
        let suiteName = "AppSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        body(AppSettings(defaults: defaults, premiumOverrideAvailable: true))
    }
}
