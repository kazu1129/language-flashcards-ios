import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \StudyReview.reviewedAt, order: .forward) private var reviews: [StudyReview]
    @State private var showingPremiumUpgrade = false
    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    todaySummary
                    calendarSection
                    trendSection
                    improvementSection
                    if !settings.isPremium {
                        PremiumHomeCard {
                            showingPremiumUpgrade = true
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("学習の成果")
            .sheet(isPresented: $showingPremiumUpgrade) {
                PremiumUpgradeView()
            }
        }
    }

    private var todayReviews: [StudyReview] {
        reviews.filter { calendar.isDateInToday($0.reviewedAt) }
    }

    private var todaySummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日")
                .font(.title2.bold())

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                MetricCard(title: "学習回数", value: "\(todayReviews.count)", color: .blue)
                MetricCard(title: "完璧", value: "\(todayReviews.filter { $0.rating == .perfect }.count)", color: .green)
                MetricCard(title: "自信なし", value: "\(todayReviews.filter { $0.rating == .unsure }.count)", color: .orange)
                MetricCard(title: "わからない", value: "\(todayReviews.filter { $0.rating == .unknown }.count)", color: .red)
            }
        }
    }

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("カレンダー")
                .font(.title2.bold())

            let days = monthDays()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(["日", "月", "火", "水", "木", "金", "土"], id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(days.indices, id: \.self) { index in
                    let date = days[index]
                    if let date {
                        let count = reviewCount(on: date)
                        VStack(spacing: 4) {
                            Text("\(calendar.component(.day, from: date))")
                                .font(.caption)
                                .fontWeight(calendar.isDateInToday(date) ? .bold : .regular)
                            Circle()
                                .fill(count > 0 ? Color.accentColor : Color.clear)
                                .frame(width: 7, height: 7)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(height: 48)
                        .frame(maxWidth: .infinity)
                        .background(calendar.isDateInToday(date) ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                    } else {
                        Color.clear.frame(height: 48)
                    }
                }
            }
        }
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("学んだカード枚数")
                .font(.title2.bold())

            Chart(dailyReviewPoints) { point in
                LineMark(
                    x: .value("日", point.date),
                    y: .value("枚数", point.count)
                )
                PointMark(
                    x: .value("日", point.date),
                    y: .value("枚数", point.count)
                )
            }
            .frame(height: 220)
        }
    }

    private var improvementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("不確かから完璧になった件数")
                .font(.title2.bold())

            Chart(improvementPoints) { point in
                BarMark(
                    x: .value("日", point.date),
                    y: .value("件数", point.count)
                )
                .foregroundStyle(.green)
            }
            .frame(height: 220)
        }
    }

    private var dailyReviewPoints: [DailyPoint] {
        pointsForLastDays(count: settings.isPremium ? 30 : 7) { day in
            reviewCount(on: day)
        }
    }

    private var improvementPoints: [DailyPoint] {
        pointsForLastDays(count: settings.isPremium ? 30 : 7) { day in
            reviews.filter { calendar.isDate($0.reviewedAt, inSameDayAs: day) && $0.promotedToPerfect }.count
        }
    }

    private func pointsForLastDays(count: Int = 14, value: (Date) -> Int) -> [DailyPoint] {
        let today = calendar.startOfDay(for: .now)
        return (0..<count).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -(count - 1 - offset), to: today) else { return nil }
            return DailyPoint(date: day, count: value(day))
        }
    }

    private func reviewCount(on date: Date) -> Int {
        reviews.filter { calendar.isDate($0.reviewedAt, inSameDayAs: date) }.count
    }

    private func monthDays() -> [Date?] {
        let now = Date()
        guard let interval = calendar.dateInterval(of: .month, for: now),
              let range = calendar.range(of: .day, in: .month, for: now) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: interval.start)
        var result: [Date?] = Array(repeating: nil, count: max(0, firstWeekday - 1))
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: interval.start) {
                result.append(date)
            }
        }
        return result
    }
}

private struct DailyPoint: Identifiable {
    var date: Date
    var count: Int
    var id: Date { date }
}

private struct MetricCard: View {
    var title: String
    var value: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title.bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
