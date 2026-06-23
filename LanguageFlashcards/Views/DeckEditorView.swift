import SwiftData
import SwiftUI

struct DeckEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let deck: FlashcardDeck?
    @State private var name = ""
    @State private var languageOneName = "日本語"
    @State private var languageTwoName = "英語"

    init(deck: FlashcardDeck? = nil) {
        self.deck = deck
        self._name = State(initialValue: deck?.name ?? "")
        self._languageOneName = State(initialValue: deck?.languageOneName ?? "日本語")
        self._languageTwoName = State(initialValue: deck?.languageTwoName ?? "英語")
    }

    var body: some View {
        Form {
            Section("セット") {
                TextField("名前", text: $name)
            }

            Section("言語") {
                TextField("第1言語", text: $languageOneName)
                TextField("第2言語", text: $languageTwoName)
            }
        }
        .navigationTitle(deck == nil ? "セットを追加" : "セットを編集")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
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
