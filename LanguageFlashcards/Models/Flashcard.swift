import Foundation
import SwiftData

@Model
final class Flashcard: Identifiable {
    @Attribute(.unique) var id: UUID
    var languageOneText: String
    var languageTwoText: String
    var meaningsJSON: String
    var createdAt: Date
    var updatedAt: Date
    var lastReviewedAt: Date?
    var dueAt: Date
    var intervalDays: Double
    var easeFactor: Double
    var lastRatingRaw: String?
    var reviewCount: Int
    var perfectCount: Int
    var unsureCount: Int
    var unknownCount: Int
    var promotedToPerfectCount: Int

    init(
        id: UUID = UUID(),
        languageOneText: String,
        languageTwoText: String = "",
        meanings: [MeaningEntry] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.languageOneText = languageOneText
        self.languageTwoText = languageTwoText
        self.meaningsJSON = MeaningEntry.encode(meanings)
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.lastReviewedAt = nil
        self.dueAt = createdAt
        self.intervalDays = 0
        self.easeFactor = 2.2
        self.lastRatingRaw = nil
        self.reviewCount = 0
        self.perfectCount = 0
        self.unsureCount = 0
        self.unknownCount = 0
        self.promotedToPerfectCount = 0
    }

    var meanings: [MeaningEntry] {
        get { MeaningEntry.decode(from: meaningsJSON) }
        set {
            meaningsJSON = MeaningEntry.encode(newValue)
            updatedAt = .now
        }
    }

    var lastRating: ReviewRating? {
        get {
            guard let lastRatingRaw else { return nil }
            return ReviewRating(rawValue: lastRatingRaw)
        }
        set {
            lastRatingRaw = newValue?.rawValue
        }
    }

    func visibleText(for side: CardSidePreference) -> String {
        switch side {
        case .languageOne:
            languageOneText
        case .languageTwo:
            languageTwoText.isEmpty ? languageOneText : languageTwoText
        }
    }

    func answerText(for side: CardSidePreference) -> String {
        switch side {
        case .languageOne:
            languageTwoText.isEmpty ? languageOneText : languageTwoText
        case .languageTwo:
            languageOneText
        }
    }

    func registerReview(_ rating: ReviewRating, at date: Date = .now) -> Bool {
        let previous = lastRating
        reviewCount += 1
        lastReviewedAt = date
        updatedAt = date
        lastRating = rating

        switch rating {
        case .perfect:
            perfectCount += 1
            easeFactor = min(easeFactor + 0.15, 3.0)
            intervalDays = intervalDays <= 0 ? 1 : min(intervalDays * easeFactor, 90)
            dueAt = Calendar.current.date(byAdding: .day, value: Int(ceil(intervalDays)), to: date) ?? date
        case .unsure:
            unsureCount += 1
            easeFactor = max(easeFactor - 0.15, 1.3)
            intervalDays = max(intervalDays * 0.6, 0.5)
            dueAt = Calendar.current.date(byAdding: .hour, value: 12, to: date) ?? date
        case .unknown:
            unknownCount += 1
            easeFactor = max(easeFactor - 0.25, 1.3)
            intervalDays = 0
            dueAt = Calendar.current.date(byAdding: .minute, value: 15, to: date) ?? date
        }

        let improved = (previous == .unsure || previous == .unknown) && rating == .perfect
        if improved {
            promotedToPerfectCount += 1
        }
        return improved
    }
}
