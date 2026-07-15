import SwiftData
import XCTest
@testable import LanguageFlashcards

@MainActor
final class QuizReviewRecorderTests: XCTestCase {
    func testMultipleChoiceOutcomeMappingHasOnlyConservativeRatings() {
        XCTAssertEqual(
            QuizReviewRecorder.rating(for: .multipleChoiceCorrect),
            .unsure
        )
        XCTAssertEqual(
            QuizReviewRecorder.rating(for: .multipleChoiceIncorrect),
            .unknown
        )
    }

    func testQuizCorrectMatchesNormalStudyUnsureReview() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let reviewedAt = Date(timeIntervalSince1970: 1_760_000_000)
        let quizCard = Flashcard(languageOneText: "猫", languageTwoText: "cat")
        let normalStudyCard = Flashcard(languageOneText: "犬", languageTwoText: "dog")
        context.insert(FlashcardDeck(name: "クイズ", cards: [quizCard]))
        try context.save()

        _ = normalStudyCard.registerReview(.unsure, at: reviewedAt)
        XCTAssertTrue(try QuizReviewRecorder.record(
            .multipleChoiceCorrect,
            cardID: quizCard.id,
            in: context,
            reviewedAt: reviewedAt
        ))

        XCTAssertEqual(quizCard.lastRating, normalStudyCard.lastRating)
        XCTAssertEqual(quizCard.dueAt, normalStudyCard.dueAt)
        XCTAssertEqual(quizCard.intervalDays, normalStudyCard.intervalDays)
        XCTAssertEqual(quizCard.easeFactor, normalStudyCard.easeFactor)
        XCTAssertEqual(
            quizCard.fsrsDifficultyValue(),
            normalStudyCard.fsrsDifficultyValue(),
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            quizCard.fsrsStabilityValue(),
            normalStudyCard.fsrsStabilityValue(),
            accuracy: 0.000_001
        )
    }

    func testConsecutiveCorrectReviewsMoveDueDateLaterAndIncorrectPullsItEarlier() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 1_760_000_000)
        let card = Flashcard(languageOneText: "猫", languageTwoText: "cat")
        context.insert(FlashcardDeck(name: "連続回答", cards: [card]))
        try context.save()

        try QuizReviewRecorder.record(
            .multipleChoiceCorrect,
            cardID: card.id,
            in: context,
            reviewedAt: start
        )
        let firstCorrectDueAt = card.dueAt

        try QuizReviewRecorder.record(
            .multipleChoiceCorrect,
            cardID: card.id,
            in: context,
            reviewedAt: start.addingTimeInterval(3_600)
        )
        let secondCorrectDueAt = card.dueAt

        try QuizReviewRecorder.record(
            .multipleChoiceIncorrect,
            cardID: card.id,
            in: context,
            reviewedAt: start.addingTimeInterval(7_200)
        )

        XCTAssertGreaterThan(secondCorrectDueAt, firstCorrectDueAt)
        XCTAssertLessThan(card.dueAt, secondCorrectDueAt)
        XCTAssertEqual(card.reviewCount, 3)

        let reviews = try context.fetch(FetchDescriptor<StudyReview>())
            .sorted { $0.reviewedAt < $1.reviewedAt }
        XCTAssertEqual(reviews.map(\.rating), [.unsure, .unsure, .unknown])
    }

    func testUnlearnedLearnedAndOverdueCardsPersistConsistentHistory() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_760_000_000)
        let setupDate = now.addingTimeInterval(-172_800)
        let unlearned = Flashcard(languageOneText: "未学習", languageTwoText: "new")
        let learned = Flashcard(languageOneText: "既習", languageTwoText: "learned")
        let overdue = Flashcard(languageOneText: "期限切れ", languageTwoText: "overdue")
        _ = learned.registerReview(.perfect, at: setupDate)
        _ = overdue.registerReview(.unsure, at: setupDate)
        XCTAssertLessThan(overdue.dueAt, now)

        context.insert(FlashcardDeck(
            name: "状態境界",
            cards: [unlearned, learned, overdue]
        ))
        try context.save()

        try QuizReviewRecorder.record(
            .multipleChoiceCorrect,
            cardID: unlearned.id,
            in: context,
            reviewedAt: now
        )
        try QuizReviewRecorder.record(
            .multipleChoiceCorrect,
            cardID: learned.id,
            in: context,
            reviewedAt: now
        )
        try QuizReviewRecorder.record(
            .multipleChoiceIncorrect,
            cardID: overdue.id,
            in: context,
            reviewedAt: now
        )

        XCTAssertEqual(unlearned.lastRating, .unsure)
        XCTAssertEqual(learned.lastRating, .unsure)
        XCTAssertEqual(overdue.lastRating, .unknown)
        XCTAssertGreaterThan(unlearned.dueAt, now)
        XCTAssertGreaterThan(learned.dueAt, now)
        XCTAssertGreaterThan(overdue.dueAt, now)

        let reviews = try context.fetch(FetchDescriptor<StudyReview>())
        let reviewByCardID = Dictionary(uniqueKeysWithValues: reviews.map { ($0.cardID, $0) })
        XCTAssertNil(reviewByCardID[unlearned.id]?.previousRatingRaw)
        XCTAssertEqual(reviewByCardID[learned.id]?.previousRatingRaw, ReviewRating.perfect.rawValue)
        XCTAssertEqual(reviewByCardID[overdue.id]?.previousRatingRaw, ReviewRating.unsure.rawValue)
    }

    func testDeletedCardIsSkippedWithoutDanglingReview() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let card = Flashcard(languageOneText: "削除対象", languageTwoText: "deleted")
        let deck = FlashcardDeck(name: "削除境界", cards: [card])
        context.insert(deck)
        try context.save()

        let question = try XCTUnwrap(QuizSession(cards: [card]).currentQuestion)
        context.delete(card)
        try context.save()

        XCTAssertFalse(try QuizReviewRecorder.record(
            .multipleChoiceCorrect,
            cardID: question.cardID,
            in: context
        ))
        XCTAssertTrue(try context.fetch(FetchDescriptor<StudyReview>()).isEmpty)
        XCTAssertEqual(question.prompt, "削除対象")
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            FlashcardDeck.self,
            Flashcard.self,
            StudyReview.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
