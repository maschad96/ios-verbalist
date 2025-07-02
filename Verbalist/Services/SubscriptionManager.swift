//
//  SubscriptionManager.swift
//  Verbalist
//
//  Created by Matt Schad on 7/1/25.
//

import StoreKit
import Foundation

@Observable
@MainActor
class SubscriptionManager {
    var isSubscribed = false
    
    private var weeklySubscription: Product?
    private var monthlySubscription: Product?
    private var transactionListener: Task<Void, Error>?
    
    static let shared = SubscriptionManager()
    static let weeklySubscriptionID = "DigitalDen.Verbalist.subscription.weekly"
    static let monthlySubscriptionID = "DigitalDen.Verbalist.subscription.monthly"
    
    init() {
        // Load initial subscription status from UserDefaults
        if let savedStatus = UserDefaults.standard.object(forKey: "isSubscribed") as? Bool {
            isSubscribed = savedStatus
            print("DEBUG: Loaded initial subscription status from UserDefaults: \(isSubscribed)")
        } else {
            isSubscribed = false
            print("DEBUG: No saved subscription status found, defaulting to false")
        }
    }
    
    func initialize() async {
        do {
            print("Initializing SubscriptionManager...")
            startTransactionListener()
            try await loadProducts()
            await clearPendingTransactions()
            await checkSubscriptionStatus()
            
            print("SubscriptionManager initialization complete - isSubscribed: \(isSubscribed)")
        } catch {
            print("Failed to initialize subscription manager: \(error)")
        }
    }
    
    private func loadProducts() async throws {
        let productIDs = [Self.weeklySubscriptionID, Self.monthlySubscriptionID]
        print("Loading products with IDs: \(productIDs)")
        
        let products = try await Product.products(for: productIDs)
        print("Found \(products.count) products")
        
        for product in products {
            if product.id == Self.weeklySubscriptionID {
                weeklySubscription = product
                print("Loaded weekly subscription product: \(product.displayName) - \(product.displayPrice)")
            } else if product.id == Self.monthlySubscriptionID {
                monthlySubscription = product
                print("Loaded monthly subscription product: \(product.displayName) - \(product.displayPrice)")
            }
        }
        
        if weeklySubscription == nil {
            print("WARNING: Weekly subscription product not found")
        }
        if monthlySubscription == nil {
            print("WARNING: Monthly subscription product not found")
        }
    }
    
    private func clearPendingTransactions() async {
        print("DEBUG: Clearing pending transactions from StoreKit queue...")
        var clearedCount = 0
        
        // Process all unfinished transactions to clear the queue
        for await result in Transaction.unfinished {
            switch result {
            case .verified(let transaction):
                print("DEBUG: Found unfinished transaction: \(transaction.id) for product: \(transaction.productID)")
                
                // Finish the transaction to remove it from the queue
                await transaction.finish()
                clearedCount += 1
                
            case .unverified(let transaction, let verificationError):
                print("DEBUG: Found unverified transaction: \(transaction.id), error: \(verificationError.localizedDescription)")
                
                // Still finish unverified transactions to clear the queue
                await transaction.finish()
                clearedCount += 1
            }
        }
        
        print("DEBUG: Cleared \(clearedCount) pending transactions from queue")
    }
    
