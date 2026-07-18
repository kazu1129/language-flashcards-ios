import Accessibility
import SwiftData
import SwiftUI

enum QuizAccessibilityText {
    static func spokenQuestion(_ displayedText: String) -> String {
        displayedText.replacingOccurrences(of: "_____", with: "空欄")
    }

    static func feedbackAnnouncement(isCorrect: Bool, correctAnswer: String) -> String {
        isCorrect
            ? "正解です。"
            : "大丈夫です。正解は「\(correctAnswer)」です。"
    }
}

struct QuizFormatSelectionState {
    private(set) var selectedQuestionType: QuestionType?

    mutating func select(_ questionType: QuestionType) {
        selectedQuestionType = questionType
    }

    mutating func resetSelection() {
        selectedQuestionType = nil
    }
}

enum QuizAnswerState: Equatable {
    case unanswered
    case selected(String)
    case gaveUp

    var hasAnswered: Bool {
        self != .unanswered
    }

    var selectedChoice: String? {
        guard case let .selected(choice) = self else { return nil }
        return choice
    }

    var didGiveUp: Bool {
        self == .gaveUp
    }

    mutating func select(_ choice: String) -> Bool {
        guard !hasAnswered else { return false }
        self = .selected(choice)
        return true
    }

    mutating func giveUp() -> Bool {
        guard !hasAnswered else { return false }
        self = .gaveUp
        return true
    }

    mutating func reset() {
        self = .unanswered
    }
}

