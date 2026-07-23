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
    @State private var showingDeleteConfirmation = false

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
                        if meanings.count > 1 {
                            Button(role: .destructive) {
                                withAnimation {
                                    meanings = MeaningRowDeleteOperation.delete(
                                        id: meaning.id,
                                        from: meanings
                                    )
                                }
                            } label: {
                                Label("この意味を削除", systemImage: "trash")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { offsets in
                    withAnimation {
                        meanings = MeaningRowDeleteOperation.delete(
                            at: offsets,
                            from: meanings
                        )
                    }
                }

                Button {
                    meanings.append(MeaningEntry())
                } label: {
                    Label("意味を追加", systemImage: "plus.circle")
                }
            }

            if CardEditorDeleteOperation.canDelete(card: card) {
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("このカードを削除", systemImage: "trash")
                    }
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
        .confirmationDialog(
            "このカードを削除しますか？",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                deleteCard()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この操作は取り消せません。")
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

    private func deleteCard() {
        guard CardEditorDeleteOperation.delete(
            card: card,
            from: deck,
            in: modelContext
        ) else { return }
        dismiss()
    }
}

enum CardEditorDeleteOperation {
    static func canDelete(card: Flashcard?) -> Bool {
        card != nil
    }

    @MainActor
    @discardableResult
    static func delete(
        card: Flashcard?,
        from deck: FlashcardDeck,
        in modelContext: ModelContext,
        at deletedAt: Date = .now
    ) -> Bool {
        guard let card else { return false }
        modelContext.delete(card)
        deck.updatedAt = deletedAt
        try? modelContext.save()
        return true
    }
}

enum MeaningRowDeleteOperation {
    static func canDelete(from meanings: [MeaningEntry]) -> Bool {
        meanings.count > 1
    }

    static func delete(id: UUID, from meanings: [MeaningEntry]) -> [MeaningEntry] {
        guard canDelete(from: meanings) else { return meanings }
        let remainingMeanings = meanings.filter { $0.id != id }
        return ensuringAtLeastOneMeaning(in: remainingMeanings)
    }

    static func delete(at offsets: IndexSet, from meanings: [MeaningEntry]) -> [MeaningEntry] {
        var remainingMeanings = meanings
        remainingMeanings.remove(atOffsets: offsets)
        return ensuringAtLeastOneMeaning(in: remainingMeanings)
    }

    private static func ensuringAtLeastOneMeaning(in meanings: [MeaningEntry]) -> [MeaningEntry] {
        meanings.isEmpty ? [MeaningEntry()] : meanings
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
