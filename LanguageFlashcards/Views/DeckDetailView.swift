import SwiftData
import SwiftUI

struct DeckDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: AppSettings
    @Query private var allDecks: [FlashcardDeck]
    @Bindable var deck: FlashcardDeck
    var onShowDashboard: () -> Void = {}

    @State private var showingManualEntry = false
    @State private var showingFileImport = false
    @State private var showingPremiumUpgrade = false
    @State private var editingCard: Flashcard?
    @State private var ocrStartSource: OCRImportStartSource?
    @State private var shareFile: ShareFile?
    @State private var exportError: String?
    @State private var searchText = ""

    var body: some View {
        List {
            Section {
                NavigationLink {
                    StudySessionView(deck: deck, onFinish: onShowDashboard)
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
                        description: Text("直接入力、写真、CSV/TXTから追加できます。")
                    )
                } else if filteredCards.isEmpty {
                    ContentUnavailableView(
                        "見つかりません",
                        systemImage: "magnifyingglass",
                        description: Text("検索語を変えてもう一度試してください。")
                    )
                } else {
                    ForEach(filteredCards) { card in
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
                        .contextMenu {
                            Button {
                                editingCard = card
                            } label: {
                                Label("編集", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                deleteCard(card)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteCard(card)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                editingCard = card
                            } label: {
                                Label("編集", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                    .onDelete(perform: deleteCards)
                }
            }
        }
        .navigationTitle(deck.name)
        .searchable(text: $searchText, prompt: "単語や表現を検索")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !deck.cards.isEmpty {
                    EditButton()
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button {
                        if settings.canAddCards(totalCardCount: totalCardCount, adding: 1) {
                            showingManualEntry = true
                        } else {
                            showingPremiumUpgrade = true
                        }
                    } label: {
                        Label("直接入力", systemImage: "keyboard")
                    }

                    Button {
                        if settings.canUseOCRImport() {
                            ocrStartSource = .camera
                        } else {
                            showingPremiumUpgrade = true
                        }
                    } label: {
                        Label("写真を撮る", systemImage: "camera")
                    }

                    Button {
                        if settings.canUseOCRImport() {
                            ocrStartSource = .library
                        } else {
                            showingPremiumUpgrade = true
                        }
                    } label: {
                        Label("写真を選ぶ", systemImage: "photo.on.rectangle")
                    }

                    Button {
                        showingFileImport = true
                    } label: {
                        Label("CSV/TXTを読み込む", systemImage: "doc.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("カードを追加")

                Menu {
                    Button("TXTで共有") { export(.text) }
                    Button(settings.isPremium ? "PDFで共有" : "PDFで共有（プレミアム）") {
                        if settings.isPremium {
                            export(.pdf)
                        } else {
                            showingPremiumUpgrade = true
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("共有")
                .disabled(deck.cards.isEmpty)
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            NavigationStack {
                CardEditorView(deck: deck, totalCardCount: totalCardCount)
            }
        }
        .sheet(item: $ocrStartSource) { source in
            NavigationStack {
                OCRImportView(deck: deck, totalCardCount: totalCardCount, startSource: source)
            }
        }
        .sheet(isPresented: $showingFileImport) {
            NavigationStack {
                TextFileImportView(deck: deck, totalCardCount: totalCardCount)
            }
        }
        .sheet(item: $editingCard) { card in
            NavigationStack {
                CardEditorView(deck: deck, card: card, totalCardCount: totalCardCount)
            }
        }
        .sheet(item: $shareFile) { file in
            ShareSheet(items: [file.url])
        }
        .sheet(isPresented: $showingPremiumUpgrade) {
            PremiumUpgradeView()
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

    private var totalCardCount: Int {
        allDecks.reduce(0) { $0 + $1.cards.count }
    }

    private var filteredCards: [Flashcard] {
        let cards = deck.sortedCards
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return cards }

        return cards.filter { card in
            card.languageOneText.localizedCaseInsensitiveContains(query) ||
            card.languageTwoText.localizedCaseInsensitiveContains(query) ||
            card.meanings.contains { meaning in
                meaning.meaning.localizedCaseInsensitiveContains(query) ||
                meaning.example.localizedCaseInsensitiveContains(query) ||
                meaning.exampleTranslation.localizedCaseInsensitiveContains(query)
            }
        }
    }

    private func deleteCards(at offsets: IndexSet) {
        let cards = filteredCards
        for index in offsets {
            modelContext.delete(cards[index])
        }
        deck.updatedAt = .now
    }

    private func deleteCard(_ card: Flashcard) {
        modelContext.delete(card)
        deck.updatedAt = .now
        try? modelContext.save()
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
