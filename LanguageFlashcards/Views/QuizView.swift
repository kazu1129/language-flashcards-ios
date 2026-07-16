import SwiftData
import SwiftUI

struct QuizView: View {
    @Environment(\.modelContext) private var modelContext
    private let cards: [Flashcard]
    private let sessionCardCount: Int

    @State private var session: QuizSession?
    @State private var selectedChoice: String?
    @State private var showsExplanation = false

    init(cards: [Flashcard] = [], sessionCardCount: Int = .max) {
        self.cards = cards
        self.sessionCardCount = sessionCardCount
        _session = State(initialValue: nil)
    }

    var body: some View {
        Group {
            if let session {
                if let question = session.currentQuestion {
                    questionView(question, session: session)
                } else {
                    completionView(totalCount: session.totalCount)
                }
            } else {
                formatSelectionView
            }
        }
        .navigationTitle("クイズ")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var formatSelectionView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("出題形式を選ぶ")
                    .font(.title.bold())
                Text("このセットで使う形式を選んでください。")
                    .foregroundStyle(.secondary)

                ForEach(QuestionType.allCases) { type in
                    formatButton(for: type)
                }
            }
            .padding()
        }
    }

    private func formatButton(for type: QuestionType) -> some View {
        let isAvailable = type.isAvailable(in: cards)
        let unavailableReason = type == .synonym
            ? "同義語が登録されていません"
            : "出題できる単語がありません"

        return Button {
            startSession(with: type)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: type.systemImage)
                    .font(.title2)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(type.title)
                            .font(.headline)
                        if !type.isImplemented {
                            Text("準備中")
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.secondary.opacity(0.15), in: Capsule())
                        }
                    }
                    Text(
                        type.isImplemented
                            ? (isAvailable ? type.description : unavailableReason)
                            : type.description
                    )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isAvailable ? "chevron.right" : "lock.fill")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.secondary.opacity(0.3))
            }
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.55)
        .accessibilityValue(type.isImplemented ? (isAvailable ? "利用可能" : unavailableReason) : "準備中")
    }

    private func questionView(_ question: QuizQuestion, session: QuizSession) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack(spacing: 12) {
                    ProgressView(
                        value: Double(session.currentIndex + 1),
                        total: Double(session.totalCount)
                    )
                    .tint(.green)

                    Text("\(session.currentIndex + 1) / \(session.totalCount)問")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Text(questionText(for: question))
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

        guard let outcome = QuizAnswerOutcome(
            questionType: question.type,
            isCorrect: question.isCorrect(choice)
        ) else { return }
        _ = try? QuizReviewRecorder.record(
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
                Text(explanationText(for: question))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }

            Button("続ける") {
                session?.advance()
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

    private func completionView(totalCount: Int) -> some View {
        VStack(spacing: 20) {
            ContentUnavailableView(
                "クイズ終了",
                systemImage: "checkmark.circle",
                description: Text("\(totalCount)問を最後まで進めました。")
            )
            Button("次のセットの形式を選ぶ") {
                session = nil
                selectedChoice = nil
                showsExplanation = false
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func startSession(with questionType: QuestionType) {
        session = QuizSession(
            cards: cards,
            questionType: questionType,
            sessionCardCount: sessionCardCount
        )
        selectedChoice = nil
        showsExplanation = false
    }

    private func questionText(for question: QuizQuestion) -> String {
        switch question.type {
        case .fourChoice: "Q. “\(question.prompt)” の意味は？"
        case .synonym: "Q. “\(question.prompt)” の同義語は？"
        case .textInput, .clozeExample: ""
        }
    }

    private func explanationText(for question: QuizQuestion) -> String {
        switch question.type {
        case .fourChoice:
            "「\(question.prompt)」は「\(question.correctAnswer)」という意味です。"
        case .synonym:
            "「\(question.correctAnswer)」は「\(question.prompt)」の同義語です。"
        case .textInput, .clozeExample:
            ""
        }
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
