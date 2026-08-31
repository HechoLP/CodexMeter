import AppKit
import SwiftUI
import XCTest
@testable import CodexMeter

@MainActor
final class MenuPopoverLayoutTests: XCTestCase {
    func testClaudeAndCodexProviderScreensFitBothAppearances() throws {
        _ = NSApplication.shared
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: "usageProvider")
        defer {
            if let previous { defaults.set(previous, forKey: "usageProvider") }
            else { defaults.removeObject(forKey: "usageProvider") }
        }
        let usage = TokenUsage(inputTokens: 1_200_000, cachedInputTokens: 900_000,
                               cacheWriteInputTokens: 100_000, outputTokens: 50_000)
        let snapshot = UsageSnapshot(today: usage, week: usage, month: usage, allTime: usage,
                                     quality: .exact, updatedAt: Date())
        for provider in UsageProvider.allCases {
            defaults.set(provider.rawValue, forKey: "usageProvider")
            for dark in [false, true] {
                for empty in [false, true] {
                    let name = "\(provider.rawValue)-\(empty ? "empty" : "ready")-\(dark ? "dark" : "light")"
                    let store = UsageStore(provider: provider,
                        initialSnapshot: empty ? .empty : snapshot, automaticallyRefresh: false)
                    let host = NSHostingView(rootView:
                        MenuPopoverView(accounts: AccountLayoutFixture.emptyStore())
                            .environmentObject(store)
                            .environmentObject(ProfileUsageStore())
                            .environmentObject(AccountLimitStore(provider: CollapsedPopoverTestLimitProvider(), pollingInterval: nil))
                            .environment(\.colorScheme, dark ? .dark : .light)
                    )
                    host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                    for _ in 0..<5 {
                        host.setFrameSize(host.fittingSize)
                        host.layoutSubtreeIfNeeded()
                    }
                    XCTAssertEqual(host.fittingSize.width, MenuPopoverMetrics.width, name)
                    XCTAssertLessThanOrEqual(host.fittingSize.height, 700, name)
                    XCTAssertFalse(containsScrollView(in: host), name)
                    let selector = try XCTUnwrap(descendants(of: NSSegmentedControl.self, in: host).first)
                    XCTAssertEqual(selector.segmentCount, 2)
                    XCTAssertEqual(selector.selectedSegment, provider == .codex ? 0 : 1)
                    XCTAssertTrue(selector.isEnabled)
                    XCTAssertEqual(selector.label(forSegment: 1), "Claude Code")
                    try captureIfRequested(host, name: name)
                }
            }
        }
    }

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
            ["Usage limits", "Today", "History", "Details"]
        )
    }

    func testClaudeDetailScreensPreserveProviderContext() throws {
        _ = NSApplication.shared
        for dark in [false, true] {
            for destination in analyticsDestinations {
                let host = NSHostingView(rootView:
                    MenuPopoverView(accounts: AccountLayoutFixture.emptyStore(),
                        navigation: MenuNavigation(path: [destination]))
                        .environmentObject(UsageStore(provider: .claude,
                            analyticsSnapshots: makeAnalyticsFixtures(provider: .claude),
                            automaticallyRefresh: false))
                        .environmentObject(ProfileUsageStore())
                        .environmentObject(AccountLimitStore(provider: CollapsedPopoverTestLimitProvider(), pollingInterval: nil))
                        .environment(\.colorScheme, dark ? .dark : .light)
                )
                host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                for _ in 0..<5 {
                    host.setFrameSize(host.fittingSize)
                    host.layoutSubtreeIfNeeded()
                }
                XCTAssertEqual(host.fittingSize.width, MenuPopoverMetrics.width)
                XCTAssertLessThanOrEqual(host.fittingSize.height, 580)
                XCTAssertEqual(scrollViewCount(in: host), 1)
                try captureIfRequested(host, name: "claude-\(destination.title(usesProfileTotals: false))-\(dark ? "dark" : "light")")
            }
        }
    }

    func testPopoverFittingSizeShowsContentWithoutEmbeddingAScrollView() {
        _ = NSApplication.shared
        let store = UsageStore()
        let profileStore = ProfileUsageStore()
        let limitStore = AccountLimitStore(
            provider: CollapsedPopoverTestLimitProvider(),
            pollingInterval: nil
        )
        let view = MenuPopoverView(accounts: AccountLayoutFixture.emptyStore())
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

    func testPolishedPopoverFitsBothAppearancesWithLongNamesAndLargeTotals() throws {
        _ = NSApplication.shared
        let destinations: [MenuDestination?] = [nil, .usage, .projects, .sessions]
        for dark in [false, true] {
            for destination in destinations {
                let name = destination?.title(usesProfileTotals: false) ?? "Overview"
                let hostingView = NSHostingView(rootView:
                    popover(destination: destination, snapshots: makeAnalyticsFixtures(longContent: true))
                        .environment(\.colorScheme, dark ? .dark : .light)
                )
                hostingView.appearance = NSAppearance(named:
                    dark ? .accessibilityHighContrastDarkAqua : .accessibilityHighContrastAqua
                )
                // Settle the measured scroll content before capturing an
                // unattached host, as a real menu window resizes with its content.
                for _ in 0..<5 {
                    hostingView.setFrameSize(hostingView.fittingSize)
                    hostingView.layoutSubtreeIfNeeded()
                }
                XCTAssertEqual(hostingView.fittingSize.width, MenuPopoverMetrics.width, name)
                // Overview keeps all three sections visible; detail screens
                // retain their tighter, independently bounded content viewport.
                XCTAssertLessThanOrEqual(hostingView.fittingSize.height, destination == nil ? 700 : 580, name)
                XCTAssertEqual(scrollViewCount(in: hostingView), destination == nil ? 0 : 1)
                if destination != nil {
                    let first = try XCTUnwrap(descendants(of: NSSegmentedControl.self, in: hostingView)
                        .map { topOriginFrame(of: $0, in: hostingView) }.min { $0.minY < $1.minY })
                    XCTAssertEqual(first.minY - MenuPopoverMetrics.detailHeaderHeight, 12, accuracy: 3, name)
                }
                try captureIfRequested(hostingView, name: "\(name)-\(dark ? "dark" : "light")")
            }
        }
    }

    func testMenuInteractionStylingKeepsDisabledControlsTheSameSize() {
        _ = NSApplication.shared
        var sizes: [NSSize] = []
        for enabled in [true, false] {
            let hostingView = NSHostingView(rootView:
                Button("Refresh") {}.frame(width: 100, height: 28)
                    .buttonStyle(MenuInteractionStyle())
                    .disabled(!enabled)
            )
            hostingView.layoutSubtreeIfNeeded()
            sizes.append(hostingView.fittingSize)
        }
        XCTAssertEqual(sizes[0], sizes[1])
        XCTAssertEqual(sizes[0], NSSize(width: 100, height: 28))
    }

    func testUnknownCostIsOmittedFromRowsButRetainedInDetails() throws {
        _ = NSApplication.shared
        let suite = "CodexMeter.MenuCopyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let through = Date(timeIntervalSince1970: 1_800_000_000)
        let model = ModelUsageSummary(modelID: "unpriced-model", usage: TokenUsage(inputTokens: 10, cachedInputTokens: 2, outputTokens: 1))
        var rowSizes: [NSSize] = []
        for enabled in [false, true] {
            defaults.set(enabled, forKey: "costEstimatesEnabled")
            let row = NSHostingView(rootView:
                analyticsRow("Model", tokens: 11, models: [model], through: through, quality: .exact)
                    .frame(width: MenuPopoverMetrics.width)
                    .defaultAppStorage(defaults)
            )
            row.layoutSubtreeIfNeeded()
            rowSizes.append(row.fittingSize)
        }
        XCTAssertEqual(rowSizes[0], rowSizes[1], "Unknown costs must not add a repeated row or a zero estimate")
        for quality: DataQuality in [.exact, .partial, .stale, .error] {
            let detail = NSHostingView(rootView:
                EstimatedCostText(models: [model], through: through, quality: quality, compact: false)
                    .defaultAppStorage(defaults)
            )
            detail.layoutSubtreeIfNeeded()
            XCTAssertGreaterThan(detail.fittingSize.height, 0, "Unavailable costs must remain explicit in details")
        }
    }

    func testAvailableCostStillAppearsInAnalyticsRows() throws {
        _ = NSApplication.shared
        let suite = "CodexMeter.MenuCopyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let through = Date(timeIntervalSince1970: 1_800_000_000)
        let model = ModelUsageSummary(modelID: "gpt-5.5", usage: TokenUsage(inputTokens: 10, cachedInputTokens: 2, outputTokens: 1))
        var rowHeights: [CGFloat] = []
        for enabled in [false, true] {
            defaults.set(enabled, forKey: "costEstimatesEnabled")
            let row = NSHostingView(rootView:
                analyticsRow("Model", tokens: 11, models: [model], through: through, quality: .exact)
                    .frame(width: MenuPopoverMetrics.width)
                    .defaultAppStorage(defaults)
            )
            row.layoutSubtreeIfNeeded()
            rowHeights.append(row.fittingSize.height)
        }
        XCTAssertGreaterThan(rowHeights[1], rowHeights[0], "Valid estimates still need their secondary row")
    }

    func testLimitsKeepCompactDetailsInReadyAndStaleStates() async throws {
        _ = NSApplication.shared
        let suite = "CodexMeter.MenuCopyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "accountLimitsEnabled")
        defaults.set(true, forKey: "additionalLimitsEnabled")
        defaults.set(true, forKey: "resetCreditsEnabled")
        let store = AccountLimitStore(provider: MenuCopyTestLimitProvider(), defaults: defaults, pollingInterval: nil)
        for stale in [false, true] {
            await store.refresh()
            XCTAssertEqual(store.status, stale ? .stale : .ready)
            let hostingView = NSHostingView(rootView:
                MenuPopoverView(accounts: AccountLayoutFixture.emptyStore(), navigation: MenuNavigation(path: [.limits]))
                    .environmentObject(UsageStore())
                    .environmentObject(ProfileUsageStore())
                    .environmentObject(store)
                    .defaultAppStorage(defaults)
                    .environment(\.colorScheme, .dark)
            )
            hostingView.appearance = NSAppearance(named: .darkAqua)
            for _ in 0..<5 {
                hostingView.setFrameSize(hostingView.fittingSize)
                hostingView.layoutSubtreeIfNeeded()
            }
            XCTAssertEqual(hostingView.fittingSize.width, MenuPopoverMetrics.width)
            XCTAssertLessThanOrEqual(hostingView.fittingSize.height, MenuPopoverMetrics.detailMaximumHeight + MenuPopoverMetrics.detailHeaderHeight + 1)
            try captureIfRequested(hostingView, name: stale ? "Limits-stale" : "Limits-ready")
        }
    }

    private func viewport(height: CGFloat) -> some View {
        ContentFittingScrollView(maximumHeight: 440) {
            Color.clear.frame(height: height)
        }
        .frame(width: MenuPopoverMetrics.width)
    }

    private var analyticsDestinations: [MenuDestination] { [.usage, .projects, .sessions] }

    private func popover(destination: MenuDestination?, snapshots: [AnalyticsRange: AnalyticsSnapshot]) -> some View {
        MenuPopoverView(accounts: AccountLayoutFixture.emptyStore(), navigation: MenuNavigation(path: destination.map { [$0] } ?? []))
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
        makeAnalyticsFixtures()
    }

    private func makeAnalyticsFixtures(longContent: Bool = false, provider: UsageProvider = .codex) -> [AnalyticsRange: AnalyticsSnapshot] {
        let now = Date(timeIntervalSince1970: 1_788_055_200)
        let usage = TokenUsage(inputTokens: longContent ? 1_234_567_890_123 : 1_000_000,
                               cachedInputTokens: 900_000, outputTokens: 5_000)
        let models = [ModelUsageSummary(
            modelID: provider == .claude ? "claude-sonnet-4-6"
                : (longContent ? "test-model-with-a-long-identifier" : "test-model"), usage: usage
        )]
        let projectName = longContent ? "A long project name · 긴 프로젝트 이름" : "Project"
        return Dictionary(uniqueKeysWithValues: AnalyticsRange.allCases.map { range in
            (range, AnalyticsSnapshot(
                range: range, interval: range.interval(through: now, calendar: .current), through: now,
                usage: usage, quality: .exact,
                buckets: [UsageBucket(start: now.addingTimeInterval(-60), end: now, models: models)],
                models: models,
                projects: (0..<20).map { index in
                    ProjectUsageSummary(id: "project-\(index)", name: "\(projectName) \(index)", usage: usage, models: models, sessionCount: 1)
                },
                sessions: (0..<20).map { index in
                    SessionUsageSummary(id: "session-\(index)", projectID: "project-\(index)", projectName: "\(projectName) \(index)",
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

private actor MenuCopyTestLimitProvider: AccountLimitProviding {
    private var didRead = false

    func readLimits() async throws -> AccountLimitsSnapshot {
        guard !didRead else { throw AccountLimitError.trustedAppServerNotFound }
        didRead = true
        let now = Date()
        return AccountLimitsSnapshot(
            windows: [
                AccountLimitWindow(id: "weekly", limitID: "codex", displayName: "Codex", windowDurationMinutes: 10_080,
                                   usedPercent: 1, resetsAt: now.addingTimeInterval(6 * 86_400)),
                AccountLimitWindow(id: "spark-short", limitID: "spark", displayName: "GPT-5.3-Codex-Spark", windowDurationMinutes: 300,
                                   usedPercent: 90, resetsAt: now.addingTimeInterval(3 * 3_600)),
                AccountLimitWindow(id: "spark-weekly", limitID: "spark", displayName: "GPT-5.3-Codex-Spark", windowDurationMinutes: 10_080,
                                   usedPercent: 0, resetsAt: now.addingTimeInterval(6 * 86_400))
            ],
            resetCredits: ResetCreditSummary(availableCount: 1, unlimited: false, expiresAt: nil), fetchedAt: now
        )
    }
}
