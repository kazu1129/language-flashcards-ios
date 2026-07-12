import Foundation

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var session: AuthSession?
    @Published var isWorking = false
    @Published var isPasswordResetWorking = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?

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
        passwordConfirmation: String
    ) async {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard password == passwordConfirmation else {
            errorMessage = SupabaseAuthError.passwordMismatch.localizedDescription
            statusMessage = nil
            return
        }
        await authenticate(email: email, password: password, validatePasswordRules: true) {
            try await service.signUp(email: normalizedEmail, password: password)
        }
    }

    func signIn(email: String, password: String) async {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        await authenticate(email: email, password: password, validatePasswordRules: false) {
            try await service.signIn(email: normalizedEmail, password: password)
        }
    }

    func requestPasswordReset(email: String) async {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedEmail.contains("@"), normalizedEmail.contains(".") else {
            errorMessage = SupabaseAuthError.invalidEmail.localizedDescription
            statusMessage = nil
            return
        }
        guard SupabaseConfiguration.isConfigured else {
            errorMessage = SupabaseAuthError.missingConfiguration.localizedDescription
            statusMessage = nil
            return
        }

        isPasswordResetWorking = true
        errorMessage = nil
        statusMessage = nil
        defer { isPasswordResetWorking = false }

        do {
            try await service.requestPasswordReset(email: normalizedEmail)
            statusMessage = String(localized: "auth.status.passwordResetSent")
        } catch {
            errorMessage = Self.friendlyNetworkMessage(for: error)
        }
    }

    func signOut(settings: AppSettings) async {
        let currentSession = session
        clearSession(settings: settings)

        if let currentSession {
            await service.signOut(
                accessToken: currentSession.accessToken
            )
        }
    }

    func clearSession(settings: AppSettings) {
        session = nil
        errorMessage = nil
        statusMessage = nil
        isPasswordResetWorking = false
        KeychainService.delete(account: Keys.session)
        settings.resetForLogout()
    }

    static func passwordValidationMessage(for password: String) -> String? {
        guard (8...20).contains(password.count) else {
            return String(localized: "auth.error.passwordLength")
        }
        guard contains("[a-z]", in: password) else {
            return String(localized: "auth.error.passwordLowercase")
        }
        guard contains("[A-Z]", in: password) else {
            return String(localized: "auth.error.passwordUppercase")
        }
        guard contains("[0-9]", in: password) else {
            return String(localized: "auth.error.passwordNumber")
        }
        guard contains("[^A-Za-z0-9]", in: password) else {
            return String(localized: "auth.error.passwordSymbol")
        }
        return nil
    }

    private func authenticate(
        email: String,
        password: String,
        validatePasswordRules: Bool,
        action: () async throws -> AuthSession
    ) async {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedEmail.contains("@"), normalizedEmail.contains(".") else {
            errorMessage = SupabaseAuthError.invalidEmail.localizedDescription
            statusMessage = nil
            return
        }
        if validatePasswordRules, let passwordMessage = Self.passwordValidationMessage(for: password) {
            errorMessage = passwordMessage
            statusMessage = nil
            return
        }
        guard SupabaseConfiguration.isConfigured else {
            errorMessage = SupabaseAuthError.missingConfiguration.localizedDescription
            statusMessage = nil
            return
        }

        isWorking = true
        errorMessage = nil
        statusMessage = nil
        defer { isWorking = false }

        do {
            let newSession = try await action()
            session = newSession
            try saveSession(newSession)
        } catch {
            errorMessage = Self.friendlyNetworkMessage(for: error)
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

    private static func friendlyNetworkMessage(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return String(localized: "auth.error.networkTimeout")
            case .notConnectedToInternet, .networkConnectionLost:
                return String(localized: "auth.error.noInternet")
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return String(localized: "auth.error.cannotConnectSupabase")
            default:
                return urlError.localizedDescription
            }
        }
        return error.localizedDescription
    }
}
