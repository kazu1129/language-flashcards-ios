import SwiftData
import SwiftUI

struct DeckEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let deck: FlashcardDeck?
    @State private var name = ""
    @State private var languageOneName = String(localized: "language.japanese")
    @State private var languageTwoName = String(localized: "language.english")

    init(deck: FlashcardDeck? = nil) {
        self.deck = deck
        self._name = State(initialValue: deck?.name ?? "")
        self._languageOneName = State(initialValue: deck?.localizedLanguageOneName ?? String(localized: "language.japanese"))
        self._languageTwoName = State(initialValue: deck?.localizedLanguageTwoName ?? String(localized: "language.english"))
    }

    var body: some View {
        Form {
            Section(String(localized: "deckEditor.set.section")) {
                TextField(String(localized: "deckEditor.name.placeholder"), text: $name)
            }

            Section(String(localized: "deckEditor.languages.section")) {
                TextField(String(localized: "deckEditor.languageOne.placeholder"), text: $languageOneName)
                TextField(String(localized: "deckEditor.languageTwo.placeholder"), text: $languageTwoName)
            }
        }
        .navigationTitle(deck == nil ? String(localized: "deckEditor.add.title") : String(localized: "deckEditor.edit.title"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "common.cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "common.save")) {
                    save()
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedLanguageOneName = languageOneName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedLanguageTwoName = languageTwoName.trimmingCharacters(in: .whitespacesAndNewlines)

        if let deck {
            deck.name = cleanedName
            deck.languageOneName = cleanedLanguageOneName
            deck.languageTwoName = cleanedLanguageTwoName
            deck.updatedAt = .now
        } else {
            let deck = FlashcardDeck(
                name: cleanedName,
                languageOneName: cleanedLanguageOneName,
                languageTwoName: cleanedLanguageTwoName
            )
            modelContext.insert(deck)
        }

        try? modelContext.save()
    }
}
