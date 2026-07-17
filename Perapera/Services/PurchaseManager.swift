import Foundation
import Combine
import StoreKit

enum SubscriptionTier: String, Codable {
    case none
    case basic
    case pro

    var hasAccess: Bool {
        self != .none
    }
}

struct StoreProductInfo: Identifiable, Equatable {
    let id: String
    let displayName: String
    let displayPrice: String
    let subscriptionPeriodText: String?
}

final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    static let proMonthlyProductID = "cc.perapera.pro.monthly"
    static let proYearlyProductID = "cc.perapera.pro.yearly"
    static let basicMonthlyProductID = "cc.perapera.base.monthly"

    let productOrder = [
        PurchaseManager.proMonthlyProductID,
        PurchaseManager.proYearlyProductID,
        PurchaseManager.basicMonthlyProductID
    ]

    @Published private(set) var productsByID: [String: StoreProductInfo] = [:]
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var currentTier: SubscriptionTier = .none
    @Published private(set) var currentProductID: String?
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isProcessingPurchase = false
    @Published var lastMessage: String?
    @Published var lastError: String?

    private let cachedProductIDsKey = "purchase.cached.product_ids"
    private let cachedCurrentProductKey = "purchase.cached.current_product_id"
    private let cachedTierKey = "purchase.cached.tier"

    private var transactionUpdatesTask: Task<Void, Never>?

    private init() {
        loadCachedState()
        startTransactionListener()
        refreshEntitlements()
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    var hasActivePlan: Bool {
        currentTier.hasAccess
    }

    var currentPlanDisplayName: String? {
        guard let currentProductID = currentProductID else { return nil }
        return productsByID[currentProductID]?.displayName ?? fallbackPlanName(for: currentProductID)
    }

    func loadProducts() {
        guard #available(iOS 15.0, *) else {
            updateError("In-App Purchase requires iOS 15 or later.")
            return
        }

        guard !isLoadingProducts else { return }
        updateOnMain {
            self.isLoadingProducts = true
            self.lastError = nil
        }

        Task { [weak self] in
            await self?.loadProductsAvailable()
        }
    }

    func purchase(productID: String) {
        guard #available(iOS 15.0, *) else {
            updateError("In-App Purchase requires iOS 15 or later.")
            return
        }

        updateOnMain {
            self.isProcessingPurchase = true
            self.lastError = nil
            self.lastMessage = nil
        }

        Task { [weak self] in
            await self?.purchaseAvailable(productID: productID)
        }
    }

    func restorePurchases() {
        guard #available(iOS 15.0, *) else {
            updateError("Restore Purchases requires iOS 15 or later.")
            return
        }

        updateOnMain {
            self.isProcessingPurchase = true
            self.lastError = nil
            self.lastMessage = nil
        }

        Task { [weak self] in
            await self?.restorePurchasesAvailable()
        }
    }

    func refreshEntitlements() {
        guard #available(iOS 15.0, *) else { return }
        Task { [weak self] in
            await self?.refreshEntitlementsAvailable()
        }
    }

    func clearMessages() {
        updateOnMain {
            self.lastMessage = nil
            self.lastError = nil
        }
    }

    @available(iOS 15.0, *)
    private func loadProductsAvailable() async {
        do {
            let storeProducts = try await Product.products(for: productOrder)
            let mapped = Dictionary(uniqueKeysWithValues: storeProducts.map { product in
                (product.id, StoreProductInfo(
                    id: product.id,
                    displayName: product.displayName,
                    displayPrice: product.displayPrice,
                    subscriptionPeriodText: self.subscriptionPeriodText(for: product)
                ))
            })

            updateOnMain {
                self.productsByID = mapped
                self.isLoadingProducts = false
            }
        } catch {
            updateOnMain {
                self.isLoadingProducts = false
            }
            updateError(error.localizedDescription)
        }
    }

    @available(iOS 15.0, *)
    private func purchaseAvailable(productID: String) async {
        do {
            guard let product = try await Product.products(for: [productID]).first else {
                throw NSError(domain: "PurchaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Product not found in App Store Connect."])
            }

            let result = try await product.purchase()
            switch result {
            case .success(let verificationResult):
                let transaction = try checkVerified(verificationResult)
                await refreshEntitlementsAvailable()
                await transaction.finish()
                updateSuccess("Purchase successful.")

            case .userCancelled:
                updateOnMain {
                    self.isProcessingPurchase = false
                    self.lastMessage = "Purchase cancelled."
                }

            case .pending:
                updateOnMain {
                    self.isProcessingPurchase = false
                    self.lastMessage = "Purchase is pending approval."
                }

            @unknown default:
                updateOnMain {
                    self.isProcessingPurchase = false
                    self.lastMessage = "Purchase status updated."
                }
            }
        } catch {
            updateOnMain {
                self.isProcessingPurchase = false
            }
            updateError(error.localizedDescription)
        }
    }

    @available(iOS 15.0, *)
    private func restorePurchasesAvailable() async {
        do {
            try await AppStore.sync()
            await refreshEntitlementsAvailable()
            updateSuccess("Purchases restored.")
        } catch {
            updateOnMain {
                self.isProcessingPurchase = false
            }
            updateError(error.localizedDescription)
        }
    }

    @available(iOS 15.0, *)
    private func refreshEntitlementsAvailable() async {
        var activeProductIDs = Set<String>()

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            guard transaction.revocationDate == nil else { continue }
            if let expirationDate = transaction.expirationDate, expirationDate < Date() {
                continue
            }
            activeProductIDs.insert(transaction.productID)
        }

        updateOnMain {
            self.applyEntitlements(activeProductIDs)
            self.isProcessingPurchase = false
        }
    }

    private func applyEntitlements(_ productIDs: Set<String>) {
        purchasedProductIDs = productIDs

        if productIDs.contains(Self.proYearlyProductID) {
            currentTier = .pro
            currentProductID = Self.proYearlyProductID
        } else if productIDs.contains(Self.proMonthlyProductID) {
            currentTier = .pro
            currentProductID = Self.proMonthlyProductID
        } else if productIDs.contains(Self.basicMonthlyProductID) {
            currentTier = .basic
            currentProductID = Self.basicMonthlyProductID
        } else {
            currentTier = .none
            currentProductID = nil
        }

        persistState()
    }

    @available(iOS 15.0, *)
    private func startTransactionListenerAvailable() {
        transactionUpdatesTask = Task { [weak self] in
            guard let self = self else { return }
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.refreshEntitlementsAvailable()
                    await transaction.finish()
                } catch {
                    self.updateError(error.localizedDescription)
                }
            }
        }
    }

    private func startTransactionListener() {
        guard #available(iOS 15.0, *) else { return }
        startTransactionListenerAvailable()
    }

    @available(iOS 15.0, *)
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let signedType):
            return signedType
        case .unverified:
            throw NSError(domain: "PurchaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Transaction verification failed."])
        }
    }

    @available(iOS 15.0, *)
    private func subscriptionPeriodText(for product: Product) -> String? {
        guard let period = product.subscription?.subscriptionPeriod else { return nil }

        switch period.unit {
        case .day:
            return period.value == 1 ? "Daily" : "Every \(period.value) days"
        case .week:
            return period.value == 1 ? "Weekly" : "Every \(period.value) weeks"
        case .month:
            return period.value == 1 ? "Monthly" : "Every \(period.value) months"
        case .year:
            return period.value == 1 ? "Yearly" : "Every \(period.value) years"
        @unknown default:
            return nil
        }
    }

    private func fallbackPlanName(for productID: String) -> String {
        switch productID {
        case Self.proMonthlyProductID:
            return "Pro Monthly"
        case Self.proYearlyProductID:
            return "Pro Yearly"
        case Self.basicMonthlyProductID:
            return "Basic Monthly"
        default:
            return productID
        }
    }

    private func loadCachedState() {
        if let cachedProductIDs = UserDefaults.standard.array(forKey: cachedProductIDsKey) as? [String] {
            purchasedProductIDs = Set(cachedProductIDs)
        }

        currentProductID = UserDefaults.standard.string(forKey: cachedCurrentProductKey)

        if let rawTier = UserDefaults.standard.string(forKey: cachedTierKey),
           let tier = SubscriptionTier(rawValue: rawTier) {
            currentTier = tier
        }
    }

    private func persistState() {
        UserDefaults.standard.set(Array(purchasedProductIDs), forKey: cachedProductIDsKey)
        UserDefaults.standard.set(currentProductID, forKey: cachedCurrentProductKey)
        UserDefaults.standard.set(currentTier.rawValue, forKey: cachedTierKey)
    }

    private func updateSuccess(_ message: String) {
        updateOnMain {
            self.isProcessingPurchase = false
            self.lastError = nil
            self.lastMessage = message
        }
    }

    private func updateError(_ message: String) {
        updateOnMain {
            self.lastError = message
            self.lastMessage = nil
        }
    }

    private func updateOnMain(_ updates: @escaping () -> Void) {
        if Thread.isMainThread {
            updates()
        } else {
            DispatchQueue.main.async {
                updates()
            }
        }
    }
}
