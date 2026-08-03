import Foundation
import Combine
import StoreKit
import Moya
import HandyJSON

enum SubscriptionTier: String, Codable {
    case none
    case basic
    case pro

    var hasAccess: Bool {
        self != .none
    }
}

enum TranslationBlockReason: Equatable {
    case noActivePlan
    case unknownEntitlementExpiration
    case insufficientRemainingTime(remaining: TimeInterval, required: TimeInterval)
}

struct StoreProductInfo: Identifiable, Equatable {
    let id: String
    let displayName: String
    let displayPrice: String
    let subscriptionPeriodText: String?
}

private struct IAPTransactionSyncPayload {
    let productID: String
    let transactionID: String
    let originalTransactionID: String
    let purchaseDate: String
    let expirationDate: String?
    let revocationDate: String?
    let appAccountToken: String?
    let ownershipType: String
    let environment: String
    let isUpgraded: Bool

    var parameters: [String: Any] {
        var parameters: [String: Any] = [
            "product_id": productID,
            "transaction_id": transactionID,
            "original_transaction_id": originalTransactionID,
            "purchase_date": purchaseDate,
            "ownership_type": ownershipType,
            "environment": environment,
            "is_upgraded": isUpgraded,
            "platform": "ios",
            "source": "storekit2",
            "bundle_id": Bundle.main.bundleIdentifier ?? ""
        ]

        if let expirationDate, !expirationDate.isEmpty {
            parameters["expiration_date"] = expirationDate
        }
        if let revocationDate, !revocationDate.isEmpty {
            parameters["revocation_date"] = revocationDate
        }
        if let appAccountToken, !appAccountToken.isEmpty {
            parameters["app_account_token"] = appAccountToken
        }

        return parameters
    }
}

private final class IAPProductModel: HandyJSON {
    var product_id: String = ""
    var id: String = ""
    var display_name: String = ""
    var name: String = ""
    var title: String = ""
    var price: String = ""
    var display_price: String = ""
    var localized_price: String = ""
    var subscription_period: String = ""
    var period: String = ""
    var tier: String = ""
    var active: Bool?
    var is_active: Bool?

    required init() {}

    var resolvedProductID: String {
        if !product_id.isEmpty { return product_id }
        return id
    }

    var resolvedDisplayName: String? {
        if !display_name.isEmpty { return display_name }
        if !name.isEmpty { return name }
        if !title.isEmpty { return title }
        return nil
    }

    var resolvedDisplayPrice: String? {
        if !display_price.isEmpty { return display_price }
        if !localized_price.isEmpty { return localized_price }
        if !price.isEmpty { return price }
        return nil
    }

    var resolvedSubscriptionPeriodText: String? {
        if !subscription_period.isEmpty { return subscription_period }
        if !period.isEmpty { return period }
        return nil
    }
}

private final class IAPStatusModel: HandyJSON, ResponseStatusable {
    var product_id: String = ""
    var current_product_id: String = ""
    var tier: String = ""
    var plan: String = ""
    var status: String = ""
    var entitlement: String = ""
    var active_product_ids: [String] = []
    var purchased_product_ids: [String] = []
    var product_ids: [String] = []
    var active: Bool?
    var is_active: Bool?
    var message: String = ""
    var detail: String = ""
    var expires_at: String = ""
    var expiration_date: String = ""
    var statusCode: Int?

    required init() {}

    var resolvedCurrentProductID: String? {
        if !current_product_id.isEmpty { return current_product_id }
        if !product_id.isEmpty { return product_id }
        return nil
    }

    var resolvedProductIDs: [String] {
        let ids = active_product_ids + purchased_product_ids + product_ids
        let filtered = ids.filter { !$0.isEmpty }
        if !filtered.isEmpty { return Array(Set(filtered)) }
        if let currentProductID = resolvedCurrentProductID, !currentProductID.isEmpty {
            return [currentProductID]
        }
        return []
    }

    var resolvedMessage: String? {
        if !message.isEmpty { return message }
        if !detail.isEmpty { return detail }
        return nil
    }
}

