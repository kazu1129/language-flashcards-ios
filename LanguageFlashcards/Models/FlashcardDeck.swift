import Foundation
import SwiftData

@Model
final class FlashcardDeck: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var languageOneName: String
    var languageTwoName: String
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade) var cards: [Flashcard]

    init(
        id: UUID = UUID(),
        name: String,
        languageOneName: String = "日本語",
        languageTwoName: String = "英語",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        cards: [Flashcard] = []
    ) {
        self.id = id
        self.name = name
        self.languageOneName = languageOneName
        self.languageTwoName = languageTwoName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.cards = cards
    }

    var sortedCards: [Flashcard] {
        cards.sorted { left, right in
            if left.createdAt == right.createdAt {
                return left.languageOneText.localizedCompare(right.languageOneText) == .orderedAscending
            }
            return left.createdAt < right.createdAt
        }
    }
}
