import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \FlashcardDeck.updatedAt, order: .forward) private var decks: [FlashcardDeck]
    @Query(sort: \StudyReview.reviewedAt, order: .forward) private var reviews: [StudyReview]
    @State private var showingPremiumUpgrade = false
    @State private var showingLogoutConfirmation = false
    @State private var showingDeleteAllConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("サブスクリプション") {
                    Picker("プラン", selection: $settings.subscriptionTier) {
                        ForEach(SubscriptionTier.allCases) { tier in
                            Text(tier.title).tag(tier)
                        }
                    }

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

                    Text("この切替は開発用です。本番公開時はAppleの1週間無料トライアル付きサブスクリプション購入状態と連携します。")
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
                    settings.resetForLogout()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("現在はアプリ内アカウント機能がないため、プレミアム状態を無料に戻し、初回説明を再表示します。カードと学習記録は削除されません。")
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
