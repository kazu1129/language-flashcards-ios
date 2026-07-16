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
        self == .fourChoice || self == .synonym
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
        case .textInput, .clozeExample:
            []
        }
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
    let type: QuestionType
    let prompt: String
    let correctAnswer: String
    let choices: [String]

    init?(card: Flashcard, cards: [Flashcard], type: QuestionType = .fourChoice) {
        cardID = card.id
        self.type = type
        prompt = card.languageOneText

        switch type {
        case .fourChoice:
            correctAnswer = Self.answerText(for: card)
            let candidates = cards.shuffled()
                .filter { $0.id != card.id }
                .map(Self.answerText(for:))
            choices = Self.choices(correctAnswer: correctAnswer, candidates: candidates)

        case .synonym:
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
        case .textInput, .clozeExample:
            return nil
        }
    }

    func isCorrect(_ choice: String) -> Bool {
        Self.normalized(choice) == Self.normalized(correctAnswer)
    }

    private static func answerText(for card: Flashcard) -> String {
        let answer = card.languageTwoText.trimmingCharacters(in: .whitespacesAndNewlines)
        return answer.isEmpty ? card.languageOneText : answer
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
        answer.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    }
}

struct QuizSession {
    private(set) var queue: [Flashcard]
    private(set) var currentIndex = 0
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

    mutating func advance() {
        guard !isFinished else { return }
        currentIndex += 1
    }
}
