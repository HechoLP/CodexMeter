import Foundation

@MainActor
final class AccountLimitStore: ObservableObject {
    @Published private(set) var snapshot: AccountLimitsSnapshot?
    @Published private(set) var status: AccountLimitStatus = .loading
    @Published private(set) var statusMessage = "Reading account limits…"
    @Published private(set) var isRefreshing = false

    private let provider: AccountLimitProviding
    private let defaults: UserDefaults
    private let pollingInterval: Duration?
    private var pollingTask: Task<Void, Never>?
    private var defaultsTask: Task<Void, Never>?
    private var inFlightReadTask: Task<AccountLimitsSnapshot, Error>?

    init(
        provider: AccountLimitProviding = AppServerLimitProvider(),
        defaults: UserDefaults = .standard,
        pollingInterval: Duration? = .seconds(120)
    ) {
        self.provider = provider
        self.defaults = defaults
        self.pollingInterval = pollingInterval
        synchronizeEnabledPreference()
        defaultsTask = Task { [weak self] in
            let changes = NotificationCenter.default.notifications(
                named: UserDefaults.didChangeNotification,
                object: nil
            )
            for await _ in changes {
                guard !Task.isCancelled else { return }
                self?.synchronizeEnabledPreference()
            }
        }
    }

    deinit {
        pollingTask?.cancel()
        defaultsTask?.cancel()
        inFlightReadTask?.cancel()
    }

    var isEnabled: Bool {
        defaults.object(forKey: "accountLimitsEnabled") == nil
            || defaults.bool(forKey: "accountLimitsEnabled")
    }

    func synchronizeEnabledPreference() {
        pollingTask?.cancel()
        pollingTask = nil
        guard isEnabled else {
            inFlightReadTask?.cancel()
            status = .disabled
            statusMessage = "Account limits are disabled"
            snapshot = nil
            return
        }
        if snapshot == nil {
            status = .loading
            statusMessage = "Reading account limits…"
        }
        guard let pollingInterval else { return }
        pollingTask = Task { [weak self] in
            await self?.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: pollingInterval)
                guard !Task.isCancelled else { return }
                await self?.refresh()
            }
        }
    }

    func refresh() async {
        guard isEnabled, !isRefreshing, !AccountSwitchActivity.isSwitching else { return }
        let accountGeneration = AccountSwitchActivity.generation
        isRefreshing = true
        if snapshot == nil { status = .loading }
        let readTask = Task { try await provider.readLimits() }
        inFlightReadTask = readTask
        defer { isRefreshing = false; inFlightReadTask = nil }
        do {
            let refreshed = try await withTaskCancellationHandler {
                try await readTask.value
            } onCancel: { readTask.cancel() }
            guard isEnabled, accountGeneration == AccountSwitchActivity.generation, !AccountSwitchActivity.isSwitching else { return }
            snapshot = refreshed
            status = .ready
            statusMessage = "Updated just now"
        } catch {
            guard isEnabled, accountGeneration == AccountSwitchActivity.generation, !AccountSwitchActivity.isSwitching else { return }
            if snapshot != nil {
                status = .stale
                statusMessage = "Showing last known limits"
            } else {
                status = .unavailable
                statusMessage = "Account limits unavailable"
            }
        }
    }

    func clearForAccountSwitch() {
        inFlightReadTask?.cancel()
        snapshot = nil
        status = .loading
        statusMessage = "Switching account…"
    }
}
