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
                    Label(String(localized: "textFile.chooseFile"), systemImage: "doc.badge.plus")
                }

                if let selectedFileName {
                    Text(selectedFileName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section(String(localized: "import.editResults.section")) {
                TextEditor(text: $importedText)
                    .frame(minHeight: 180)
                    .overlay(alignment: .topLeading) {
                        if importedText.isEmpty {
                            Text("textFile.textEditor.placeholder")
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                    }
            }

            Section(String(localized: "import.savedCards.section")) {
                if parsedRows.isEmpty {
                    Text("textFile.savedCards.emptyDescription")
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
                            Text("\(deck.localizedLanguageOneName): \(row.languageOne)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if duplicateRowIDs.contains(row.id) {
                                Text("import.duplicate.possible")
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
                Section(String(localized: "import.rejected.section")) {
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
        .navigationTitle(String(localized: "home.addFromFile.title"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "cardEditor.cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? String(localized: "import.save.inProgress") : String(localized: "cardEditor.save")) {
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
        .alert(String(localized: "textFile.loadError.title"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(String(localized: "common.cardLimit.title"), isPresented: Binding(
            get: { cardLimitWarningMessage != nil },
            set: { if !$0 { cardLimitWarningMessage = nil } }
        )) {
            Button(String(localized: "common.viewTrial")) {
                cardLimitWarningMessage = nil
                showingPremiumUpgrade = true
            }
            Button(String(localized: "import.alert.duplicate.back"), role: .cancel) {}
        } message: {
            Text(cardLimitWarningMessage ?? "")
        }
        .alert(String(localized: "cardEditor.alert.duplicate.title"), isPresented: Binding(
            get: { duplicateWarningMessage != nil },
            set: { if !$0 { duplicateWarningMessage = nil } }
        )) {
            Button(String(localized: "cardEditor.alert.duplicate.allow")) {
                let rows = parsedRows
                duplicateWarningMessage = nil
                Task { await saveRows(rows) }
            }
            Button(String(localized: "import.alert.duplicate.back"), role: .cancel) {}
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
        String.localizedStringWithFormat(
            String(localized: "common.cardLimit.summary"),
            Int64(remainingFreeCardSlots),
            Int64(parsedRows.count)
        )
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
                errorMessage = String(localized: "textFile.encodingError")
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
            cardLimitWarningMessage = String.localizedStringWithFormat(
                String(localized: "common.cardLimit.message"),
                cardLimitSummary
            )
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
