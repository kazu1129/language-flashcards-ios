import Foundation

struct QuizSession {
    private(set) var queue: [Flashcard]
    private(set) var currentIndex = 0

    init(cards: [Flashcard]) {
        queue = cards
    }

    var currentCard: Flashcard? {
        guard queue.indices.contains(currentIndex) else { return nil }
        return queue[currentIndex]
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
