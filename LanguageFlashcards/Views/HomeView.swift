import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \FlashcardDeck.updatedAt, order: .reverse) private var decks: [FlashcardDeck]
    @Query(sort: \StudyReview.reviewedAt, order: .forward) private var reviews: [StudyReview]
    @State private var showingDeckEditor = false
    @State private var showingPremiumUpgrade = false

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
                                DeckDetailView(deck: deck)
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
                    Button {
                        if settings.canCreateDeck(existingDeckCount: decks.count) {
                            showingDeckEditor = true
                        } else {
                            showingPremiumUpgrade = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("セットを追加")
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
