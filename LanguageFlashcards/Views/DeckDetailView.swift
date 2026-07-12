import SwiftData
import SwiftUI

struct DeckDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: AppSettings
    @Query private var allDecks: [FlashcardDeck]
    @Bindable var deck: FlashcardDeck
    var onShowDashboard: () -> Void = {}

    @State private var showingDeckEditor = false
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
                    Label(String(localized: "deckDetail.startStudy"), systemImage: "play.circle.fill")
                        .font(.headline)
                }
                .disabled(deck.cards.isEmpty)

                HStack {
                    Label(sessionCardsText, systemImage: "number.circle")
                    Spacer()
                    Text(displaySideStartText)
                        .foregroundStyle(.secondary)
                }
            }

            Section(String(localized: "deckDetail.cards.section")) {
                if deck.cards.isEmpty {
                    Button {
                        presentManualEntry()
                    } label: {
                        ContentUnavailableView(
                            String(localized: "deckDetail.empty.title"),
                            systemImage: "plus.rectangle.on.rectangle",
                            description: Text("deckDetail.empty.description")
                        )
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                } else if filteredCards.isEmpty {
                    ContentUnavailableView(
                        String(localized: "deckDetail.noResults.title"),
                        systemImage: "magnifyingglass",
                        description: Text("deckDetail.noResults.description")
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
                                Text(card.languageTwoText.isEmpty ? String(localized: "deckDetail.manualPending") : card.languageTwoText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if let last = card.lastRating {
                                    Text(lastRatingText(for: last))
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
                                Label(String(localized: "deckDetail.edit"), systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                deleteCard(card)
                            } label: {
                                Label(String(localized: "deckDetail.delete"), systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteCard(card)
                            } label: {
                                Label(String(localized: "deckDetail.delete"), systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                editingCard = card
                            } label: {
                                Label(String(localized: "deckDetail.edit"), systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                    .onDelete(perform: deleteCards)
                }
            }
        }
        .navigationTitle(deck.name)
        .searchable(text: $searchText, prompt: String(localized: "deckDetail.searchPrompt"))
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                Button {
                    showingDeckEditor = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel(String(localized: "deckDetail.setName.edit.accessibility"))

                if !deck.cards.isEmpty {
                    EditButton()
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button {
                        presentManualEntry()
                    } label: {
                        Label(String(localized: "deckDetail.directEntry"), systemImage: "keyboard")
                    }

                    Button {
                        if settings.canUseOCRImport() {
                            ocrStartSource = .camera
                        } else {
                            showingPremiumUpgrade = true
                        }
                    } label: {
                        Label(String(localized: "home.takePhoto"), systemImage: "camera")
                    }

                    Button {
                        if settings.canUseOCRImport() {
                            ocrStartSource = .library
                        } else {
                            showingPremiumUpgrade = true
                        }
                    } label: {
                        Label(String(localized: "home.choosePhoto"), systemImage: "photo.on.rectangle")
                    }

                    Button {
                        showingFileImport = true
                    } label: {
                        Label(String(localized: "home.importCSVTXT"), systemImage: "doc.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "deckDetail.addCard.accessibility"))

                Menu {
                    Button(String(localized: "deckDetail.share.txt")) { export(.text) }
                    Button(String(localized: "deckDetail.share.csv")) { export(.csv) }
                    Button(settings.isPremium ? String(localized: "deckDetail.share.pdf") : String(localized: "deckDetail.share.pdfPremium")) {
                        if settings.isPremium {
                            export(.pdf)
                        } else {
                            showingPremiumUpgrade = true
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(String(localized: "deckDetail.share.accessibility"))
                .disabled(deck.cards.isEmpty)
            }
        }
        .sheet(isPresented: $showingDeckEditor) {
            NavigationStack {
                DeckEditorView(deck: deck)
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
        .alert(String(localized: "deckDetail.exportError.title"), isPresented: Binding(
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

    private var sessionCardsText: String {
        String.localizedStringWithFormat(
            String(localized: "deckDetail.sessionCards"),
            Int64(settings.sessionCardCount)
        )
    }

    private var displaySideStartText: String {
        String.localizedStringWithFormat(
            String(localized: "deckDetail.displaySideStart"),
            settings.displaySide.title
        )
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
                meaning.synonyms.localizedCaseInsensitiveContains(query) ||
                meaning.example.localizedCaseInsensitiveContains(query) ||
                meaning.exampleTranslation.localizedCaseInsensitiveContains(query)
            }
        }
    }

    private func lastRatingText(for rating: ReviewRating) -> String {
        String.localizedStringWithFormat(
            String(localized: "deckDetail.lastRating"),
            rating.title
        )
    }

    private func presentManualEntry() {
        if settings.canAddCards(totalCardCount: totalCardCount, adding: 1) {
            showingManualEntry = true
        } else {
            showingPremiumUpgrade = true
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
