import Foundation

enum QuestionType: String, CaseIterable, Identifiable {
    case fourChoice
    case synonym
    case textInput
    case clozeExample

    var id: Self { self }

    var title: String {
        switch self {
        case .fourChoice: "4択"
        case .synonym: "同義語"
        case .textInput: "手入力"
        case .clozeExample: "例文穴埋め"
        }
    }

    var systemImage: String {
        switch self {
        case .fourChoice: "list.bullet.rectangle"
        case .synonym: "arrow.triangle.branch"
        case .textInput: "keyboard"
        case .clozeExample: "text.badge.checkmark"
        }
    }

    var description: String {
        switch self {
        case .fourChoice: "意味を4択から選ぶ"
        case .synonym: "正しい同義語を選ぶ"
        case .textInput: "答えを文字で入力"
        case .clozeExample: "例文の空欄を入力"
        }
    }

    var isImplemented: Bool {
        self == .fourChoice || self == .synonym || self == .textInput || self == .clozeExample
    }

    func isAvailable(in cards: [Flashcard]) -> Bool {
        !eligibleCards(from: cards).isEmpty
    }

    fileprivate func eligibleCards(from cards: [Flashcard]) -> [Flashcard] {
        switch self {
        case .fourChoice:
            cards
        case .synonym:
            cards.filter { !SynonymParser.parse($0.meanings).isEmpty }
        case .clozeExample:
            cards.filter { ClozeExampleBuilder.make(for: $0) != nil }
        case .textInput:
            cards.filter { !QuizQuestion.answerText(for: $0).isEmpty }
        }
    }
}

struct ClozeExample: Equatable {
    let prompt: String
    let answer: String
    let translation: String?
}

enum ClozeExampleBuilder {
    static func make(for card: Flashcard) -> ClozeExample? {
        let answerCandidates = [card.languageOneText, card.languageTwoText]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for meaning in card.meanings {
            let example = meaning.example.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !example.isEmpty else { continue }

            for answer in answerCandidates {
                guard let prompt = blankFirstOccurrence(of: answer, in: example) else { continue }

                let translation = meaning.exampleTranslation.trimmingCharacters(in: .whitespacesAndNewlines)
                return ClozeExample(
                    prompt: prompt,
                    answer: answer,
                    translation: translation.isEmpty ? nil : translation
                )
            }
        }

        return nil
    }

    private static func blankFirstOccurrence(of answer: String, in example: String) -> String? {
        let escapedAnswer = NSRegularExpression.escapedPattern(for: answer)
        let pattern = "(?<![\\p{L}\\p{N}_])\(escapedAnswer)(?![\\p{L}\\p{N}_])"
        guard let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }

        let searchRange = NSRange(example.startIndex..<example.endIndex, in: example)
        guard
            let match = expression.firstMatch(in: example, range: searchRange),
            let range = Range(match.range, in: example)
        else {
            return nil
        }

        return example.replacingCharacters(in: range, with: "_____")
    }
}

enum SynonymParser {
    private static let separators = CharacterSet(charactersIn: ",、・;/\n\r")

    static func parse(_ text: String) -> [String] {
        unique(text.components(separatedBy: separators))
    }

    static func parse(_ meanings: [MeaningEntry]) -> [String] {
        unique(meanings.flatMap { parse($0.synonyms) })
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(normalized(trimmed)).inserted else {
                return nil
            }
            return trimmed
        }
    }

    private static func normalized(_ value: String) -> String {
        value.localizedLowercase
    }
}

struct QuizQuestion {
    let cardID: UUID
    let cardText: String
    let type: QuestionType
    let prompt: String
    let correctAnswer: String
    let choices: [String]
    let hint: String?

    init?(card: Flashcard, cards: [Flashcard], type: QuestionType = .fourChoice) {
        cardID = card.id
        cardText = card.languageOneText
        self.type = type

        switch type {
        case .fourChoice:
            prompt = card.languageOneText
            correctAnswer = Self.answerText(for: card)
            let candidates = cards.shuffled()
                .filter { $0.id != card.id }
                .map(Self.answerText(for:))
            choices = Self.choices(correctAnswer: correctAnswer, candidates: candidates)
            hint = nil

        case .synonym:
            prompt = card.languageOneText
            let correctAnswers = SynonymParser.parse(card.meanings)
            guard let answer = correctAnswers.first else { return nil }
            correctAnswer = answer

            let otherCards = cards.shuffled().filter { $0.id != card.id }
            let synonymCandidates = otherCards.flatMap { card in
                SynonymParser.parse(card.meanings).shuffled()
            }
            let fallbackCandidates = otherCards.map(\.languageOneText)
            let blockedAnswers = Set(correctAnswers.map(Self.normalized))

            choices = Self.choices(
                correctAnswer: correctAnswer,
                candidates: synonymCandidates + fallbackCandidates,
                blockedAnswers: blockedAnswers
            )
            hint = nil

        case .clozeExample:
            guard let cloze = ClozeExampleBuilder.make(for: card) else { return nil }
            prompt = cloze.prompt
            correctAnswer = cloze.answer
            choices = []
            hint = cloze.translation

        case .textInput:
            let answer = Self.answerText(for: card)
            guard !answer.isEmpty else { return nil }
            prompt = card.languageOneText
            correctAnswer = answer
            choices = []
            hint = nil
        }
    }

