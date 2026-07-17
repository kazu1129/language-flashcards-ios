import SwiftData
import Testing
import XCTest
@testable import LanguageFlashcards

final class QuizSessionTests: XCTestCase {
    func testEmptyDeckStartsFinished() {
        var session = QuizSession(cards: [])

        XCTAssertEqual(session.totalCount, 0)
        XCTAssertNil(session.currentCard)
        XCTAssertTrue(session.isFinished)

        session.advance()
        XCTAssertEqual(session.currentIndex, 0)
    }

    func testSingleCardAdvancesToFinished() {
        let card = Flashcard(languageOneText: "猫", languageTwoText: "cat")
        var session = QuizSession(cards: [card])

        XCTAssertEqual(session.totalCount, 1)
        XCTAssertEqual(session.currentCard?.id, card.id)
        XCTAssertEqual(session.currentQuestion?.choices, ["cat"])
        XCTAssertFalse(session.isFinished)

        session.advance()

        XCTAssertNil(session.currentCard)
        XCTAssertTrue(session.isFinished)

        session.advance()
        XCTAssertEqual(session.currentIndex, 1)
    }

    func testEveryQuestionContainsItsCorrectAnswerWithoutDuplicates() throws {
        let cards = [
            Flashcard(languageOneText: "猫", languageTwoText: "cat"),
            Flashcard(languageOneText: "犬", languageTwoText: "dog"),
            Flashcard(languageOneText: "鳥", languageTwoText: "bird"),
            Flashcard(languageOneText: "魚", languageTwoText: "fish"),
        ]
        var session = QuizSession(cards: cards)

        while let question = session.currentQuestion {
            XCTAssertEqual(question.choices.count, 4)
            XCTAssertTrue(question.choices.contains(question.correctAnswer))
            XCTAssertEqual(Set(question.choices).count, question.choices.count)
            session.advance()
        }
    }

    func testDuplicateDeckAnswersAreNotRepeatedInChoices() throws {
        let cards = [
            Flashcard(languageOneText: "猫", languageTwoText: "cat"),
            Flashcard(languageOneText: "ネコ", languageTwoText: "CAT"),
            Flashcard(languageOneText: "犬", languageTwoText: "dog"),
            Flashcard(languageOneText: "鳥", languageTwoText: "bird"),
            Flashcard(languageOneText: "魚", languageTwoText: "fish"),
        ]
        let session = QuizSession(cards: cards)
        let question = try XCTUnwrap(session.currentQuestion)
        let normalizedChoices = question.choices.map { $0.localizedLowercase }

        XCTAssertTrue(question.choices.contains(question.correctAnswer))
        XCTAssertEqual(Set(normalizedChoices).count, normalizedChoices.count)
    }

    func testTwoCardDeckUsesAvailableUniqueChoicesWithoutBreaking() throws {
        let cards = [
            Flashcard(languageOneText: "猫", languageTwoText: "cat"),
            Flashcard(languageOneText: "犬", languageTwoText: "dog"),
        ]
        var session = QuizSession(cards: cards)

        for _ in cards {
            let question = try XCTUnwrap(session.currentQuestion)
            XCTAssertEqual(question.choices.count, 2)
            XCTAssertTrue(question.choices.contains(question.correctAnswer))
            XCTAssertEqual(Set(question.choices).count, question.choices.count)
            session.advance()
        }

        XCTAssertTrue(session.isFinished)
    }

    func testQuizUsesTheSamePlanAndCountAsFlashcardStudy() {
        let now = Date(timeIntervalSince1970: 1_760_000_000)
        let cards = (0..<12).map { index in
            Flashcard(
                languageOneText: "単語\(index)",
                languageTwoText: "word\(index)",
                createdAt: now.addingTimeInterval(Double(index))
            )
        }
        let sessionCardCount = 5
        let studyPlan = StudyScheduler.plan(
            cards: cards,
            count: sessionCardCount,
            now: now
        )
        let quizSession = QuizSession(
            cards: cards,
            sessionCardCount: sessionCardCount,
            now: now
        )

        XCTAssertEqual(quizSession.totalCount, studyPlan.count)
        XCTAssertEqual(quizSession.queue.map(\.id), studyPlan.map(\.id))
    }

