import Foundation

struct DeckMasteryStat: Equatable, Identifiable {
    let deckID: UUID
    let deckName: String
    let totalCount: Int
    let perfectCount: Int
    let unsureCount: Int
    let unlearnedCount: Int

    var id: UUID { deckID }
    var masteryRate: Double { ratio(perfectCount) }
    var unsureRate: Double { ratio(unsureCount) }
    var unlearnedRate: Double { ratio(unlearnedCount) }
    var masteryPercentage: Int { Int((masteryRate * 100).rounded()) }

    private func ratio(_ count: Int) -> Double {
        totalCount > 0 ? Double(count) / Double(totalCount) : 0
    }
}

struct DailyReviewScheduleStat: Equatable, Identifiable {
    let date: Date
    let count: Int

    var id: Date { date }
}

struct RetentionTrendStat: Equatable, Identifiable {
    let date: Date
    let averageRetrievability: Double

    var id: Date { date }
}

struct StudyHourStat: Equatable, Identifiable {
    let hour: Int
    let count: Int

    var id: Int { hour }
}

struct WeakCardStat: Equatable, Identifiable {
    let cardID: UUID
    let deckID: UUID
    let deckName: String
    let cardText: String
    let unknownCount: Int
    let unsureCount: Int
    let retrievability: Double
    let score: Double

    var id: UUID { cardID }
}

struct ForgettingCardStat: Equatable, Identifiable {
    let cardID: UUID
    let deckID: UUID
    let deckName: String
    let cardText: String
    let retrievability: Double
    let dueAt: Date

    var id: UUID { cardID }
}

struct PremiumAnalyticsSnapshot: Equatable {
    let deckMastery: [DeckMasteryStat]
    let upcomingReviews: [DailyReviewScheduleStat]
    let retentionTrend: [RetentionTrendStat]
    let studyHours: [StudyHourStat]
    let weakCards: [WeakCardStat]
    let forgettingCards: [ForgettingCardStat]
    let weakestDeck: DeckMasteryStat?
}

enum StatsAnalyzer {
    static func analyze(
        decks: [FlashcardDeck],
        reviews: [StudyReview],
        now: Date = .now,
        calendar: Calendar = .current,
        weakCardLimit: Int = 5,
        forgettingThreshold: Double = 0.5
    ) -> PremiumAnalyticsSnapshot {
        let cards = decks.flatMap(\.cards)
        let mastery = deckMastery(for: decks)
        return PremiumAnalyticsSnapshot(
            deckMastery: mastery,
            upcomingReviews: upcomingReviewSchedule(cards: cards, now: now, calendar: calendar),
            retentionTrend: retentionTrend(cards: cards, reviews: reviews, now: now, calendar: calendar),
            studyHours: studyHourHistogram(reviews: reviews, calendar: calendar),
            weakCards: weakCards(in: decks, at: now, limit: weakCardLimit),
            forgettingCards: forgettingCards(
                in: decks,
                at: now,
                threshold: forgettingThreshold
            ),
            weakestDeck: mastery.filter { $0.totalCount > 0 }.min {
                if $0.masteryRate == $1.masteryRate {
                    return $0.unlearnedRate > $1.unlearnedRate
                }
                return $0.masteryRate < $1.masteryRate
            }
        )
    }

    static func deckMastery(for decks: [FlashcardDeck]) -> [DeckMasteryStat] {
        decks.map { deck in
            let perfect = deck.cards.filter { $0.lastRating == .perfect }.count
            let unsure = deck.cards.filter { $0.lastRating == .unsure }.count
            return DeckMasteryStat(
                deckID: deck.id,
                deckName: deck.name,
                totalCount: deck.cards.count,
                perfectCount: perfect,
                unsureCount: unsure,
                unlearnedCount: deck.cards.count - perfect - unsure
            )
        }
        .sorted { $0.deckName.localizedCompare($1.deckName) == .orderedAscending }
    }

