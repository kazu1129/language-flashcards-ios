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
            String(localized: "home.takePhoto")
        case .library:
            String(localized: "home.choosePhoto")
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
                    Label(String(localized: "home.takePhoto"), systemImage: "camera")
                }
                .disabled(!settings.canUseOCRImport() || !UIImagePickerController.isSourceTypeAvailable(.camera))

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label(String(localized: "home.choosePhoto"), systemImage: "photo.on.rectangle")
                }
                .disabled(!settings.canUseOCRImport())

                if isRecognizing {
                    HStack {
                        ProgressView()
                        Text("ocr.recognizing")
                    }
                }

                if !UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Text("ocr.cameraUnavailable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !settings.isPremium {
                    Text(freeOCRRemainingText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !settings.canUseOCRImport() {
                    Button(String(localized: "ocr.continueTrial")) {
                        showingPremiumUpgrade = true
                    }
                }
            }

            Section(String(localized: "import.editResults.section")) {
                TextEditor(text: $recognizedText)
                    .frame(minHeight: 180)
                    .overlay(alignment: .topLeading) {
                        if recognizedText.isEmpty {
                            Text("ocr.textEditor.placeholder")
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                    }
            }

            Section(String(localized: "import.savedCards.section")) {
                if parsedRows.isEmpty {
                    Text("ocr.savedCards.emptyDescription")
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
        .navigationTitle(String(localized: "ocr.navigationTitle"))
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
        .alert(String(localized: "ocr.processingError.title"), isPresented: Binding(
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
        String.localizedStringWithFormat(
            String(localized: "common.cardLimit.summary"),
            Int64(remainingFreeCardSlots),
            Int64(parsedRows.count)
        )
    }

    private var freeOCRRemainingText: String {
        String.localizedStringWithFormat(
            String(localized: "ocr.freeRemaining"),
            Int64(PremiumLimits.freeOCRImportsPerMonth),
            Int64(settings.totalFreeOCRRemainingThisMonth)
        )
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
            errorMessage = String(localized: "ocr.cameraUnavailable")
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
