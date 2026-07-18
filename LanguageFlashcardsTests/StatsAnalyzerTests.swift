import Foundation
import Testing
@testable import LanguageFlashcards

@Suite("プレミアム詳細統計・弱点分析")
struct StatsAnalyzerTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test("デッキ別習得率をperfect・unsure・未習得から正しく算出する")
    func calculatesDeckMasteryRates() throws {
        let cards = [
            ownerCard("共依存の", "codependent on", rating: .perfect),
            ownerCard("独立した", "independent", rating: .unsure),
            ownerCard("協力的な", "cooperative", rating: .unknown),
            ownerCard("相互的な", "mutual", rating: nil),
        ]
        let deck = FlashcardDeck(name: "人間関係", cards: cards)

        let stat = try #require(StatsAnalyzer.deckMastery(for: [deck]).first)

        #expect(stat.totalCount == 4)
        #expect(stat.perfectCount == 1)
        #expect(stat.unsureCount == 1)
        #expect(stat.unlearnedCount == 2)
        #expect(stat.masteryRate == 0.25)
        #expect(stat.unsureRate == 0.25)
        #expect(stat.unlearnedRate == 0.5)
        #expect(stat.masteryPercentage == 25)
    }

    @Test("苦手スコアは誤答回数が多く、同数なら定着率が低いカードを上位にする")
    func ranksWeakCardsByErrorsAndRetrievability() {
        let now = date(2026, 7, 18, 12)
        let manyErrors = reviewedCard(
            "共依存の",
            "codependent on",
            unknown: 4,
            unsure: 0,
            lastReviewedAt: now,
            stability: 10
        )
        let lowRetention = reviewedCard(
            "依存した",
            "dependent",
            unknown: 1,
            unsure: 0,
            lastReviewedAt: now.addingTimeInterval(-20 * 86_400),
            stability: 1
        )
        let highRetention = reviewedCard(
            "独立した",
            "independent",
            unknown: 1,
            unsure: 0,
            lastReviewedAt: now,
            stability: 10
        )
        let deck = FlashcardDeck(name: "人間関係", cards: [highRetention, lowRetention, manyErrors])

        let result = StatsAnalyzer.weakCards(in: [deck], at: now, limit: 10)

        #expect(result.map(\.cardID) == [manyErrors.id, lowRetention.id, highRetention.id])
        #expect(result[1].retrievability < result[2].retrievability)
        #expect(result[1].score > result[2].score)
    }

    @Test("忘却予測は定着率0.5未満または期限超過だけを抽出する")
    func extractsForgettingCardsAtBoundary() {
        let now = date(2026, 7, 18, 12)
        let future = now.addingTimeInterval(86_400)

        #expect(StatsAnalyzer.isForgetting(
            retrievability: 0.499,
            dueAt: future,
            now: now
        ))
        #expect(!StatsAnalyzer.isForgetting(
            retrievability: 0.5,
            dueAt: future,
            now: now
        ))
        #expect(StatsAnalyzer.isForgetting(
            retrievability: 0.9,
            dueAt: now.addingTimeInterval(-1),
            now: now
        ))

        let lowRetention = reviewedCard(
            "共依存の",
            "codependent on",
            unknown: 1,
            unsure: 0,
            lastReviewedAt: now.addingTimeInterval(-10 * 86_400),
            stability: 1,
            dueAt: future
        )
        let healthy = reviewedCard(
            "独立した",
            "independent",
            unknown: 0,
            unsure: 1,
            lastReviewedAt: now,
            stability: 10,
            dueAt: future
        )
        let overdue = reviewedCard(
            "協力的な",
            "cooperative",
            unknown: 0,
            unsure: 1,
            lastReviewedAt: now,
            stability: 10,
            dueAt: now.addingTimeInterval(-1)
        )
        let deck = FlashcardDeck(name: "人間関係", cards: [healthy, overdue, lowRetention])

        let result = StatsAnalyzer.forgettingCards(in: [deck], at: now)

        #expect(Set(result.map(\.cardID)) == Set([lowRetention.id, overdue.id]))
        #expect(!result.map(\.cardID).contains(healthy.id))
    }

    @Test("今後7日の復習予定は当日を含み、7日後の境界を除外する")
    func groupsUpcomingReviewsByDayBoundaries() {
        let now = date(2026, 7, 18, 12)
        let today = calendar.startOfDay(for: now)
        let cards = [
            cardDue(at: today),
            cardDue(at: today.addingTimeInterval(86_399)),
            cardDue(at: calendar.date(byAdding: .day, value: 6, to: today)!),
            cardDue(at: calendar.date(byAdding: .day, value: 7, to: today)!),
            cardDue(at: today.addingTimeInterval(-1)),
        ]

        let result = StatsAnalyzer.upcomingReviewSchedule(
            cards: cards,
            now: now,
            calendar: calendar
        )

        #expect(result.count == 7)
        #expect(result[0].count == 2)
        #expect(result[6].count == 1)
        #expect(result.map(\.count).reduce(0, +) == 3)
    }

    @Test("復習日の定着カーブと学習時間帯を既存履歴だけで集計する")
    func aggregatesRetentionTrendAndStudyHours() {
        let now = date(2026, 7, 18, 12)
        let cardOne = reviewedCard(
            "共依存の",
            "codependent on",
            unknown: 1,
            unsure: 0,
            lastReviewedAt: now.addingTimeInterval(-86_400),
            stability: 2
        )
        let cardTwo = reviewedCard(
            "独立した",
            "independent",
            unknown: 0,
            unsure: 1,
            lastReviewedAt: now,
            stability: 10
        )
        let deckID = UUID()
        let reviews = [
            review(deckID: deckID, card: cardOne, at: date(2026, 7, 17, 9)),
            review(deckID: deckID, card: cardTwo, at: date(2026, 7, 18, 9)),
            review(deckID: deckID, card: cardTwo, at: date(2026, 7, 18, 20)),
        ]

        let trend = StatsAnalyzer.retentionTrend(
            cards: [cardOne, cardTwo],
            reviews: reviews,
            now: now,
            calendar: calendar
        )
        let hours = StatsAnalyzer.studyHourHistogram(reviews: reviews, calendar: calendar)

        #expect(trend.count == 2)
        #expect(trend.allSatisfy { 0.0...1.0 ~= $0.averageRetrievability })
        #expect(hours[9].count == 2)
        #expect(hours[20].count == 1)
        #expect(hours.map(\.count).reduce(0, +) == 3)
    }

    private func ownerCard(
        _ languageOne: String,
        _ languageTwo: String,
        rating: ReviewRating?
    ) -> Flashcard {
        let card = Flashcard(languageOneText: languageOne, languageTwoText: languageTwo)
        card.lastRating = rating
        return card
    }

    private func reviewedCard(
        _ languageOne: String,
        _ languageTwo: String,
        unknown: Int,
        unsure: Int,
        lastReviewedAt: Date,
        stability: Double,
        dueAt: Date? = nil
    ) -> Flashcard {
        let card = Flashcard(languageOneText: languageOne, languageTwoText: languageTwo)
        card.unknownCount = unknown
        card.unsureCount = unsure
        card.reviewCount = max(1, unknown + unsure)
        card.lastReviewedAt = lastReviewedAt
        card.fsrsStability = stability
        card.dueAt = dueAt ?? lastReviewedAt.addingTimeInterval(86_400)
        return card
    }

    private func cardDue(at dueAt: Date) -> Flashcard {
        let card = Flashcard(languageOneText: UUID().uuidString, languageTwoText: "word")
        card.dueAt = dueAt
        return card
    }

    private func review(deckID: UUID, card: Flashcard, at date: Date) -> StudyReview {
        StudyReview(
            deckID: deckID,
            cardID: card.id,
            deckName: "人間関係",
            cardText: card.languageOneText,
            rating: .unsure,
            previousRating: .unknown,
            promotedToPerfect: false,
            reviewedAt: date
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour
        ))!
    }
}
