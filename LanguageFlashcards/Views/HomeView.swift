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

                Section("フラッシュカードセット") {
                    if decks.isEmpty {
                        ContentUnavailableView(
                            "フラッシュカードセットがありません",
                            systemImage: "rectangle.stack.badge.plus",
                            description: Text("右上の追加ボタンから、最初のセットを作れます。")
                        )
                    } else {
                        ForEach(decks) { deck in
                            NavigationLink {
                                DeckDetailView(deck: deck, onShowDashboard: onShowDashboard)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(deck.name)
                                        .font(.headline)
                                    Text("\(deck.languageOneName) / \(deck.languageTwoName) ・ \(deck.cards.count)枚")
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
            .navigationTitle("ホーム")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            if settings.canCreateDeck(existingDeckCount: decks.count) {
                                showingDeckEditor = true
                            } else {
                                showingPremiumUpgrade = true
                            }
                        } label: {
                            Label("セットを追加", systemImage: "rectangle.stack.badge.plus")
                        }

                        Button {
                            homeImportSource = .camera
                        } label: {
                            Label("写真を撮る", systemImage: "camera")
                        }

                        Button {
                            homeImportSource = .library
                        } label: {
                            Label("写真を選ぶ", systemImage: "photo.on.rectangle")
                        }

                        Button {
                            showingHomeFileImport = true
                        } label: {
                            Label("CSV/TXTを読み込む", systemImage: "doc.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("追加")
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

    private func deleteDecks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(decks[index])
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
                    "追加先のセットがありません",
                    systemImage: "rectangle.stack.badge.plus",
                    description: Text("先にフラッシュカードセットを作ると、写真からカードを追加できます。")
                )
            } else {
                Section("追加先のセット") {
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
                                Text("\(deck.languageOneName) / \(deck.languageTwoName) ・ \(deck.cards.count)枚")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(source.title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") { dismiss() }
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
                    "追加先のセットがありません",
                    systemImage: "rectangle.stack.badge.plus",
                    description: Text("先にフラッシュカードセットを作ると、CSV/TXTからカードを追加できます。")
                )
            } else {
                Section("追加先のセット") {
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
                                Text("\(deck.languageOneName) / \(deck.languageTwoName) ・ \(deck.cards.count)枚")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("ファイルから追加")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") { dismiss() }
            }
        }
    }

    private var totalCardCount: Int {
        decks.reduce(0) { $0 + $1.cards.count }
    }
}
