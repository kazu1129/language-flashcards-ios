import SwiftData
import SwiftUI
import UIKit
import XCTest
@testable import LanguageFlashcards

@MainActor
final class QuizS1SmokeTests: XCTestCase {
    func testQuizViewLoads() {
        let host = UIHostingController(rootView: NavigationStack { QuizView() })

        host.loadViewIfNeeded()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
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
