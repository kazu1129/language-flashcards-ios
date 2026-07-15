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
            Section("単語 / フレーズ") {
                TextField(deck.languageOneName, text: $languageOneText, axis: .vertical)
                    .lineLimit(1...4)
                TextField(deck.languageTwoName, text: $languageTwoText, axis: .vertical)
                    .lineLimit(1...4)

                if hasDuplicate {
                    Label("同じ単語/表現がすでに登録されている可能性があります。", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("意味・同義語・例文") {
                ForEach($meanings) { $meaning in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("意味", text: $meaning.meaning, axis: .vertical)
                            .lineLimit(1...3)
                        TextField("同義語", text: $meaning.synonyms, axis: .vertical)
                            .lineLimit(1...3)
                        TextField("例文", text: $meaning.example, axis: .vertical)
                            .lineLimit(1...4)
                        TextField("例文の訳", text: $meaning.exampleTranslation, axis: .vertical)
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
                    Label("意味を追加", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle(card == nil ? "カードを追加" : "カードを編集")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .disabled(languageOneText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .alert("重複があります", isPresented: Binding(
            get: { duplicateWarningMessage != nil },
            set: { if !$0 { duplicateWarningMessage = nil } }
        )) {
            Button("重複を含めて保存") {
                duplicateWarningMessage = nil
                save(allowDuplicate: true)
            }
            Button("戻る", role: .cancel) {}
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
            duplicateWarningMessage = "同じ単語/表現がすでに登録されている可能性があります。保存してもよいか確認してください。"
            return
        }

        let savedAt = Date.now
        if let card {
            CardEditorSaveOperation.updateExistingCard(
                card,
                in: deck,
                languageOneText: cleanedLanguageOne,
                languageTwoText: cleanedLanguageTwo,
                meanings: cleanedMeanings,
                savedAt: savedAt
            )
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
            deck.updatedAt = savedAt
        }

        try? modelContext.save()
        dismiss()
    }
}

enum CardEditorSaveOperation {
    static func updateExistingCard(
        _ card: Flashcard,
        in deck: FlashcardDeck,
        languageOneText: String,
        languageTwoText: String,
        meanings: [MeaningEntry],
        savedAt: Date = .now
    ) {
        card.languageOneText = languageOneText
        card.languageTwoText = languageTwoText
        card.meanings = meanings
        card.updatedAt = savedAt
        deck.updatedAt = savedAt
    }
}
