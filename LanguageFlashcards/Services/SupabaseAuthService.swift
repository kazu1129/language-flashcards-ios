import Foundation

struct SupabaseAuthService {
    func signUp(email: String, password: String) async throws -> AuthSession {
        try await sendAuthRequest(
            path: "auth/v1/signup",
            queryItems: [],
            body: SupabaseEmailPasswordRequest(email: email, password: password),
            missingSessionMessage: String(localized: "auth.error.emailConfirmationRequired")
        )
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        try await sendAuthRequest(
            path: "auth/v1/token",
            queryItems: [URLQueryItem(name: "grant_type", value: "password")],
            body: SupabaseEmailPasswordRequest(email: email, password: password),
            missingSessionMessage: String(localized: "auth.error.invalidCredentials")
        )
    }

    func requestPasswordReset(email: String) async throws {
        guard var request = makeRequest(
            path: "auth/v1/recover",
            queryItems: [URLQueryItem(name: "redirect_to", value: SupabaseConfiguration.passwordResetRedirectURL)]
        ) else {
            throw SupabaseAuthError.missingConfiguration
        }

        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(SupabasePasswordResetRequest(email: email))

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(statusCode) else {
            throw SupabaseAuthError.server(
                friendlyErrorMessage(
                    from: decodeErrorMessage(from: data),
                    fallback: String(localized: "auth.error.passwordResetEmailFailed")
                )
            )
        }
    }

    func signOut(accessToken: String) async {
        guard let request = makeRequest(
            path: "auth/v1/logout",
            queryItems: [],
            accessToken: accessToken
        ) else {
            return
        }

        var logoutRequest = request
        logoutRequest.httpMethod = "POST"
        _ = try? await URLSession.shared.data(for: logoutRequest)
    }

    private func sendAuthRequest(
        path: String,
        queryItems: [URLQueryItem],
        body: SupabaseEmailPasswordRequest,
        missingSessionMessage: String
    ) async throws -> AuthSession {
        guard var request = makeRequest(path: path, queryItems: queryItems) else {
            throw SupabaseAuthError.missingConfiguration
        }

        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(statusCode) else {
            throw SupabaseAuthError.server(
                friendlyErrorMessage(
                    from: decodeErrorMessage(from: data),
                    fallback: String(localized: "auth.error.supabaseAuthFailed")
                )
            )
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let authResponse = try decoder.decode(SupabaseAuthResponse.self, from: data)

        guard
            let accessToken = authResponse.accessToken,
            let refreshToken = authResponse.refreshToken,
            let user = authResponse.user
        else {
            throw SupabaseAuthError.server(missingSessionMessage)
        }

        return AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userID: user.id,
            email: user.email ?? body.email
        )
    }

    private func makeRequest(
        path: String,
        queryItems: [URLQueryItem],
        accessToken: String? = nil
    ) -> URLRequest? {
        guard SupabaseConfiguration.isConfigured else { return nil }
        let trimmedURL = SupabaseConfiguration.projectURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = SupabaseConfiguration.publishableKey.trimmingCharacters(in: .whitespacesAndNewlines)

        let baseString = trimmedURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(string: baseString) else { return nil }
        let joinedPath = [components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")), path]
            .filter { !$0.isEmpty }
            .joined(separator: "/")
        components.path = "/" + joinedPath
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(trimmedKey, forHTTPHeaderField: "apikey")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func decodeErrorMessage(from data: Data) -> String? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        if let error = try? decoder.decode(SupabaseErrorResponse.self, from: data) {
            return error.message ?? error.msg ?? error.errorDescription ?? error.error
        }
        return String(data: data, encoding: .utf8)
    }

    private func friendlyErrorMessage(from message: String?, fallback: String) -> String {
        guard let message else { return fallback }
        let lowercasedMessage = message.lowercased()
        if lowercasedMessage.contains("email rate limit exceeded") {
            return String(localized: "auth.error.emailRateLimit")
        }
        if lowercasedMessage.contains("error sending recovery email") ||
            lowercasedMessage.contains("error sending confirmation email") ||
            lowercasedMessage.contains("smtp") {
            return String(localized: "auth.error.emailSendingFailed")
        }
        return message
    }
}

private struct SupabaseEmailPasswordRequest: Encodable {
    let email: String
    let password: String
}

private struct SupabasePasswordResetRequest: Encodable {
    let email: String
}

private struct SupabaseAuthResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let user: SupabaseUser?
}

private struct SupabaseUser: Decodable {
    let id: String
    let email: String?
}

private struct SupabaseErrorResponse: Decodable {
    let error: String?
    let errorDescription: String?
    let msg: String?
    let message: String?
}

enum SupabaseAuthError: LocalizedError {
    case missingConfiguration
    case invalidEmail
    case invalidPassword(String)
    case passwordMismatch
    case server(String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            String(localized: "auth.error.missingConfiguration")
        case .invalidEmail:
            String(localized: "auth.error.invalidEmail")
        case .invalidPassword(let message):
            message
        case .passwordMismatch:
            String(localized: "auth.error.passwordMismatch")
        case .server(let message):
            message
        }
    }
}
