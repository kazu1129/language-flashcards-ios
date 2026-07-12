import Foundation

enum FlashcardDuplicateChecker {
    static func hasDuplicate(
        in deck: FlashcardDeck,
        languageOne: String,
        languageTwo: String,
        excluding cardID: UUID? = nil
    ) -> Bool {
        let candidates = normalizedValues([languageOne, languageTwo])
        guard !candidates.isEmpty else { return false }

        return deck.cards.contains { card in
            guard card.id != cardID else { return false }
            let existing = normalizedValues([card.languageOneText, card.languageTwoText])
            return !candidates.isDisjoint(with: existing)
        }
    }

    static func duplicateRowIDs(for rows: [TextImportParsedRow], in deck: FlashcardDeck) -> Set<String> {
        var seen: [String: String] = [:]
        var duplicatedIDs: Set<String> = []

        for row in rows {
            let values = normalizedValues([row.languageOne, row.languageTwo, row.englishTerm])
            if hasDuplicate(in: deck, languageOne: row.languageOne, languageTwo: row.languageTwo) {
                duplicatedIDs.insert(row.id)
            }

            for value in values {
                if let firstID = seen[value] {
                    duplicatedIDs.insert(firstID)
                    duplicatedIDs.insert(row.id)
                } else {
                    seen[value] = row.id
                }
            }
        }

        return duplicatedIDs
    }

    static func warningMessage(for rows: [TextImportParsedRow], in deck: FlashcardDeck) -> String? {
        let duplicateIDs = duplicateRowIDs(for: rows, in: deck)
        guard !duplicateIDs.isEmpty else { return nil }
        return String.localizedStringWithFormat(
            String(localized: "import.warning.duplicateRows"),
            Int64(duplicateIDs.count)
        )
    }

    private static func normalizedValues(_ values: [String]) -> Set<String> {
        Set(
            values
                .map { normalize($0) }
                .filter { !$0.isEmpty }
        )
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
    }
}
