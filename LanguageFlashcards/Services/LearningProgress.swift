import Foundation

struct TodayLearningSummary {
    var total: Int
    var perfect: Int
    var unsure: Int
    var unknown: Int
}

struct CharacterGrowthStage: Identifiable, Equatable {
    var level: Int
    var requiredDays: Int
    var title: String
    var subtitle: String
    var imageName: String

    var id: Int { level }
}

enum LearningProgress {
    static let growthStages: [CharacterGrowthStage] = [
        CharacterGrowthStage(level: 1, requiredDays: 0, title: "はじめの一歩", subtitle: "ここから育てていきましょう", imageName: "MascotStage1"),
        CharacterGrowthStage(level: 2, requiredDays: 1, title: "学習パートナー", subtitle: "今日の一歩が形になりました", imageName: "MascotStage2"),
        CharacterGrowthStage(level: 3, requiredDays: 3, title: "3日継続", subtitle: "少しずつ自信がついています", imageName: "MascotStage3"),
        CharacterGrowthStage(level: 4, requiredDays: 7, title: "1週間継続", subtitle: "学ぶ流れができてきました", imageName: "MascotStage4"),
        CharacterGrowthStage(level: 5, requiredDays: 14, title: "2週間継続", subtitle: "カードの積み重ねが見えています", imageName: "MascotStage5"),
        CharacterGrowthStage(level: 6, requiredDays: 30, title: "1ヶ月継続", subtitle: "続ける力が育っています", imageName: "MascotStage6"),
        CharacterGrowthStage(level: 7, requiredDays: 90, title: "90日継続", subtitle: "上級者のペースです", imageName: "MascotStage7"),
        CharacterGrowthStage(level: 8, requiredDays: 365, title: "1年マスター", subtitle: "大きな継続の証です", imageName: "MascotStage8")
    ]

    static func currentStage(for streakDays: Int) -> CharacterGrowthStage {
        growthStages.last { streakDays >= $0.requiredDays } ?? growthStages[0]
    }

    static func consecutiveStudyDays(from reviews: [StudyReview], calendar: Calendar = .current) -> Int {
        let studiedDays = Set(reviews.map { calendar.startOfDay(for: $0.reviewedAt) })
        guard !studiedDays.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: .now)
        let anchor = studiedDays.contains(today)
            ? today
            : (calendar.date(byAdding: .day, value: -1, to: today) ?? today)

        var day = anchor
        var count = 0
        while studiedDays.contains(day) {
            count += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previousDay
        }
        return count
    }

    static func todaySummary(from reviews: [StudyReview], calendar: Calendar = .current) -> TodayLearningSummary {
        let todayReviews = reviews.filter { calendar.isDateInToday($0.reviewedAt) }
        return TodayLearningSummary(
            total: todayReviews.count,
            perfect: todayReviews.filter { $0.rating == .perfect }.count,
            unsure: todayReviews.filter { $0.rating == .unsure }.count,
            unknown: todayReviews.filter { $0.rating == .unknown }.count
        )
    }

    static func startDate(decks: [FlashcardDeck], reviews: [StudyReview]) -> Date? {
        let deckDates = decks.map(\.createdAt)
        let reviewDates = reviews.map(\.reviewedAt)
        return (deckDates + reviewDates).min()
    }
}

