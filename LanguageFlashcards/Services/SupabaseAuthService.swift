import Foundation

struct SupabaseAuthService {
    func signUp(email: String, password: String, supabaseURL: String, anonKey: String) async throws -> AuthSession {
        try await sendAuthRequest(
            path: "auth/v1/signup",
            queryItems: [],
            supabaseURL: supabaseURL,
            anonKey: anonKey,
            body: SupabaseEmailPasswordRequest(email: email, password: password),
            missingSessionMessage: "登録確認メールが必要な設定です。メール確認後にログインしてください。"
        )
    }

    func signIn(email: String, password: String, supabaseURL: String, anonKey: String) async throws -> AuthSession {
        try await sendAuthRequest(
            path: "auth/v1/token",
            queryItems: [URLQueryItem(name: "grant_type", value: "password")],
            supabaseURL: supabaseURL,
            anonKey: anonKey,
            body: SupabaseEmailPasswordRequest(email: email, password: password),
            missingSessionMessage: "ログイン情報を確認できませんでした。メールアドレスとパスワードを確認してください。"
        )
    }

    func signOut(accessToken: String, supabaseURL: String, anonKey: String) async {
        guard let request = makeRequest(
            path: "auth/v1/logout",
            queryItems: [],
            supabaseURL: supabaseURL,
            anonKey: anonKey,
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
        supabaseURL: String,
        anonKey: String,
        body: SupabaseEmailPasswordRequest,
        missingSessionMessage: String
    ) async throws -> AuthSession {
        guard var request = makeRequest(path: path, queryItems: queryItems, supabaseURL: supabaseURL, anonKey: anonKey) else {
            throw SupabaseAuthError.missingConfiguration
        }

        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(statusCode) else {
            throw SupabaseAuthError.server(decodeErrorMessage(from: data) ?? "Supabase認証に失敗しました。")
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
        supabaseURL: String,
        anonKey: String,
        accessToken: String? = nil
    ) -> URLRequest? {
        let trimmedURL = supabaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = anonKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty, !trimmedKey.isEmpty else { return nil }

        let baseString = trimmedURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(string: baseString) else { return nil }
        let joinedPath = [components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")), path]
            .filter { !$0.isEmpty }
            .joined(separator: "/")
        components.path = "/" + joinedPath
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
}

private struct SupabaseEmailPasswordRequest: Encodable {
    let email: String
    let password: String
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
            "Supabase URLとAnon Keyを設定してください。"
        case .invalidEmail:
            "メールアドレスの形式を確認してください。"
        case .invalidPassword(let message):
            message
        case .passwordMismatch:
            "確認用パスワードが一致していません。"
        case .server(let message):
            message
        }
    }
}
