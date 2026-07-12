import Foundation

enum SupabaseConfiguration {
    static let projectURL = "https://ykrlxavymzgfwolujddg.supabase.co"
    static let publishableKey = "sb_publishable_X-9UgHJqZErgK3MMHL0xEg_1RmWHqZm"
    static let passwordResetRedirectURL = "https://language-cards.blue/reset-password/"

    static var isConfigured: Bool {
        let trimmedURL = projectURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = publishableKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedURL.isEmpty
            && !trimmedKey.isEmpty
            && !trimmedURL.contains("YOUR_PROJECT_REF")
            && !trimmedKey.contains("YOUR_SUPABASE_PUBLISHABLE_KEY")
    }
}