    func isCorrect(_ choice: String) -> Bool {
        Self.normalized(choice) == Self.normalized(correctAnswer)
    }

    fileprivate static func answerText(for card: Flashcard) -> String {
        let answer = card.languageTwoText.trimmingCharacters(in: .whitespacesAndNewlines)
        return answer.isEmpty
            ? card.languageOneText.trimmingCharacters(in: .whitespacesAndNewlines)
            : answer
    }

    private static func choices(
        correctAnswer: String,
        candidates: [String],
        blockedAnswers: Set<String> = []
    ) -> [String] {
        var seenAnswers = blockedAnswers
        seenAnswers.insert(normalized(correctAnswer))
        var distractors: [String] = []

        for candidate in candidates {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seenAnswers.insert(normalized(trimmed)).inserted else {
                continue
            }

            distractors.append(trimmed)
            if distractors.count == 3 { break }
        }

        return ([correctAnswer] + distractors).shuffled()
    }

    private static func normalized(_ answer: String) -> String {
        answer
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .localizedLowercase
    }
}

struct QuizSessionAnswer: Equatable, Identifiable {
    let cardID: UUID
    let cardText: String
    let isCorrect: Bool
    let promoted: Bool

    var id: UUID { cardID }
}

struct QuizSessionResult: Equatable {
    let totalCount: Int
    let answers: [QuizSessionAnswer]

    var correctCount: Int {
        answers.filter(\.isCorrect).count
    }

    var promotedCount: Int {
        answers.filter(\.promoted).count
    }

    var incorrectAnswers: [QuizSessionAnswer] {
        answers.filter { !$0.isCorrect }
    }
}

struct QuizSession {
    private(set) var queue: [Flashcard]
    private(set) var currentIndex = 0
    private(set) var answers: [QuizSessionAnswer] = []
    private let questions: [QuizQuestion]
    let questionType: QuestionType

    init(
        cards: [Flashcard],
        questionType: QuestionType = .fourChoice,
        sessionCardCount: Int = .max,
        now: Date = .now
    ) {
        self.questionType = questionType
        let sessionCards = StudyScheduler.plan(
            cards: questionType.eligibleCards(from: cards),
            count: sessionCardCount,
            now: now
        )
        let entries = sessionCards.compactMap { card in
            QuizQuestion(card: card, cards: cards, type: questionType).map { (card, $0) }
        }
        queue = entries.map(\.0)
        questions = entries.map(\.1)
    }

    var currentCard: Flashcard? {
        guard queue.indices.contains(currentIndex) else { return nil }
        return queue[currentIndex]
    }

    var currentQuestion: QuizQuestion? {
        guard questions.indices.contains(currentIndex) else { return nil }
        return questions[currentIndex]
    }

    var totalCount: Int {
        queue.count
    }

    var isFinished: Bool {
        currentIndex >= queue.count
    }

    var result: QuizSessionResult {
        QuizSessionResult(totalCount: totalCount, answers: answers)
    }

    mutating func recordAnswer(isCorrect: Bool, promoted: Bool) {
        guard
            let question = currentQuestion,
            !answers.contains(where: { $0.cardID == question.cardID })
        else {
            return
        }

        answers.append(QuizSessionAnswer(
            cardID: question.cardID,
            cardText: question.cardText,
            isCorrect: isCorrect,
            promoted: promoted
        ))
    }

    func retrySession(from availableCards: [Flashcard], now: Date = .now) -> QuizSession? {
        let incorrectCardIDs = Set(result.incorrectAnswers.map(\.cardID))
        guard !incorrectCardIDs.isEmpty else { return nil }

        let retryCards = availableCards.filter { incorrectCardIDs.contains($0.id) }
        let retrySession = QuizSession(
            cards: retryCards,
            questionType: questionType,
            sessionCardCount: retryCards.count,
            now: now
        )
        return retrySession.totalCount > 0 ? retrySession : nil
    }

    mutating func advance() {
        guard !isFinished else { return }
        currentIndex += 1
    }
}
