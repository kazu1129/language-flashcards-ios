import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \StudyReview.reviewedAt, order: .forward) private var reviews: [StudyReview]
    @State private var showingPremiumUpgrade = false
    @State private var displayedMonth = Date()
    @State private var selectedCalendarDate: Date?
    @State private var chartEndDate = Calendar.current.startOfDay(for: .now)
    @State private var chartVisibleDayCount = 30
    @State private var chartPinchStartDayCount: Int?
    @State private var chartDragStartEndDate: Date?
    private let calendar = Calendar.current
    private let minimumChartVisibleDays = 3

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
            .onAppear {
                clampChartRange()
            }
            .navigationTitle(String(localized: "dashboard.navigationTitle"))
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
            Text("dashboard.today.title")
                .font(.title2.bold())

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                MetricCard(title: String(localized: "dashboard.metric.reviews"), value: "\(todayReviews.count)", color: .blue)
                MetricCard(title: String(localized: "dashboard.metric.perfect"), value: "\(todayReviews.filter { $0.rating == .perfect }.count)", color: .green)
                MetricCard(title: String(localized: "dashboard.metric.unsure"), value: "\(todayReviews.filter { $0.rating == .unsure }.count)", color: .orange)
                MetricCard(title: String(localized: "dashboard.metric.unknown"), value: "\(todayReviews.filter { $0.rating == .unknown }.count)", color: .red)
            }
        }
    }

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("dashboard.calendar.title")
                .font(.title2.bold())

            HStack(spacing: 12) {
                Button {
                    moveDisplayedMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(Text("dashboard.calendar.previousMonth"))

                Text(displayedMonthTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                Button {
                    moveDisplayedMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.bordered)
                .disabled(!canMoveToNextMonth)
                .accessibilityLabel(Text("dashboard.calendar.nextMonth"))
            }

            let days = monthDays(for: displayedMonth)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(localizedWeekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(days.indices, id: \.self) { index in
                    let date = days[index]
                    if let date {
                        let count = reviewCount(on: date)
                        Button {
                            selectedCalendarDate = date
                        } label: {
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
                        }
                        .buttonStyle(.plain)
                        .background(calendarCellBackground(for: date), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(calendarCellBorder(for: date), lineWidth: selectedCalendarDate.map { calendar.isDate($0, inSameDayAs: date) } == true ? 2 : 0)
                        )
                    } else {
                        Color.clear.frame(height: 48)
                    }
                }
            }

            if let selectedDate = selectedCalendarDate {
                selectedDateSummary(for: selectedDate)
            }
        }
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("dashboard.learnedCards.title")
                .font(.title2.bold())

            Text(chartRangeTitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            interactiveChart {
                Chart(dailyReviewPoints) { point in
                    LineMark(
                        x: .value(String(localized: "dashboard.chart.axis.day"), point.date),
                        y: .value(String(localized: "dashboard.chart.axis.cards"), point.count)
                    )
                    PointMark(
                        x: .value(String(localized: "dashboard.chart.axis.day"), point.date),
                        y: .value(String(localized: "dashboard.chart.axis.cards"), point.count)
                    )
                }
            }
        }
    }

    private var improvementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("dashboard.improvement.title")
                .font(.title2.bold())

            Text(chartRangeTitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            interactiveChart {
                Chart(improvementPoints) { point in
                    LineMark(
                        x: .value(String(localized: "dashboard.chart.axis.day"), point.date),
                        y: .value(String(localized: "dashboard.chart.axis.count"), point.count)
                    )
                    .foregroundStyle(.green)
                    PointMark(
                        x: .value(String(localized: "dashboard.chart.axis.day"), point.date),
                        y: .value(String(localized: "dashboard.chart.axis.count"), point.count)
                    )
                    .foregroundStyle(.green)
                }
            }
        }
    }

    private var dailyReviewPoints: [DailyPoint] {
        let countsByDay = reviewCountsByDay
        return pointsForVisibleChartRange { day in
            countsByDay[day, default: 0]
        }
    }

    private var improvementPoints: [DailyPoint] {
        let countsByDay = unknownToPerfectCountsByDay
        return pointsForVisibleChartRange { day in
            countsByDay[day, default: 0]
        }
    }

    private var reviewCountsByDay: [Date: Int] {
        Dictionary(grouping: reviews, by: { calendar.startOfDay(for: $0.reviewedAt) })
            .mapValues(\.count)
    }

    private var unknownToPerfectCountsByDay: [Date: Int] {
        Dictionary(grouping: reviews.filter { review in
            review.rating == .perfect && review.previousRatingRaw == ReviewRating.unknown.rawValue
        }, by: { calendar.startOfDay(for: $0.reviewedAt) })
        .mapValues(\.count)
    }

    private var chartStartDate: Date {
        calendar.date(byAdding: .day, value: -(chartVisibleDayCount - 1), to: chartEndDate) ?? chartEndDate
    }

    private var chartDateDomain: ClosedRange<Date> {
        chartStartDate...chartEndDate
    }

    private var chartRangeTitle: String {
        "\(chartStartDate.formatted(.dateTime.month().day())) - \(chartEndDate.formatted(.dateTime.month().day()))"
    }

    private var maximumChartVisibleDays: Int {
        let today = calendar.startOfDay(for: .now)
        let earliestReviewDate = reviews.map { calendar.startOfDay(for: $0.reviewedAt) }.min() ?? today
        let daySpan = calendar.dateComponents([.day], from: earliestReviewDate, to: today).day ?? 0
        return max(30, daySpan + 1)
    }

    private var minimumChartEndDate: Date {
        reviews.map { calendar.startOfDay(for: $0.reviewedAt) }.min() ?? calendar.startOfDay(for: .now)
    }

    private var localizedWeekdays: [String] {
        [
            String(localized: "dashboard.weekday.sun"),
            String(localized: "dashboard.weekday.mon"),
            String(localized: "dashboard.weekday.tue"),
            String(localized: "dashboard.weekday.wed"),
            String(localized: "dashboard.weekday.thu"),
            String(localized: "dashboard.weekday.fri"),
            String(localized: "dashboard.weekday.sat")
        ]
    }

    private func pointsForVisibleChartRange(value: (Date) -> Int) -> [DailyPoint] {
        (0..<chartVisibleDayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: chartStartDate) else { return nil }
            return DailyPoint(date: day, count: value(day))
        }
    }

    private var displayedMonthTitle: String {
        monthStart(for: displayedMonth).formatted(.dateTime.year().month(.wide))
    }

    private var canMoveToNextMonth: Bool {
        monthStart(for: displayedMonth) < monthStart(for: .now)
    }

    private func moveDisplayedMonth(by value: Int) {
        guard let nextMonth = calendar.date(byAdding: .month, value: value, to: monthStart(for: displayedMonth)) else { return }
        displayedMonth = nextMonth
        selectedCalendarDate = nil
    }

    private func reviewCount(on date: Date) -> Int {
        reviews(on: date).count
    }

    private func reviews(on date: Date) -> [StudyReview] {
        reviews.filter { calendar.isDate($0.reviewedAt, inSameDayAs: date) }
    }

    private func ratingSummary(on date: Date) -> TodayLearningSummary {
        let dateReviews = reviews(on: date)
        return TodayLearningSummary(
            total: dateReviews.count,
            perfect: dateReviews.filter { $0.rating == .perfect }.count,
            unsure: dateReviews.filter { $0.rating == .unsure }.count,
            unknown: dateReviews.filter { $0.rating == .unknown }.count
        )
    }

    private func monthStart(for date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    private func monthDays(for month: Date) -> [Date?] {
        let monthStart = monthStart(for: month)
        guard let interval = calendar.dateInterval(of: .month, for: monthStart),
              let range = calendar.range(of: .day, in: .month, for: monthStart) else {
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

    @ViewBuilder
    private func selectedDateSummary(for date: Date) -> some View {
        let summary = ratingSummary(on: date)

        VStack(alignment: .leading, spacing: 12) {
            Text(date.formatted(.dateTime.year().month().day().weekday(.wide)))
                .font(.headline)

            if summary.total == 0 {
                Text("dashboard.calendar.noReviews")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 10) {
                    DailyRatingCount(
                        title: String(localized: "dashboard.metric.perfect"),
                        count: summary.perfect,
                        color: .green
                    )
                    DailyRatingCount(
                        title: String(localized: "dashboard.metric.unsure"),
                        count: summary.unsure,
                        color: .orange
                    )
                    DailyRatingCount(
                        title: String(localized: "dashboard.metric.unknown"),
                        count: summary.unknown,
                        color: .red
                    )
                }

                Text(String.localizedStringWithFormat(
                    String(localized: "dashboard.calendar.totalReviews"),
                    Int64(summary.total)
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func calendarCellBackground(for date: Date) -> Color {
        guard selectedCalendarDate.map({ calendar.isDate($0, inSameDayAs: date) }) != true else {
            return Color.accentColor.opacity(0.18)
        }
        return calendar.isDateInToday(date) ? Color.accentColor.opacity(0.12) : Color.clear
    }

    private func calendarCellBorder(for date: Date) -> Color {
        selectedCalendarDate.map { calendar.isDate($0, inSameDayAs: date) } == true ? Color.accentColor : Color.clear
    }

    private func interactiveChart<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        GeometryReader { proxy in
            content()
                .chartXScale(domain: chartDateDomain)
                .contentShape(Rectangle())
                .simultaneousGesture(chartPinchGesture())
                .simultaneousGesture(chartDragGesture(width: proxy.size.width))
        }
        .frame(height: 220)
    }

    private func chartPinchGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                if chartPinchStartDayCount == nil {
                    chartPinchStartDayCount = chartVisibleDayCount
                }

                let baseDayCount = chartPinchStartDayCount ?? chartVisibleDayCount
                let safeScale = max(Double(scale), 0.05)
                let proposedDayCount = Int((Double(baseDayCount) / safeScale).rounded())
                chartVisibleDayCount = clampedChartVisibleDayCount(proposedDayCount)
            }
            .onEnded { _ in
                chartPinchStartDayCount = nil
                clampChartRange()
            }
    }

    private func chartDragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if chartDragStartEndDate == nil {
                    chartDragStartEndDate = chartEndDate
                }

                let dayWidth = max(8, width / CGFloat(max(chartVisibleDayCount, 1)))
                let dayOffset = Int((-value.translation.width / dayWidth).rounded())
                guard let baseEndDate = chartDragStartEndDate,
                      let proposedEndDate = calendar.date(byAdding: .day, value: dayOffset, to: baseEndDate) else {
                    return
                }
                chartEndDate = clampedChartEndDate(proposedEndDate)
            }
            .onEnded { _ in
                chartDragStartEndDate = nil
            }
    }

    private func clampChartRange() {
        chartVisibleDayCount = clampedChartVisibleDayCount(chartVisibleDayCount)
        chartEndDate = clampedChartEndDate(chartEndDate)
    }

    private func clampedChartVisibleDayCount(_ value: Int) -> Int {
        min(max(value, minimumChartVisibleDays), maximumChartVisibleDays)
    }

    private func clampedChartEndDate(_ date: Date) -> Date {
        let today = calendar.startOfDay(for: .now)
        let day = calendar.startOfDay(for: date)
        if day > today {
            return today
        }
        if day < minimumChartEndDate {
            return minimumChartEndDate
        }
        return day
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

private struct DailyRatingCount: View {
    var title: String
    var count: Int
    var color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }
}