struct QuizView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \StudyReview.reviewedAt, order: .reverse) private var reviews: [StudyReview]
    private let cards: [Flashcard]

    @State private var session: QuizSession?
    @State private var answerState: QuizAnswerState = .unanswered
    @State private var textAnswer = ""
    @State private var showsExplanation = false
    @State private var formatSelectionState = QuizFormatSelectionState()

    init(cards: [Flashcard] = []) {
        self.cards = cards
        _session = State(initialValue: nil)
    }

    var body: some View {
        Group {
            if let session {
                if let question = session.currentQuestion {
                    questionView(question, session: session)
                } else {
                    completionView(session: session)
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
        let unavailableReason = unavailableReason(for: type)

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
        let displayedQuestion = questionText(for: question)

        return ScrollView {
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

                Text(displayedQuestion)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .accessibilityLabel(Text(QuizAccessibilityText.spokenQuestion(displayedQuestion)))

                if let hint = question.hint {
                    Label("ヒント: \(hint)", systemImage: "lightbulb")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if question.choices.isEmpty {
                    textAnswerView(question)
                } else {
                    LazyVGrid(
                        columns: choiceColumns,
                        spacing: 12
                    ) {
                        ForEach(question.choices, id: \.self) { choice in
                            choiceButton(choice, question: question)
                        }
                    }
                }

                Button("わからない") {
                    giveUp(question: question)
                }
                .buttonStyle(.bordered)
                .disabled(answerState.hasAnswered)

                if answerState.hasAnswered {
                    feedbackView(question: question)
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
                    .fixedSize(horizontal: false, vertical: true)

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
        .allowsHitTesting(!answerState.hasAnswered)
        .accessibilityValue(state.status?.text ?? "未回答")
    }

    private func textAnswerView(_ question: QuizQuestion) -> some View {
        VStack(spacing: 12) {
            TextField(
                question.type == .clozeExample ? "空欄の語を入力" : "答えを入力",
                text: $textAnswer
            )
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .disabled(answerState.hasAnswered)
                .accessibilityLabel(question.type == .clozeExample ? "空欄に入る語" : "答え")
                .onSubmit { submitTextAnswer(for: question) }

            Button("回答する") {
                submitTextAnswer(for: question)
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                answerState.hasAnswered ||
                textAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
    }

    private func submitTextAnswer(for question: QuizQuestion) {
        let answer = textAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else { return }
        selectChoice(answer, question: question)
    }

    private func selectChoice(_ choice: String, question: QuizQuestion) {
        guard answerState.select(choice) else { return }
        recordAnswer(isCorrect: question.isCorrect(choice), question: question)
    }

    private func giveUp(question: QuizQuestion) {
        guard answerState.giveUp() else { return }
        recordAnswer(isCorrect: false, question: question)
    }

    private func recordAnswer(isCorrect: Bool, question: QuizQuestion) {
        guard let outcome = QuizAnswerOutcome(
            questionType: question.type,
            isCorrect: isCorrect
        ) else { return }
        let reviewResult = try? QuizReviewRecorder.record(
            outcome,
            cardID: question.cardID,
            in: modelContext
        )
        session?.recordAnswer(
            isCorrect: isCorrect,
            promoted: reviewResult?.promoted ?? false
        )
        AccessibilityNotification.Announcement(
            QuizAccessibilityText.feedbackAnnouncement(
                isCorrect: isCorrect,
                correctAnswer: question.correctAnswer
            )
        ).post()
    }

    private func feedbackView(question: QuizQuestion) -> some View {
        let isCorrect = answerState.selectedChoice.map { question.isCorrect($0) } ?? false
        let didGiveUp = answerState.didGiveUp
        let tint: Color = isCorrect ? .green : (didGiveUp ? .secondary : .red)

        return VStack(alignment: .leading, spacing: 16) {
            Label(
                isCorrect
                    ? "正解！"
                    : (didGiveUp ? "正解を確認しましょう。" : "大丈夫。正解を確認しましょう。"),
                systemImage: isCorrect
                    ? "checkmark.circle.fill"
                    : (didGiveUp ? "questionmark.circle.fill" : "xmark.circle.fill")
            )
            .font(.headline)
            .foregroundStyle(tint)

            if !isCorrect {
                Label("正解は「\(question.correctAnswer)」です。", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            let explanation = explanationText(for: question)
            if !explanation.isEmpty {
                DisclosureGroup("なぜ？", isExpanded: $showsExplanation) {
                    Text(explanation)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
            }

            Button("続ける") {
                session?.advance()
                resetAnswerState()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
    }

    private func completionView(session completedSession: QuizSession) -> some View {
        let result = completedSession.result
        let streakDays = LearningProgress.consecutiveStudyDays(from: reviews)

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label("クイズ終了", systemImage: "checkmark.circle.fill")
                    .font(.title.bold())
                    .foregroundStyle(.green)

                resultMetrics(result: result, streakDays: streakDays)

                if result.incorrectAnswers.isEmpty {
                    Label("全問正解です！", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(.green)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("苦手")
                            .font(.headline)
                        ForEach(result.incorrectAnswers) { answer in
                            Label(answer.cardText, systemImage: "arrow.counterclockwise.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                VStack(spacing: 12) {
                    if completedSession.retrySession(from: cards) != nil {
                        Button("間違えた語だけもう一度") {
                            session = completedSession.retrySession(from: cards)
                            resetAnswerState()
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Button("もう1セット") {
                        startSession(with: completedSession.questionType)
                    }
                    .buttonStyle(.bordered)

                    Button("形式を選び直す") {
                        session = nil
                        formatSelectionState.resetSelection()
                        resetAnswerState()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
    }

    private func resultMetric(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.monospacedDigit())
                .fixedSize(horizontal: false, vertical: true)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(value))
    }

    @ViewBuilder
    private func resultMetrics(result: QuizSessionResult, streakDays: Int) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 12) {
                resultMetric(title: "正解", value: "\(result.correctCount) / \(result.totalCount)")
                resultMetric(title: "連続", value: "\(streakDays)日")
                resultMetric(title: "覚え度UP", value: "\(result.promotedCount)語")
            }
        } else {
            HStack(spacing: 12) {
                resultMetric(title: "正解", value: "\(result.correctCount) / \(result.totalCount)")
                resultMetric(title: "連続", value: "\(streakDays)日")
                resultMetric(title: "覚え度UP", value: "\(result.promotedCount)語")
            }
        }
    }

    private var choiceColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
    }

    private func startSession(with questionType: QuestionType) {
        formatSelectionState.select(questionType)
        session = QuizSession(
            cards: cards,
            questionType: questionType,
            sessionCardCount: settings.sessionCardCount
        )
        resetAnswerState()
    }

    private func resetAnswerState() {
        answerState.reset()
        textAnswer = ""
        showsExplanation = false
    }

    private func questionText(for question: QuizQuestion) -> String {
        switch question.type {
        case .fourChoice: "Q. “\(question.prompt)” の意味は？"
        case .synonym: "Q. “\(question.prompt)” の同義語は？"
        case .clozeExample: question.prompt
        case .textInput: "Q. “\(question.prompt)” の意味を入力してください"
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

    private func unavailableReason(for type: QuestionType) -> String {
        switch type {
        case .synonym: "同義語が登録されていません"
        case .clozeExample: "穴埋めできる例文がありません"
        case .textInput: "入力する答えが登録されていません"
        case .fourChoice: "出題できる単語がありません"
        }
    }

    private func choiceState(for choice: String, question: QuizQuestion) -> ChoiceState {
        guard answerState.hasAnswered else { return .neutral }
        if question.isCorrect(choice) { return .correct }
        if choice == answerState.selectedChoice { return .incorrect }
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
