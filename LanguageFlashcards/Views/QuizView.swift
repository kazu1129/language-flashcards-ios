import SwiftData
import SwiftUI

struct QuizView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var session: QuizSession
    @State private var selectedChoice: String?
    @State private var showsExplanation = false

    init(cards: [Flashcard] = []) {
        _session = State(initialValue: QuizSession(cards: cards))
    }

    var body: some View {
        Group {
            if let question = session.currentQuestion {
                questionView(question)
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

    private func questionView(_ question: QuizQuestion) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack(spacing: 12) {
                    ProgressView(
                        value: Double(session.currentIndex + 1),
                        total: Double(session.totalCount)
                    )
                    .tint(.green)

                    Text("\(session.currentIndex + 1)/\(session.totalCount)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Text("Q. “\(question.prompt)” の意味は？")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(question.choices, id: \.self) { choice in
                        choiceButton(choice, question: question)
                    }
                }

                if let selectedChoice {
                    feedbackView(for: selectedChoice, question: question)
                }
            }
            .padding()
        }
    }

    private func choiceButton(_ choice: String, question: QuizQuestion) -> some View {
        let state = choiceState(for: choice, question: question)

        return Button {
            selectChoice(choice, question: question)
        } label: {
            VStack(spacing: 8) {
                Text(choice)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                if let status = state.status {
                    Label(status.text, systemImage: status.icon)
                        .font(.caption.bold())
                        .foregroundStyle(state.tint)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 88)
            .padding(.horizontal, 8)
            .background(state.tint.opacity(state == .neutral ? 0.06 : 0.15))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(state.tint, lineWidth: state == .neutral ? 1 : 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .allowsHitTesting(selectedChoice == nil)
        .accessibilityValue(state.status?.text ?? "未回答")
    }

    private func selectChoice(_ choice: String, question: QuizQuestion) {
        guard selectedChoice == nil else { return }
        selectedChoice = choice

        let outcome: QuizAnswerOutcome = question.isCorrect(choice)
            ? .multipleChoiceCorrect
            : .multipleChoiceIncorrect
        try? QuizReviewRecorder.record(
            outcome,
            cardID: question.cardID,
            in: modelContext
        )
    }

    private func feedbackView(for choice: String, question: QuizQuestion) -> some View {
        let isCorrect = question.isCorrect(choice)
        let tint: Color = isCorrect ? .green : .red

        return VStack(alignment: .leading, spacing: 16) {
            Label(
                isCorrect ? "正解！" : "大丈夫。正解を確認しましょう。",
                systemImage: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .font(.headline)
            .foregroundStyle(tint)

            if !isCorrect {
                Label("正解は「\(question.correctAnswer)」です。", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            DisclosureGroup("なぜ？", isExpanded: $showsExplanation) {
                Text("「\(question.prompt)」は「\(question.correctAnswer)」という意味です。")
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }

            Button("続ける") {
                session.advance()
                selectedChoice = nil
                showsExplanation = false
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
    }

    private func choiceState(for choice: String, question: QuizQuestion) -> ChoiceState {
        guard let selectedChoice else { return .neutral }
        if question.isCorrect(choice) { return .correct }
        if choice == selectedChoice { return .incorrect }
        return .neutral
    }

    private enum ChoiceState: Equatable {
        case neutral
        case correct
        case incorrect

        var tint: Color {
            switch self {
            case .neutral: .secondary
            case .correct: .green
            case .incorrect: .red
            }
        }

        var status: (text: String, icon: String)? {
            switch self {
            case .neutral: nil
            case .correct: ("正解", "checkmark.circle.fill")
            case .incorrect: ("選んだ回答", "xmark.circle.fill")
            }
        }
    }
}
