import Foundation
import SwiftUI

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot = UsageSnapshot.empty
    @Published private(set) var isRefreshing = false
    @Published private(set) var statusMessage = "Looking for Codex usage…"

    @AppStorage("menuBarDisplay") private var displayRawValue = MenuBarDisplay.total.rawValue
    @AppStorage("menuBarPeriod") private var periodRawValue = UsagePeriod.today.rawValue
    @AppStorage("numberStyle") private var numberStyleRawValue = TokenNumberStyle.compact.rawValue
    @AppStorage("weekStart") private var weekStartRawValue = WeekStart.monday.rawValue

    private let formatter = TokenFormatter()
    private var collector: CodexUsageCollector?
    private var watcher: CodexSessionWatcher?
    private var watcherTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?

    var menuBarText: String {
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

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        if snapshot.updatedAt == nil {
            statusMessage = "Scanning local Codex usage…"
        }

        do {
            let collector = try await collector()
            let weekStart = WeekStart(rawValue: weekStartRawValue) ?? .monday
            let result = try await collector.refresh(weekStart: weekStart)
            if result.snapshot != snapshot {
                snapshot = result.snapshot
            }
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
            if snapshot.updatedAt != nil {
                snapshot.quality = .stale
                statusMessage = "Showing the last good update"
            } else {
                snapshot.quality = .error
                statusMessage = "Unable to read local usage"
            }
        }
    }

    private func collector() async throws -> CodexUsageCollector {
        if let collector { return collector }

        let setup = try await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library/Application Support", isDirectory: true)
            let databaseURL = applicationSupport
                .appendingPathComponent("CodexMeter", isDirectory: true)
                .appendingPathComponent("CodexMeter.sqlite")
            let database = try SQLiteDatabase(url: databaseURL)
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
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }

    deinit {
        watcherTask?.cancel()
        debounceTask?.cancel()
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
