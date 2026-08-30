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

    func testAllAnalyticsDetailsKeepTheSameHeightAndOneContentScroller() {
        _ = NSApplication.shared
        let empty = Dictionary(uniqueKeysWithValues: AnalyticsRange.allCases.map {
            ($0, AnalyticsSnapshot.empty(range: $0, through: Date(), calendar: .current))
        })
        for snapshots in [[:], empty, analyticsFixtures] {
            for (name, screen) in analyticsScreens {
                let hostingView = NSHostingView(rootView:
                    screen.environmentObject(UsageStore(analyticsSnapshots: snapshots))
                )
                hostingView.layoutSubtreeIfNeeded()
                XCTAssertEqual(hostingView.fittingSize.width, MenuPopoverMetrics.width, name)
                XCTAssertEqual(hostingView.fittingSize.height, MenuPopoverMetrics.analyticsDetailHeight, name)
                XCTAssertEqual(scrollViewCount(in: hostingView), 1, name)
            }
        }
    }

    func testAnalyticsFiltersStayAtTopOfTheirAllocatedHeight() throws {
        _ = NSApplication.shared
        for (name, screen) in analyticsScreens {
            let hostingView = NSHostingView(rootView:
                NavigationStack(path: .constant([name])) {
                    Text("Token Usage")
                        .frame(width: MenuPopoverMetrics.width, height: 340)
                        .navigationDestination(for: String.self) { _ in screen }
                }
                .fixedSize(horizontal: false, vertical: true)
                .environmentObject(UsageStore(analyticsSnapshots: analyticsFixtures))
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
            for control in controls {
                let frame = hostingView.convert(control.bounds, from: control)
                let top = hostingView.isFlipped ? frame.minY : hostingView.bounds.maxY - frame.maxY
                XCTAssertLessThan(top, 90, "\(name) filter has \(top)pt of space above it")
                XCTAssertLessThan(frame.height, 36, "\(name) filter must keep its native control height")
            }
            let scroll = try XCTUnwrap(descendants(of: NSScrollView.self, in: hostingView).first)
            XCTAssertGreaterThan(scroll.frame.height, 400, "\(name) content must retain most of the height")
            let frame = hostingView.convert(scroll.bounds, from: scroll)
            let top = hostingView.isFlipped ? frame.minY : hostingView.bounds.maxY - frame.maxY
            XCTAssertLessThan(top, 125, "\(name) content must start immediately below the filters")
            try captureIfRequested(hostingView, name: name)
        }
    }

    private var analyticsScreens: [(String, AnyView)] {
        [
            ("Usage", AnyView(UsageAnalyticsView())),
            ("Projects", AnyView(ProjectsAnalyticsView())),
            ("Sessions", AnyView(SessionsAnalyticsView()))
        ]
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
