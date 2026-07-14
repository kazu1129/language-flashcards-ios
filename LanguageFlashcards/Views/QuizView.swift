import SwiftUI

struct QuizView: View {
    @State private var session: QuizSession

    init(cards: [Flashcard] = []) {
        _session = State(initialValue: QuizSession(cards: cards))
    }

    var body: some View {
        Group {
            if let card = session.currentCard {
                VStack(spacing: 24) {
                    Text("問題 \(session.currentIndex + 1) / \(session.totalCount)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(card.languageOneText)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)

                    Text("この単語の意味を思い出してください。")
                        .foregroundStyle(.secondary)

                    Button("次へ") {
                        session.advance()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if session.totalCount == 0 {
                ContentUnavailableView(
                    "出題できる単語がありません",
                    systemImage: "rectangle.stack.badge.minus",
                    description: Text("デッキに単語を追加してから始めてください。")
                )
            } else {
                ContentUnavailableView(
                    "クイズ終了",
                    systemImage: "checkmark.circle",
                    description: Text("\(session.totalCount)問を最後まで進めました。")
                )
            }
        }
        .navigationTitle("クイズ")
        .navigationBarTitleDisplayMode(.inline)
    }
}
