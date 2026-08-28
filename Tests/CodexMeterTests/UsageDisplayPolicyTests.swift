import Foundation
import XCTest
@testable import CodexMeter

final class UsageDisplayPolicyTests: XCTestCase {
    private let localUsage = TokenUsage(
        inputTokens: 188_421_328,
        cachedInputTokens: 184_070_144,
        outputTokens: 603_353
    )

    private let profileSnapshot = ProfileUsageSnapshot(
        today: 490_000_000,
        week: 971_000_000,
        month: 3_140_000_000,
        lifetime: 4_490_000_000,
        statsAsOf: Date(timeIntervalSince1970: 1_777_248_000),
        generatedAt: Date(timeIntervalSince1970: 1_777_291_200)
    )

    func testTodayAlwaysUsesLiveLocalTotalWhenProfileTotalsAreAvailable() {
        XCTAssertEqual(
            UsageDisplayPolicy.displayedTotal(
                for: .today,
                localUsage: localUsage,
                profileSnapshot: profileSnapshot
            ),
            189_024_681
        )
        XCTAssertNil(
            UsageDisplayPolicy.profileOverride(
                for: .today,
                profileSnapshot: profileSnapshot
            )
        )
    }

    func testLongerPeriodsContinueToUseEnabledProfileTotals() {
        XCTAssertEqual(
            UsageDisplayPolicy.displayedTotal(
                for: .week,
                localUsage: localUsage,
                profileSnapshot: profileSnapshot
            ),
            971_000_000
        )
        XCTAssertEqual(
            UsageDisplayPolicy.profileOverride(
                for: .month,
                profileSnapshot: profileSnapshot
            ),
            3_140_000_000
        )
        XCTAssertEqual(
            UsageDisplayPolicy.profileOverride(
                for: .allTime,
                profileSnapshot: profileSnapshot
            ),
            4_490_000_000
        )
    }

    func testAllPeriodsUseLocalTotalsWithoutProfileSnapshot() {
        for period in UsagePeriod.allCases {
            XCTAssertEqual(
                UsageDisplayPolicy.displayedTotal(
                    for: period,
                    localUsage: localUsage,
                    profileSnapshot: nil
                ),
                189_024_681
            )
            XCTAssertNil(
                UsageDisplayPolicy.profileOverride(
                    for: period,
                    profileSnapshot: nil
                )
            )
        }
    }
}
