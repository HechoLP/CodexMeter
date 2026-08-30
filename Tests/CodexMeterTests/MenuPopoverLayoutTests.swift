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

    func testAllAnalyticsDetailsHaveBoundedHeightAndOneContentScroller() {
        _ = NSApplication.shared
        let empty = Dictionary(uniqueKeysWithValues: AnalyticsRange.allCases.map {
            ($0, AnalyticsSnapshot.empty(range: $0, through: Date(), calendar: .current))
        })
        for snapshots in [[:], empty, analyticsFixtures] {
            for destination in analyticsDestinations {
                let hostingView = NSHostingView(rootView:
                    popover(destination: destination, snapshots: snapshots)
                )
                hostingView.layoutSubtreeIfNeeded()
                XCTAssertEqual(hostingView.fittingSize.width, MenuPopoverMetrics.width)
                XCTAssertLessThanOrEqual(hostingView.fittingSize.height, 580)
                XCTAssertEqual(scrollViewCount(in: hostingView), 1)
            }
        }
    }

    func testProductionPopoverPlacesFiltersDirectlyBelowItsHeader() throws {
        _ = NSApplication.shared
        for destination in analyticsDestinations {
            let name = destination.title(usesProfileTotals: false)
            let hostingView = NSHostingView(rootView:
                popover(destination: destination, snapshots: analyticsFixtures)
            )
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 372, height: 570),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.contentView = hostingView
            defer { window.contentView = nil }
            window.setContentSize(hostingView.fittingSize)
            hostingView.layoutSubtreeIfNeeded()
            let controls = descendants(of: NSSegmentedControl.self, in: hostingView)
            XCTAssertFalse(controls.isEmpty, name)
            let frames = controls.map { topOriginFrame(of: $0, in: hostingView) }.sorted { $0.minY < $1.minY }
            let first = try XCTUnwrap(frames.first)
            XCTAssertEqual(first.minY - MenuPopoverMetrics.detailHeaderHeight, 12, accuracy: 3, name)
            for frame in frames {
                XCTAssertLessThan(frame.height, 36, "\(name) filter must keep its native control height")
            }
            let scroll = try XCTUnwrap(descendants(of: NSScrollView.self, in: hostingView).first)
            let scrollFrame = topOriginFrame(of: scroll, in: hostingView)
            let last = try XCTUnwrap(frames.last)
            XCTAssertEqual(scrollFrame.minY - last.maxY, 12, accuracy: 3, name)
            XCTAssertLessThanOrEqual(scrollFrame.height, MenuPopoverMetrics.analyticsViewportMaximumHeight)
            XCTAssertNil(window.toolbar, "MenuBarExtra must not gain a second, automatic navigation toolbar")
            try captureIfRequested(hostingView, name: name)
        }
    }

    func testNavigationReturnsToParentAndPreservesItsSelections() {
        let navigation = MenuNavigation()
        navigation.push(.usage)
        navigation.usageRange = .thirtyDays
        navigation.chartMetric = .cost
        navigation.push(.model(id: "model", range: .thirtyDays))
        navigation.back()
        XCTAssertEqual(navigation.destination, .usage)
        XCTAssertEqual(navigation.usageRange, .thirtyDays)
        XCTAssertEqual(navigation.chartMetric, .cost)
        navigation.back()
        XCTAssertNil(navigation.destination)
        navigation.back()
        XCTAssertTrue(navigation.path.isEmpty)
    }

    func testEveryDestinationKeepsThePopoverWidthAndBoundedHeight() {
        _ = NSApplication.shared
        let destinations: [MenuDestination] = analyticsDestinations + [
            .limits,
            .project(id: "project-0", range: .thirtyDays),
            .session(id: "session-0", range: .sevenDays),
            .model(id: "test-model", range: .sevenDays)
        ] + UsagePeriod.allCases.map { .period($0) }
        for destination in destinations {
            let hostingView = NSHostingView(rootView:
                popover(destination: destination, snapshots: analyticsFixtures)
            )
            hostingView.layoutSubtreeIfNeeded()
            XCTAssertEqual(hostingView.fittingSize.width, MenuPopoverMetrics.width, "\(destination)")
            XCTAssertLessThanOrEqual(hostingView.fittingSize.height, 580, "\(destination)")
            XCTAssertGreaterThan(hostingView.fittingSize.height, MenuPopoverMetrics.detailHeaderHeight)
        }
    }

    func testContentViewportFitsShortContentAndCapsLongContent() async {
        _ = NSApplication.shared
        let hostingView = NSHostingView(rootView: viewport(height: 90))
        // Reuse the same host: data loading and filter changes must both grow
        // and shrink an already open detail screen, not just size its first render.
        for height: CGFloat in [90, 900, 260, 90] {
            hostingView.rootView = viewport(height: height)
            for _ in 0..<8 {
                hostingView.setFrameSize(hostingView.fittingSize)
                hostingView.layoutSubtreeIfNeeded()
                await Task.yield()
            }
            XCTAssertEqual(hostingView.fittingSize.height, min(height, 440), accuracy: 1)
        }
    }

    private func viewport(height: CGFloat) -> some View {
        ContentFittingScrollView(maximumHeight: 440) {
            Color.clear.frame(height: height)
        }
        .frame(width: MenuPopoverMetrics.width)
    }

    private var analyticsDestinations: [MenuDestination] { [.usage, .projects, .sessions] }

    private func popover(destination: MenuDestination, snapshots: [AnalyticsRange: AnalyticsSnapshot]) -> some View {
        MenuPopoverView(navigation: MenuNavigation(path: [destination]))
            .environmentObject(UsageStore(analyticsSnapshots: snapshots))
            .environmentObject(ProfileUsageStore())
            .environmentObject(AccountLimitStore(provider: CollapsedPopoverTestLimitProvider(), pollingInterval: nil))
    }

    private func topOriginFrame(of view: NSView, in hostingView: NSView) -> NSRect {
        let frame = hostingView.convert(view.bounds, from: view)
        return NSRect(x: frame.minX,
                      y: hostingView.isFlipped ? frame.minY : hostingView.bounds.maxY - frame.maxY,
                      width: frame.width, height: frame.height)
    }

    private func captureIfRequested(_ view: NSView, name: String) throws {
        guard let path = ProcessInfo.processInfo.environment["CODEXMETER_LAYOUT_CAPTURE_DIR"] else { return }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: directory.appendingPathComponent("\(name).png"))
    }

    private func descendants<T: NSView>(of type: T.Type, in view: NSView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { descendants(of: type, in: $0) }
    }

    private var analyticsFixtures: [AnalyticsRange: AnalyticsSnapshot] {
        let now = Date(timeIntervalSince1970: 1_788_055_200)
        let usage = TokenUsage(inputTokens: 1_000_000, cachedInputTokens: 900_000, outputTokens: 5_000)
        let models = [ModelUsageSummary(modelID: "test-model", usage: usage)]
        return Dictionary(uniqueKeysWithValues: AnalyticsRange.allCases.map { range in
            (range, AnalyticsSnapshot(
                range: range, interval: range.interval(through: now, calendar: .current), through: now,
                usage: usage, quality: .exact,
                buckets: [UsageBucket(start: now.addingTimeInterval(-60), end: now, models: models)],
                models: models,
                projects: (0..<20).map { index in
                    ProjectUsageSummary(id: "project-\(index)", name: "Project \(index)", usage: usage, models: models, sessionCount: 1)
                },
                sessions: (0..<20).map { index in
                    SessionUsageSummary(id: "session-\(index)", projectID: "project-\(index)", projectName: "Project \(index)",
                        startedAt: now, lastActivityAt: now, usage: usage, models: models,
                        directSubagentCount: 0, imageAttachmentCount: 0, parentSessionID: nil)
                }
            ))
        })
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
