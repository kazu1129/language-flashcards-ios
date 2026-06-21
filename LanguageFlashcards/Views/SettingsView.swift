import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        NavigationStack {
            Form {
                Section("フラッシュカード") {
                    Picker("最初に見せる面", selection: $settings.displaySide) {
                        ForEach(CardSidePreference.allCases) { side in
                            Text(side.title).tag(side)
                        }
                    }

                    Toggle("発音を無音化", isOn: $settings.muteAudio)

                    Stepper(value: $settings.sessionCardCount, in: 1...100) {
                        Text("1セッション \(settings.sessionCardCount)枚")
                    }
                }

                Section("表示") {
                    Picker("カラー", selection: $settings.appearance) {
                        ForEach(AppearancePreference.allCases) { appearance in
                            Text(appearance.title).tag(appearance)
                        }
                    }

                    VStack(alignment: .leading) {
                        Text("文字サイズ")
                        Slider(value: $settings.fontScale, in: 0.8...1.6, step: 0.05)
                        Text("プレビュー")
                            .font(.system(size: 18 * settings.fontScale, weight: .semibold))
                    }
                }

                Section("Gemini") {
                    SecureField("APIキー", text: $settings.geminiAPIKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("モデル", text: $settings.geminiModel)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Text("APIキーは端末のKeychainに保存され、GitHubには保存されません。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("設定")
        }
    }
}