    func testQuizUsesAllCardsWhenDeckHasFewerThanSessionCount() {
        let cards = [
            Flashcard(languageOneText: "猫", languageTwoText: "cat"),
            Flashcard(languageOneText: "犬", languageTwoText: "dog"),
        ]
        let quizSession = QuizSession(cards: cards, sessionCardCount: 10)

        XCTAssertEqual(quizSession.totalCount, 2)
        XCTAssertEqual(Set(quizSession.queue.map(\.id)), Set(cards.map(\.id)))
    }
}

@Suite("S5' クイズ形式選択")
struct QuizFormatSelectionTests {
    @Test("同義語パーサ: 空・混在区切り・空白・重複・単一要素を正規化する")
    func synonymParserBoundaries() {
        #expect(SynonymParser.parse("").isEmpty)
        #expect(
            SynonymParser.parse(" fast, quick、rapid・swift;speedy/slapdash\n hasty ")
                == ["fast", "quick", "rapid", "swift", "speedy", "slapdash", "hasty"]
        )
        #expect(SynonymParser.parse(" Same, same、SAME ") == ["Same"])
        #expect(SynonymParser.parse("solo") == ["solo"])
    }

    @Test("形式ゲート: 同義語なしは無効、登録済みなら有効になる")
    func synonymAvailabilityFollowsDeckData() {
        let withoutSynonyms = [
            Flashcard(
                languageOneText: "run",
                meanings: [MeaningEntry(meaning: "走る", synonyms: "")]
            ),
        ]
        let withSynonyms = [
            Flashcard(
                languageOneText: "run",
                meanings: [MeaningEntry(meaning: "走る", synonyms: "jog")]
            ),
        ]

        #expect(!QuestionType.synonym.isAvailable(in: withoutSynonyms))
        #expect(QuestionType.synonym.isAvailable(in: withSynonyms))
        #expect(QuestionType.fourChoice.isAvailable(in: withoutSynonyms))
        #expect(!QuestionType.fourChoice.isAvailable(in: []))
        #expect(QuestionType.textInput.isAvailable(in: withSynonyms))
        #expect(!QuestionType.clozeExample.isAvailable(in: withSynonyms))
    }

    @Test("選択肢生成: 両形式で正解必含・重複なし・同義語優先と不足時補完を守る")
    func questionChoicesStayValidAndFallbackSafely() throws {
        let fourChoiceCards = [
            Flashcard(languageOneText: "猫", languageTwoText: "cat"),
            Flashcard(languageOneText: "犬", languageTwoText: "dog"),
            Flashcard(languageOneText: "鳥", languageTwoText: "bird"),
            Flashcard(languageOneText: "魚", languageTwoText: "fish"),
        ]
        let fourChoice = try #require(QuizQuestion(
            card: fourChoiceCards[0],
            cards: fourChoiceCards,
            type: .fourChoice
        ))
        #expect(fourChoice.choices.contains(fourChoice.correctAnswer))
        #expect(Set(fourChoice.choices).count == fourChoice.choices.count)
        #expect(fourChoice.choices.count == 4)

        let synonymCards = [
            synonymCard("fast", synonyms: "quick"),
            synonymCard("slow", synonyms: "sluggish"),
            synonymCard("quiet", synonyms: "silent"),
            synonymCard("small", synonyms: "tiny"),
        ]
        let synonymQuestion = try #require(QuizQuestion(
            card: synonymCards[0],
            cards: synonymCards,
            type: .synonym
        ))
        #expect(Set(synonymQuestion.choices) == ["quick", "sluggish", "silent", "tiny"])
        #expect(Set(synonymQuestion.choices).count == synonymQuestion.choices.count)

        let fallbackCards = [
            synonymCard("fast", synonyms: "quick"),
            synonymCard("slow"),
            synonymCard("quiet"),
            synonymCard("small"),
        ]
        let fallbackQuestion = try #require(QuizQuestion(
            card: fallbackCards[0],
            cards: fallbackCards,
            type: .synonym
        ))
        #expect(fallbackQuestion.choices.contains("quick"))
        #expect(fallbackQuestion.choices.count == 4)
        #expect(Set(fallbackQuestion.choices).count == fallbackQuestion.choices.count)
    }

    @MainActor
    @Test("評価変換: 4択・同義語の正解はunsure、誤答はunknownとして保存する")
    func reviewMappingReachesRegisterReview() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fourChoiceCorrect = Flashcard(languageOneText: "猫", languageTwoText: "cat")
        let synonymCorrect = synonymCard("fast", synonyms: "quick")
        let incorrect = synonymCard("slow", synonyms: "sluggish")
        context.insert(FlashcardDeck(
            name: "形式別評価",
            cards: [fourChoiceCorrect, synonymCorrect, incorrect]
        ))
        try context.save()

        #expect(QuizReviewRecorder.rating(for: .multipleChoiceCorrect) == .unsure)
        #expect(QuizReviewRecorder.rating(for: .synonymCorrect) == .unsure)
        #expect(QuizReviewRecorder.rating(for: .multipleChoiceIncorrect) == .unknown)
        #expect(QuizReviewRecorder.rating(for: .synonymIncorrect) == .unknown)

        let firstRecorded = try QuizReviewRecorder.record(
            .multipleChoiceCorrect,
            cardID: fourChoiceCorrect.id,
            in: context
        )
        let secondRecorded = try QuizReviewRecorder.record(
            .synonymCorrect,
            cardID: synonymCorrect.id,
            in: context
        )
        let thirdRecorded = try QuizReviewRecorder.record(
            .synonymIncorrect,
            cardID: incorrect.id,
            in: context
        )

        #expect(firstRecorded != nil && secondRecorded != nil && thirdRecorded != nil)
        #expect(fourChoiceCorrect.lastRating == .unsure)
        #expect(synonymCorrect.lastRating == .unsure)
        #expect(incorrect.lastRating == .unknown)
    }

    @MainActor
    @Test("極小・削除境界: 同義語1件で進行し、途中削除は履歴保存を安全に中止する")
    func singleSynonymAndDeletedCardStaySafe() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let card = synonymCard("fast", synonyms: "quick")
        context.insert(FlashcardDeck(name: "削除境界", cards: [card]))
        try context.save()

        let session = QuizSession(cards: [card], questionType: .synonym)
        let question = try #require(session.currentQuestion)
        #expect(session.totalCount == 1)
        #expect(question.choices == ["quick"])

        context.delete(card)
        try context.save()

        let recorded = try QuizReviewRecorder.record(
            .synonymCorrect,
            cardID: question.cardID,
            in: context
        )
        #expect(recorded == nil)
        #expect(question.prompt == "fast")
        #expect(try context.fetch(FetchDescriptor<StudyReview>()).isEmpty)
    }

    private func synonymCard(_ word: String, synonyms: String = "") -> Flashcard {
        Flashcard(
            languageOneText: word,
            languageTwoText: word,
            meanings: [MeaningEntry(meaning: word, synonyms: synonyms)]
        )
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            FlashcardDeck.self,
            Flashcard.self,
            StudyReview.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

@Suite("S6' 例文穴埋め")
struct QuizClozeExampleTests {
    @Test("言語方向: 第2言語が例文にある場合はその語を空欄と正解にする")
    func usesTheLanguageThatExistsInTheExample() throws {
        let card = Flashcard(
            languageOneText: "共依存の",
            languageTwoText: "codependent on",
            meanings: [MeaningEntry(
                meaning: "共依存の",
                example: "She is codependent on her boyfriend and can't make any decisions without him."
            )]
        )

        let cloze = try #require(ClozeExampleBuilder.make(for: card))

        #expect(QuestionType.clozeExample.isAvailable(in: [card]))
        #expect(cloze.prompt == "She is _____ her boyfriend and can't make any decisions without him.")
        #expect(cloze.answer == "codependent on")
    }

    @Test("空欄生成: 大文字小文字を無視し、単語境界を守って最初の1か所だけ置換する")
    func buildsOnlyTheFirstWholeWordBlank() throws {
        let card = clozeCard(
            "cat",
            example: "A CAT watches another cat near a category.",
            translation: "猫が別の猫を見ています。"
        )

        let cloze = try #require(ClozeExampleBuilder.make(for: card))

        #expect(cloze.prompt == "A _____ watches another cat near a category.")
        #expect(cloze.answer == "cat")
        #expect(cloze.translation == "猫が別の猫を見ています。")
        #expect(ClozeExampleBuilder.make(for: clozeCard("cat", example: "A category.")) == nil)
    }

    @Test("対象抽出: 空例文と見出し語なしを除外し、混在デッキは穴埋め可能カードだけ出題する")
    func filtersIneligibleCardsAndGatesTheFormat() {
        let emptyExample = clozeCard("cat", example: "")
        let missingHeadword = clozeCard("dog", example: "A puppy is running.")
        let eligible = clozeCard("bird", example: "A bird can fly.")

        #expect(QuestionType.clozeExample.isImplemented)
        #expect(QuestionType.textInput.isImplemented)
        #expect(!QuestionType.clozeExample.isAvailable(in: [emptyExample, missingHeadword]))
        #expect(QuestionType.clozeExample.isAvailable(in: [emptyExample, missingHeadword, eligible]))

        let session = QuizSession(
            cards: [emptyExample, missingHeadword, eligible],
            questionType: .clozeExample,
            sessionCardCount: 10
        )
        #expect(session.totalCount == 1)
        #expect(session.queue.map(\.id) == [eligible.id])
    }

    @Test("回答判定: 前後空白と大文字小文字違いを許容し、別語は誤答にする")
    func judgesTrimmedCaseInsensitiveAnswers() throws {
        let card = clozeCard("cat", example: "The cat is sleeping.")
        let question = try #require(QuizQuestion(
            card: card,
            cards: [card],
            type: .clozeExample
        ))

        #expect(question.prompt == "The _____ is sleeping.")
        #expect(question.correctAnswer == "cat")
        #expect(question.isCorrect("  CAT\n"))
        #expect(!question.isCorrect("dog"))
    }

    @MainActor
    @Test("評価変換: 穴埋め正解はperfect、誤答はunknownとして既存記録層から保存する")
    func recordsClozeRatingsThroughTheSharedRecorder() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let correctCard = clozeCard("cat", example: "The cat is sleeping.")
        let incorrectCard = clozeCard("dog", example: "The dog is running.")
        context.insert(FlashcardDeck(name: "穴埋め評価", cards: [correctCard, incorrectCard]))
        try context.save()

        let correctOutcome = try #require(QuizAnswerOutcome(
            questionType: .clozeExample,
            isCorrect: true
        ))
        let incorrectOutcome = try #require(QuizAnswerOutcome(
            questionType: .clozeExample,
            isCorrect: false
        ))

        #expect(QuizReviewRecorder.rating(for: correctOutcome) == .perfect)
        #expect(QuizReviewRecorder.rating(for: incorrectOutcome) == .unknown)
        let correctResult = try QuizReviewRecorder.record(
            correctOutcome,
            cardID: correctCard.id,
            in: context
        )
        let incorrectResult = try QuizReviewRecorder.record(
            incorrectOutcome,
            cardID: incorrectCard.id,
            in: context
        )
        #expect(correctResult != nil)
        #expect(incorrectResult != nil)
        #expect(correctCard.lastRating == .perfect)
        #expect(incorrectCard.lastRating == .unknown)
        #expect(try context.fetch(FetchDescriptor<StudyReview>()).count == 2)
    }

    private func clozeCard(
        _ word: String,
        example: String,
        translation: String = ""
    ) -> Flashcard {
        Flashcard(
            languageOneText: word,
            languageTwoText: word,
            meanings: [MeaningEntry(
                meaning: word,
                example: example,
                exampleTranslation: translation
            )]
        )
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            FlashcardDeck.self,
            Flashcard.self,
            StudyReview.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

@Suite("S7' 文字記入")
struct QuizTextInputTests {
    @Test("実データ構成: 日本語を提示し、登録済みの英語を手入力の正解にする")
    func usesTheOwnerDeckLanguageDirection() throws {
        let card = Flashcard(
            languageOneText: "共依存の",
            languageTwoText: "codependent on"
        )
        let emptyAnswerCard = Flashcard(languageOneText: " ", languageTwoText: "\n")

        #expect(QuestionType.textInput.isImplemented)
        #expect(QuestionType.textInput.isAvailable(in: [card]))
        #expect(!QuestionType.textInput.isAvailable(in: [emptyAnswerCard]))

        let session = QuizSession(cards: [emptyAnswerCard, card], questionType: .textInput)
        let question = try #require(session.currentQuestion)

        #expect(session.totalCount == 1)
        #expect(question.prompt == "共依存の")
        #expect(question.correctAnswer == "codependent on")
        #expect(question.choices.isEmpty)
        #expect(question.hint == nil)
        #expect(question.isCorrect("codependent on"))
    }

    @Test("表記ゆれ境界: 大文字小文字と連続空白は許容し、空白欠落と別語は誤答にする")
    func normalizesCaseAndRepeatedWordSpacing() throws {
        let card = Flashcard(
            languageOneText: "共依存の",
            languageTwoText: "codependent on"
        )
        let question = try #require(QuizQuestion(
            card: card,
            cards: [card],
            type: .textInput
        ))

        #expect(question.isCorrect("  CODEPENDENT   ON  "))
        #expect(!question.isCorrect("codependenton"))
        #expect(!question.isCorrect("dependent on"))
    }

    @MainActor
    @Test("評価変換: 手入力の正誤を既存記録層からFSRSと履歴へ保存する")
    func recordsTextInputRatingsThroughTheSharedRecorder() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let correctCard = Flashcard(languageOneText: "共依存の", languageTwoText: "codependent on")
        let incorrectCard = Flashcard(languageOneText: "独立した", languageTwoText: "independent")
        context.insert(FlashcardDeck(name: "文字記入評価", cards: [correctCard, incorrectCard]))
        try context.save()

        let correctOutcome = try #require(QuizAnswerOutcome(
            questionType: .textInput,
            isCorrect: true
        ))
        let incorrectOutcome = try #require(QuizAnswerOutcome(
            questionType: .textInput,
            isCorrect: false
        ))

        #expect(QuizReviewRecorder.rating(for: correctOutcome) == .perfect)
        #expect(QuizReviewRecorder.rating(for: incorrectOutcome) == .unknown)
        let correctResult = try QuizReviewRecorder.record(
            correctOutcome,
            cardID: correctCard.id,
            in: context
        )
        let incorrectResult = try QuizReviewRecorder.record(
            incorrectOutcome,
            cardID: incorrectCard.id,
            in: context
        )
        #expect(correctResult != nil)
        #expect(incorrectResult != nil)
        #expect(correctCard.lastRating == .perfect)
        #expect(incorrectCard.lastRating == .unknown)
        #expect(try context.fetch(FetchDescriptor<StudyReview>()).count == 2)
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            FlashcardDeck.self,
            Flashcard.self,
            StudyReview.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

