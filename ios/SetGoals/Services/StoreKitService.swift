import Foundation
import StoreKit

/// Native replacement for the web `src/lib/storekit.ts` shim.
/// Entitlement itself is granted server-side by Apple's server notifications
/// (`/api/public/payments/apple-notifications`), exactly like the web app —
/// the client only starts the purchase and refreshes settings afterwards.
enum StoreKitService {
    enum Plan: String, CaseIterable, Identifiable {
        case monthly, yearly, family_monthly, family_yearly
        var id: String { rawValue }
        var isFamily: Bool { rawValue.hasPrefix("family") }
        var productID: String {
            switch self {
            case .monthly: return "app.setgoals.pro.monthly"
            case .yearly: return "app.setgoals.pro.yearly"
            case .family_monthly: return "app.setgoals.pro.family.monthly"
            case .family_yearly: return "app.setgoals.pro.family.yearly"
            }
        }
    }

    enum Result {
        case purchased
        case pending
        case cancelled
        case nothingToRestore
        case failed
    }

    static func purchase(_ plan: Plan) async -> Result {
        do {
            guard let product = try await Product.products(for: [plan.productID]).first else {
                return .failed
            }
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    return .purchased
                }
                return .failed
            case .pending: return .pending
            case .userCancelled: return .cancelled
            @unknown default: return .failed
            }
        } catch {
            return .failed
        }
    }

    static func restore() async -> Result {
        do { try await AppStore.sync() } catch { return .failed }
        for await entitlement in Transaction.currentEntitlements {
            if case .verified = entitlement { return .purchased }
        }
        return .nothingToRestore
    }

    /// Opens the App Store subscription management sheet.
    @MainActor
    static func openManageSubscriptions() async {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else { return }
        try? await AppStore.showManageSubscriptions(in: scene)
    }
}
