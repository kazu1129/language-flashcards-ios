import Foundation
import SwiftData

enum QuizAnswerOutcome {
    case multipleChoiceCorrect
    case multipleChoiceIncorrect
}

enum QuizReviewRecorder {
    static func rating(for outcome: QuizAnswerOutcome) -> ReviewRating {
        switch outcome {
        case .multipleChoiceCorrect:
            .unsure
        case .multipleChoiceIncorrect:
            .unknown
        }
    }

    @MainActor
    @discardableResult
    static func record(
        _ outcome: QuizAnswerOutcome,
        cardID: UUID,
        in modelContext: ModelContext,
        reviewedAt: Date = .now
    ) throws -> Bool {
        let cards = try modelContext.fetch(FetchDescriptor<Flashcard>())
        guard let card = cards.first(where: { $0.id == cardID }) else { return false }

        let decks = try modelContext.fetch(FetchDescriptor<FlashcardDeck>())
        guard let deck = decks.first(where: { deck in
            deck.cards.contains(where: { $0.id == cardID })
        }) else { return false }

        let rating = rating(for: outcome)
        let previousRating = card.lastRating
        let promoted = card.registerReview(rating, at: reviewedAt)
        let review = StudyReview(
            deckID: deck.id,
            cardID: card.id,
            deckName: deck.name,
            cardText: card.languageOneText,
            rating: rating,
            previousRating: previousRating,
            promotedToPerfect: promoted,
            reviewedAt: reviewedAt
        )

        modelContext.insert(review)
        deck.updatedAt = reviewedAt
        try modelContext.save()
        return true
    }
}
