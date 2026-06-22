import Testing
@testable import LingoLab

@Suite("SubscriptionTier")
struct SubscriptionTierTests {

    @Test("displayName returns correct label")
    func displayName() {
        #expect(SubscriptionTier.monthly.displayName == "Monthly")
        #expect(SubscriptionTier.yearly.displayName == "Yearly")
    }

    @Test("isBestValue only true for yearly")
    func isBestValue() {
        #expect(SubscriptionTier.yearly.isBestValue)
        #expect(!SubscriptionTier.monthly.isBestValue)
    }

    @Test("savingsBadge present only on yearly")
    func savingsBadge() {
        #expect(SubscriptionTier.yearly.savingsBadge == "SAVE 44%")
        #expect(SubscriptionTier.monthly.savingsBadge == nil)
    }

    @Test("billingDescription contains expected text")
    func billingDescription() {
        #expect(SubscriptionTier.monthly.billingDescription.contains("monthly"))
        #expect(SubscriptionTier.yearly.billingDescription.contains("Save"))
    }

    @Test("init from product ID succeeds for known IDs")
    func initFromProductID() {
        #expect(SubscriptionTier(productID: "com.yourname.lingolab.monthly") == .monthly)
        #expect(SubscriptionTier(productID: "com.yourname.lingolab.yearly") == .yearly)
    }

    @Test("init from unknown product ID returns nil")
    func initFromUnknownProductID() {
        #expect(SubscriptionTier(productID: "com.unknown.product") == nil)
        #expect(SubscriptionTier(productID: "") == nil)
    }

    @Test("allCases contains both tiers")
    func allCases() {
        #expect(SubscriptionTier.allCases.count == 2)
        #expect(SubscriptionTier.allCases.contains(.monthly))
        #expect(SubscriptionTier.allCases.contains(.yearly))
    }
}
