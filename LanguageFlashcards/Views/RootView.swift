import SwiftData
import SwiftUI

private enum RootTab {
    case home
    case dashboard
    case settings
}

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    @Query private var decks: [FlashcardDeck]
    @Query(sort: \StudyReview.reviewedAt, order: .forward) private var reviews: [StudyReview]
    @State private var selectedTab: RootTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView {
                selectedTab = .dashboard
            }
                .tabItem {
                    Label("ホーム", systemImage: "rectangle.stack")
                }
                .tag(RootTab.home)

            DashboardView()
                .tabItem {
                    Label("成果", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(RootTab.dashboard)

            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape")
                }
                .tag(RootTab.settings)
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
        .sheet(isPresented: Binding(
            get: { !settings.hasSeenFSRSOnboarding },
            set: { if !$0 { settings.hasSeenFSRSOnboarding = true } }
        )) {
            FSRSOnboardingView {
                settings.hasSeenFSRSOnboarding = true
            }
        }
    }

    private func refreshNotifications() async {
        await NotificationService.refresh(settings: settings, decks: decks, reviews: reviews)
    }
}
