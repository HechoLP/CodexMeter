import AppKit
import SwiftUI
import XCTest
@testable import CodexMeter

@MainActor
final class MenuPopoverLayoutTests: XCTestCase {
    func testPopoverCategoriesFollowThePrimaryReadingOrder() {
        XCTAssertEqual(
            MenuPopoverCategory.allCases.map(\.title),
            ["Local Usage", "Account Limits", "Token History", "Explore"]
        )
        XCTAssertTrue(MenuPopoverCategory.allCases.allSatisfy { !$0.symbol.isEmpty })
    }

    func testPopoverFittingSizeCannotCollapseToHeaderAndFooterOnly() {
        _ = NSApplication.shared
        let store = UsageStore()
        let profileStore = ProfileUsageStore()
        let limitStore = AccountLimitStore(
            provider: CollapsedPopoverTestLimitProvider(),
            pollingInterval: nil
        )
        let view = MenuPopoverView()
            .environmentObject(store)
            .environmentObject(profileStore)
            .environmentObject(limitStore)
        let hostingView = NSHostingView(rootView: view)

        hostingView.layoutSubtreeIfNeeded()

        XCTAssertEqual(hostingView.fittingSize.width, MenuPopoverMetrics.width)
        XCTAssertGreaterThanOrEqual(
            hostingView.fittingSize.height,
            MenuPopoverMetrics.minimumBodyHeight,
            "The menu body must retain enough height to render usage content."
        )
    }
}

private struct CollapsedPopoverTestLimitProvider: AccountLimitProviding {
    func readLimits() async throws -> AccountLimitsSnapshot {
        throw AccountLimitError.trustedAppServerNotFound
    }
}
