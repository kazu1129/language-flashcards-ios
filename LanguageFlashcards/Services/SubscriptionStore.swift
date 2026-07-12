import Foundation
import StoreKit

@MainActor
final class SubscriptionStore: ObservableObject {
    static let monthlyProductID = "language_flashcards_premium_monthly"
    static let yearlyProductID = "language_flashcards_premium_yearly"
    static let productIDs = [monthlyProductID, yearlyProductID]

    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var isPurchasing = false
    @Published var message: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            await self?.observeTransactionUpdates()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var hasActivePremium: Bool {
        !purchasedProductIDs.isDisjoint(with: Self.productIDs)
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let loadedProducts = try await Product.products(for: Self.productIDs)
            products = loadedProducts.sorted { productOrder($0.id) < productOrder($1.id) }
            if products.isEmpty {
                message = "StoreKit商品がまだ見つかりません。App Store ConnectでMonthly/Yearly商品を作成してください。"
            }
        } catch {
            message = "StoreKit商品の読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    func purchase(_ product: Product, accountToken: UUID?, settings: AppSettings) async {
        isPurchasing = true
        message = nil
        defer { isPurchasing = false }

        do {
            let result: Product.PurchaseResult
            if let accountToken {
                result = try await product.purchase(options: [.appAccountToken(accountToken)])
            } else {
                result = try await product.purchase()
            }

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                purchasedProductIDs.insert(transaction.productID)
                settings.subscriptionTier = .premium
                await transaction.finish()
                await syncPurchasedSubscriptions(settings: settings)
                message = "プレミアムが有効になりました。"
            case .pending:
                message = "購入は承認待ちです。完了後に自動で反映されます。"
            case .userCancelled:
                message = "購入はキャンセルされました。"
            @unknown default:
                message = "購入結果を確認できませんでした。時間をおいて再度お試しください。"
            }
        } catch {
            message = "購入に失敗しました: \(error.localizedDescription)"
        }
    }

    func restorePurchases(settings: AppSettings) async {
        message = nil
        do {
            try await AppStore.sync()
            await syncPurchasedSubscriptions(settings: settings)
            message = hasActivePremium ? "購入状態を復元しました。" : "有効なプレミアム購入は見つかりませんでした。"
        } catch {
            message = "購入状態の復元に失敗しました: \(error.localizedDescription)"
        }
    }

    func syncPurchasedSubscriptions(settings: AppSettings) async {
        var activeProductIDs: Set<String> = []
        for await entitlement in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(entitlement) else { continue }
            guard Self.productIDs.contains(transaction.productID), transaction.revocationDate == nil else { continue }
            activeProductIDs.insert(transaction.productID)
        }
        purchasedProductIDs = activeProductIDs
        settings.subscriptionTier = activeProductIDs.isEmpty ? .free : .premium
    }

    func displayName(for product: Product) -> String {
        switch product.id {
        case Self.monthlyProductID:
            "Monthly"
        case Self.yearlyProductID:
            "Yearly"
        default:
            product.displayName
        }
    }

    func periodText(for product: Product) -> String {
        switch product.id {
        case Self.monthlyProductID:
            "月額"
        case Self.yearlyProductID:
            "年額"
        default:
            "サブスクリプション"
        }
    }

    // ── 無料トライアル期間の導出（App Store 審査 2.1(b) 対策）──────────
    // トライアルの有無・期間は固定値で持たず、実商品の introductoryOffer から
    // 導出する（唯一の真実）。App Store Connect の設定を変えれば表示も追従し、
    // トライアルが無い商品には「無料トライアル」を宣伝しない。
    func trialLabel(for product: Product) -> String? {
        guard let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let value = offer.period.value
        switch offer.period.unit {
        case .day:   return "\(value)日間"
        case .week:  return "\(value)週間"
        case .month: return "\(value)か月"
        case .year:  return "\(value)年"
        @unknown default: return nil
        }
    }

    // 読み込み済み商品（Monthly→Yearly順）から最初に見つかったトライアル期間ラベル。
    var trialLabelAny: String? {
        products.compactMap { trialLabel(for: $0) }.first
    }

    var hasAnyTrial: Bool { trialLabelAny != nil }

    private func observeTransactionUpdates() async {
        for await update in Transaction.updates {
            guard let transaction = try? checkVerified(update) else { continue }
            purchasedProductIDs.insert(transaction.productID)
            await transaction.finish()
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            value
        case .unverified:
            throw SubscriptionStoreError.failedVerification
        }
    }

    private func productOrder(_ productID: String) -> Int {
        switch productID {
        case Self.monthlyProductID:
            0
        case Self.yearlyProductID:
            1
        default:
            99
        }
    }
}

enum SubscriptionStoreError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            "購入情報の検証に失敗しました。"
        }
    }
}
