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
    @State private var duplicateWarningMessage: String?
    @State private var cardLimitWarningMessage: String?

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
                    Button("無料トライアルでOCRを続ける") {
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
        .navigationTitle("写真から追加")
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
        TextImportParser.parse(recognizedText)
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