    static func upcomingReviewSchedule(
        cards: [Flashcard],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [DailyReviewScheduleStat] {
        let today = calendar.startOfDay(for: now)
        return (0..<7).compactMap { offset in
            guard
                let day = calendar.date(byAdding: .day, value: offset, to: today),
                let nextDay = calendar.date(byAdding: .day, value: 1, to: day)
            else { return nil }
            let count = cards.filter { $0.dueAt >= day && $0.dueAt < nextDay }.count
            return DailyReviewScheduleStat(date: day, count: count)
        }
    }

    static func retentionTrend(
        cards: [Flashcard],
        reviews: [StudyReview],
        now: Date = .now,
        calendar: Calendar = .current,
        maximumReviewDays: Int = 14
    ) -> [RetentionTrendStat] {
        let cardsByID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        let reviewsByDay = Dictionary(grouping: reviews) {
            calendar.startOfDay(for: $0.reviewedAt)
        }
        let days = reviewsByDay.keys.sorted().suffix(maximumReviewDays)

        return days.compactMap { day in
            guard let dayReviews = reviewsByDay[day] else { return nil }
            let cardIDs = Set(dayReviews.map(\.cardID))
            let values = cardIDs.compactMap { cardsByID[$0]?.retrievability(at: now) }
            guard !values.isEmpty else { return nil }
            return RetentionTrendStat(
                date: day,
                averageRetrievability: values.reduce(0, +) / Double(values.count)
            )
        }
    }

    static func studyHourHistogram(
        reviews: [StudyReview],
        calendar: Calendar = .current
    ) -> [StudyHourStat] {
        let counts = Dictionary(grouping: reviews) {
            calendar.component(.hour, from: $0.reviewedAt)
        }
        .mapValues(\.count)
        return (0..<24).map { StudyHourStat(hour: $0, count: counts[$0, default: 0]) }
    }

    static func weakCards(
        in decks: [FlashcardDeck],
        at now: Date = .now,
        limit: Int = 5
    ) -> [WeakCardStat] {
        cardContexts(in: decks)
            .filter { $0.card.reviewCount > 0 }
            .map { context in
                let retrievability = context.card.retrievability(at: now)
                let score = Double(context.card.unknownCount) * 3
                    + Double(context.card.unsureCount) * 1.5
                    + (1 - retrievability) * 2
                return WeakCardStat(
                    cardID: context.card.id,
                    deckID: context.deckID,
                    deckName: context.deckName,
                    cardText: context.card.languageOneText,
                    unknownCount: context.card.unknownCount,
                    unsureCount: context.card.unsureCount,
                    retrievability: retrievability,
                    score: score
                )
            }
            .sorted {
                if $0.score == $1.score {
                    return $0.cardText.localizedCompare($1.cardText) == .orderedAscending
                }
                return $0.score > $1.score
            }
            .prefix(max(0, limit))
            .map { $0 }
    }

    static func forgettingCards(
        in decks: [FlashcardDeck],
        at now: Date = .now,
        threshold: Double = 0.5
    ) -> [ForgettingCardStat] {
        cardContexts(in: decks)
            .filter { $0.card.reviewCount > 0 }
            .compactMap { context in
                let retrievability = context.card.retrievability(at: now)
                guard isForgetting(
                    retrievability: retrievability,
                    dueAt: context.card.dueAt,
                    now: now,
                    threshold: threshold
                ) else { return nil }
                return ForgettingCardStat(
                    cardID: context.card.id,
                    deckID: context.deckID,
                    deckName: context.deckName,
                    cardText: context.card.languageOneText,
                    retrievability: retrievability,
                    dueAt: context.card.dueAt
                )
            }
            .sorted {
                if $0.retrievability == $1.retrievability {
                    return $0.dueAt < $1.dueAt
                }
                return $0.retrievability < $1.retrievability
            }
    }

    static func isForgetting(
        retrievability: Double,
        dueAt: Date,
        now: Date,
        threshold: Double = 0.5
    ) -> Bool {
        retrievability < threshold || dueAt < now
    }

    private struct CardContext {
        let deckID: UUID
        let deckName: String
        let card: Flashcard
    }

    private static func cardContexts(in decks: [FlashcardDeck]) -> [CardContext] {
        decks.flatMap { deck in
            deck.cards.map { CardContext(deckID: deck.id, deckName: deck.name, card: $0) }
        }
    }
}
