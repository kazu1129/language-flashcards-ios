import Foundation

struct QuizQuestion {
    let cardID: UUID
    let prompt: String
    let correctAnswer: String
    let choices: [String]

    init(card: Flashcard, cards: [Flashcard]) {
        cardID = card.id
        prompt = card.languageOneText
        correctAnswer = Self.answerText(for: card)

        var seenAnswers = Set([Self.normalized(correctAnswer)])
        var distractors: [String] = []

        for candidate in cards.shuffled() where candidate.id != card.id {
            let answer = Self.answerText(for: candidate)
            guard seenAnswers.insert(Self.normalized(answer)).inserted else { continue }

            distractors.append(answer)
            if distractors.count == 3 { break }
        }

        choices = ([correctAnswer] + distractors).shuffled()
    }

    func isCorrect(_ choice: String) -> Bool {
        Self.normalized(choice) == Self.normalized(correctAnswer)
    }

    private static func answerText(for card: Flashcard) -> String {
        let answer = card.languageTwoText.trimmingCharacters(in: .whitespacesAndNewlines)
        return answer.isEmpty ? card.languageOneText : answer
    }

    private static func normalized(_ answer: String) -> String {
        answer.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    }
}

struct QuizSession {
    private(set) var queue: [Flashcard]
    private(set) var currentIndex = 0
    private let questions: [QuizQuestion]

    init(cards: [Flashcard]) {
        queue = cards
        questions = cards.map { QuizQuestion(card: $0, cards: cards) }
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
