import SwiftData
import SwiftUI

@main
struct LanguageFlashcardsApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var authManager = AuthManager()
    @StateObject private var subscriptionStore = SubscriptionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(authManager)
                .environmentObject(subscriptionStore)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
        .modelContainer(for: [
            FlashcardDeck.self,
            Flashcard.self,
            StudyReview.self
        ])
    }
}