private final class IAPEntitlementModel: HandyJSON, ResponseStatusable {
    var product_id: String = ""
    var type: String = ""
    var entitled: Bool?
    var has_entitlement: Bool?
    var active: Bool?
    var is_active: Bool?
    var will_renew: Bool?
    var auto_renew_status: Bool?
    var is_in_grace_period: Bool?
    var is_in_billing_retry: Bool?
    var purchase_date: String = ""
    var purchaseDate: String = ""
    var expires_date: String = ""
    var expiration_date: String = ""
    var expires_at: String = ""
    var expireDate: String = ""
    var expiresDate: String = ""
    var grace_period_expires_date: String = ""
    var quantity_remaining: Int = 0
    var environment: String = ""
    var message: String = ""
    var detail: String = ""
    var statusCode: Int?

    required init() {}

    var resolvedProductID: String {
        product_id
    }

    var hasAccess: Bool {
        entitled == true || has_entitlement == true || active == true || is_active == true
    }

    var resolvedExpirationDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = ISO8601DateFormatter()
        let candidates = [
            expires_date,
            expiration_date,
            expires_at,
            expireDate,
            expiresDate
        ]
        for raw in candidates {
            if raw.isEmpty { continue }
            if let date = formatter.date(from: raw) ?? fallbackFormatter.date(from: raw) {
                return date
            }
        }
        return nil
    }

    func remainingTimeInterval(referenceDate: Date = Date()) -> TimeInterval? {
        guard hasAccess else { return nil }
        guard let expiration = resolvedExpirationDate else {
            return hasAccess ? .greatestFiniteMagnitude : nil
        }
        return expiration.timeIntervalSince(referenceDate)
    }

    var resolvedMessage: String? {
        if !message.isEmpty { return message }
        if !detail.isEmpty { return detail }
        return nil
    }
}

private final class IAPVerifyResponseModel: HandyJSON, ResponseStatusable {
    var message: String = ""
    var detail: String = ""
    var status: String = ""
    var product_id: String = ""
    var entitlement: IAPEntitlementModel?
    var statusCode: Int?

    required init() {}

    var resolvedMessage: String? {
        if !message.isEmpty { return message }
        if !detail.isEmpty { return detail }
        if !status.isEmpty { return status }
        return nil
    }
}

private final class IAPRestoreResponseModel: HandyJSON, ResponseStatusable {
    var message: String = ""
    var detail: String = ""
    var restored: Bool?
    var statusCode: Int?

    required init() {}

    var resolvedMessage: String? {
        if !message.isEmpty { return message }
        if !detail.isEmpty { return detail }
        return nil
    }
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
    @Published private var remoteEntitlementsByProductID: [String: IAPEntitlementModel] = [:]
    @Published var lastMessage: String?
    @Published var lastError: String?

    private let cachedProductIDsKey = "purchase.cached.product_ids"
    private let cachedCurrentProductKey = "purchase.cached.current_product_id"
    private let cachedTierKey = "purchase.cached.tier"

    private var transactionUpdatesTask: Swift.Task<Void, Never>?
    private lazy var iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

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

    fileprivate var currentEntitlement: IAPEntitlementModel? {
        guard let currentProductID = currentProductID else { return nil }
        return remoteEntitlementsByProductID[currentProductID]
    }

    fileprivate func entitlementRemainingSeconds(referenceDate: Date = Date()) -> TimeInterval? {
        guard let currentProductID = currentProductID,
              let entitlement = remoteEntitlementsByProductID[currentProductID] else {
            return nil
        }
        return entitlement.remainingTimeInterval(referenceDate: referenceDate)
    }

    func canTranslate(audioDurationSeconds: TimeInterval, referenceDate: Date = Date()) -> Bool {
        guard audioDurationSeconds > 0 else { return true }
        guard hasActivePlan else { return false }
        guard let remaining = entitlementRemainingSeconds(referenceDate: referenceDate) else {
            return false
        }
        return remaining + 1.0 >= audioDurationSeconds
    }

