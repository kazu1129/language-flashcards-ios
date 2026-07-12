import SwiftData
import SwiftUI
import UIKit

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
    @State private var sessionCardCountInput = ""
    @FocusState private var isSessionCountFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "settings.account.section")) {
                    LabeledContent(
                        String(localized: "settings.email"),
                        value: authManager.email.isEmpty ? String(localized: "settings.loggedOut") : authManager.email
                    )
                    LabeledContent(
                        String(localized: "settings.userID"),
                        value: authManager.accountUUID?.uuidString ?? String(localized: "settings.unverified")
                    )

                    Text("settings.account.subscriptionLinkDescription")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section(String(localized: "settings.subscription.section")) {
                    if hasActivePremiumSubscription {
                        Label(String(localized: "settings.premiumActive"), systemImage: "crown.fill")
                            .foregroundStyle(.yellow)
                    } else {
                        Button {
                            showingPremiumUpgrade = true
                        } label: {
                            Label(String(localized: "common.viewTrial"), systemImage: "crown")
                        }
                    }

                    if subscriptionStore.hasActiveMonthly && !subscriptionStore.hasActiveYearly {
                        Button {
                            Task {
                                await subscriptionStore.changeMonthlyToYearly(
                                    accountToken: authManager.accountUUID,
                                    settings: settings
                                )
                            }
                        } label: {
                            Label(String(localized: "settings.subscription.changeToYearly"), systemImage: "arrow.up.circle")
                        }
                        .disabled(subscriptionStore.isLoading || subscriptionStore.isPurchasing)
                    }

                    Button {
                        Task {
                            await subscriptionStore.manageSubscriptions(in: activeWindowScene, settings: settings)
                        }
                    } label: {
                        Label(String(localized: "settings.subscription.manage"), systemImage: "person.crop.circle.badge.checkmark")
                    }
                    .disabled(subscriptionStore.isManagingSubscriptions)

                    Text("settings.subscription.manageHint")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        Task { await subscriptionStore.restorePurchases(settings: settings) }
                    } label: {
                        Label(String(localized: "premium.restorePurchases"), systemImage: "arrow.clockwise")
                    }

                    if let message = subscriptionStore.message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(subscriptionStore.isMessageError ? .red : .secondary)
                    }

                    Text(productIDsNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section(String(localized: "settings.flashcards.section")) {
                    Picker(String(localized: "settings.firstSide"), selection: $settings.displaySide) {
                        ForEach(CardSidePreference.allCases) { side in
                            Text(side.title).tag(side)
                        }
                    }

                    Toggle(String(localized: "settings.muteAudio"), isOn: $settings.muteAudio)

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("settings.sessionCount.title")
                            Text("settings.sessionCount.rangeHint")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        TextField(
                            String(settings.sessionCardCount),
                            text: $sessionCardCountInput
                        )
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .focused($isSessionCountFocused)
                        .frame(width: 58)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel(Text("settings.sessionCount.title"))
                        .onSubmit {
                            confirmSessionCardCountInput()
                        }

                        Button(String(localized: "common.confirm")) {
                            confirmSessionCardCountInput()
                            isSessionCountFocused = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Stepper(String(localized: "settings.sessionCount.title"), value: sessionCardCountBinding, in: 1...100)
                            .labelsHidden()
                    }
                }

                Section(String(localized: "settings.character.section")) {
                    Toggle(String(localized: "settings.showCharacterOnHome"), isOn: $settings.showCharacterOnHome)

                    HStack(spacing: 12) {
                        CharacterAvatarView(stage: currentStage, size: 72)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentStage.localizedTitle)
                                .font(.headline)
                            Text(String.localizedStringWithFormat(
                                String(localized: "character.streak"),
                                Int64(streakDays)
                            ))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle(String(localized: "settings.growthNotifications"), isOn: $settings.growthNotificationsEnabled)
                }

                Section(String(localized: "settings.notifications.section")) {
                    Toggle(String(localized: "settings.studyReminder"), isOn: $settings.studyReminderEnabled)
                    Toggle(String(localized: "settings.dailySummary"), isOn: $settings.dailySummaryEnabled)
                    Toggle(String(localized: "settings.anniversaryNotifications"), isOn: $settings.anniversaryNotificationsEnabled)

                    Toggle(String(localized: "settings.birthdayToggle"), isOn: $settings.hasBirthday)
                    if settings.hasBirthday {
                        DatePicker(String(localized: "settings.birthday"), selection: $settings.birthday, displayedComponents: [.date])
                    }
                }

                Section(String(localized: "settings.display.section")) {
                    Picker(String(localized: "settings.color"), selection: $settings.appearance) {
                        ForEach(AppearancePreference.allCases) { appearance in
                            Text(appearance.title).tag(appearance)
                        }
                    }

                    VStack(alignment: .leading) {
                        Text("settings.fontSize")
                        Slider(value: $settings.fontScale, in: 0.8...1.6, step: 0.05)
                        Text("settings.preview")
                            .font(.system(size: 18 * settings.fontScale, weight: .semibold))
                    }
                }

                Section(String(localized: "settings.support.section")) {
                    NavigationLink {
                        AppInfoDocumentView(document: .manual)
                    } label: {
                        Label(String(localized: "settings.manual"), systemImage: "book")
                    }

                    NavigationLink {
                        AppInfoDocumentView(document: .privacyPolicy)
                    } label: {
                        Label(String(localized: "settings.privacyPolicy"), systemImage: "hand.raised")
                    }

                    NavigationLink {
                        AppInfoDocumentView(document: .termsOfUse)
                    } label: {
                        Label(String(localized: "settings.termsOfUse"), systemImage: "doc.text")
                    }
                }

                Section(String(localized: "settings.accountData.section")) {
                    Button {
                        showingLogoutConfirmation = true
                    } label: {
                        Label(String(localized: "settings.logout"), systemImage: "rectangle.portrait.and.arrow.right")
                    }

                    Button(role: .destructive) {
                        showingDeleteAllConfirmation = true
                    } label: {
                        Label(String(localized: "settings.deleteAll"), systemImage: "trash")
                    }
                }
            }
            .navigationTitle(String(localized: "settings.navigationTitle"))
            .toolbar {
                if isSessionCountFocused {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button(String(localized: "common.confirm")) {
                            confirmSessionCardCountInput()
                            isSessionCountFocused = false
                        }
                    }
                }
            }
            .onAppear {
                syncSessionCardCountInput()
            }
            .task {
                await subscriptionStore.loadProducts()
                await subscriptionStore.syncPurchasedSubscriptions(settings: settings)
            }
            .onChange(of: sessionCardCountInput) {
                let sanitizedInput = sanitizedSessionCountInput(sessionCardCountInput)
                if sessionCardCountInput != sanitizedInput {
                    sessionCardCountInput = sanitizedInput
                }
            }
            .onChange(of: isSessionCountFocused) {
                if isSessionCountFocused {
                    syncSessionCardCountInput()
                } else {
                    confirmSessionCardCountInput()
                }
            }
            .onChange(of: settings.sessionCardCount) {
                syncSessionCardCountInput()
            }
            .alert(String(localized: "settings.logout.alert.title"), isPresented: $showingLogoutConfirmation) {
                Button(String(localized: "settings.logout"), role: .destructive) {
                    Task { await authManager.signOut(settings: settings) }
                }
                Button(String(localized: "cardEditor.cancel"), role: .cancel) {}
            } message: {
                Text("settings.logout.alert.message")
            }
            .alert(String(localized: "settings.deleteAll.alert.title"), isPresented: $showingDeleteAllConfirmation) {
                Button(String(localized: "settings.deleteAll.confirm"), role: .destructive) {
                    deleteAllRecords()
                }
                Button(String(localized: "cardEditor.cancel"), role: .cancel) {}
            } message: {
                Text("settings.deleteAll.alert.message")
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

    private var hasActivePremiumSubscription: Bool {
        settings.isPremium || subscriptionStore.hasActivePremium
    }

    private var sessionCardCountBinding: Binding<Int> {
        Binding(
            get: { settings.sessionCardCount },
            set: {
                settings.sessionCardCount = AppSettings.clampedSessionCardCount($0)
                syncSessionCardCountInput()
            }
        )
    }

    private var productIDsNote: String {
        String.localizedStringWithFormat(
            String(localized: "settings.productIDs.note"),
            SubscriptionStore.monthlyProductID,
            SubscriptionStore.yearlyProductID
        )
    }

    private var activeWindowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
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

    private func confirmSessionCardCountInput() {
        guard let inputValue = Int(sessionCardCountInput) else {
            syncSessionCardCountInput()
            return
        }

        settings.sessionCardCount = AppSettings.clampedSessionCardCount(inputValue)
        syncSessionCardCountInput()
    }

    private func syncSessionCardCountInput() {
        sessionCardCountInput = String(settings.sessionCardCount)
    }

    private func sanitizedSessionCountInput(_ input: String) -> String {
        let digits = input.compactMap(\.wholeNumberValue).map(String.init).joined()
        return String(digits.prefix(3))
    }
}
