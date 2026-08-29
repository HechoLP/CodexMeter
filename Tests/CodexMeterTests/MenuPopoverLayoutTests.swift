import AppKit
import SwiftUI
import XCTest
@testable import CodexMeter

@MainActor
final class MenuPopoverLayoutTests: XCTestCase {
    func testPopoverSectionsSeparateTokenUsageFromCodexLimits() {
        XCTAssertEqual(
            MenuPopoverSection.allCases.map(\.title),
            ["Overview", "Codex"]
        )
        XCTAssertEqual(MenuPopoverSection.overview.categories, [.localUsage, .tokenHistory, .explore])
        XCTAssertEqual(MenuPopoverSection.codex.categories, [.accountLimits])
        XCTAssertTrue(MenuPopoverSection.allCases.allSatisfy { !$0.symbol.isEmpty })
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
