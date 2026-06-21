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
    @State private var isCompleting = false
    @State private var errorMessage: String?
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
            }

            Section {
                Button {
                    if settings.canUseGeminiCompletion() {
                        Task { await completeWithGemini() }
                    } else {
                        showingPremiumUpgrade = true
                    }
                } label: {
                    if isCompleting {
                        ProgressView()
                    } else {
                        Label("Gemini（Google検索込み）で意味と例文を補完", systemImage: "sparkles")
                    }
                }
                .disabled(isCompleting || languageOneText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || settings.geminiAPIKey.isEmpty)

                if settings.geminiAPIKey.isEmpty {
                    Text("Gemini補完を使うには、設定でAPIキーを入力してください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !settings.isPremium {
                    Text("無料版のGemini補完は1日\(PremiumLimits.freeGeminiCompletionsPerDay)回まで。残り\(settings.totalFreeGeminiRemainingToday)回です。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Gemini APIのGoogle検索機能で、意味と例文を補完します。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("意味と例文") {
                ForEach($meanings) { $meaning in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("意味", text: $meaning.meaning, axis: .vertical)
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
                    .disabled(languageOneText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCompleting)
            }
        }
        .alert("Gemini補完に失敗しました", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showingPremiumUpgrade) {
            PremiumUpgradeView()
        }
    }

    private func completeWithGemini() async {
        isCompleting = true
        defer { isCompleting = false }

        do {
            let suggestion = try await GeminiService().completeCard(
                languageOneText: languageOneText,
                languageOneName: deck.languageOneName,
                languageTwoName: deck.languageTwoName,
                apiKey: settings.geminiAPIKey,
                model: settings.geminiModel
            )
            languageTwoText = suggestion.languageTwoText
            meanings = suggestion.meanings.isEmpty ? [MeaningEntry()] : suggestion.meanings
            settings.recordGeminiCompletion()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        let cleanedMeanings = meanings.filter { entry in
            !entry.meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !entry.example.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !entry.exampleTranslation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        if let card {
            card.languageOneText = languageOneText.trimmingCharacters(in: .whitespacesAndNewlines)
            card.languageTwoText = languageTwoText.trimmingCharacters(in: .whitespacesAndNewlines)
            card.meanings = cleanedMeanings
            card.updatedAt = .now
        } else {
            guard settings.canAddCards(totalCardCount: totalCardCount, adding: 1) else {
                showingPremiumUpgrade = true
                return
            }
            let newCard = Flashcard(
                languageOneText: languageOneText.trimmingCharacters(in: .whitespacesAndNewlines),
                languageTwoText: languageTwoText.trimmingCharacters(in: .whitespacesAndNewlines),
                meanings: cleanedMeanings
            )
            deck.cards.append(newCard)
        }

        deck.updatedAt = .now
        try? modelContext.save()
        dismiss()
    }
}
