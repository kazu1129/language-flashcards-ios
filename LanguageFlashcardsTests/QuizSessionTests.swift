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
        XCTAssertEqual(session.currentQuestion?.choices, ["cat"])
        XCTAssertFalse(session.isFinished)

        session.advance()

        XCTAssertNil(session.currentCard)
        XCTAssertTrue(session.isFinished)

        session.advance()
        XCTAssertEqual(session.currentIndex, 1)
    }

    func testEveryQuestionContainsItsCorrectAnswerWithoutDuplicates() throws {
        let cards = [
            Flashcard(languageOneText: "猫", languageTwoText: "cat"),
            Flashcard(languageOneText: "犬", languageTwoText: "dog"),
            Flashcard(languageOneText: "鳥", languageTwoText: "bird"),
            Flashcard(languageOneText: "魚", languageTwoText: "fish"),
        ]
        var session = QuizSession(cards: cards)

        while let question = session.currentQuestion {
            XCTAssertEqual(question.choices.count, 4)
            XCTAssertTrue(question.choices.contains(question.correctAnswer))
            XCTAssertEqual(Set(question.choices).count, question.choices.count)
            session.advance()
        }
    }

    func testDuplicateDeckAnswersAreNotRepeatedInChoices() throws {
        let cards = [
            Flashcard(languageOneText: "猫", languageTwoText: "cat"),
            Flashcard(languageOneText: "ネコ", languageTwoText: "CAT"),
            Flashcard(languageOneText: "犬", languageTwoText: "dog"),
            Flashcard(languageOneText: "鳥", languageTwoText: "bird"),
            Flashcard(languageOneText: "魚", languageTwoText: "fish"),
        ]
        let session = QuizSession(cards: cards)
        let question = try XCTUnwrap(session.currentQuestion)
        let normalizedChoices = question.choices.map { $0.localizedLowercase }

        XCTAssertTrue(question.choices.contains(question.correctAnswer))
        XCTAssertEqual(Set(normalizedChoices).count, normalizedChoices.count)
    }

    func testTwoCardDeckUsesAvailableUniqueChoicesWithoutBreaking() throws {
        let cards = [
            Flashcard(languageOneText: "猫", languageTwoText: "cat"),
            Flashcard(languageOneText: "犬", languageTwoText: "dog"),
        ]
        var session = QuizSession(cards: cards)

        for _ in cards {
            let question = try XCTUnwrap(session.currentQuestion)
            XCTAssertEqual(question.choices.count, 2)
            XCTAssertTrue(question.choices.contains(question.correctAnswer))
            XCTAssertEqual(Set(question.choices).count, question.choices.count)
            session.advance()
        }

        XCTAssertTrue(session.isFinished)
    }

    func testQuizUsesTheSamePlanAndCountAsFlashcardStudy() {
        let now = Date(timeIntervalSince1970: 1_760_000_000)
        let cards = (0..<12).map { index in
            Flashcard(
                languageOneText: "単語\(index)",
                languageTwoText: "word\(index)",
                createdAt: now.addingTimeInterval(Double(index))
            )
        }
        let sessionCardCount = 5
        let studyPlan = StudyScheduler.plan(
            cards: cards,
            count: sessionCardCount,
            now: now
        )
        let quizSession = QuizSession(
            cards: cards,
            sessionCardCount: sessionCardCount,
            now: now
        )

        XCTAssertEqual(quizSession.totalCount, studyPlan.count)
        XCTAssertEqual(quizSession.queue.map(\.id), studyPlan.map(\.id))
    }

    func testQuizUsesAllCardsWhenDeckHasFewerThanSessionCount() {
        let cards = [
            Flashcard(languageOneText: "猫", languageTwoText: "cat"),
            Flashcard(languageOneText: "犬", languageTwoText: "dog"),
        ]
        let quizSession = QuizSession(cards: cards, sessionCardCount: 10)

        XCTAssertEqual(quizSession.totalCount, 2)
        XCTAssertEqual(Set(quizSession.queue.map(\.id)), Set(cards.map(\.id)))
    }
}
