import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct TextFileImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: AppSettings
    @Bindable var deck: FlashcardDeck

    private let totalCardCount: Int
    private let onComplete: () -> Void

    @State private var importedText = ""
    @State private var selectedFileName: String?
    @State private var showingFileImporter = false
    @State private var showingPremiumUpgrade = false
    @State private var duplicateWarningMessage: String?
    @State private var cardLimitWarningMessage: String?
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(
        deck: FlashcardDeck,
        totalCardCount: Int = 0,
        onComplete: @escaping () -> Void = {}
    ) {
        self._deck = Bindable(deck)
        self.totalCardCount = totalCardCount
        self.onComplete = onComplete
    }

    var body: some View {
        Form {
            Section {
                Button {
                    showingFileImporter = true
                } label: {
                    Label("CSV/TXTファイルを選ぶ", systemImage: "doc.badge.plus")
                }

                if let selectedFileName {
                    Text(selectedFileName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("読み取り結果を編集") {
                TextEditor(text: $importedText)
                    .frame(minHeight: 180)
                    .overlay(alignment: .topLeading) {
                        if importedText.isEmpty {
                            Text("CSV/TXTから読み込んだ内容がここに入ります。必要に応じて保存前に修正できます。")
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                    }
            }

            Section("保存されるカード") {
                if parsedRows.isEmpty {
                    Text("英語と日本語の順序は任意です。英語のword/phraseを見つけて、自動的に第2言語側へ振り分けます。")
                        .foregroundStyle(.secondary)
                } else {
                    if exceedsCardLimit {
                        Label(cardLimitSummary, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    ForEach(parsedRows) { row in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(row.languageTwo)
                                .font(.headline)
                            Text("\(deck.languageOneName): \(row.languageOne)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if duplicateRowIDs.contains(row.id) {
                                Text("重複の可能性があります")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            if !row.note.isEmpty {
                                Text(row.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if !rejectedRows.isEmpty {
                Section("保存しない読み取り結果") {
                    ForEach(rejectedRows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.text)
                            Text(row.reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

        }
        .navigationTitle("ファイルから追加")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "保存中" : "保存") {
                    Task { await attemptSaveRows() }
                }
                .disabled(parsedRows.isEmpty || isSaving)
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText, .text],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .alert("読み込めませんでした", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("カード数の上限を超えています", isPresented: Binding(
            get: { cardLimitWarningMessage != nil },
            set: { if !$0 { cardLimitWarningMessage = nil } }
        )) {
            Button("無料トライアルを見る") {
                cardLimitWarningMessage = nil
                showingPremiumUpgrade = true
            }
            Button("戻る", role: .cancel) {}
        } message: {
            Text(cardLimitWarningMessage ?? "")
        }
        .alert("重複があります", isPresented: Binding(
            get: { duplicateWarningMessage != nil },
            set: { if !$0 { duplicateWarningMessage = nil } }
        )) {
            Button("重複を含めて保存") {
                let rows = parsedRows
                duplicateWarningMessage = nil
                Task { await saveRows(rows) }
            }
            Button("戻る", role: .cancel) {}
        } message: {
            Text(duplicateWarningMessage ?? "")
        }
        .sheet(isPresented: $showingPremiumUpgrade) {
            PremiumUpgradeView()
        }
    }

    private var parseResult: TextImportParseResult {
        TextImportParser.parse(importedText)
    }

    private var parsedRows: [TextImportParsedRow] {
        parseResult.parsedRows
    }

    private var rejectedRows: [TextImportRejectedRow] {
        parseResult.rejectedRows
    }

    private var duplicateRowIDs: Set<String> {
        FlashcardDuplicateChecker.duplicateRowIDs(for: parsedRows, in: deck)
    }

    private var exceedsCardLimit: Bool {
        !parsedRows.isEmpty && !settings.canAddCards(totalCardCount: totalCardCount, adding: parsedRows.count)
    }

    private var remainingFreeCardSlots: Int {
        max(0, PremiumLimits.freeCards - totalCardCount)
    }

    private var cardLimitSummary: String {
        "無料版のカード上限を超えています。追加可能: 残り\(remainingFreeCardSlots)枚 / 保存対象: \(parsedRows.count)枚"
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            guard let text = decodeText(from: data) else {
                errorMessage = "UTF-8または日本語の一般的な文字コードとして読み取れませんでした。"
                return
            }

            importedText = text
            selectedFileName = url.lastPathComponent
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func decodeText(from data: Data) -> String? {
        let encodings: [String.Encoding] = [.utf8, .utf16, .shiftJIS, .japaneseEUC]
        for encoding in encodings {
            if let text = String(data: data, encoding: encoding) {
                return text
            }
        }
        return nil
    }

    private func attemptSaveRows() async {
        let rows = parsedRows
        guard settings.canAddCards(totalCardCount: totalCardCount, adding: rows.count) else {
            cardLimitWarningMessage = "\(cardLimitSummary)。保存するには、無料プレミアムトライアルを開始するか、読み取り結果を編集して保存対象を減らしてください。"
            return
        }

        if let warning = FlashcardDuplicateChecker.warningMessage(for: rows, in: deck) {
            duplicateWarningMessage = warning
            return
        }
        await saveRows(rows)
    }

    private func saveRows(_ rows: [TextImportParsedRow]) async {
        guard settings.canAddCards(totalCardCount: totalCardCount, adding: rows.count) else {
            showingPremiumUpgrade = true
            return
        }

        isSaving = true
        defer { isSaving = false }

        for row in rows {
            let languageOne = row.languageOne
            let languageTwo = row.languageTwo

            deck.cards.append(
                Flashcard(
                    languageOneText: languageOne,
                    languageTwoText: languageTwo
                )
            )
        }

        deck.updatedAt = .now
        try? modelContext.save()
        dismiss()
        onComplete()
    }
}
