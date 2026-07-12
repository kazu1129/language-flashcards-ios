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
        languageOneName: String = String(localized: "language.japanese"),
        languageTwoName: String = String(localized: "language.english"),
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

    var localizedLanguageOneName: String {
        LanguageDisplayName.localizedName(for: languageOneName)
    }

    var localizedLanguageTwoName: String {
        LanguageDisplayName.localizedName(for: languageTwoName)
    }
}

enum LanguageDisplayName {
    static func localizedName(for languageName: String) -> String {
        switch languageName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "\u{65E5}\u{672C}\u{8A9E}", "japanese":
            String(localized: "language.japanese")
        case "\u{82F1}\u{8A9E}", "\u{7C73}\u{8A9E}", "english":
            String(localized: "language.english")
        default:
            languageName
        }
    }
}
