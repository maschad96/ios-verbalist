//
//  OnboardingView.swift
//  Verbalist
//
//  Created by Matt Schad on 6/1/25.
//

import SwiftUI
import StoreKit

extension Color {
    static let sageGreen = Color(hex: "85998B")
    static let charcoal = Color(hex: "404243")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

enum SubscriptionPlan: String, CaseIterable {
    case weekly = "weekly"
    case monthly = "monthly"
    
    var title: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
    
    var price: String {
        switch self {
        case .weekly: return "$4.99"
        case .monthly: return "$17.99"
        }
    }
    
    var description: String {
        switch self {
        case .weekly: return "Perfect for trying out Verbalist"
        case .monthly: return "Best value for regular users"
        }
    }
}

struct OnboardingView: View {
    @Binding var isShowingOnboarding: Bool
    @State private var selectedPlan: SubscriptionPlan = .monthly
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var subscriptionManager = SubscriptionManager.shared
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    header
                        .frame(height: geometry.size.height * 0.25)
                    
                    // Features
                    featuresSection
                    
                    // Subscription
                    subscriptionSection
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                }
            }
            .scrollIndicators(.hidden)
            .background(
                LinearGradient(
                    colors: [
                        Color.sageGreen.opacity(0.08),
                        Color.charcoal.opacity(0.03),
                        Color.sageGreen.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
        .task {
            await subscriptionManager.initialize()
        }
    }
    
    private var header: some View {
        VStack(spacing: 20) {
            // Premium icon
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.sageGreen, Color.charcoal]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.sageGreen.opacity(0.3), radius: 10, x: 0, y: 5)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
            .padding(.top, 44)
            
            Text("Verbalist Premium")
                .font(.system(.largeTitle, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(LinearGradient(
                    gradient: Gradient(colors: [Color.sageGreen, Color.charcoal]),
                    startPoint: .leading,
                    endPoint: .trailing
                ))
            
            Text("Unlock unlimited voice tasks and premium features")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 30)
                .padding(.bottom, 32)
        }
    }
    
    private var featuresSection: some View {
        VStack(spacing: 16) {
            premiumFeature(icon: "infinity", title: "Unlimited Tasks", description: "Create as many voice tasks as you need")
            premiumFeature(icon: "brain.head.profile", title: "Advanced AI Processing", description: "Smarter task extraction and organization")
            premiumFeature(icon: "icloud.fill", title: "Cloud Sync", description: "Access your tasks across all devices")
            premiumFeature(icon: "sparkles", title: "Priority Support", description: "Get help when you need it most")
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }
    
    private var subscriptionSection: some View {
        VStack(spacing: 16) {
            // Plan cards
            VStack(spacing: 12) {
                ForEach(SubscriptionPlan.allCases, id: \.self) { plan in
                    premiumPlanCard(for: plan)
                }
            }
            .padding(.horizontal, 24)
            
            // Purchase button
            Button(action: {
                startPurchase(for: selectedPlan)
            }) {
                HStack {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    }
                    
                    Text(isPurchasing ? "Processing..." : "Subscribe Now")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.sageGreen, Color.charcoal]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: Color.sageGreen.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 24)
            .disabled(isPurchasing)
            .scaleEffect(isPurchasing ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPurchasing)
            
            if let error = purchaseError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.callout)
                    .fontWeight(.medium)
                    .padding(.horizontal, 24)
                    .multilineTextAlignment(.center)
            }
            
            // Billing info
            VStack(spacing: 4) {
                Text("\(selectedPlan.price)/\(selectedPlan == .weekly ? "week" : "month")")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Cancel anytime in Settings • No commitment")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 8)
            
            // Terms and Privacy links
            HStack(spacing: 20) {
                Button("Terms of Use") {
                    if let url = URL(string: "https://www.apple.com/legal/internet-services/terms/site.html") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption2)
                .foregroundColor(.sageGreen)
                
                Text("•")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Button("Privacy Policy") {
                    if let url = URL(string: "https://www.apple.com/privacy/privacy-policy/") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption2)
                .foregroundColor(.sageGreen)
            }
        }
    }
    
    private func premiumFeature(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.sageGreen.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.sageGreen)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
    
    private func premiumPlanCard(for plan: SubscriptionPlan) -> some View {
        Button(action: {
            selectedPlan = plan
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(plan.title)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .fixedSize()
                        
                        if plan == .monthly {
                            Text("BEST VALUE")
                                .font(.caption2)
                                .fontWeight(.heavy)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.orange, Color.red]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                    }
                    
                    Text(plan.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.price)
                        .font(.title2)
                        .fontWeight(.heavy)
                        .foregroundStyle(LinearGradient(
                            gradient: Gradient(colors: [Color.sageGreen, Color.charcoal]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .fixedSize()
                    
                    Text(plan == .weekly ? "per week" : "per month")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize()
                }
                
                Image(systemName: selectedPlan == plan ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedPlan == plan ? .sageGreen : .gray.opacity(0.4))
                    .font(.title2)
                    .padding(.leading, 16)
            }
            .padding(.all, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        selectedPlan == plan 
                            ? LinearGradient(
                                gradient: Gradient(colors: [Color.sageGreen, Color.charcoal]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                gradient: Gradient(colors: [Color.gray.opacity(0.2)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: selectedPlan == plan ? 2 : 1
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(selectedPlan == plan ? Color.sageGreen.opacity(0.08) : Color(.systemBackground))
                            .shadow(
                                color: selectedPlan == plan ? Color.sageGreen.opacity(0.2) : Color.clear,
                                radius: selectedPlan == plan ? 8 : 0,
                                x: 0,
                                y: selectedPlan == plan ? 4 : 0
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(selectedPlan == plan ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: selectedPlan == plan)
    }
    
    
    private func startPurchase(for plan: SubscriptionPlan) {
        isPurchasing = true
        purchaseError = nil
        
        Task {
            do {
                try await subscriptionManager.purchase(plan: plan)
                await MainActor.run {
                    isPurchasing = false
                    isShowingOnboarding = false
                }
            } catch SubscriptionError.userCancelled {
                await MainActor.run {
                    isPurchasing = false
                    purchaseError = "Purchase was cancelled"
                }
            } catch SubscriptionError.productNotFound {
                await MainActor.run {
                    isPurchasing = false
                    purchaseError = "Product not available"
                }
            } catch SubscriptionError.verificationFailed {
                await MainActor.run {
                    isPurchasing = false
                    purchaseError = "Purchase verification failed"
                }
            } catch SubscriptionError.pending {
                await MainActor.run {
                    isPurchasing = false
                    purchaseError = "Purchase is pending approval"
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    purchaseError = "Purchase failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    OnboardingView(isShowingOnboarding: .constant(true))
}
