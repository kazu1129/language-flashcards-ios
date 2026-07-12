import StoreKit
import SwiftUI

struct PremiumUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var subscriptionStore: SubscriptionStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("home.premiumTrial.title")
                            .font(.title.bold())
                        Text("premium.hero.description")
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 12) {
                        PremiumBenefitRow(icon: "rectangle.stack.badge.plus", title: String(localized: "premium.benefit.cards.title"), detail: String(localized: "premium.benefit.cards.detail"))
                        PremiumBenefitRow(icon: "camera.viewfinder", title: String(localized: "premium.benefit.ocr.title"), detail: String(localized: "premium.benefit.ocr.detail"))
                        PremiumBenefitRow(icon: "chart.line.uptrend.xyaxis", title: String(localized: "premium.benefit.analytics.title"), detail: String(localized: "premium.benefit.analytics.detail"))
                        PremiumBenefitRow(icon: "square.and.arrow.up", title: String(localized: "premium.benefit.pdf.title"), detail: String(localized: "premium.benefit.pdf.detail"))
                        PremiumBenefitRow(icon: "leaf.fill", title: String(localized: "premium.benefit.notifications.title"), detail: String(localized: "premium.benefit.notifications.detail"))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("premium.plan.section")
                            .font(.headline)

                        if subscriptionStore.isLoading {
                            ProgressView(String(localized: "premium.loadingProducts"))
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else if subscriptionStore.products.isEmpty {
                            ProductSetupNotice()
                        } else {
                            ForEach(subscriptionStore.products, id: \.id) { product in
                                ProductPurchaseRow(product: product) {
                                    Task {
                                        await subscriptionStore.purchase(
                                            product,
                                            accountToken: authManager.accountUUID,
                                            settings: settings
                                        )
                                        if settings.isPremium {
                                            dismiss()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Button {
                        Task {
                            await subscriptionStore.restorePurchases(settings: settings)
                        }
                    } label: {
                        Label(String(localized: "premium.restorePurchases"), systemImage: "arrow.clockwise")
                    }
                    .disabled(subscriptionStore.isPurchasing)

                    if let message = subscriptionStore.message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(subscriptionStore.isMessageError ? .red : .secondary)
                    }

                    Text("premium.note")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle(String(localized: "premium.navigationTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "premium.close")) { dismiss() }
                }
            }
        }
        .task {
            await subscriptionStore.loadProducts()
            await subscriptionStore.syncPurchasedSubscriptions(settings: settings)
        }
    }
}

struct PremiumHomeCard: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(String(localized: "home.premiumTrial.title"), systemImage: "crown.fill")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                }

                Text("home.premiumTrial.description")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct PremiumBenefitRow: View {
    var icon: String
    var title: String
    var detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ProductPurchaseRow: View {
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    let product: Product
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subscriptionStore.displayName(for: product))
                        .font(.headline)
                    Text(freeTrialText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.headline)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(subscriptionStore.isPurchasing)
    }

    private var freeTrialText: String {
        String.localizedStringWithFormat(
            String(localized: "premium.product.freeTrial"),
            subscriptionStore.periodText(for: product)
        )
    }
}

private struct ProductSetupNotice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(String(localized: "premium.setup.title"), systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text("premium.setup.detail")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(SubscriptionStore.monthlyProductID)
                .font(.caption.monospaced())
            Text(SubscriptionStore.yearlyProductID)
                .font(.caption.monospaced())
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
