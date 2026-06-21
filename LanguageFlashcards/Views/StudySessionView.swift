import SwiftData
import SwiftUI

struct StudySessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: AppSettings
    @Bindable var deck: FlashcardDeck
    var onFinish: () -> Void

    @StateObject private var speech = SpeechService()
    @State private var sessionCards: [Flashcard] = []
    @State private var currentIndex = 0
    @State private var flipped = false
    @State private var ratedCardIDs: Set<UUID> = []
    @State private var showRatingReminder = false
    @State private var showingCompletion = false

    init(deck: FlashcardDeck, onFinish: @escaping () -> Void = {}) {
        self._deck = Bindable(deck)
        self.onFinish = onFinish
    }

    var body: some View {
        Group {
            if sessionCards.isEmpty {
                ContentUnavailableView(
                    "学習できるカードがありません",
                    systemImage: "rectangle.stack.badge.person.crop",
                    description: Text("カードを追加してから学習を開始してください。")
                )
            } else if showingCompletion {
                StudySessionCompletionView(
                    studiedCount: ratedCardIDs.count,
                    nextSetAction: startNextSession,
                    finishAction: finishSession
                )
            } else if let card = currentCard {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        ProgressView(value: Double(currentIndex + 1), total: Double(sessionCards.count))
                        Text("\(currentIndex + 1) / \(sessionCards.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    FlashcardStudyCard(
                        card: card,
                        deck: deck,
                        shownSide: settings.displaySide,
                        flipped: flipped,
                        fontScale: settings.fontScale
                    )
                    .onTapGesture {
                        toggleFlip(for: card)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 40)
                            .onEnded { value in
                                if value.translation.width < -80 {
                                    moveNext()
                                } else if value.translation.width > 80 {
                                    movePrevious()
                                }
                            }
                    )
                    .padding(.horizontal)

                    if showRatingReminder {
                        Text("次に進む前に、記憶の確からしさを選んでください。")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    HStack(spacing: 10) {
                        ForEach(ReviewRating.allCases) { rating in
                            Button {
                                rateCurrentCard(rating)
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: iconName(for: rating))
                                    Text(rating.shortTitle)
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(rating.tint)
                        }
                    }
                    .padding(.horizontal)

                    HStack {
                        Button {
                            movePrevious()
                        } label: {
                            Label("前へ", systemImage: "chevron.left")
                        }
                        .disabled(currentIndex == 0)

                        Spacer()

                        Button {
                            moveNext()
                        } label: {
                            Label(currentIndex == sessionCards.count - 1 ? "完了" : "次へ", systemImage: "chevron.right")
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if sessionCards.isEmpty {
                sessionCards = StudyScheduler.plan(cards: deck.cards, count: settings.sessionCardCount)
            }
        }
        .onDisappear {
            speech.stop()
        }
    }

    private var currentCard: Flashcard? {
        guard sessionCards.indices.contains(currentIndex) else { return nil }
        return sessionCards[currentIndex]
    }

    private func toggleFlip(for card: Flashcard) {
        let willShowBack = !flipped
        withAnimation(.snappy(duration: 0.35)) {
            flipped.toggle()
        }

        if willShowBack {
            let text = card.answerText(for: settings.displaySide)
            let language = settings.displaySide == .languageOne ? deck.languageTwoName : deck.languageOneName
            speech.speak(text, languageName: language, muted: settings.muteAudio)
        } else {
            speech.stop()
        }
    }

    private func rateCurrentCard(_ rating: ReviewRating) {
        guard let card = currentCard else { return }
        let previous = card.lastRating
        let promoted = card.registerReview(rating)
        let review = StudyReview(
            deckID: deck.id,
            cardID: card.id,
            deckName: deck.name,
            cardText: card.languageOneText,
            rating: rating,
            previousRating: previous,
            promotedToPerfect: promoted
        )
        modelContext.insert(review)
        deck.updatedAt = .now
        try? modelContext.save()

        ratedCardIDs.insert(card.id)
        showRatingReminder = false

        if currentIndex < sessionCards.count - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                moveNext(allowWithoutRating: true)
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                completeSession()
            }
        }
    }

    private func moveNext(allowWithoutRating: Bool = false) {
        guard currentIndex < sessionCards.count - 1 else {
            if !allowWithoutRating, let card = currentCard, !ratedCardIDs.contains(card.id) {
                showRatingReminder = true
                return
            }
            completeSession()
            return
        }
        if !allowWithoutRating, let card = currentCard, !ratedCardIDs.contains(card.id) {
            showRatingReminder = true
            return
        }
        showRatingReminder = false
        speech.stop()
        withAnimation(.snappy) {
            currentIndex += 1
            flipped = false
        }
    }

    private func movePrevious() {
        guard currentIndex > 0 else { return }
        showRatingReminder = false
        speech.stop()
        withAnimation(.snappy) {
            currentIndex -= 1
            flipped = false
        }
    }

    private func completeSession() {
        showRatingReminder = false
        speech.stop()
        withAnimation(.snappy) {
            showingCompletion = true
            flipped = false
        }
    }

    private func startNextSession() {
        speech.stop()
        let plannedCards = StudyScheduler.plan(cards: deck.cards, count: settings.sessionCardCount)
        withAnimation(.snappy) {
            sessionCards = plannedCards
            currentIndex = 0
            flipped = false
            ratedCardIDs = []
            showRatingReminder = false
            showingCompletion = false
        }
    }

    private func finishSession() {
        speech.stop()
        dismiss()
        onFinish()
    }

    private func iconName(for rating: ReviewRating) -> String {
        switch rating {
        case .perfect:
            "checkmark.circle.fill"
        case .unsure:
            "questionmark.circle.fill"
        case .unknown:
            "xmark.circle.fill"
        }
    }
}

private struct StudySessionCompletionView: View {
    var studiedCount: Int
    var nextSetAction: () -> Void
    var finishAction: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 58))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("このセットが完了しました")
                    .font(.title2.bold())
                Text("\(studiedCount)枚を学習しました。続ける場合は、忘却曲線で優先度が高いカードから次のセットを出します。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button {
                    nextSetAction()
                } label: {
                    Label("次のセット", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    finishAction()
                } label: {
                    Label("終了", systemImage: "chart.line.uptrend.xyaxis")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 8)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FlashcardStudyCard: View {
    var card: Flashcard
    var deck: FlashcardDeck
    var shownSide: CardSidePreference
    var flipped: Bool
    var fontScale: Double

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.quaternary, lineWidth: 1)
                )

            if flipped {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(card.answerText(for: shownSide))
                            .font(.system(size: 32 * fontScale, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if card.meanings.isEmpty {
                            Text("意味と例文は未入力です。カード編集画面で入力、またはGemini（Google検索込み）で補完できます。")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(card.meanings) { meaning in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(meaning.meaning)
                                        .font(.system(size: 19 * fontScale, weight: .semibold))
                                    if !meaning.example.isEmpty {
                                        Text(meaning.example)
                                            .font(.system(size: 17 * fontScale))
                                    }
                                    if !meaning.exampleTranslation.isEmpty {
                                        Text(meaning.exampleTranslation)
                                            .font(.system(size: 15 * fontScale))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(22)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                VStack(spacing: 12) {
                    Text(shownSide == .languageOne ? deck.languageOneName : deck.languageTwoName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(card.visibleText(for: shownSide))
                        .font(.system(size: 34 * fontScale, weight: .bold))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                    Text("タップして裏面を表示")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 430)
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }
}
