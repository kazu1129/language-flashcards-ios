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

    var localizedTitle: String {
        switch level {
        case 1:
            String(localized: "character.stage.1.title")
        case 2:
            String(localized: "character.stage.2.title")
        case 3:
            String(localized: "character.stage.3.title")
        case 4:
            String(localized: "character.stage.4.title")
        case 5:
            String(localized: "character.stage.5.title")
        case 6:
            String(localized: "character.stage.6.title")
        case 7:
            String(localized: "character.stage.7.title")
        case 8:
            String(localized: "character.stage.8.title")
        default:
            title
        }
    }

    var localizedSubtitle: String {
        switch level {
        case 1:
            String(localized: "character.stage.1.subtitle")
        case 2:
            String(localized: "character.stage.2.subtitle")
        case 3:
            String(localized: "character.stage.3.subtitle")
        case 4:
            String(localized: "character.stage.4.subtitle")
        case 5:
            String(localized: "character.stage.5.subtitle")
        case 6:
            String(localized: "character.stage.6.subtitle")
        case 7:
            String(localized: "character.stage.7.subtitle")
        case 8:
            String(localized: "character.stage.8.subtitle")
        default:
            subtitle
        }
    }
}

enum LearningProgress {
    static let growthStages: [CharacterGrowthStage] = [
        CharacterGrowthStage(level: 1, requiredDays: 0, title: "First step", subtitle: "Let's start growing from here", imageName: "MascotStage1"),
        CharacterGrowthStage(level: 2, requiredDays: 1, title: "Learning partner", subtitle: "Today's step has taken shape", imageName: "MascotStage2"),
        CharacterGrowthStage(level: 3, requiredDays: 3, title: "3-day streak", subtitle: "Your confidence is growing little by little", imageName: "MascotStage3"),
        CharacterGrowthStage(level: 4, requiredDays: 7, title: "1-week streak", subtitle: "Your learning rhythm is taking shape", imageName: "MascotStage4"),
        CharacterGrowthStage(level: 5, requiredDays: 14, title: "2-week streak", subtitle: "Your card progress is becoming visible", imageName: "MascotStage5"),
        CharacterGrowthStage(level: 6, requiredDays: 30, title: "1-month streak", subtitle: "Your consistency is growing", imageName: "MascotStage6"),
        CharacterGrowthStage(level: 7, requiredDays: 90, title: "90-day streak", subtitle: "This is an advanced pace", imageName: "MascotStage7"),
        CharacterGrowthStage(level: 8, requiredDays: 365, title: "1-year master", subtitle: "A big sign of consistency", imageName: "MascotStage8")
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
