import SwiftData
import SwiftUI

private enum RootTab {
    case home
    case dashboard
    case settings
}

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @Query private var decks: [FlashcardDeck]
    @Query(sort: \StudyReview.reviewedAt, order: .forward) private var reviews: [StudyReview]
    @State private var selectedTab: RootTab = .home

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                appTabs
            } else {
                AuthView()
            }
        }
        .task(id: authManager.isAuthenticated) {
            guard authManager.isAuthenticated else { return }
            await subscriptionStore.loadProducts()
            await subscriptionStore.syncPurchasedSubscriptions(settings: settings)
            await refreshNotifications()
        }
        .sheet(isPresented: Binding(
            get: { authManager.isAuthenticated && !settings.hasSeenFSRSOnboarding },
            set: { if !$0 { settings.hasSeenFSRSOnboarding = true } }
        )) {
            FSRSOnboardingView {
                settings.hasSeenFSRSOnboarding = true
            }
        }
    }

    private var appTabs: some View {
        TabView(selection: $selectedTab) {
            HomeView {
                selectedTab = .dashboard
            }
                .tabItem {
                    Label(String(localized: "root.tab.home"), systemImage: "rectangle.stack")
                }
                .tag(RootTab.home)

            DashboardView()
                .tabItem {
                    Label(String(localized: "root.tab.dashboard"), systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(RootTab.dashboard)

            SettingsView()
                .tabItem {
                    Label(String(localized: "root.tab.settings"), systemImage: "gearshape")
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
    }

    private func refreshNotifications() async {
        await NotificationService.refresh(settings: settings, decks: decks, reviews: reviews)
    }
}
