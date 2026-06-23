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
    var fsrsDifficulty: Double?
    var fsrsStability: Double?
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
        self.fsrsDifficulty = 5.0
        self.fsrsStability = 0.25
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
        let previousReviewedAt = lastReviewedAt
        reviewCount += 1
        lastReviewedAt = date
        updatedAt = date
        lastRating = rating
        updateFSRSLite(for: rating, at: date, previousReviewedAt: previousReviewedAt)

        switch rating {
        case .perfect:
            perfectCount += 1
            easeFactor = min(easeFactor + 0.15, 3.0)
            intervalDays = min(max(fsrsStabilityValue(), 1.0), 180.0)
            dueAt = Calendar.current.date(byAdding: .day, value: Int(ceil(intervalDays)), to: date) ?? date
        case .unsure:
            unsureCount += 1
            easeFactor = max(easeFactor - 0.15, 1.3)
            intervalDays = 0.5
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

    func fsrsDifficultyValue() -> Double {
        min(max(fsrsDifficulty ?? 5.0, 1.0), 10.0)
    }

    func fsrsStabilityValue() -> Double {
        min(max(fsrsStability ?? max(intervalDays, 0.25), 0.05), 180.0)
    }

    func retrievability(at date: Date = .now) -> Double {
        guard let lastReviewedAt else { return 0.0 }
        let elapsedDays = max(0, date.timeIntervalSince(lastReviewedAt) / 86_400)
        let stability = fsrsStabilityValue()
        return pow(0.9, elapsedDays / stability)
    }

    private func updateFSRSLite(for rating: ReviewRating, at date: Date, previousReviewedAt: Date?) {
        let currentDifficulty = fsrsDifficultyValue()
        let currentStability = fsrsStabilityValue()
        let currentRetrievability = retrievability(at: date, previousReviewedAt: previousReviewedAt, stability: currentStability)

        switch rating {
        case .perfect:
            let newDifficulty = min(max(currentDifficulty - 0.35, 1.0), 10.0)
            let retrievabilityBonus = currentRetrievability < 0.85 ? 0.25 : 0.0
            let growth = 1.55 + (10.0 - newDifficulty) * 0.08 + retrievabilityBonus
            fsrsDifficulty = newDifficulty
            fsrsStability = min(max(currentStability * growth, 1.0), 180.0)
        case .unsure:
            let newDifficulty = min(max(currentDifficulty + 0.35, 1.0), 10.0)
            fsrsDifficulty = newDifficulty
            fsrsStability = min(max(currentStability * 0.9, 0.5), 30.0)
        case .unknown:
            let newDifficulty = min(max(currentDifficulty + 0.8, 1.0), 10.0)
            fsrsDifficulty = newDifficulty
            fsrsStability = min(max(currentStability * 0.35, 0.05), 3.0)
        }
    }

    private func retrievability(at date: Date, previousReviewedAt: Date?, stability: Double) -> Double {
        guard let previousReviewedAt else { return 0.0 }
        let elapsedDays = max(0, date.timeIntervalSince(previousReviewedAt) / 86_400)
        return pow(0.9, elapsedDays / stability)
    }
}