@Suite("S8' 結果画面")
struct QuizResultTests {
    @Test("実データ構成: 正誤・覚え度UP・苦手語をモデル側で集計する")
    func aggregatesOwnerDeckLanguageDirection() throws {
        let cards = [
            Flashcard(languageOneText: "共依存の", languageTwoText: "codependent on"),
            Flashcard(languageOneText: "独立した", languageTwoText: "independent"),
            Flashcard(languageOneText: "協力的な", languageTwoText: "cooperative"),
        ]
        var session = QuizSession(cards: cards, questionType: .textInput, sessionCardCount: 10)

        while let question = session.currentQuestion {
            let isIncorrect = question.cardID == cards[1].id
            session.recordAnswer(
                isCorrect: !isIncorrect,
                promoted: question.cardID == cards[0].id
            )
            session.advance()
        }

        let result = session.result
        #expect(result.correctCount == 2)
        #expect(result.totalCount == 3)
        #expect(result.promotedCount == 1)
        #expect(result.incorrectAnswers.map(\.cardID) == [cards[1].id])
        #expect(result.incorrectAnswers.map(\.cardText) == ["独立した"])
    }

    @MainActor
    @Test("QZ-22: 記録層からpromotedを返し、perfectへの昇格だけを数えられる")
    func propagatesPromotedFromTheSharedRecorder() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let promotedCard = Flashcard(languageOneText: "共依存の", languageTwoText: "codependent on")
        let unknownCard = Flashcard(languageOneText: "独立した", languageTwoText: "independent")
        context.insert(FlashcardDeck(name: "結果集計", cards: [promotedCard, unknownCard]))
        try context.save()

