import AppKit
import SwiftUI
import XCTest
@testable import CodexMeter

@MainActor
final class MenuPopoverLayoutTests: XCTestCase {
    func testPopoverSectionsSeparateTokenUsageFromCodexLimits() {
        XCTAssertEqual(
            MenuPopoverSection.allCases.map(\.title),
            ["Token Usage", "Codex Limits"]
        )
        XCTAssertEqual(MenuPopoverSection.overview.categories, [.localUsage, .tokenHistory, .explore])
        XCTAssertEqual(MenuPopoverSection.codex.categories, [.accountLimits])
        XCTAssertTrue(MenuPopoverSection.allCases.allSatisfy { !$0.symbol.isEmpty })
        XCTAssertTrue(MenuPopoverCategory.allCases.allSatisfy { !$0.symbol.isEmpty })
        XCTAssertEqual(
            MenuPopoverCategory.allCases.map(\.title),
            ["Codex Usage Limits", "Today’s Tokens", "Usage History", "Detailed Views"]
        )
    }

    func testPopoverFittingSizeShowsContentWithoutEmbeddingAScrollView() {
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
        XCTAssertGreaterThan(hostingView.fittingSize.height, 300)
        XCTAssertFalse(containsScrollView(in: hostingView))
    }

    func testUsageDetailRequestsStableHeightAndKeepsOneContentScroller() {
        _ = NSApplication.shared
        let view = UsageAnalyticsView()
            .environmentObject(UsageStore())
        let hostingView = NSHostingView(rootView: view)

        hostingView.layoutSubtreeIfNeeded()

        XCTAssertEqual(hostingView.fittingSize.width, MenuPopoverMetrics.width)
        XCTAssertEqual(hostingView.fittingSize.height, MenuPopoverMetrics.analyticsDetailHeight)
        XCTAssertEqual(scrollViewCount(in: hostingView), 1)
    }

    private func containsScrollView(in view: NSView) -> Bool {
        view is NSScrollView || view.subviews.contains(where: containsScrollView)
    }

    private func scrollViewCount(in view: NSView) -> Int {
        (view is NSScrollView ? 1 : 0) + view.subviews.reduce(0) { $0 + scrollViewCount(in: $1) }
    }
}

private struct CollapsedPopoverTestLimitProvider: AccountLimitProviding {
    func readLimits() async throws -> AccountLimitsSnapshot {
        throw AccountLimitError.trustedAppServerNotFound
    }
}
