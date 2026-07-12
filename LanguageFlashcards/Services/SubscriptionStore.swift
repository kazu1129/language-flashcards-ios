import Foundation
import StoreKit
import UIKit

@MainActor
final class SubscriptionStore: ObservableObject {
    static let monthlyProductID = "language_flashcards_premium_monthly"
    static let yearlyProductID = "language_flashcards_premium_yearly"
    static let productIDs = [monthlyProductID, yearlyProductID]

    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var isPurchasing = false
    @Published var isManagingSubscriptions = false
    @Published var message: String?
    @Published var isMessageError = false

    private var updatesTask: Task<Void, Never>?
    private weak var connectedSettings: AppSettings?
    private var entitlementRevision = 0

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

    var hasActiveMonthly: Bool {
        purchasedProductIDs.contains(Self.monthlyProductID)
    }

    var hasActiveYearly: Bool {
        purchasedProductIDs.contains(Self.yearlyProductID)
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let loadedProducts = try await Product.products(for: Self.productIDs)
            products = loadedProducts.sorted { productOrder($0.id) < productOrder($1.id) }
            if products.isEmpty {
                setMessage(String(localized: "subscription.message.productsMissing"))
            }
        } catch {
            setMessage(
                String.localizedStringWithFormat(String(localized: "subscription.message.loadFailed"), error.localizedDescription),
                isError: true
            )
        }
    }

    func purchase(_ product: Product, accountToken: UUID?, settings: AppSettings) async {
        connectedSettings = settings
        isPurchasing = true
        clearMessage()
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
                guard Self.productIDs.contains(transaction.productID),
                      isActive(transaction) else {
                    throw SubscriptionStoreError.failedVerification
                }

                applyPurchasedProductIDs([transaction.productID], settings: settings)
                await transaction.finish()
                setMessage(String(localized: "subscription.message.premiumActive"))
            case .pending:
                setMessage(String(localized: "subscription.message.pending"))
            case .userCancelled:
                setMessage(String(localized: "subscription.message.cancelled"))
            @unknown default:
                setMessage(String(localized: "subscription.message.unknownResult"), isError: true)
            }
        } catch {
            setMessage(
                String.localizedStringWithFormat(String(localized: "subscription.message.purchaseFailed"), error.localizedDescription),
                isError: true
            )
        }
    }

    func restorePurchases(settings: AppSettings) async {
        connectedSettings = settings
        clearMessage()
        do {
            try await AppStore.sync()
            await syncPurchasedSubscriptions(settings: settings)
            setMessage(hasActivePremium ? String(localized: "subscription.message.restoreSuccess") : String(localized: "subscription.message.restoreNoActive"))
        } catch {
            setMessage(
                String.localizedStringWithFormat(String(localized: "subscription.message.restoreFailed"), error.localizedDescription),
                isError: true
            )
        }
    }

    func changeMonthlyToYearly(accountToken: UUID?, settings: AppSettings) async {
        clearMessage()

        if products.isEmpty {
            await loadProducts()
        }

        guard hasActiveMonthly else {
            setMessage(String(localized: "subscription.message.monthlyRequired"), isError: true)
            return
        }

        guard !hasActiveYearly else {
            setMessage(String(localized: "subscription.message.yearlyAlreadyActive"))
            return
        }

        guard let yearlyProduct = products.first(where: { $0.id == Self.yearlyProductID }) else {
            setMessage(String(localized: "subscription.message.productsMissing"), isError: true)
            return
        }

        await purchase(yearlyProduct, accountToken: accountToken, settings: settings)
    }

    func manageSubscriptions(in scene: UIWindowScene?, settings: AppSettings) async {
        clearMessage()

        guard let scene else {
            setMessage(String(localized: "subscription.message.manageUnavailable"), isError: true)
            return
        }

        isManagingSubscriptions = true
        defer { isManagingSubscriptions = false }

        do {
            try await AppStore.showManageSubscriptions(in: scene)
            await syncPurchasedSubscriptions(settings: settings)
        } catch {
            setMessage(
                String.localizedStringWithFormat(String(localized: "subscription.message.manageFailed"), error.localizedDescription),
                isError: true
            )
        }
    }

    func syncPurchasedSubscriptions(settings: AppSettings) async {
        connectedSettings = settings
        let startingRevision = entitlementRevision
        var activeProductIDs: Set<String> = []
        var failedToVerifyKnownProduct = false

        for await entitlement in Transaction.currentEntitlements {
            switch entitlement {
            case .verified(let transaction):
                guard Self.productIDs.contains(transaction.productID),
                      isActive(transaction) else { continue }
                activeProductIDs.insert(transaction.productID)
            case .unverified(let transaction, _):
                if Self.productIDs.contains(transaction.productID) {
                    failedToVerifyKnownProduct = true
                }
            }
        }

        // A purchase or renewal may complete while this asynchronous scan is running.
        // In that case, don't let the older scan overwrite the newer entitlement.
        guard startingRevision == entitlementRevision else { return }

        if failedToVerifyKnownProduct && activeProductIDs.isEmpty {
            setMessage(
                SubscriptionStoreError.failedVerification.localizedDescription,
                isError: true
            )
            return
        }

        applyPurchasedProductIDs(activeProductIDs, settings: settings)
    }

    func displayName(for product: Product) -> String {
        switch product.id {
        case Self.monthlyProductID:
            String(localized: "subscription.product.monthlyName")
        case Self.yearlyProductID:
            String(localized: "subscription.product.yearlyName")
        default:
            product.displayName
        }
    }

    func periodText(for product: Product) -> String {
        switch product.id {
        case Self.monthlyProductID:
            String(localized: "subscription.period.monthly")
        case Self.yearlyProductID:
            String(localized: "subscription.period.yearly")
        default:
            String(localized: "subscription.period.subscription")
        }
    }

    private func setMessage(_ text: String, isError: Bool = false) {
        message = text
        isMessageError = isError
    }

    private func clearMessage() {
        message = nil
        isMessageError = false
    }

    private func observeTransactionUpdates() async {
        for await update in Transaction.updates {
            guard let transaction = try? checkVerified(update) else { continue }
            guard Self.productIDs.contains(transaction.productID) else { continue }

            var updatedProductIDs = purchasedProductIDs
            if isActive(transaction) {
                updatedProductIDs.insert(transaction.productID)
            } else {
                updatedProductIDs.remove(transaction.productID)
            }
            applyPurchasedProductIDs(updatedProductIDs, settings: connectedSettings)
            await transaction.finish()
        }
    }

    private func applyPurchasedProductIDs(
        _ productIDs: Set<String>,
        settings: AppSettings?
    ) {
        entitlementRevision &+= 1
        purchasedProductIDs = productIDs
        (settings ?? connectedSettings)?.subscriptionTier = productIDs.isEmpty ? .free : .premium
    }

    private func isActive(_ transaction: Transaction, now: Date = .now) -> Bool {
        guard transaction.revocationDate == nil else { return false }
        guard let expirationDate = transaction.expirationDate else { return true }
        return expirationDate > now
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
            String(localized: "subscriptionStore.failedVerification")
        }
    }
}