    func translationBlockedReason(audioDurationSeconds: TimeInterval,
                                  referenceDate: Date = Date()) -> TranslationBlockReason? {
        guard audioDurationSeconds > 0 else { return nil }
        if !hasActivePlan {
            return .noActivePlan
        }
        guard let remaining = entitlementRemainingSeconds(referenceDate: referenceDate) else {
            return .unknownEntitlementExpiration
        }
        if remaining + 1.0 < audioDurationSeconds {
            return .insufficientRemainingTime(remaining: remaining, required: audioDurationSeconds)
        }
        return nil
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

        Swift.Task { [weak self] in
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

        Swift.Task { [weak self] in
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

        Swift.Task { [weak self] in
            await self?.restorePurchasesAvailable()
        }
    }

    func refreshEntitlements() {
        guard #available(iOS 15.0, *) else { return }
        Swift.Task { [weak self] in
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
        let remoteProducts = await fetchRemoteProductsAvailable()

        if !remoteProducts.isEmpty {
            updateOnMain {
                self.productsByID = self.mergeRemoteProducts(remoteProducts, into: self.productsByID)
            }
        }

        do {
            let storeProducts = try await Product.products(for: productOrder)
            let storeMapped = Dictionary(uniqueKeysWithValues: storeProducts.map { product in
                (product.id, StoreProductInfo(
                    id: product.id,
                    displayName: product.displayName,
                    displayPrice: product.displayPrice,
                    subscriptionPeriodText: self.subscriptionPeriodText(for: product)
                ))
            })

            let mergedProducts = mergeRemoteProducts(remoteProducts, into: storeMapped)

            updateOnMain {
                self.productsByID = mergedProducts
                self.isLoadingProducts = false
            }
        } catch {
            updateOnMain {
                self.isLoadingProducts = false
            }
            if remoteProducts.isEmpty {
                updateError(error.localizedDescription)
            }
        }

        await refreshRemoteEntitlementCacheIfNeeded(for: productOrder, silent: true)
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
                let localProductIDs = await refreshEntitlementsAvailable(syncWithServer: false)
                let syncMessage = await verifyTransactionWithServerIfNeeded(transaction, userInitiated: true)
                await refreshRemoteStatusIfNeeded(localProductIDs: localProductIDs, silent: syncMessage == nil)
                await transaction.finish()
                updateSuccess(syncMessage ?? "Purchase successful.")

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
            let localProductIDs = await refreshEntitlementsAvailable(syncWithServer: false)
            let syncMessage = await restorePurchasesToServerIfNeeded(localProductIDs: localProductIDs, userInitiated: true)
            await refreshRemoteStatusIfNeeded(localProductIDs: localProductIDs, silent: syncMessage == nil)
            updateSuccess(syncMessage ?? "Purchases restored.")
        } catch {
            updateOnMain {
                self.isProcessingPurchase = false
            }
            updateError(error.localizedDescription)
        }
    }

    @available(iOS 15.0, *)
    @discardableResult
    private func refreshEntitlementsAvailable(syncWithServer: Bool = true) async -> Set<String> {
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

        if syncWithServer {
            await refreshRemoteStatusIfNeeded(localProductIDs: activeProductIDs, silent: true)
        }

        return activeProductIDs
    }

    private func applyEntitlements(_ productIDs: Set<String>, preferredCurrentProductID: String? = nil) {
        purchasedProductIDs = productIDs

        currentProductID = prioritizedProductID(from: productIDs, preferredCurrentProductID: preferredCurrentProductID)

        switch currentProductID {
        case Self.proYearlyProductID, Self.proMonthlyProductID:
            currentTier = .pro
        case Self.basicMonthlyProductID:
            currentTier = .basic
        default:
            currentTier = .none
        }

        persistState()
    }

    @available(iOS 15.0, *)
    private func startTransactionListenerAvailable() {
        transactionUpdatesTask = Swift.Task { [weak self] in
            guard let self = self else { return }
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    let localProductIDs = await self.refreshEntitlementsAvailable(syncWithServer: false)
                    _ = await self.verifyTransactionWithServerIfNeeded(transaction, userInitiated: false)
                    await self.refreshRemoteStatusIfNeeded(localProductIDs: localProductIDs, silent: true)
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

    private func mergeRemoteProducts(_ remoteProducts: [IAPProductModel], into base: [String: StoreProductInfo]) -> [String: StoreProductInfo] {
        var merged = base

        for remoteProduct in remoteProducts {
            let productID = remoteProduct.resolvedProductID
            guard !productID.isEmpty else { continue }

            let existing = merged[productID]
            merged[productID] = StoreProductInfo(
                id: productID,
                displayName: existing?.displayName ?? remoteProduct.resolvedDisplayName ?? fallbackPlanName(for: productID),
                displayPrice: existing?.displayPrice ?? remoteProduct.resolvedDisplayPrice ?? "",
                subscriptionPeriodText: existing?.subscriptionPeriodText ?? remoteProduct.resolvedSubscriptionPeriodText
            )
        }

        return merged
    }

    private func prioritizedProductID(from productIDs: Set<String>, preferredCurrentProductID: String?) -> String? {
        if let preferredCurrentProductID, productIDs.contains(preferredCurrentProductID) {
            return preferredCurrentProductID
        }

        for productID in productOrder where productIDs.contains(productID) {
            return productID
        }

        return nil
    }

    @available(iOS 15.0, *)
    private func fetchRemoteProductsAvailable() async -> [IAPProductModel] {
        guard canSyncPurchasesToServer else { return [] }

        do {
            let (jsonObject, statusCode) = try await requestJSONObject(.iapProducts)
            print("iap products raw status:", statusCode)
            print("iap products raw json:", jsonObject)

            if let jsonArray = jsonObject as? [[String: Any]],
               let models = [IAPProductModel].deserialize(from: jsonArray) as? [IAPProductModel] {
                return models
            }

            if let json = jsonObject as? [String: Any],
               let dataArray = json["data"] as? [[String: Any]],
               let models = [IAPProductModel].deserialize(from: dataArray) as? [IAPProductModel] {
                return models
            }

            throw NSError(domain: "PurchaseManager", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Unable to parse server response."])
        } catch {
            return []
        }
    }

    @available(iOS 15.0, *)
    private func verifyTransactionWithServerIfNeeded(_ transaction: Transaction, userInitiated: Bool) async -> String? {
        guard canSyncPurchasesToServer else {
            return userInitiated ? "Purchase successful. Log in to sync this subscription with your account." : nil
        }

        do {
            let resolvedPrice = productsByID[transaction.productID]?.displayPrice
            var verifyParameters: [String: Any] = [
                "transaction_id": String(transaction.id),
                "product_id": transaction.productID
            ]
            if let resolvedPrice, !resolvedPrice.isEmpty {
                verifyParameters["price"] = resolvedPrice
            }
            print("iap verify params:", verifyParameters)
            let response = try await requestModel(.iapVerify(parameters: verifyParameters), type: IAPVerifyResponseModel.self)
            print("iap verify raw:", response)
            if let entitlement = response.entitlement {
                cacheRemoteEntitlement(entitlement, fallbackProductID: transaction.productID)
            }
            return response.resolvedMessage
        } catch {
            return userInitiated ? "Purchase successful, but server sync failed: \(error.localizedDescription)" : nil
        }
    }

    @available(iOS 15.0, *)
    private func restorePurchasesToServerIfNeeded(localProductIDs: Set<String>, userInitiated: Bool) async -> String? {
        guard canSyncPurchasesToServer else {
            return userInitiated ? "Purchases restored locally. Log in to sync them with your account." : nil
        }

        let transactionPayloads = await collectCurrentTransactionPayloadsAvailable()
        var parameters: [String: Any] = [
            "product_ids": Array(localProductIDs).sorted(),
            "transactions": transactionPayloads.map(\.parameters),
            "platform": "ios",
            "source": "storekit2"
        ]

        if let prioritizedProductID = prioritizedProductID(from: localProductIDs, preferredCurrentProductID: currentProductID) {
            parameters["current_product_id"] = prioritizedProductID
        }

        do {
            let response = try await requestModel(.iapRestore(parameters: parameters), type: IAPRestoreResponseModel.self)
            return response.resolvedMessage
        } catch {
            return userInitiated ? "Purchases restored locally, but server sync failed: \(error.localizedDescription)" : nil
        }
    }

    @available(iOS 15.0, *)
    private func refreshRemoteStatusIfNeeded(localProductIDs: Set<String>, silent: Bool) async {
        guard canSyncPurchasesToServer else { return }

        do {
            let statusModel = try await requestModel(.iapStatus, type: IAPStatusModel.self)
            print("iap status raw:", statusModel)
            var mergedProductIDs = localProductIDs.union(statusModel.resolvedProductIDs)
            if let currentProductID = statusModel.resolvedCurrentProductID, !currentProductID.isEmpty {
                mergedProductIDs.insert(currentProductID)
            }

            updateOnMain {
                self.applyEntitlements(mergedProductIDs, preferredCurrentProductID: statusModel.resolvedCurrentProductID)
            }

            await refreshRemoteEntitlementCacheIfNeeded(for: mergedProductIDs.isEmpty ? productOrder : Array(mergedProductIDs), silent: true)
        } catch {
            if !silent {
                updateError(error.localizedDescription)
            }
        }
    }

    private func cacheRemoteEntitlement(_ entitlement: IAPEntitlementModel, fallbackProductID: String) {
        let productID = entitlement.resolvedProductID.isEmpty ? fallbackProductID : entitlement.resolvedProductID
        guard !productID.isEmpty else { return }

        updateOnMain {
            var cache = self.remoteEntitlementsByProductID
            cache[productID] = entitlement
            self.remoteEntitlementsByProductID = cache

            if entitlement.hasAccess {
                var merged = self.purchasedProductIDs
                merged.insert(productID)
                self.applyEntitlements(merged, preferredCurrentProductID: productID)
            }
        }
    }

    @available(iOS 15.0, *)
    private func refreshRemoteEntitlementCacheIfNeeded(for productIDs: [String], silent: Bool) async {
        guard canSyncPurchasesToServer else { return }

        var updatedCache: [String: IAPEntitlementModel] = remoteEntitlementsByProductID
        var remotelyEntitledProductIDs = Set<String>()

        for productID in Array(Set(productIDs)).filter({ !$0.isEmpty }) {
            do {
                let entitlement = try await requestModel(.iapProductEntitlement(productID: productID), type: IAPEntitlementModel.self)
                let resolvedProductID = entitlement.resolvedProductID.isEmpty ? productID : entitlement.resolvedProductID
                updatedCache[resolvedProductID] = entitlement
                if entitlement.hasAccess {
                    remotelyEntitledProductIDs.insert(resolvedProductID)
                }
            } catch {
                if !silent {
                    updateError(error.localizedDescription)
                }
            }
        }

        updateOnMain {
            self.remoteEntitlementsByProductID = updatedCache
            if !remotelyEntitledProductIDs.isEmpty {
                let mergedProductIDs = self.purchasedProductIDs.union(remotelyEntitledProductIDs)
                self.applyEntitlements(mergedProductIDs, preferredCurrentProductID: self.currentProductID)
            }
        }
    }

    @available(iOS 15.0, *)
    private func collectCurrentTransactionPayloadsAvailable() async -> [IAPTransactionSyncPayload] {
        var payloads: [IAPTransactionSyncPayload] = []

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            guard transaction.revocationDate == nil else { continue }
            if let expirationDate = transaction.expirationDate, expirationDate < Date() {
                continue
            }
            payloads.append(transactionPayload(from: transaction))
        }

        return payloads
    }

    @available(iOS 15.0, *)
    private func transactionPayload(from transaction: Transaction) -> IAPTransactionSyncPayload {
        let environment: String
        if #available(iOS 16.0, *) {
            environment = String(describing: transaction.environment)
        } else {
            environment = "unknown"
        }

        return IAPTransactionSyncPayload(
            productID: transaction.productID,
            transactionID: String(transaction.id),
            originalTransactionID: String(transaction.originalID),
            purchaseDate: iso8601String(from: transaction.purchaseDate) ?? "",
            expirationDate: iso8601String(from: transaction.expirationDate),
            revocationDate: iso8601String(from: transaction.revocationDate),
            appAccountToken: transaction.appAccountToken?.uuidString,
            ownershipType: String(describing: transaction.ownershipType),
            environment: environment,
            isUpgraded: transaction.isUpgraded
        )
    }

    private func iso8601String(from date: Date?) -> String? {
        guard let date else { return nil }
        return iso8601Formatter.string(from: date)
    }

    @discardableResult
    private func requestModel<T: HandyJSON>(_ endpoint: AppAPIEndPoint, type: T.Type) async throws -> T {
        let (jsonObject, statusCode) = try await requestJSONObject(endpoint)

        if let json = jsonObject as? [String: Any] {
            if let model = T.deserialize(from: json) {
                if var statusModel = model as? ResponseStatusable {
                    statusModel.statusCode = statusCode
                }
                return model
            }

            if let data = json["data"] as? [String: Any], let model = T.deserialize(from: data) {
                if var statusModel = model as? ResponseStatusable {
                    statusModel.statusCode = statusCode
                }
                return model
            }
        }

        throw NSError(domain: "PurchaseManager", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Unable to parse server response."])
    }

    private func requestModelArray<T: HandyJSON>(_ endpoint: AppAPIEndPoint, type: T.Type) async throws -> [T] {
        let (jsonObject, statusCode) = try await requestJSONObject(endpoint)

        if let jsonArray = jsonObject as? [[String: Any]],
           let models = [T].deserialize(from: jsonArray) as? [T] {
            return models
        }

        if let json = jsonObject as? [String: Any],
           let dataArray = json["data"] as? [[String: Any]],
           let models = [T].deserialize(from: dataArray) as? [T] {
            return models
        }

        throw NSError(domain: "PurchaseManager", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Unable to parse server response."])
    }

    private func requestJSONObject(_ endpoint: AppAPIEndPoint) async throws -> (Any, Int) {
        try await withCheckedThrowingContinuation { continuation in
            appApi.request(endpoint) { result in
                switch result {
                case .success(let response):
                    self.logIAPResponseIfNeeded(for: endpoint, response: response)
                    guard (200 ..< 300).contains(response.statusCode) else {
                        continuation.resume(throwing: self.apiError(from: response))
                        return
                    }

                    do {
                        continuation.resume(returning: (try response.mapJSON(), response.statusCode))
                    } catch {
                        continuation.resume(throwing: error)
                    }

                case .failure(let error):
                    self.logIAPRequestFailureIfNeeded(for: endpoint, error: error)
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func logIAPResponseIfNeeded(for endpoint: AppAPIEndPoint, response: Response) {
        guard endpoint.path.contains("iap/") else { return }

        let rawString = String(data: response.data, encoding: .utf8) ?? ""
        print("iap api path:", endpoint.path)
        print("iap api status:", response.statusCode)
        print("iap api raw response:", rawString)

        if let jsonObject = try? response.mapJSON() {
            print("iap api raw json:", jsonObject)
        }
    }

    private func logIAPRequestFailureIfNeeded(for endpoint: AppAPIEndPoint, error: MoyaError) {
        guard endpoint.path.contains("iap/") else { return }

        print("iap api path:", endpoint.path)
        print("iap api request failed:", error.localizedDescription)
    }

    private func apiError(from response: Response) -> Error {
        if let json = try? response.mapJSON() as? [String: Any] {
            let message = (json["detail"] as? String)
                ?? (json["message"] as? String)
                ?? (json["error"] as? String)

            if let message, !message.isEmpty {
                return NSError(domain: "PurchaseManager", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
            }
        }

        return NSError(
            domain: "PurchaseManager",
            code: response.statusCode,
            userInfo: [NSLocalizedDescriptionKey: "Request failed with status code \(response.statusCode)."]
        )
    }

    private var accessToken: String? {
        let currentToken = UserManager.shared.currentUser?.access_token.trimmingCharacters(in: .whitespacesAndNewlines)
        if let currentToken, !currentToken.isEmpty {
            return currentToken
        }

        let cachedToken = (PUserDefault.getVauleForKey(key: "access_token") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let cachedToken, !cachedToken.isEmpty {
            return cachedToken
        }

        return nil
    }

    private var canSyncPurchasesToServer: Bool {
        accessToken?.isEmpty == false
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
            self.isProcessingPurchase = false
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
