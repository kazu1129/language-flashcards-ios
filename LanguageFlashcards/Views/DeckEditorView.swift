import SwiftData
import SwiftUI

struct DeckEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var languageOneName = "日本語"
    @State private var languageTwoName = "英語"

    var body: some View {
        Form {
            Section("セット") {
                TextField("名前", text: $name)
            }

            Section("言語") {
                TextField("第1言語", text: $languageOneName)
                TextField("第2言語", text: $languageTwoName)
            }
        }
        .navigationTitle("セットを追加")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    let deck = FlashcardDeck(
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        languageOneName: languageOneName.trimmingCharacters(in: .whitespacesAndNewlines),
                        languageTwoName: languageTwoName.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    modelContext.insert(deck)
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

