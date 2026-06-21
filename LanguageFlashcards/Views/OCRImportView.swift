import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct OCRImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var deck: FlashcardDeck

    @State private var selectedItem: PhotosPickerItem?
    @State private var recognizedText = ""
    @State private var isRecognizing = false
    @State private var errorMessage: String?

    init(deck: FlashcardDeck) {
        self._deck = Bindable(deck)
    }

    var body: some View {
        Form {
            Section {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("写真を選ぶ", systemImage: "photo.on.rectangle")
                }

                if isRecognizing {
                    HStack {
                        ProgressView()
                        Text("文字を読み取り中")
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
                    Text("1行につき1カードとして保存します。区切りは「,」「/」「->」「 - 」などに対応しています。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(parsedRows.indices, id: \.self) { index in
                        let row = parsedRows[index]
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.languageOne)
                                .font(.headline)
                            Text(row.languageTwo.isEmpty ? "第2言語は未入力" : row.languageTwo)
                                .font(.subheadline)
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
                Button("保存") { saveRows() }
                    .disabled(parsedRows.isEmpty)
            }
        }
        .task(id: selectedItem) {
            await recognizeSelectedImage()
        }
        .alert("写真を読み取れませんでした", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var parsedRows: [(languageOne: String, languageTwo: String)] {
        recognizedText
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map(parseLine)
    }

    private func parseLine(_ line: String) -> (languageOne: String, languageTwo: String) {
        let delimiters = ["\t", " -> ", "->", " - ", ",", "，", "/", "／", ":"]
        for delimiter in delimiters {
            if let range = line.range(of: delimiter) {
                let first = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let second = String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                return (first, second)
            }
        }
        return (line, "")
    }

    private func recognizeSelectedImage() async {
        guard let selectedItem else { return }
        isRecognizing = true
        defer { isRecognizing = false }

        do {
            guard let data = try await selectedItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                throw OCRServiceError.missingImage
            }
            recognizedText = try await OCRService().recognizeText(from: image)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveRows() {
        for row in parsedRows where !row.languageOne.isEmpty {
            deck.cards.append(Flashcard(languageOneText: row.languageOne, languageTwoText: row.languageTwo))
        }
        deck.updatedAt = .now
        try? modelContext.save()
        dismiss()
    }
}

