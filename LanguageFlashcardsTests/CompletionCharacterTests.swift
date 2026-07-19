import Foundation
import Testing
@testable import LanguageFlashcards

@Suite("完了画面のFutaba表示")
struct CompletionCharacterTests {
    // 狙い: 完了画面が再利用する既存8段階の境界を固定し、成長画像の取り違えを防ぐ。
    @Test("成長段階の主要境界を維持する")
    func preservesGrowthStageBoundaries() {
        let expectedLevels = [
            0: 1,
            1: 2,
            3: 3,
            7: 4,
            14: 5,
            30: 6,
            90: 7,
            365: 8,
        ]

        for (streakDays, level) in expectedLevels {
            #expect(LearningProgress.currentStage(for: streakDays).level == level)
        }
    }

    // 狙い: クイズ完了がStudyReviewの連続日数からstageを解決し、全問正解の称賛へつながることを保証する。
    @Test("クイズ全問正解はレビューからstageと称賛を解決する")
    func resolvesQuizCompletionFromReviews() {
        let calendar = Calendar.current
        let streakDays = LearningProgress.consecutiveStudyDays(
            from: makeReviews(dayOffsets: [0, -1, -2], calendar: calendar),
            calendar: calendar
        )
        let presentation = CompletionCharacterPresentation.quiz(
            streakDays: streakDays,
            isAllCorrect: true
        )

        #expect(presentation.stage.level == 3)
        #expect(presentation.message == "ふたばも大よろこび！全問正解、すごい！")
    }

    // 狙い: 誤答を含むクイズでも同じstage経路を使い、責めない既定メッセージを表示することを固定する。
    @Test("クイズ一部不正解は非叱責の称賛を返す")
    func resolvesSupportiveQuizMessage() {
        let presentation = CompletionCharacterPresentation.quiz(
            streakDays: 0,
            isAllCorrect: false
        )

        #expect(presentation.stage.level == 1)
        #expect(presentation.message == "ふたばと一緒にコツコツ。苦手はあとで復習しよう。")
    }

    // 狙い: 学習完了の@Query相当データからstageと学習枚数入り称賛を生成し、Viewへの受け渡しを固定する。
    @Test("学習完了はレビューと学習枚数からstageと称賛を解決する")
    func resolvesStudyCompletionFromReviews() {
        let calendar = Calendar.current
        let streakDays = LearningProgress.consecutiveStudyDays(
            from: makeReviews(dayOffsets: Array(-6...0), calendar: calendar),
            calendar: calendar
        )
        let presentation = CompletionCharacterPresentation.study(
            streakDays: streakDays,
            studiedCount: 10
        )

        #expect(presentation.stage.level == 4)
        #expect(presentation.message == "ふたばが見てるよ。今日も10枚、よく続けたね！")
    }

    private func makeReviews(dayOffsets: [Int], calendar: Calendar) -> [StudyReview] {
        dayOffsets.map { offset in
            let reviewedAt = calendar.date(
                byAdding: .day,
                value: offset,
                to: .now
            ) ?? .now
            return StudyReview(
                deckID: UUID(),
                cardID: UUID(),
                deckName: "人間関係",
                cardText: "共依存の",
                rating: .perfect,
                previousRating: .unsure,
                promotedToPerfect: true,
                reviewedAt: reviewedAt
            )
        }
    }
}
