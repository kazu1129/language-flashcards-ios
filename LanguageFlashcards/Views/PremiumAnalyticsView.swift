import Charts
import SwiftUI

struct PremiumAnalyticsView: View {
    let snapshot: PremiumAnalyticsSnapshot
    var showsActions = true
    var onReviewWeakCards: () -> Void = {}
    var onReviewForgettingCards: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("詳細統計", systemImage: "chart.xyaxis.line")
                .font(.title2.bold())
            deckMasterySection
            upcomingReviewsSection
            retentionSection
            studyHoursSection

            Label("弱点分析", systemImage: "scope")
                .font(.title2.bold())
            weakDeckSection
            weakCardsSection
            forgettingSection
        }
    }

    private var deckMasterySection: some View {
        analyticsGroup(title: "デッキ別習得率", systemImage: "rectangle.stack") {
            if snapshot.deckMastery.isEmpty {
                emptyMessage("デッキを作ると習得率が表示されます。")
            } else {
                ForEach(snapshot.deckMastery) { stat in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(stat.deckName).font(.headline)
                            Spacer()
                            Text("習得 \(stat.masteryPercentage)%")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(.green)
                        }
                        ProgressView(value: stat.masteryRate)
                            .tint(.green)
                        Text(
                            "完璧 \(percent(stat.masteryRate))・あやふや \(percent(stat.unsureRate))・未習得 \(percent(stat.unlearnedRate))"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    if stat.id != snapshot.deckMastery.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var upcomingReviewsSection: some View {
        analyticsGroup(title: "今後7日の復習予定", systemImage: "calendar.badge.clock") {
            Chart(snapshot.upcomingReviews) { point in
                BarMark(
                    x: .value("日", point.date, unit: .day),
                    y: .value("カード", point.count)
                )
                .foregroundStyle(.blue)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) {
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .frame(height: 180)
        }
    }

    private var retentionSection: some View {
        analyticsGroup(title: "定着カーブ", systemImage: "waveform.path.ecg") {
            if snapshot.retentionTrend.isEmpty {
                emptyMessage("復習すると定着率の推移が表示されます。")
            } else {
                Chart(snapshot.retentionTrend) { point in
                    LineMark(
                        x: .value("復習日", point.date),
                        y: .value("定着率", point.averageRetrievability * 100)
                    )
                    PointMark(
                        x: .value("復習日", point.date),
                        y: .value("定着率", point.averageRetrievability * 100)
                    )
                }
                .chartYScale(domain: 0...100)
                .frame(height: 180)
                Text("復習日ごとの対象カードを、現在の定着率で近似しています。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var studyHoursSection: some View {
        analyticsGroup(title: "よく勉強する時間帯", systemImage: "clock") {
            Chart(snapshot.studyHours) { point in
                BarMark(
                    x: .value("時刻", point.hour),
                    y: .value("復習", point.count)
                )
                .foregroundStyle(.orange)
            }
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                    AxisValueLabel {
                        if let hour = value.as(Int.self) {
                            Text("\(hour)時")
                        }
                    }
                }
            }
            .frame(height: 180)
        }
    }

    private var weakDeckSection: some View {
        analyticsGroup(title: "手薄なデッキ", systemImage: "rectangle.stack.badge.minus") {
            if let deck = snapshot.weakestDeck {
                HStack {
                    Text(deck.deckName).font(.headline)
                    Spacer()
                    Text("習得 \(deck.masteryPercentage)%")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.orange)
                }
            } else {
                emptyMessage("分析できるデッキがありません。")
            }
        }
    }

    private var weakCardsSection: some View {
        analyticsGroup(title: "苦手カード TOP \(snapshot.weakCards.count)", systemImage: "exclamationmark.triangle") {
            if snapshot.weakCards.isEmpty {
                emptyMessage("復習すると苦手カードが表示されます。")
            } else {
                ForEach(snapshot.weakCards) { stat in
                    analysisRow(
                        title: stat.cardText,
                        subtitle: "\(stat.deckName)・不明 \(stat.unknownCount)・あやふや \(stat.unsureCount)",
                        value: "定着 \(percent(stat.retrievability))"
                    )
                }
                if showsActions {
                    Button("苦手だけ復習", action: onReviewWeakCards)
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var forgettingSection: some View {
        analyticsGroup(title: "そろそろ忘れそう", systemImage: "brain.head.profile") {
            if snapshot.forgettingCards.isEmpty {
                Label("今すぐ復習が必要なカードはありません", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
            } else {
                ForEach(snapshot.forgettingCards.prefix(5)) { stat in
                    analysisRow(
                        title: stat.cardText,
                        subtitle: stat.deckName,
                        value: "定着 \(percent(stat.retrievability))"
                    )
                }
                if showsActions {
                    Button("忘れる前に復習", action: onReviewForgettingCards)
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func analyticsGroup<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12, content: content)
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.headline)
        }
    }

    private func analysisRow(title: String, subtitle: String, value: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func emptyMessage(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
