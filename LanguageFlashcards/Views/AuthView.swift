import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var authManager: AuthManager
    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var showingSupabaseSettings = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("モード", selection: $mode) {
                        ForEach(AuthMode.allCases) { authMode in
                            Text(authMode.title).tag(authMode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("アカウント") {
                    TextField("メールアドレス", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("パスワード", text: $password)
                        .textContentType(mode == .signUp ? .newPassword : .password)

                    if mode == .signUp {
                        SecureField("パスワード確認", text: $passwordConfirmation)
                            .textContentType(.newPassword)

                        Text("パスワードは8文字以上20文字以下。英大文字・英小文字・数字・特殊文字をすべて含めてください。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Supabase設定") {
                    DisclosureGroup("接続情報", isExpanded: $showingSupabaseSettings) {
                        TextField("Project URL 例: https://xxxx.supabase.co", text: $settings.supabaseURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        TextField("Anon public key", text: $settings.supabaseAnonKey, axis: .vertical)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .lineLimit(2...5)
                    }

                    Text("本番ではSupabaseプロジェクトのURLとAnon Keyを設定します。Anon Keyは公開クライアントキーですが、サービスロールキーは絶対に入れないでください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage = authManager.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if authManager.isWorking {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(mode.buttonTitle)
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(authManager.isWorking)
                } footer: {
                    Text("ログイン後、App StoreのMonthly/YearlyサブスクリプションをSupabaseアカウントに紐づけます。")
                }
            }
            .navigationTitle("ログイン")
        }
    }

    private func submit() async {
        switch mode {
        case .signIn:
            await authManager.signIn(
                email: email,
                password: password,
                supabaseURL: settings.supabaseURL,
                anonKey: settings.supabaseAnonKey
            )
        case .signUp:
            await authManager.signUp(
                email: email,
                password: password,
                passwordConfirmation: passwordConfirmation,
                supabaseURL: settings.supabaseURL,
                anonKey: settings.supabaseAnonKey
            )
        }
    }
}

private enum AuthMode: String, CaseIterable, Identifiable {
    case signIn
    case signUp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .signIn:
            "ログイン"
        case .signUp:
            "新規登録"
        }
    }

    var buttonTitle: String {
        switch self {
        case .signIn:
            "ログイン"
        case .signUp:
            "新規登録"
        }
    }
}