        let initialUnknownResult = try QuizReviewRecorder.record(
            .textInputIncorrect,
            cardID: promotedCard.id,
            in: context
        )
        let promotedResult = try QuizReviewRecorder.record(
            .textInputCorrect,
            cardID: promotedCard.id,
            in: context
        )
        let remainedUnknownResult = try QuizReviewRecorder.record(
            .textInputIncorrect,
            cardID: unknownCard.id,
            in: context
        )
        let initialUnknown = try #require(initialUnknownResult)
        let promoted = try #require(promotedResult)
        let remainedUnknown = try #require(remainedUnknownResult)

        #expect(!initialUnknown.promoted)
        #expect(promoted.promoted)
        #expect(!remainedUnknown.promoted)
        #expect(promotedCard.lastRating == .perfect)
        #expect(unknownCard.lastRating == .unknown)
        #expect(try context.fetch(FetchDescriptor<StudyReview>()).count == 3)
    }

    @Test("弱点再挑戦: 誤答カードだけで同形式を再生成し、全問正解と対象外は安全に縮退する")
    func retriesOnlyEligibleIncorrectCards() throws {
        let incorrectCard = Flashcard(languageOneText: "共依存の", languageTwoText: "codependent on")
        let correctCard = Flashcard(languageOneText: "独立した", languageTwoText: "independent")
        let cards = [incorrectCard, correctCard]
        var session = QuizSession(cards: cards, questionType: .textInput, sessionCardCount: 10)

        while let question = session.currentQuestion {
            session.recordAnswer(isCorrect: question.cardID == correctCard.id, promoted: false)
            session.advance()
        }

        let retry = try #require(session.retrySession(from: cards))
        #expect(retry.questionType == .textInput)
        #expect(retry.totalCount == 1)
        #expect(retry.queue.map(\.id) == [incorrectCard.id])

        var allCorrect = QuizSession(cards: cards, questionType: .textInput, sessionCardCount: 10)
        while allCorrect.currentQuestion != nil {
            allCorrect.recordAnswer(isCorrect: true, promoted: false)
            allCorrect.advance()
        }
        #expect(allCorrect.retrySession(from: cards) == nil)

        incorrectCard.languageOneText = " "
        incorrectCard.languageTwoText = " "
        #expect(session.retrySession(from: cards) == nil)
    }

    @MainActor
    @Test("ストリーク: クイズが保存した履歴を既存LearningProgressで連続日数に変換する")
    func usesExistingLearningProgressForQuizReviews() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let todayCard = Flashcard(languageOneText: "共依存の", languageTwoText: "codependent on")
        let yesterdayCard = Flashcard(languageOneText: "独立した", languageTwoText: "independent")
        context.insert(FlashcardDeck(name: "連続学習", cards: [todayCard, yesterdayCard]))
        try context.save()

        let calendar = Calendar.current
        let today = Date.now
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let yesterdayResult = try QuizReviewRecorder.record(
            .textInputCorrect,
            cardID: yesterdayCard.id,
            in: context,
            reviewedAt: yesterday
        )
        let todayResult = try QuizReviewRecorder.record(
            .textInputCorrect,
            cardID: todayCard.id,
            in: context,
            reviewedAt: today
        )
        _ = try #require(yesterdayResult)
        _ = try #require(todayResult)

        let reviews = try context.fetch(FetchDescriptor<StudyReview>())
        #expect(LearningProgress.consecutiveStudyDays(from: reviews, calendar: calendar) == 2)
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            FlashcardDeck.self,
            Flashcard.self,
            StudyReview.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
