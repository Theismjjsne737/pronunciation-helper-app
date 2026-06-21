import SwiftUI
import StoreKit

struct PaywallView: View {

    @ObservedObject private var subs = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss

    var onSubscribed: (() -> Void)? = nil   // Called after successful purchase

    @State private var selectedTier: SubscriptionTier = .yearly
    @State private var showSuccessBanner = false
    @State private var pulseYearly = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    celebrationHeader
                    benefitsList
                    planCards
                    subscribeButton
                    secondaryActions
                    legalFooter
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(paywallBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Maybe Later") { dismiss() }
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
            .overlay(alignment: .top) {
                if showSuccessBanner { successBanner }
            }
            .task {
                if subs.products.isEmpty { await subs.loadProducts() }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulseYearly = true
                }
            }
        }
    }

    // MARK: - Header

    private var celebrationHeader: some View {
        VStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.indigo.opacity(0.15), .purple.opacity(0.10)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                Text("🎯")
                    .font(.system(size: 46))
            }

            VStack(spacing: 6) {
                Text("You've Used Your 5 Free Sessions!")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("Unlock unlimited AI coaching for just $14.99/month and keep improving.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Benefits

    private var benefitsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(benefits, id: \.title) { b in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.indigo)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(b.title).font(.subheadline.weight(.semibold))
                        Text(b.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private let benefits: [(title: String, subtitle: String)] = [
        ("Unlimited pronunciation practice", "Any word, name, or phrase — no limits"),
        ("Personalized accent coaching",     "The coach adapts to your specific patterns"),
        ("Daily practice reminders",         "Build a streak with gentle habit nudges"),
        ("Track your improvement",           "See your accuracy grow over time"),
    ]

    // MARK: - Plan cards

    private var planCards: some View {
        VStack(spacing: 12) {
            // Yearly — featured
            PlanCard(
                tier: .yearly,
                product: subs.product(for: .yearly),
                isSelected: selectedTier == .yearly,
                isFeatured: true,
                pulsing: pulseYearly && selectedTier == .yearly
            ) { selectedTier = .yearly }

            // Monthly
            PlanCard(
                tier: .monthly,
                product: subs.product(for: .monthly),
                isSelected: selectedTier == .monthly,
                isFeatured: false,
                pulsing: false
            ) { selectedTier = .monthly }
        }
    }

    // MARK: - Subscribe button

    private var subscribeButton: some View {
        Button {
            Task { await handlePurchase() }
        } label: {
            HStack(spacing: 10) {
                if subs.isPurchasing {
                    ProgressView().tint(.white).scaleEffect(0.85)
                }
                Text(subscribeButtonLabel)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .indigo.opacity(0.4), radius: 10, y: 5)
        }
        .disabled(subs.isPurchasing || subs.products.isEmpty)
        .animation(.easeInOut(duration: 0.2), value: subs.isPurchasing)
    }

    private var subscribeButtonLabel: String {
        guard let product = subs.product(for: selectedTier) else {
            return subs.products.isEmpty ? "Loading…" : "Subscribe"
        }
        return "Start \(selectedTier.displayName) – \(product.displayPrice)"
    }

    // MARK: - Secondary actions

    private var secondaryActions: some View {
        VStack(spacing: 14) {
            if let err = subs.purchaseError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await subs.restorePurchases() }
            } label: {
                Text(subs.restoreSuccess ? "✓ Purchases restored!" : "Restore Purchases")
                    .font(.subheadline)
                    .foregroundStyle(subs.restoreSuccess ? .green : .indigo)
            }
            .disabled(subs.isPurchasing)
        }
    }

    // MARK: - Legal footer

    private var legalFooter: some View {
        VStack(spacing: 6) {
            HStack(spacing: 16) {
                Link("Terms of Use",       destination: URL(string: "https://example.com/terms")!)
                Link("Privacy Policy",     destination: URL(string: "https://example.com/privacy")!)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text("Subscriptions auto-renew until cancelled. Cancel any time in App Store settings.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Success banner

    private var successBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
            Text("Subscription activated! Unlimited access unlocked.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
        }
        .padding(16)
        .background(Color.green.gradient)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Background

    private var paywallBackground: some View {
        Color(.systemGroupedBackground).ignoresSafeArea()
    }

    // MARK: - Purchase handler

    private func handlePurchase() async {
        guard let product = subs.product(for: selectedTier) else { return }
        let result = await subs.purchase(product)
        if case .success = result {
            withAnimation { showSuccessBanner = true }
            try? await Task.sleep(for: .seconds(1.5))
            onSubscribed?()
            dismiss()
        }
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let tier: SubscriptionTier
    let product: Product?
    let isSelected: Bool
    let isFeatured: Bool
    let pulsing: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Selection circle
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.indigo : Color(.systemGray4), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.indigo)
                            .frame(width: 13, height: 13)
                    }
                }

                // Plan info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        if isFeatured { Text("💎").font(.subheadline) }
                        Text(tier.displayName).font(.headline)
                        if isFeatured {
                            Text("BEST VALUE")
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.indigo)
                                .clipShape(Capsule())
                        }
                        if let badge = tier.savingsBadge {
                            Text(badge)
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.green)
                                .clipShape(Capsule())
                        }
                    }
                    Text(tier.billingDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Price
                if let p = product {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(p.displayPrice).font(.headline.weight(.bold))
                        if tier == .yearly {
                            Text("/ year")
                                .font(.caption2).foregroundStyle(.secondary)
                            Text("vs $179.88")
                                .font(.caption2).foregroundStyle(.secondary)
                                .strikethrough(true, color: .secondary)
                        }
                    }
                } else {
                    ProgressView().scaleEffect(0.7)
                }
            }
            .padding(18)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color.indigo : Color(.systemGray5),
                        lineWidth: isSelected ? 2 : 1
                    )
                    .scaleEffect(pulsing ? 1.01 : 1.0)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private var cardBackground: Color {
        isSelected
            ? Color.indigo.opacity(0.06)
            : Color(.secondarySystemGroupedBackground)
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
}
