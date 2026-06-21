import SwiftData
import SwiftUI

@main
struct LanguageFlashcardsApp: App {
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
        .modelContainer(for: [
            FlashcardDeck.self,
            Flashcard.self,
            StudyReview.self
        ])
    }
}

