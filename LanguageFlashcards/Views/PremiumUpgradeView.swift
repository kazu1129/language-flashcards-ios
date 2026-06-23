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
                        Text("1週間無料プレミアムトライアル")
                            .font(.title.bold())
                        Text("まずは7日間、カード数・OCR・分析・共有を広げて試せます。無料でも学習は続けられます。")
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 12) {
                        PremiumBenefitRow(icon: "rectangle.stack.badge.plus", title: "カードとセットを無制限に", detail: "無料は3セット・100カードまで。")
                        PremiumBenefitRow(icon: "camera.viewfinder", title: "写真OCRをもっと使える", detail: "無料は月10回まで。メモ写真からまとめて追加。")
                        PremiumBenefitRow(icon: "chart.line.uptrend.xyaxis", title: "詳しい成果分析", detail: "長期推移や弱点の把握をしやすく。")
                        PremiumBenefitRow(icon: "square.and.arrow.up", title: "PDF共有に対応", detail: "学習セットをきれいに出力。")
                        PremiumBenefitRow(icon: "leaf.fill", title: "継続を後押しする通知", detail: "成長通知や記念日メッセージで続けやすく。")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("プラン")
                            .font(.headline)

                        if subscriptionStore.isLoading {
                            ProgressView("商品を読み込み中...")
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
                        Label("購入状態を復元", systemImage: "arrow.clockwise")
                    }
                    .disabled(subscriptionStore.isPurchasing)

                    if let message = subscriptionStore.message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(message.contains("失敗") ? .red : .secondary)
                    }

                    Text("1週間無料トライアルはApp Store Connectの商品設定でMonthly/Yearlyの両方に設定します。アプリはStoreKit商品を読み込み、購入時にSupabaseユーザーIDをAppleの購入情報へ紐づけます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("プレミアム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
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
                    Label("1週間無料プレミアムトライアル", systemImage: "crown.fill")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                }

                Text("無制限カード、OCR、PDF共有、詳しい成果分析を7日間試せます。")
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
                    Text("\(subscriptionStore.periodText(for: product))・最初の1週間無料")
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
}

private struct ProductSetupNotice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("StoreKit商品が未設定です", systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text("App Store Connectで以下の自動更新サブスクリプションを作成し、それぞれに1週間無料トライアルを設定してください。")
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
