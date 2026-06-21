import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FlashcardDeck.updatedAt, order: .reverse) private var decks: [FlashcardDeck]
    @State private var showingDeckEditor = false

    var body: some View {
        NavigationStack {
            Group {
                if decks.isEmpty {
                    ContentUnavailableView(
                        "フラッシュカードセットがありません",
                        systemImage: "rectangle.stack.badge.plus",
                        description: Text("右上の追加ボタンから、最初のセットを作れます。")
                    )
                } else {
                    List {
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
            }
            .navigationTitle("ホーム")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingDeckEditor = true
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
        }
    }

    private func deleteDecks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(decks[index])
        }
    }
}

