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

    func testDeckDetailSettingsLinkPresentsSheet() {
        // 狙い: デッキ詳細の新しい「枚数を変更」導線が設定シートの提示状態を確実にONにする。
        var state = DeckSessionSettingsState()

        state.present()

        XCTAssertTrue(state.isPresented)
    }

    func testSettingsDismissReturnsToDeckDetail() {
        // 狙い: シートを閉じると提示状態がOFFになり、元のデッキ詳細へ戻れる動線要件を保証する。
        var state = DeckSessionSettingsState()
        state.present()

        state.didDismiss()

        XCTAssertFalse(state.isPresented)
    }

    func testSessionCountUpdatesDeckSummaryAndQuizButton() throws {
        // 狙い: 共通設定の変更が「N枚/セッション」と「クイズを始める（N問）」へ一貫して即時反映される。
        let suiteName = "QuizS1SmokeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)
        let cards = (0..<30).map {
            Flashcard(languageOneText: "単語\($0)", languageTwoText: "word\($0)")
        }

        settings.sessionCardCount = 24
        let questionCount = DeckSessionSettingsState.quizQuestionCount(
            cards: cards,
            sessionCardCount: settings.sessionCardCount
        )

        XCTAssertEqual(
            DeckSessionSettingsState.sessionCountText(settings.sessionCardCount),
            "24枚 / セッション"
        )
        XCTAssertEqual(questionCount, 24)
        XCTAssertEqual(
            DeckSessionSettingsState.quizStartText(questionCount: questionCount),
            "クイズを始める（24問）"
        )
    }

    func testQuizFormatSelectionHasNoSettingsShortcutAndQuestionTypesStillWork() throws {
        // 狙い: 設定導線の移設漏れを防ぎ、QZ-03として4択・同義語のS5'出題が従来どおり動くことを守る。
        let suiteName = "QuizS1SmokeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)
        let cards = [
            Flashcard(
                languageOneText: "fast",
                languageTwoText: "速い",
                meanings: [MeaningEntry(meaning: "速い", synonyms: "quick")]
            ),
            Flashcard(
                languageOneText: "slow",
                languageTwoText: "遅い",
                meanings: [MeaningEntry(meaning: "遅い", synonyms: "sluggish")]
            ),
        ]
        let host = UIHostingController(
            rootView: NavigationStack { QuizView(cards: cards) }
                .environmentObject(settings)
        )
        host.loadViewIfNeeded()
        host.view.layoutIfNeeded()

        let fourChoiceSession = QuizSession(cards: cards, questionType: .fourChoice)
        let synonymSession = QuizSession(cards: cards, questionType: .synonym)

        XCTAssertFalse(
            containsAccessibilityIdentifier(
                "quiz-session-count-settings-button",
                in: host.view
            )
        )
        XCTAssertEqual(fourChoiceSession.currentQuestion?.type, .fourChoice)
        XCTAssertEqual(synonymSession.currentQuestion?.type, .synonym)
        XCTAssertTrue(
            synonymSession.currentQuestion?.choices.contains(
                synonymSession.currentQuestion?.correctAnswer ?? ""
            ) == true
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

    private func containsAccessibilityIdentifier(_ identifier: String, in view: UIView) -> Bool {
        view.accessibilityIdentifier == identifier || view.subviews.contains {
            containsAccessibilityIdentifier(identifier, in: $0)
        }
    }
}
