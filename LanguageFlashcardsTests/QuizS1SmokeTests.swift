import SwiftData
import SwiftUI
import UIKit
import XCTest
@testable import LanguageFlashcards

@MainActor
final class QuizS1SmokeTests: XCTestCase {
    func testQuizViewLoads() throws {
        let suiteName = "QuizS1SmokeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)
        let host = UIHostingController(
            rootView: NavigationStack { QuizView() }
                .environmentObject(settings)
        )

        host.loadViewIfNeeded()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testSettingsLinkPresentsSheet() {
        // 狙い: 「枚数を変更」導線が設定シートの提示状態を確実にONにすることを固定する。
        var state = QuizFormatSelectionState()

        state.presentSettings()

        XCTAssertTrue(state.isSettingsPresented)
    }

    func testSettingsDismissReturnsToUnselectedFormatState() {
        // 狙い: シートを閉じた後も形式未選択の元画面へ戻れる動線要件を保証する。
        var state = QuizFormatSelectionState()
        state.presentSettings()

        state.settingsDidDismiss()

        XCTAssertFalse(state.isSettingsPresented)
        XCTAssertNil(state.selectedQuestionType)
    }

    func testSessionCountSummaryUsesUpdatedSharedSetting() throws {
        // 狙い: 既存AppSettingsの変更がシート終了後の案内文へ即時反映されることを保証する。
        let suiteName = "QuizS1SmokeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(
            QuizFormatSelectionState.sessionSummary(
                sessionCardCount: settings.sessionCardCount,
                displaySide: settings.displaySide
            ),
            "設定 10枚/セッション（第1言語から表示）"
        )

        settings.sessionCardCount = 24

        XCTAssertEqual(
            QuizFormatSelectionState.sessionSummary(
                sessionCardCount: settings.sessionCardCount,
                displaySide: settings.displaySide
            ),
            "設定 24枚/セッション（第1言語から表示）"
        )
    }

    func testAnchoredSettingsAndExistingStudyFlowLoadWithoutRegression() throws {
        // 狙い: QZ-03として、アンカー付き設定シート追加後も通常学習と既存設定画面が読み込めることを確認する。
        let schema = Schema([
            FlashcardDeck.self,
            Flashcard.self,
            StudyReview.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let card = Flashcard(languageOneText: "猫", languageTwoText: "cat")
        let deck = FlashcardDeck(name: "退行確認", cards: [card])
        container.mainContext.insert(deck)

        let suiteName = "QuizS1SmokeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)

        let studyHost = UIHostingController(
            rootView: NavigationStack { StudySessionView(deck: deck) }
                .environmentObject(settings)
                .modelContainer(container)
        )
        studyHost.loadViewIfNeeded()
        studyHost.view.layoutIfNeeded()

        let settingsHost = UIHostingController(
            rootView: SettingsView(
                initialScrollTarget: .sessionCardCount,
                showsDismissButton: true
            )
            .environmentObject(settings)
            .environmentObject(AuthManager())
            .environmentObject(SubscriptionStore())
            .modelContainer(container)
        )
        settingsHost.loadViewIfNeeded()
        settingsHost.view.layoutIfNeeded()

        XCTAssertNotNil(studyHost.view)
        XCTAssertNotNil(settingsHost.view)
        XCTAssertEqual(deck.cards.map(\.id), [card.id])
        XCTAssertEqual(settings.sessionCardCount, 10)
    }

    func testDeckDetailViewLoadsWithoutChangingExistingCards() throws {
        let schema = Schema([
            FlashcardDeck.self,
            Flashcard.self,
            StudyReview.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let card = Flashcard(languageOneText: "猫", languageTwoText: "cat")
        let deck = FlashcardDeck(name: "既存デッキ", cards: [card])
        container.mainContext.insert(deck)

        let suiteName = "QuizS1SmokeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)

        let host = UIHostingController(
            rootView: NavigationStack {
                DeckDetailView(deck: deck)
            }
            .environmentObject(settings)
            .modelContainer(container)
        )

        host.loadViewIfNeeded()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
        XCTAssertEqual(deck.cards.count, 1)
        XCTAssertEqual(deck.cards.first?.languageOneText, "猫")
        XCTAssertEqual(deck.cards.first?.languageTwoText, "cat")
    }
}
