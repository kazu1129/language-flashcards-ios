import Foundation

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var session: AuthSession?
    @Published var isWorking = false
    @Published var errorMessage: String?

    private enum Keys {
        static let session = "supabase-auth-session"
    }

    private let service = SupabaseAuthService()

    init() {
        restoreSession()
    }

    var isAuthenticated: Bool {
        session != nil
    }

    var email: String {
        session?.email ?? ""
    }

    var accountUUID: UUID? {
        guard let userID = session?.userID else { return nil }
        return UUID(uuidString: userID)
    }

    func signUp(
        email: String,
        password: String,
        passwordConfirmation: String,
        supabaseURL: String,
        anonKey: String
    ) async {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard password == passwordConfirmation else {
            errorMessage = SupabaseAuthError.passwordMismatch.localizedDescription
            return
        }
        await authenticate(email: email, password: password, supabaseURL: supabaseURL, anonKey: anonKey, validatePasswordRules: true) {
            try await service.signUp(email: normalizedEmail, password: password, supabaseURL: supabaseURL, anonKey: anonKey)
        }
    }

    func signIn(email: String, password: String, supabaseURL: String, anonKey: String) async {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        await authenticate(email: email, password: password, supabaseURL: supabaseURL, anonKey: anonKey, validatePasswordRules: false) {
            try await service.signIn(email: normalizedEmail, password: password, supabaseURL: supabaseURL, anonKey: anonKey)
        }
    }

    func signOut(settings: AppSettings) async {
        let currentSession = session
        clearSession(settings: settings)

        if let currentSession {
            await service.signOut(
                accessToken: currentSession.accessToken,
                supabaseURL: settings.supabaseURL,
                anonKey: settings.supabaseAnonKey
            )
        }
    }

    func clearSession(settings: AppSettings) {
        session = nil
        errorMessage = nil
        KeychainService.delete(account: Keys.session)
        settings.resetForLogout()
    }

    static func passwordValidationMessage(for password: String) -> String? {
        guard (8...20).contains(password.count) else {
            return "パスワードは8文字以上20文字以下にしてください。"
        }
        guard contains("[a-z]", in: password) else {
            return "パスワードには英小文字を含めてください。"
        }
        guard contains("[A-Z]", in: password) else {
            return "パスワードには英大文字を含めてください。"
        }
        guard contains("[0-9]", in: password) else {
            return "パスワードには数字を含めてください。"
        }
        guard contains("[^A-Za-z0-9]", in: password) else {
            return "パスワードには特殊文字を含めてください。"
        }
        return nil
    }

    private func authenticate(
        email: String,
        password: String,
        supabaseURL: String,
        anonKey: String,
        validatePasswordRules: Bool,
        action: () async throws -> AuthSession
    ) async {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedEmail.contains("@"), normalizedEmail.contains(".") else {
            errorMessage = SupabaseAuthError.invalidEmail.localizedDescription
            return
        }
        if validatePasswordRules, let passwordMessage = Self.passwordValidationMessage(for: password) {
            errorMessage = passwordMessage
            return
        }
        guard !supabaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !anonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = SupabaseAuthError.missingConfiguration.localizedDescription
            return
        }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let newSession = try await action()
            session = newSession
            try saveSession(newSession)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restoreSession() {
        guard let json = KeychainService.load(account: Keys.session),
              let data = json.data(using: .utf8),
              let restored = try? JSONDecoder().decode(AuthSession.self, from: data) else {
            return
        }
        session = restored
    }

    private func saveSession(_ session: AuthSession) throws {
        let data = try JSONEncoder().encode(session)
        guard let json = String(data: data, encoding: .utf8) else { return }
        try KeychainService.save(json, account: Keys.session)
    }

    private static func contains(_ pattern: String, in text: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }
}
