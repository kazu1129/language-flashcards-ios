import XCTest
@testable import LanguageFlashcards

final class QuizSessionTests: XCTestCase {
    func testEmptyDeckStartsFinished() {
        var session = QuizSession(cards: [])

        XCTAssertEqual(session.totalCount, 0)
        XCTAssertNil(session.currentCard)
        XCTAssertTrue(session.isFinished)

        session.advance()
        XCTAssertEqual(session.currentIndex, 0)
    }

    func testSingleCardAdvancesToFinished() {
        let card = Flashcard(languageOneText: "猫", languageTwoText: "cat")
        var session = QuizSession(cards: [card])

        XCTAssertEqual(session.totalCount, 1)
        XCTAssertEqual(session.currentCard?.id, card.id)
        XCTAssertFalse(session.isFinished)

        session.advance()

        XCTAssertNil(session.currentCard)
        XCTAssertTrue(session.isFinished)

        session.advance()
        XCTAssertEqual(session.currentIndex, 1)
    }
}
