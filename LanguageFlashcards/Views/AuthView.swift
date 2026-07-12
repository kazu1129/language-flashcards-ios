import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(String(localized: "auth.mode"), selection: $mode) {
                        ForEach(AuthMode.allCases) { authMode in
                            Text(authMode.title).tag(authMode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(String(localized: "auth.account.section")) {
                    TextField(String(localized: "auth.email.placeholder"), text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField(String(localized: "auth.password.placeholder"), text: $password)
                        .textContentType(mode == .signUp ? .newPassword : .password)

                    if mode == .signUp {
                        SecureField(String(localized: "auth.passwordConfirmation.placeholder"), text: $passwordConfirmation)
                            .textContentType(.newPassword)

                        Text("auth.password.rules")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage = authManager.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                if let statusMessage = authManager.statusMessage {
                    Section {
                        Text(statusMessage)
                            .foregroundStyle(.secondary)
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

                    if mode == .signIn {
                        Button {
                            Task { await requestPasswordReset() }
                        } label: {
                            if authManager.isPasswordResetWorking {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("auth.forgotPassword")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(authManager.isWorking || authManager.isPasswordResetWorking)
                    }
                } footer: {
                    Text("auth.subscription.footer")
                }
            }
            .navigationTitle(String(localized: "auth.navigationTitle"))
        }
    }

    private func submit() async {
        switch mode {
        case .signIn:
            await authManager.signIn(
                email: email,
                password: password
            )
        case .signUp:
            await authManager.signUp(
                email: email,
                password: password,
                passwordConfirmation: passwordConfirmation
            )
        }
    }

    private func requestPasswordReset() async {
        await authManager.requestPasswordReset(email: email)
    }
}

private enum AuthMode: String, CaseIterable, Identifiable {
    case signIn
    case signUp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .signIn:
            String(localized: "auth.signIn")
        case .signUp:
            String(localized: "auth.signUp")
        }
    }

    var buttonTitle: String {
        switch self {
        case .signIn:
            String(localized: "auth.signIn")
        case .signUp:
            String(localized: "auth.signUp")
        }
    }
}
