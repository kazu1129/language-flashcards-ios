import SwiftData
import SwiftUI

struct CardEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: AppSettings
    @Bindable var deck: FlashcardDeck

    private let card: Flashcard?
    private let totalCardCount: Int
    @State private var languageOneText: String
    @State private var languageTwoText: String
    @State private var meanings: [MeaningEntry]
    @State private var duplicateWarningMessage: String?
    @State private var showingPremiumUpgrade = false

    init(deck: FlashcardDeck, card: Flashcard? = nil, totalCardCount: Int = 0) {
        self._deck = Bindable(deck)
        self.card = card
        self.totalCardCount = totalCardCount
        self._languageOneText = State(initialValue: card?.languageOneText ?? "")
        self._languageTwoText = State(initialValue: card?.languageTwoText ?? "")
        let savedMeanings = card?.meanings ?? []
        self._meanings = State(initialValue: savedMeanings.isEmpty ? [MeaningEntry()] : savedMeanings)
    }

    var body: some View {
        Form {
            Section(String(localized: "cardEditor.word.section")) {
                TextField(deck.localizedLanguageOneName, text: $languageOneText, axis: .vertical)
                    .lineLimit(1...4)
                TextField(deck.localizedLanguageTwoName, text: $languageTwoText, axis: .vertical)
                    .lineLimit(1...4)

                if hasDuplicate {
                    Label(String(localized: "cardEditor.duplicate.inline"), systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section(String(localized: "cardEditor.details.section")) {
                ForEach($meanings) { $meaning in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField(String(localized: "cardEditor.meaning.placeholder"), text: $meaning.meaning, axis: .vertical)
                            .lineLimit(1...3)
                        TextField(String(localized: "cardEditor.synonyms.placeholder"), text: $meaning.synonyms, axis: .vertical)
                            .lineLimit(1...3)
                        TextField(String(localized: "cardEditor.example.placeholder"), text: $meaning.example, axis: .vertical)
                            .lineLimit(1...4)
                        TextField(String(localized: "cardEditor.exampleTranslation.placeholder"), text: $meaning.exampleTranslation, axis: .vertical)
                            .lineLimit(1...4)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { offsets in
                    meanings.remove(atOffsets: offsets)
                    if meanings.isEmpty {
                        meanings.append(MeaningEntry())
                    }
                }

                Button {
                    meanings.append(MeaningEntry())
                } label: {
                    Label(String(localized: "cardEditor.add"), systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle(card == nil
            ? String(localized: "cardEditor.title.add")
            : String(localized: "cardEditor.title.edit")
        )
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "cardEditor.cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "cardEditor.save")) { save() }
                    .disabled(languageOneText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .alert(String(localized: "cardEditor.alert.duplicate.title"), isPresented: Binding(
            get: { duplicateWarningMessage != nil },
            set: { if !$0 { duplicateWarningMessage = nil } }
        )) {
            Button(String(localized: "cardEditor.alert.duplicate.allow")) {
                duplicateWarningMessage = nil
                save(allowDuplicate: true)
            }
            Button(String(localized: "cardEditor.alert.duplicate.back"), role: .cancel) {}
        } message: {
            Text(duplicateWarningMessage ?? "")
        }
        .sheet(isPresented: $showingPremiumUpgrade) {
            PremiumUpgradeView()
        }
    }

    private var hasDuplicate: Bool {
        FlashcardDuplicateChecker.hasDuplicate(
            in: deck,
            languageOne: languageOneText,
            languageTwo: languageTwoText,
            excluding: card?.id
        )
    }

    private func save(allowDuplicate: Bool = false) {
        let cleanedMeanings = meanings.filter { entry in
            !entry.meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !entry.synonyms.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !entry.example.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !entry.exampleTranslation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let cleanedLanguageOne = languageOneText.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedLanguageTwo = languageTwoText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !allowDuplicate,
           FlashcardDuplicateChecker.hasDuplicate(
               in: deck,
               languageOne: cleanedLanguageOne,
               languageTwo: cleanedLanguageTwo,
               excluding: card?.id
           ) {
            duplicateWarningMessage = String(localized: "cardEditor.alert.duplicate.message")
            return
        }

        if let card {
            card.languageOneText = cleanedLanguageOne
            card.languageTwoText = cleanedLanguageTwo
            card.meanings = cleanedMeanings
            card.updatedAt = .now
        } else {
            guard settings.canAddCards(totalCardCount: totalCardCount, adding: 1) else {
                showingPremiumUpgrade = true
                return
            }
            let newCard = Flashcard(
                languageOneText: cleanedLanguageOne,
                languageTwoText: cleanedLanguageTwo,
                meanings: cleanedMeanings
            )
            deck.cards.append(newCard)
        }

        deck.updatedAt = .now
        try? modelContext.save()
        dismiss()
    }
}
