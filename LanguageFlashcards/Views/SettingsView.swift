import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @Query(sort: \FlashcardDeck.updatedAt, order: .forward) private var decks: [FlashcardDeck]
    @Query(sort: \StudyReview.reviewedAt, order: .forward) private var reviews: [StudyReview]
    @State private var showingPremiumUpgrade = false
    @State private var showingLogoutConfirmation = false
    @State private var showingDeleteAllConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("アカウント") {
                    LabeledContent("メールアドレス", value: authManager.email.isEmpty ? "未ログイン" : authManager.email)
                    LabeledContent("ユーザーID", value: authManager.accountUUID?.uuidString ?? "未確認")

                    Text("サブスクリプション購入時、このSupabaseユーザーIDをAppleの購入情報へ紐づけます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("サブスクリプション") {
                    if settings.isPremium {
                        Label("プレミアム機能が有効です", systemImage: "crown.fill")
                            .foregroundStyle(.yellow)
                    } else {
                        Button {
                            showingPremiumUpgrade = true
                        } label: {
                            Label("1週間無料トライアルを見る", systemImage: "crown")
                        }
                    }

                    Button {
                        Task { await subscriptionStore.restorePurchases(settings: settings) }
                    } label: {
                        Label("購入状態を復元", systemImage: "arrow.clockwise")
                    }

                    if let message = subscriptionStore.message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(message.contains("失敗") ? .red : .secondary)
                    }

                    Text("商品ID: \(SubscriptionStore.monthlyProductID) / \(SubscriptionStore.yearlyProductID)。1週間無料トライアルはApp Store Connectで両方の商品に設定します。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Supabase接続") {
                    TextField("Project URL", text: $settings.supabaseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Anon public key", text: $settings.supabaseAnonKey, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(2...5)

                    Text("サービスロールキーは入れないでください。アプリにはSupabaseのAnon public keyだけを設定します。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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

                Section("キャラクター") {
                    Toggle("ホームに表示", isOn: $settings.showCharacterOnHome)

                    HStack(spacing: 12) {
                        CharacterAvatarView(stage: currentStage, size: 72)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentStage.title)
                                .font(.headline)
                            Text("継続 \(streakDays)日")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle("成長したら通知", isOn: $settings.growthNotificationsEnabled)
                }

                Section("通知") {
                    Toggle("20時の学習リマインド", isOn: $settings.studyReminderEnabled)
                    Toggle("22時の今日の成果", isOn: $settings.dailySummaryEnabled)
                    Toggle("記念日のメッセージ", isOn: $settings.anniversaryNotificationsEnabled)

                    Toggle("誕生日を登録", isOn: $settings.hasBirthday)
                    if settings.hasBirthday {
                        DatePicker("誕生日", selection: $settings.birthday, displayedComponents: [.date])
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

                Section("サポートと規約") {
                    NavigationLink {
                        AppInfoDocumentView(document: .manual)
                    } label: {
                        Label("取説", systemImage: "book")
                    }

                    NavigationLink {
                        AppInfoDocumentView(document: .privacyPolicy)
                    } label: {
                        Label("プライバシーポリシー", systemImage: "hand.raised")
                    }

                    NavigationLink {
                        AppInfoDocumentView(document: .termsOfUse)
                    } label: {
                        Label("利用規約", systemImage: "doc.text")
                    }
                }

                Section("アカウントとデータ") {
                    Button {
                        showingLogoutConfirmation = true
                    } label: {
                        Label("ログアウト", systemImage: "rectangle.portrait.and.arrow.right")
                    }

                    Button(role: .destructive) {
                        showingDeleteAllConfirmation = true
                    } label: {
                        Label("全ての記録を削除", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("設定")
            .alert("ログアウトしますか？", isPresented: $showingLogoutConfirmation) {
                Button("ログアウト", role: .destructive) {
                    Task { await authManager.signOut(settings: settings) }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("Supabaseからログアウトし、端末内のログイン情報を削除します。カードと学習記録は削除されません。")
            }
            .alert("全ての記録を削除しますか？", isPresented: $showingDeleteAllConfirmation) {
                Button("削除", role: .destructive) {
                    deleteAllRecords()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("全てのフラッシュカードセット、カード、学習履歴を削除します。この操作は元に戻せません。")
            }
            .sheet(isPresented: $showingPremiumUpgrade) {
                PremiumUpgradeView()
            }
        }
    }

    private var streakDays: Int {
        LearningProgress.consecutiveStudyDays(from: reviews)
    }

    private var currentStage: CharacterGrowthStage {
        LearningProgress.currentStage(for: streakDays)
    }

    private func deleteAllRecords() {
        for deck in decks {
            modelContext.delete(deck)
        }
        for review in reviews {
            modelContext.delete(review)
        }
        try? modelContext.save()
    }
}
