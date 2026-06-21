import PhotosUI
import SwiftData
import SwiftUI
import UIKit

enum OCRImportStartSource: String, Identifiable {
    case camera
    case library

    var id: String { rawValue }

    var title: String {
        switch self {
        case .camera:
            "写真を撮る"
        case .library:
            "写真を選ぶ"
        }
    }
}

struct OCRImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: AppSettings
    @Bindable var deck: FlashcardDeck

    private let totalCardCount: Int
    private let startSource: OCRImportStartSource?
    private let onComplete: () -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var cameraImage: UIImage?
    @State private var recognizedText = ""
    @State private var isRecognizing = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingCamera = false
    @State private var showingPremiumUpgrade = false
    @State private var didHandleStartSource = false
    @State private var shouldCompleteWithGemini = true

    init(
        deck: FlashcardDeck,
        totalCardCount: Int = 0,
        startSource: OCRImportStartSource? = nil,
        onComplete: @escaping () -> Void = {}
    ) {
        self._deck = Bindable(deck)
        self.totalCardCount = totalCardCount
        self.startSource = startSource
        self.onComplete = onComplete
    }

    var body: some View {
        Form {
            Section {
                Button {
                    openCamera()
                } label: {
                    Label("写真を撮る", systemImage: "camera")
                }
                .disabled(!settings.canUseOCRImport() || !UIImagePickerController.isSourceTypeAvailable(.camera))

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("写真を選ぶ", systemImage: "photo.on.rectangle")
                }
                .disabled(!settings.canUseOCRImport())

                if isRecognizing {
                    HStack {
                        ProgressView()
                        Text("文字を読み取り中")
                    }
                }

                if !UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Text("この端末ではカメラ撮影を使えません。写真ライブラリから選んでください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !settings.isPremium {
                    Text("無料版の写真OCRは月\(PremiumLimits.freeOCRImportsPerMonth)回まで。残り\(settings.totalFreeOCRRemainingThisMonth)回です。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !settings.canUseOCRImport() {
                    Button("プレミアムでOCRを続ける") {
                        showingPremiumUpgrade = true
                    }
                }
            }

            Section("読み取り結果を編集") {
                TextEditor(text: $recognizedText)
                    .frame(minHeight: 180)
                    .overlay(alignment: .topLeading) {
                        if recognizedText.isEmpty {
                            Text("写真から抽出した文字がここに入ります。読み取りが違う場合は、この画面で修正できます。")
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                    }
            }

            Section("保存されるカード") {
                if parsedRows.isEmpty {
                    Text("英語のword/phraseを含む行だけ保存します。日本語など第1言語も同じ行にあれば、ペアとして登録します。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(parsedRows) { row in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(row.languageTwo)
                                .font(.headline)
                            Text("\(deck.languageOneName): \(row.languageOne)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
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

            if !parsedRows.isEmpty {
                Section("意味と例文") {
                    Toggle("Gemini（Google検索込み）で追加", isOn: $shouldCompleteWithGemini)
                        .disabled(settings.geminiAPIKey.isEmpty)

                    if settings.geminiAPIKey.isEmpty {
                        Text("保存時に意味と例文を追加するには、設定でGemini APIキーを入力してください。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Chromeを直接操作せず、Gemini APIのGoogle検索機能で意味と例文を補完します。無料版の残りは\(settings.totalFreeGeminiRemainingToday)回です。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("写真から追加")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "保存中" : "保存") {
                    Task { await saveRows() }
                }
                .disabled(parsedRows.isEmpty || isSaving || !settings.canAddCards(totalCardCount: totalCardCount, adding: parsedRows.count))
            }
        }
        .onAppear {
            handleStartSourceIfNeeded()
        }
        .task(id: selectedItem) {
            await recognizeSelectedImage()
        }
        .sheet(isPresented: $showingCamera) {
            CameraCaptureView(image: $cameraImage) { image in
                Task { await recognize(image: image) }
            }
                .ignoresSafeArea()
        }
        .alert("処理できませんでした", isPresented: Binding(
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

    private var parseResult: OCRParseResult {
        OCRLineParser.parse(recognizedText)
    }

    private var parsedRows: [OCRParsedRow] {
        parseResult.parsedRows
    }

    private var rejectedRows: [OCRRejectedRow] {
        parseResult.rejectedRows
    }

    private func handleStartSourceIfNeeded() {
        guard !didHandleStartSource else { return }
        didHandleStartSource = true
        if startSource == .camera {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                openCamera()
            }
        }
    }

    private func openCamera() {
        guard settings.canUseOCRImport() else {
            showingPremiumUpgrade = true
            return
        }
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            errorMessage = "この端末ではカメラ撮影を使えません。写真ライブラリから選んでください。"
            return
        }
        showingCamera = true
    }

    private func recognizeSelectedImage() async {
        guard let selectedItem else { return }
        guard settings.canUseOCRImport() else {
            showingPremiumUpgrade = true
            return
        }

        do {
            guard let data = try await selectedItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                throw OCRServiceError.missingImage
            }
            await recognize(image: image)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recognize(image: UIImage) async {
        guard settings.canUseOCRImport() else {
            showingPremiumUpgrade = true
            return
        }
        isRecognizing = true
        defer { isRecognizing = false }

        do {
            recognizedText = try await OCRService().recognizeText(from: image)
            settings.recordOCRImport()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveRows() async {
        let rows = parsedRows
        guard settings.canAddCards(totalCardCount: totalCardCount, adding: rows.count) else {
            showingPremiumUpgrade = true
            return
        }

        isSaving = true
        defer { isSaving = false }

        for row in rows {
            var languageOne = row.languageOne
            let languageTwo = row.languageTwo
            var meanings: [MeaningEntry] = []

            if shouldCompleteWithGemini,
               !settings.geminiAPIKey.isEmpty,
               settings.canUseGeminiCompletion() {
                do {
                    let suggestion = try await GeminiService().completeCard(
                        languageOneText: row.englishTerm,
                        languageOneName: deck.languageTwoName,
                        languageTwoName: deck.languageOneName,
                        apiKey: settings.geminiAPIKey,
                        model: settings.geminiModel,
                        exampleLanguageName: deck.languageTwoName,
                        useGoogleSearch: true
                    )
                    if languageOne == row.englishTerm || languageOne.isEmpty {
                        languageOne = suggestion.languageTwoText
                    }
                    meanings = suggestion.meanings
                    settings.recordGeminiCompletion()
                } catch {
                    errorMessage = "一部の意味と例文を追加できませんでした。カード自体は保存します。\(error.localizedDescription)"
                }
            }

            deck.cards.append(
                Flashcard(
                    languageOneText: languageOne,
                    languageTwoText: languageTwo,
                    meanings: meanings
                )
            )
        }

        deck.updatedAt = .now
        try? modelContext.save()
        dismiss()
        onComplete()
    }
}

private struct OCRParseResult {
    var parsedRows: [OCRParsedRow]
    var rejectedRows: [OCRRejectedRow]
}

private struct OCRParsedRow: Identifiable {
    let id = UUID()
    var rawLine: String
    var languageOne: String
    var languageTwo: String
    var englishTerm: String
    var note: String
}

private struct OCRRejectedRow: Identifiable {
    let id = UUID()
    var text: String
    var reason: String
}

private enum OCRLineParser {
    static func parse(_ text: String) -> OCRParseResult {
        var parsedRows: [OCRParsedRow] = []
        var rejectedRows: [OCRRejectedRow] = []

        for line in text
            .split(whereSeparator: \.isNewline)
            .map({ String($0).trimmingCharacters(in: .whitespacesAndNewlines) })
            .filter({ !$0.isEmpty }) {
            switch parseLine(line) {
            case .parsed(let row):
                parsedRows.append(row)
            case .rejected(let row):
                rejectedRows.append(row)
            }
        }

        return OCRParseResult(parsedRows: parsedRows, rejectedRows: rejectedRows)
    }

    private static func parseLine(_ line: String) -> ParseLineResult {
        let parts = splitLine(line)
        guard let englishPart = parts.first(where: containsEnglish) else {
            return .rejected(
                OCRRejectedRow(
                    text: line,
                    reason: "英語のword/phraseとして認識できなかったため、保存対象から外しました。"
                )
            )
        }

        let counterpart = parts.first { part in
            part != englishPart && !containsEnglish(part)
        }

        if let counterpart, !counterpart.isEmpty {
            return .parsed(
                OCRParsedRow(
                    rawLine: line,
                    languageOne: counterpart,
                    languageTwo: englishPart,
                    englishTerm: englishPart,
                    note: "第1言語と第2言語をペアで登録します。"
                )
            )
        }

        return .parsed(
            OCRParsedRow(
                rawLine: line,
                languageOne: englishPart,
                languageTwo: englishPart,
                englishTerm: englishPart,
                note: "英語のみ読み取れたため、第1言語は保存時にGemini補完できます。"
            )
        )
    }

    private static func splitLine(_ line: String) -> [String] {
        let delimiters = ["\t", " -> ", "->", " - ", " — ", " – ", ",", "，", "/", "／", ":", "："]
        for delimiter in delimiters {
            if let range = line.range(of: delimiter) {
                let first = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let second = String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                return [first, second].filter { !$0.isEmpty }
            }
        }

        if let englishRange = line.range(of: #"[A-Za-z][A-Za-z0-9 .,'’!?-]*"#, options: .regularExpression) {
            let english = String(line[englishRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let before = String(line[..<englishRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let after = String(line[englishRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            let other = [before, after].filter { !$0.isEmpty }.joined(separator: " ")
            if !other.isEmpty {
                return [other, english].filter { !$0.isEmpty }
            }
        }

        return [line]
    }

    private static func containsEnglish(_ text: String) -> Bool {
        text.range(of: #"[A-Za-z]"#, options: .regularExpression) != nil
    }
}

private enum ParseLineResult {
    case parsed(OCRParsedRow)
    case rejected(OCRRejectedRow)
}
