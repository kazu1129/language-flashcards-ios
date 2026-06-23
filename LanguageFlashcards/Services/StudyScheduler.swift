import Foundation

enum StudyScheduler {
    static func plan(cards: [Flashcard], count: Int, now: Date = .now) -> [Flashcard] {
        let usableCount = max(1, count)
        let sorted = cards.sorted { left, right in
            score(left, now: now) > score(right, now: now)
        }
        return Array(sorted.prefix(usableCount))
    }

    private static func score(_ card: Flashcard, now: Date) -> Double {
        let overdueHours = max(0, now.timeIntervalSince(card.dueAt) / 3600)
        let retrievability = card.retrievability(at: now)
        let forgettingPressure = (1 - retrievability) * 100
        let difficultyPressure = card.fsrsDifficultyValue() * 4
        let uncertainty = Double(card.unknownCount * 8 + card.unsureCount * 4)
        let freshnessPenalty: Double
        if let lastReviewedAt = card.lastReviewedAt {
            freshnessPenalty = max(0, 12 - now.timeIntervalSince(lastReviewedAt) / 3600)
        } else {
            freshnessPenalty = 0
        }

        let base: Double
        switch card.lastRating {
        case .unknown:
            base = 80
        case .unsure:
            base = 55
        case .perfect:
            base = card.dueAt <= now ? 25 : 5
        case nil:
            base = 70
        }

        return base + forgettingPressure + difficultyPressure + overdueHours + uncertainty - freshnessPenalty
    }
}
