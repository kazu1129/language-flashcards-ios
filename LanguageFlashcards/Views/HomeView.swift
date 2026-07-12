import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \FlashcardDeck.updatedAt, order: .reverse) private var decks: [FlashcardDeck]
    @Query(sort: \StudyReview.reviewedAt, order: .forward) private var reviews: [StudyReview]
    var onShowDashboard: () -> Void = {}

    @State private var showingDeckEditor = false
    @State private var showingPremiumUpgrade = false
    @State private var homeImportSource: OCRImportStartSource?
    @State private var showingHomeFileImport = false

    var body: some View {
        NavigationStack {
            List {
                if settings.showCharacterOnHome {
                    Section {
                        CharacterHomeHeader(
                            stage: currentStage,
                            streakDays: streakDays,
                            isPremium: settings.isPremium
                        )
                    }
                    .listRowSeparator(.hidden)
                }

                Section(String(localized: "home.flashcardSets.section")) {
                    if decks.isEmpty {
                        Button {
                            presentDeckCreation()
                        } label: {
                            ContentUnavailableView(
                                String(localized: "home.emptyDeck.title"),
                                systemImage: "rectangle.stack.badge.plus",
                                description: Text("home.emptyDeck.description")
                            )
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    } else {
                        ForEach(decks) { deck in
                            NavigationLink {
                                DeckDetailView(deck: deck, onShowDashboard: onShowDashboard)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(deck.name)
                                        .font(.headline)
                                    Text(localizedDeckSummary(for: deck))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete(perform: deleteDecks)
                    }
                }

                if !settings.isPremium {
                    Section {
                        PremiumHomeCard {
                            showingPremiumUpgrade = true
                        }
                    }
                    .listRowSeparator(.hidden)
                }
            }
            .navigationTitle(String(localized: "home.navigationTitle"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            presentDeckCreation()
                        } label: {
                            Label(String(localized: "home.addDeck"), systemImage: "rectangle.stack.badge.plus")
                        }

                        Button {
                            homeImportSource = .camera
                        } label: {
                            Label(String(localized: "home.takePhoto"), systemImage: "camera")
                        }

                        Button {
                            homeImportSource = .library
                        } label: {
                            Label(String(localized: "home.choosePhoto"), systemImage: "photo.on.rectangle")
                        }

                        Button {
                            showingHomeFileImport = true
                        } label: {
                            Label(String(localized: "home.importCSVTXT"), systemImage: "doc.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "home.add.accessibility"))
                }
            }
            .sheet(isPresented: $showingDeckEditor) {
                NavigationStack {
                    DeckEditorView()
                }
            }
            .sheet(isPresented: $showingPremiumUpgrade) {
                PremiumUpgradeView()
            }
            .sheet(item: $homeImportSource) { source in
                NavigationStack {
                    HomeOCRImportDestinationView(source: source)
                }
            }
            .sheet(isPresented: $showingHomeFileImport) {
                NavigationStack {
                    HomeTextFileImportDestinationView()
                }
            }
        }
    }

    private var streakDays: Int {
        LearningProgress.consecutiveStudyDays(from: reviews)
    }

    private var currentStage: CharacterGrowthStage {
        LearningProgress.currentStage(for: streakDays)
    }

    private func presentDeckCreation() {
        if settings.canCreateDeck(existingDeckCount: decks.count) {
            showingDeckEditor = true
        } else {
            showingPremiumUpgrade = true
        }
    }

    private func deleteDecks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(decks[index])
        }
    }
}

private func localizedDeckSummary(for deck: FlashcardDeck) -> String {
    let format = deck.cards.count == 1
        ? String(localized: "home.deck.summary.one")
        : String(localized: "home.deck.summary.many")
    return String.localizedStringWithFormat(
        format,
        deck.localizedLanguageOneName,
        deck.localizedLanguageTwoName,
        Int64(deck.cards.count)
    )
}

private extension OCRImportStartSource {
    var localizedHomeTitle: String {
        switch self {
        case .camera:
            String(localized: "home.takePhoto")
        case .library:
            String(localized: "home.choosePhoto")
        }
    }
}

private struct HomeOCRImportDestinationView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FlashcardDeck.updatedAt, order: .reverse) private var decks: [FlashcardDeck]

    let source: OCRImportStartSource

    var body: some View {
        List {
            if decks.isEmpty {
                ContentUnavailableView(
                    String(localized: "home.addDestination.empty.title"),
                    systemImage: "rectangle.stack.badge.plus",
                    description: Text("home.addDestination.photo.description")
                )
            } else {
                Section(String(localized: "home.addDestination.section")) {
                    ForEach(decks) { deck in
                        NavigationLink {
                            OCRImportView(
                                deck: deck,
                                totalCardCount: totalCardCount,
                                startSource: source
                            ) {
                                dismiss()
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(deck.name)
                                    .font(.headline)
                                Text(localizedDeckSummary(for: deck))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(source.localizedHomeTitle)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "home.close")) { dismiss() }
            }
        }
    }

    private var totalCardCount: Int {
        decks.reduce(0) { $0 + $1.cards.count }
    }
}

private struct HomeTextFileImportDestinationView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FlashcardDeck.updatedAt, order: .reverse) private var decks: [FlashcardDeck]

    var body: some View {
        List {
            if decks.isEmpty {
                ContentUnavailableView(
                    String(localized: "home.addDestination.empty.title"),
                    systemImage: "rectangle.stack.badge.plus",
                    description: Text("home.addDestination.file.description")
                )
            } else {
                Section(String(localized: "home.addDestination.section")) {
                    ForEach(decks) { deck in
                        NavigationLink {
                            TextFileImportView(
                                deck: deck,
                                totalCardCount: totalCardCount
                            ) {
                                dismiss()
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(deck.name)
                                    .font(.headline)
                                Text(localizedDeckSummary(for: deck))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "home.addFromFile.title"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "home.close")) { dismiss() }
            }
        }
    }

    private var totalCardCount: Int {
        decks.reduce(0) { $0 + $1.cards.count }
    }
}
