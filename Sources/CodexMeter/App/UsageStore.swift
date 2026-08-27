import AppKit
import Foundation
import SwiftUI

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot = UsageSnapshot.empty
    @Published private(set) var isRefreshing = false
    @Published private(set) var isMaintainingData = false
    @Published private(set) var statusMessage = "Looking for Codex usage…"
    @Published private(set) var lastRefreshAt: Date?
    @Published private(set) var dataStatistics = DataStatistics.empty
    @Published private(set) var sourceCount = 0

    private let formatter = TokenFormatter()
    private let defaults = UserDefaults.standard
    private var collector: CodexUsageCollector?
    private var watcher: CodexSessionWatcher?
    private var watcherTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var refreshSchedulerTask: Task<Void, Never>?
    private var wakeTask: Task<Void, Never>?
    private var defaultsTask: Task<Void, Never>?
    private var refreshPending = false
    private var previousWeekStartRawValue = WeekStart.monday.rawValue

    var menuBarText: String {
        let displayRawValue = defaults.string(forKey: "menuBarDisplay") ?? MenuBarDisplay.total.rawValue
        let periodRawValue = defaults.string(forKey: "menuBarPeriod") ?? UsagePeriod.today.rawValue
        let numberStyleRawValue = defaults.string(forKey: "numberStyle") ?? TokenNumberStyle.compact.rawValue
        let display = MenuBarDisplay(rawValue: displayRawValue) ?? .total
        let period = UsagePeriod(rawValue: periodRawValue) ?? .today
        let style = TokenNumberStyle(rawValue: numberStyleRawValue) ?? .compact
        let usage = snapshot.totals(for: period)

        return switch display {
        case .total:
            formatter.string(from: usage.totalTokens, style: style)
        case .inputOutput:
            "↑\(formatter.string(from: usage.inputTokens, style: style)) ↓\(formatter.string(from: usage.outputTokens, style: style))"
        case .input:
            "↑\(formatter.string(from: usage.inputTokens, style: style))"
        case .output:
            "↓\(formatter.string(from: usage.outputTokens, style: style))"
        case .iconOnly:
            ""
        }
    }

    var menuBarAccessibilityLabel: String {
        let periodRawValue = defaults.string(forKey: "menuBarPeriod") ?? UsagePeriod.today.rawValue
        let period = UsagePeriod(rawValue: periodRawValue) ?? .today
        let usage = snapshot.totals(for: period)
        let periodName = switch period {
        case .today: "today"
        case .week: "this week"
        case .month: "this month"
        case .allTime: "all time"
        }
        return "CodexMeter, \(usage.totalTokens) total tokens \(periodName)"
    }

    init() {
        previousWeekStartRawValue = storedWeekStartRawValue
        refreshSchedulerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled, let self else { return }
                self.refreshIfScheduled()
            }
        }
        wakeTask = Task { [weak self] in
            let notifications = NSWorkspace.shared.notificationCenter.notifications(
                named: NSWorkspace.didWakeNotification
            )
            for await _ in notifications {
                guard !Task.isCancelled else { return }
                await self?.refresh()
            }
        }
        defaultsTask = Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: UserDefaults.didChangeNotification,
                object: nil
            )
            for await _ in notifications {
                guard !Task.isCancelled, let self else { return }
                self.objectWillChange.send()
                let weekStart = self.storedWeekStartRawValue
                if weekStart != self.previousWeekStartRawValue {
                    self.previousWeekStartRawValue = weekStart
                    await self.refresh()
                }
            }
        }
    }

    func refresh() async {
        guard !isMaintainingData else {
            refreshPending = true
            return
        }
        guard !isRefreshing else {
            refreshPending = true
            return
        }
        isRefreshing = true
        await DiagnosticsLogger.shared.record(.refreshStarted)
        defer {
            isRefreshing = false
            if refreshPending {
                refreshPending = false
                scheduleRefresh(delay: .milliseconds(100))
            }
        }

        do {
            let collector = try await collector()
            let weekStart = selectedWeekStart
            if snapshot.updatedAt == nil {
                let cached = try await collector.cachedSnapshot(weekStart: weekStart)
                if cached.updatedAt != nil {
                    snapshot = cached
                    statusMessage = "Updating local usage…"
                } else {
                    statusMessage = "Scanning local Codex usage…"
                }
            }
            let result = try await collector.refresh(weekStart: weekStart)
            if result.snapshot != snapshot {
                snapshot = result.snapshot
            }
            dataStatistics = result.statistics
            sourceCount = result.sourceCount
            lastRefreshAt = Date()
            await DiagnosticsLogger.shared.record(
                .refreshCompleted(
                    quality: result.snapshot.quality,
                    sourceCount: result.sourceCount,
                    processedBytes: result.processedBytes
                )
            )
            switch result.snapshot.quality {
            case .exact:
                statusMessage = result.snapshot.updatedAt == nil ? "No Codex usage found" : "Updated just now"
            case .partial:
                statusMessage = "Some history is incomplete"
            case .stale:
                statusMessage = "Showing the last good update"
            case .unavailable:
                statusMessage = result.sourceCount == 0 ? "Codex sessions not found" : "No Codex usage found"
            case .error:
                statusMessage = "Unable to update usage"
            }
        } catch is CancellationError {
            statusMessage = snapshot.updatedAt == nil ? "Refresh cancelled" : "Showing the last good update"
        } catch {
            await DiagnosticsLogger.shared.record(
                .refreshFailed(hasCachedSnapshot: snapshot.updatedAt != nil)
            )
            if snapshot.updatedAt != nil {
                snapshot.quality = .stale
                statusMessage = "Showing the last good update"
            } else {
                snapshot.quality = .error
                statusMessage = "Unable to read local usage"
            }
        }
    }

    func rebuildStatistics() async {
        guard !isMaintainingData, !isRefreshing else { return }
        isMaintainingData = true
        statusMessage = "Rebuilding local statistics…"
        defer { isMaintainingData = false }

        do {
            let collector = try await collector()
            let weekStart = selectedWeekStart
            let result = try await collector.rebuild(weekStart: weekStart)
            snapshot = result.snapshot
            dataStatistics = result.statistics
            sourceCount = result.sourceCount
            refreshPending = false
            lastRefreshAt = Date()
            await DiagnosticsLogger.shared.record(.rebuildCompleted(quality: result.snapshot.quality))
            statusMessage = result.snapshot.quality == .partial ? "Some history is incomplete" : "Rebuild complete"
        } catch {
            await DiagnosticsLogger.shared.record(.rebuildFailed)
            snapshot.quality = snapshot.updatedAt == nil ? .error : .stale
            statusMessage = "Unable to rebuild statistics"
        }
    }

    func clearLocalHistory() async {
        guard !isMaintainingData, !isRefreshing else { return }
        isMaintainingData = true
        statusMessage = "Clearing local history…"
        defer { isMaintainingData = false }

        do {
            let collector = try await collector()
            let weekStart = selectedWeekStart
            let result = try await collector.clearLocalHistory(weekStart: weekStart)
            snapshot = result.snapshot
            dataStatistics = result.statistics
            sourceCount = result.sourceCount
            refreshPending = false
            lastRefreshAt = Date()
            await DiagnosticsLogger.shared.record(.clearCompleted)
            statusMessage = "Local history cleared"
        } catch {
            await DiagnosticsLogger.shared.record(.clearFailed)
            snapshot.quality = snapshot.updatedAt == nil ? .error : .stale
            statusMessage = "Unable to clear local history"
        }
    }

    private func collector() async throws -> CodexUsageCollector {
        if let collector { return collector }

        let setup = try await Task.detached(priority: .utility) {
            let database = try SQLiteDatabase(url: AppPaths.databaseURL)
            let roots = CodexSourceDiscovery().defaultRoots()
            return (database, roots)
        }.value

        let collector = CodexUsageCollector(database: setup.0, roots: setup.1)
        self.collector = collector
        startWatcher(roots: setup.1)
        return collector
    }

    private func startWatcher(roots: [URL]) {
        guard watcher == nil else { return }
        let existingRoots = roots.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !existingRoots.isEmpty else { return }

        let watcher = CodexSessionWatcher(roots: existingRoots)
        self.watcher = watcher
        watcher.start()
        watcherTask = Task { [weak self, watcher] in
            for await _ in watcher.events {
                guard !Task.isCancelled else { return }
                self?.scheduleRefresh()
            }
        }
    }

    private func scheduleRefresh() {
        scheduleRefresh(delay: .milliseconds(500))
    }

    private func scheduleRefresh(delay: Duration) {
        guard currentRefreshMode == "automatic" else { return }
        guard debounceTask == nil else { return }
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.debounceTask = nil
            await self?.refresh()
        }
    }

    private var currentRefreshMode: String {
        defaults.string(forKey: "refreshMode") ?? "automatic"
    }

    private var selectedWeekStart: WeekStart {
        WeekStart(rawValue: storedWeekStartRawValue) ?? .monday
    }

    private var storedWeekStartRawValue: Int {
        defaults.object(forKey: "weekStart") == nil
            ? WeekStart.monday.rawValue
            : defaults.integer(forKey: "weekStart")
    }

    private func refreshIfScheduled(now: Date = Date()) {
        guard let seconds = TimeInterval(currentRefreshMode), seconds > 0 else { return }
        guard let lastRefreshAt else {
            Task { await refresh() }
            return
        }
        guard now.timeIntervalSince(lastRefreshAt) >= seconds else { return }
        Task { await refresh() }
    }

    deinit {
        watcherTask?.cancel()
        debounceTask?.cancel()
        refreshSchedulerTask?.cancel()
        wakeTask?.cancel()
        defaultsTask?.cancel()
    }
}

enum MenuBarDisplay: String, CaseIterable, Identifiable {
    case total
    case inputOutput
    case input
    case output
    case iconOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .total: "Total Tokens"
        case .inputOutput: "Input / Output"
        case .input: "Input Only"
        case .output: "Output Only"
        case .iconOnly: "Icon Only"
        }
    }
}
