import Foundation

enum UsageDisplayPolicy {
    static func displayedTotal(
        for period: UsagePeriod,
        localUsage: TokenUsage,
        profileSnapshot: ProfileUsageSnapshot?
    ) -> Int64 {
        guard let profileSnapshot else { return localUsage.totalTokens }

        return switch period {
        case .today:
            localUsage.totalTokens
        case .week:
            profileSnapshot.week
        case .month:
            profileSnapshot.month
        case .allTime:
            profileSnapshot.lifetime
        }
    }

    static func profileOverride(
        for period: UsagePeriod,
        profileSnapshot: ProfileUsageSnapshot?
    ) -> Int64? {
        guard let profileSnapshot else { return nil }

        return switch period {
        case .today:
            nil
        case .week:
            profileSnapshot.week
        case .month:
            profileSnapshot.month
        case .allTime:
            profileSnapshot.lifetime
        }
    }
}
