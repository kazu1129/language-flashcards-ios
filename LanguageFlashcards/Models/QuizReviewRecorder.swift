import Foundation
import SwiftData

enum QuizAnswerOutcome {
    case multipleChoiceCorrect
    case multipleChoiceIncorrect
    case synonymCorrect
    case synonymIncorrect
    case clozeCorrect
    case clozeIncorrect
    case textInputCorrect
    case textInputIncorrect

    init?(questionType: QuestionType, isCorrect: Bool) {
        switch (questionType, isCorrect) {
        case (.fourChoice, true): self = .multipleChoiceCorrect
        case (.fourChoice, false): self = .multipleChoiceIncorrect
        case (.synonym, true): self = .synonymCorrect
        case (.synonym, false): self = .synonymIncorrect
        case (.clozeExample, true): self = .clozeCorrect
        case (.clozeExample, false): self = .clozeIncorrect
        case (.textInput, true): self = .textInputCorrect
        case (.textInput, false): self = .textInputIncorrect
        }
    }
}

struct QuizReviewResult: Equatable {
    let promoted: Bool
}

enum QuizReviewRecorder {
    static func rating(for outcome: QuizAnswerOutcome) -> ReviewRating {
        switch outcome {
        case .multipleChoiceCorrect, .synonymCorrect:
            .unsure
        case .clozeCorrect, .textInputCorrect:
            .perfect
        case .multipleChoiceIncorrect, .synonymIncorrect, .clozeIncorrect, .textInputIncorrect:
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
    ) throws -> QuizReviewResult? {
        let cards = try modelContext.fetch(FetchDescriptor<Flashcard>())
        guard let card = cards.first(where: { $0.id == cardID }) else { return nil }

        let decks = try modelContext.fetch(FetchDescriptor<FlashcardDeck>())
        guard let deck = decks.first(where: { deck in
            deck.cards.contains(where: { $0.id == cardID })
        }) else { return nil }

        let rating = rating(for: outcome)
        let previousRating = card.lastRating
        let registeredPromotion = card.registerReview(rating, at: reviewedAt)
        let promoted = registeredPromotion || (previousRating == nil && rating == .perfect)
        if promoted && !registeredPromotion {
            card.promotedToPerfectCount += 1
        }
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
        return QuizReviewResult(promoted: promoted)
    }
}