    private func startTransactionListener() {
        print("DEBUG: Starting transaction listener for updates...")
        
        transactionListener = Task.detached { [weak self] in
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction):
                    print("DEBUG: Transaction update received: \(transaction.id) for product: \(transaction.productID)")
                    
                    await MainActor.run {
                        self?.handleTransactionUpdate(transaction)
                    }
                    
                case .unverified(let transaction, let verificationError):
                    print("DEBUG: Unverified transaction update: \(transaction.id), error: \(verificationError.localizedDescription)")
                }
            }
        }
    }
    
    @MainActor
    private func handleTransactionUpdate(_ transaction: Transaction) {
        // Handle subscription updates
        if transaction.productID == Self.weeklySubscriptionID || transaction.productID == Self.monthlySubscriptionID {
            if transaction.revocationDate == nil && 
               (transaction.expirationDate == nil || transaction.expirationDate! > Date()) {
                // Active subscription
                isSubscribed = true
                UserDefaults.standard.set(true, forKey: "isSubscribed")
                print("DEBUG: Subscription activated via transaction update")
            } else {
                // Expired/revoked subscription
                isSubscribed = false
                UserDefaults.standard.set(false, forKey: "isSubscribed")
                print("DEBUG: Subscription deactivated via transaction update")
            }
            UserDefaults.standard.synchronize()
        }
        
        // Finish the transaction
        Task {
            await transaction.finish()
        }
    }
    
    deinit {
        Task { @MainActor in
            transactionListener?.cancel()
        }
    }
    
    func purchase(plan: SubscriptionPlan) async throws {
        let product: Product?
        
        switch plan {
        case .weekly:
            product = weeklySubscription
        case .monthly:
            product = monthlySubscription
        }
        
        guard let product = product else {
            print("DEBUG: Product not found for purchase plan: \(plan.title)")
            throw SubscriptionError.productNotFound
        }
        
        print("DEBUG: Attempting to purchase: \(product.id)")
        let result = try await product.purchase()
        
        switch result {
        case .success(let verificationResult):
            switch verificationResult {
            case .verified(let transaction):
                print("DEBUG: Purchase verified, transaction ID: \(transaction.id)")
                await transaction.finish()
                isSubscribed = true
                print("DEBUG: isSubscribed set to \(isSubscribed)")
                
                // Save subscription status to UserDefaults
                UserDefaults.standard.set(true, forKey: "isSubscribed")
                UserDefaults.standard.set(plan.rawValue, forKey: "subscriptionPlan")
                UserDefaults.standard.synchronize()
                print("DEBUG: Saved subscription status to UserDefaults")
            case .unverified(_, let error):
                print("DEBUG: Purchase verification failed: \(error.localizedDescription)")
                throw SubscriptionError.verificationFailed
            }
        case .userCancelled:
            print("DEBUG: User cancelled purchase")
            throw SubscriptionError.userCancelled
        case .pending:
            print("DEBUG: Purchase pending")
            throw SubscriptionError.pending
        @unknown default:
            print("DEBUG: Unknown purchase result")
            throw SubscriptionError.unknown
        }
    }
    
    private func checkSubscriptionStatus() async {
        // Reset subscription status before checking
        isSubscribed = false
        
        // Check for active subscription entitlements
        var hasActiveSubscription = false
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if transaction.productID == Self.weeklySubscriptionID || transaction.productID == Self.monthlySubscriptionID {
                    // Check if transaction is still valid (not revoked or expired)
                    if transaction.revocationDate == nil && 
                       (transaction.expirationDate == nil || transaction.expirationDate! > Date()) {
                        // Only consider active if we're not forcing it to be inactive via UserDefaults
                        let forceInactive = UserDefaults.standard.bool(forKey: "forceOnboarding")
                        if !forceInactive {
                            hasActiveSubscription = true
                            print("Active subscription found: \(transaction.productID), expires: \(transaction.expirationDate?.description ?? "no expiration")")
                        } else {
                            print("Found valid subscription but forceOnboarding is enabled, keeping inactive")
                        }
                    } else {
                        print("Found expired or revoked subscription: \(transaction.productID), revoked: \(transaction.revocationDate?.description ?? "not revoked"), expires: \(transaction.expirationDate?.description ?? "no expiration")")
                    }
                }
            case .unverified(_, let verificationError):
                print("Unverified transaction: \(verificationError.localizedDescription)")
                continue
            }
        }
        
        isSubscribed = hasActiveSubscription
        // Save the current subscription status to UserDefaults
        UserDefaults.standard.set(isSubscribed, forKey: "isSubscribed")
        UserDefaults.standard.synchronize()
        
        print("Subscription status check complete. isSubscribed: \(isSubscribed)")
    }
}

enum SubscriptionError: Error {
    case productNotFound
    case verificationFailed
    case userCancelled
    case pending
    case unknown
}

extension SubscriptionManager {
    static var preview: SubscriptionManager {
        let manager = SubscriptionManager()
        return manager
    }
    
    // For testing cancellation
    @MainActor
    func cancelSubscription() async {
        print("DEBUG: Canceling subscription")
        isSubscribed = false
        
        // Force the app to show onboarding
        UserDefaults.standard.set(true, forKey: "forceOnboarding")
        UserDefaults.standard.synchronize()
        
        // Also update the subscription status in UserDefaults
        UserDefaults.standard.set(false, forKey: "isSubscribed") 
        UserDefaults.standard.synchronize()
        
        print("DEBUG: Subscription cancelled and forceOnboarding enabled")
    }
    
    // For development and testing: Simulate a successful purchase
    @MainActor
    func simulatePurchase(plan: SubscriptionPlan) {
        print("DEBUG: Simulating purchase of \(plan.title) plan")
        isSubscribed = true
        
        // Save subscription status and plan to UserDefaults
        UserDefaults.standard.set(true, forKey: "isSubscribed")
        UserDefaults.standard.set(plan.rawValue, forKey: "subscriptionPlan")
        UserDefaults.standard.synchronize()
        
        print("DEBUG: Simulated purchase complete - isSubscribed: \(isSubscribed)")
    }
}
