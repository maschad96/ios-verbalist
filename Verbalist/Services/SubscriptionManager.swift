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
        } else {
            isSubscribed = false
        }
    }
    
    func initialize() async {
        do {
            startTransactionListener()
            try await loadProducts()
            await clearPendingTransactions()
            await checkSubscriptionStatus()
        } catch {
            // Silently handle initialization errors
        }
    }
    
    private func loadProducts() async throws {
        let productIDs = [Self.weeklySubscriptionID, Self.monthlySubscriptionID]
        
        let products = try await Product.products(for: productIDs)
        
        for product in products {
            if product.id == Self.weeklySubscriptionID {
                weeklySubscription = product
            } else if product.id == Self.monthlySubscriptionID {
                monthlySubscription = product
            }
        }
    }
    
    private func clearPendingTransactions() async {
        // Process all unfinished transactions to clear the queue
        for await result in Transaction.unfinished {
            switch result {
            case .verified(let transaction):
                // Finish the transaction to remove it from the queue
                await transaction.finish()
                
            case .unverified(let transaction, _):
                // Still finish unverified transactions to clear the queue
                await transaction.finish()
            }
        }
    }
    
    private func startTransactionListener() {
        transactionListener = Task.detached { [weak self] in
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction):
                    await MainActor.run {
                        self?.handleTransactionUpdate(transaction)
                    }
                    
                case .unverified:
                    break
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
            } else {
                // Expired/revoked subscription
                isSubscribed = false
                UserDefaults.standard.set(false, forKey: "isSubscribed")
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
            throw SubscriptionError.productNotFound
        }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verificationResult):
            switch verificationResult {
            case .verified(let transaction):
                await transaction.finish()
                isSubscribed = true
                
                // Save subscription status to UserDefaults
                UserDefaults.standard.set(true, forKey: "isSubscribed")
                UserDefaults.standard.set(plan.rawValue, forKey: "subscriptionPlan")
                UserDefaults.standard.synchronize()
            case .unverified:
                throw SubscriptionError.verificationFailed
            }
        case .userCancelled:
            throw SubscriptionError.userCancelled
        case .pending:
            throw SubscriptionError.pending
        @unknown default:
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
                        }
                    }
                }
            case .unverified:
                continue
            }
        }
        
        isSubscribed = hasActiveSubscription
        // Save the current subscription status to UserDefaults
        UserDefaults.standard.set(isSubscribed, forKey: "isSubscribed")
        UserDefaults.standard.synchronize()
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
        isSubscribed = false
        
        // Force the app to show onboarding
        UserDefaults.standard.set(true, forKey: "forceOnboarding")
        UserDefaults.standard.synchronize()
        
        // Also update the subscription status in UserDefaults
        UserDefaults.standard.set(false, forKey: "isSubscribed") 
        UserDefaults.standard.synchronize()
    }
    
    // For development and testing: Simulate a successful purchase
    @MainActor
    func simulatePurchase(plan: SubscriptionPlan) {
        isSubscribed = true
        
        // Save subscription status and plan to UserDefaults
        UserDefaults.standard.set(true, forKey: "isSubscribed")
        UserDefaults.standard.set(plan.rawValue, forKey: "subscriptionPlan")
        UserDefaults.standard.synchronize()
    }
}
