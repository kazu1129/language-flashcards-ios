import SwiftData
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    @Query private var decks: [FlashcardDeck]
    @Query(sort: \StudyReview.reviewedAt, order: .forward) private var reviews: [StudyReview]

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("ホーム", systemImage: "rectangle.stack")
                }

            DashboardView()
                .tabItem {
                    Label("成果", systemImage: "chart.line.uptrend.xyaxis")
                }

            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape")
                }
        }
        .task {
            await refreshNotifications()
        }
        .onChange(of: reviews.count) {
            Task { await refreshNotifications() }
        }
        .onChange(of: settings.studyReminderEnabled) {
            Task { await refreshNotifications() }
        }
        .onChange(of: settings.dailySummaryEnabled) {
            Task { await refreshNotifications() }
        }
        .onChange(of: settings.anniversaryNotificationsEnabled) {
            Task { await refreshNotifications() }
        }
        .onChange(of: settings.growthNotificationsEnabled) {
            Task { await refreshNotifications() }
        }
        .onChange(of: settings.hasBirthday) {
            Task { await refreshNotifications() }
        }
        .onChange(of: settings.birthday) {
            Task { await refreshNotifications() }
        }
    }

    private func refreshNotifications() async {
        await NotificationService.refresh(settings: settings, decks: decks, reviews: reviews)
    }
}
