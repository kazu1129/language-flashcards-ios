import SwiftData
import SwiftUI

struct DeckDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: AppSettings
    @Bindable var deck: FlashcardDeck

    @State private var showingManualEntry = false
    @State private var showingOCRImport = false
    @State private var editingCard: Flashcard?
    @State private var shareFile: ShareFile?
    @State private var exportError: String?

    var body: some View {
        List {
            Section {
                NavigationLink {
                    StudySessionView(deck: deck)
                } label: {
                    Label("学習を開始", systemImage: "play.circle.fill")
                        .font(.headline)
                }
                .disabled(deck.cards.isEmpty)

                HStack {
                    Label("\(settings.sessionCardCount)枚 / セッション", systemImage: "number.circle")
                    Spacer()
                    Text(settings.displaySide.title + "から表示")
                        .foregroundStyle(.secondary)
                }
            }

            Section("カード") {
                if deck.cards.isEmpty {
                    ContentUnavailableView(
                        "カードがありません",
                        systemImage: "plus.rectangle.on.rectangle",
                        description: Text("直接入力または写真から追加できます。")
                    )
                } else {
                    ForEach(deck.sortedCards) { card in
                        Button {
                            editingCard = card
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(card.languageOneText)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(card.languageTwoText.isEmpty ? "Gemini補完または手入力待ち" : card.languageTwoText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if let last = card.lastRating {
                                    Text("前回: \(last.title)")
                                        .font(.caption)
                                        .foregroundStyle(last.tint)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete(perform: deleteCards)
                }
            }
        }
        .navigationTitle(deck.name)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingManualEntry = true
                    } label: {
                        Label("直接入力", systemImage: "keyboard")
                    }

                    Button {
                        showingOCRImport = true
                    } label: {
                        Label("写真から抽出", systemImage: "camera.viewfinder")
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("カードを追加")

                Menu {
                    Button("TXTで共有") { export(.text) }
                    Button("PDFで共有") { export(.pdf) }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("共有")
                .disabled(deck.cards.isEmpty)
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            NavigationStack {
                CardEditorView(deck: deck)
            }
        }
        .sheet(isPresented: $showingOCRImport) {
            NavigationStack {
                OCRImportView(deck: deck)
            }
        }
        .sheet(item: $editingCard) { card in
            NavigationStack {
                CardEditorView(deck: deck, card: card)
            }
        }
        .sheet(item: $shareFile) { file in
            ShareSheet(items: [file.url])
        }
        .alert("共有ファイルを作れませんでした", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
    }

    private func deleteCards(at offsets: IndexSet) {
        let cards = deck.sortedCards
        for index in offsets {
            modelContext.delete(cards[index])
        }
        deck.updatedAt = .now
    }

    private func export(_ format: DeckExportFormat) {
        do {
            let url = try DeckExporter.export(deck: deck, format: format)
            shareFile = ShareFile(url: url)
        } catch {
            exportError = error.localizedDescription
        }
    }
}

