import Foundation
import SwiftData

@Model
final class StudyReview: Identifiable {
    @Attribute(.unique) var id: UUID
    var deckID: UUID
    var cardID: UUID
    var deckName: String
    var cardText: String
    var ratingRaw: String
    var previousRatingRaw: String?
    var promotedToPerfect: Bool
    var reviewedAt: Date

    init(
        id: UUID = UUID(),
        deckID: UUID,
        cardID: UUID,
        deckName: String,
        cardText: String,
        rating: ReviewRating,
        previousRating: ReviewRating?,
        promotedToPerfect: Bool,
        reviewedAt: Date = .now
    ) {
        self.id = id
        self.deckID = deckID
        self.cardID = cardID
        self.deckName = deckName
        self.cardText = cardText
        self.ratingRaw = rating.rawValue
        self.previousRatingRaw = previousRating?.rawValue
        self.promotedToPerfect = promotedToPerfect
        self.reviewedAt = reviewedAt
    }

    var rating: ReviewRating {
        ReviewRating(rawValue: ratingRaw) ?? .unknown
    }
}
