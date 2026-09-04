import AppKit
import ClaudeBridgeCore
import CryptoKit
import Foundation

struct ClaudeAccount: Equatable, Sendable {
    let email: String?
    let subscriptionType: String?
    let authenticationMethod: String?
    let linkIdentifier: String

    init(
        email: String?,
        subscriptionType: String?,
        authenticationMethod: String?,
        stableIdentity: String? = nil
    ) {
        self.email = email
        self.subscriptionType = subscriptionType
        self.authenticationMethod = authenticationMethod
        let identity = stableIdentity ?? email ?? [authenticationMethod, subscriptionType]
            .compactMap { $0 }
            .joined(separator: ":")
        linkIdentifier = SHA256.hash(data: Data(identity.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    var displayName: String { email ?? "Claude account" }
    var planName: String? {
        subscriptionType.map { $0.replacingOccurrences(of: "_", with: " ").capitalized }
    }
}

enum ClaudeIntegrationStatus: Equatable, Sendable {
    case disabled
    case checking
    case needsAccount
    case ready
    case stale
    case waitingForLimits
    case unavailable
}

enum ClaudeIntegrationError: Error, LocalizedError, Equatable {
    case cliNotFound
    case processFailed
    case timedOut
    case responseTooLarge
    case malformedResponse
    case noSignedInAccount
    case bridgeNotFound
    case invalidSettings

    var errorDescription: String? {
        switch self {
        case .cliNotFound: "Claude Code was not found. Make sure the `claude` command runs in your terminal."
        case .processFailed: "Claude Code could not be opened."
        case .timedOut: "Checking the Claude account took too long."
        case .responseTooLarge, .malformedResponse: "Claude returned an unsupported account response."
        case .noSignedInAccount: "Sign in to Claude Code, then add the account again."
        case .bridgeNotFound: "The Claude limits helper is missing. Reinstall CodexMeter."
        case .invalidSettings: "Claude settings could not be updated safely."
        }
    }
}

protocol ClaudeAuthenticating: Sendable {
    func accountStatus() async throws -> ClaudeAccount?
}

protocol ClaudeStatusLineInstalling: Sendable {
    func install() throws
    func uninstall() throws
}

struct ClaudeCLIService: ClaudeAuthenticating {
    private static let maximumStatusBytes = 131_072

    func accountStatus() async throws -> ClaudeAccount? {
        let data = try await ClaudeCommandRunner.run(
            executable: try ClaudeExecutable.resolve(),
            arguments: ["auth", "status"],
            timeout: .seconds(10),
            maximumOutputBytes: Self.maximumStatusBytes,
            acceptsNonzeroExit: true
        )
        return try Self.account(from: data)
    }

    static func account(from data: Data) throws -> ClaudeAccount? {
        guard !data.isEmpty else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let loggedIn = object["loggedIn"] as? Bool
        else { throw ClaudeIntegrationError.malformedResponse }
        guard loggedIn else { return nil }
        let email = Self.safeText(object["email"])
        let organizationID = Self.safeText(object["orgId"])
        let stableIdentity = [organizationID, email]
            .compactMap { $0 }
            .joined(separator: "\u{1F}")
        guard !stableIdentity.isEmpty else { throw ClaudeIntegrationError.malformedResponse }
        return ClaudeAccount(
            email: email,
            subscriptionType: Self.safeText(object["subscriptionType"]),
            authenticationMethod: Self.safeText(object["authMethod"]),
            stableIdentity: stableIdentity
        )
    }

    private static func safeText(_ value: Any?) -> String? {
        guard let text = value as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.utf8.count <= 320,
              !trimmed.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
        else { return nil }
        return trimmed
    }
}

enum ClaudeExecutable {
    static func resolve(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> URL {
        var candidates = [
            home.appendingPathComponent(".local/bin/claude"),
            home.appendingPathComponent(".claude/local/claude"),
            URL(fileURLWithPath: "/opt/homebrew/bin/claude"),
            URL(fileURLWithPath: "/usr/local/bin/claude")
        ]
        // A GUI launch usually inherits a minimal PATH, but honor a fuller one
        // (Node version managers, custom prefixes) when the launch environment has it.
        for directory in (environment["PATH"] ?? "").split(separator: ":") where directory.hasPrefix("/") {
            candidates.append(URL(fileURLWithPath: String(directory), isDirectory: true)
                .appendingPathComponent("claude"))
        }
        guard let executable = candidates.first(where: { fileManager.isExecutableFile(atPath: $0.path) }) else {
            throw ClaudeIntegrationError.cliNotFound
        }
        return executable.standardizedFileURL
    }
}

struct ClaudeStatusLineInstaller: ClaudeStatusLineInstalling, @unchecked Sendable {
    private let settingsURL: URL
    private let managedDirectory: URL
    private let bridgeSource: @Sendable () throws -> URL
    private let fileManager: FileManager

    init(
        settingsURL: URL = ClaudeStatusLineInstaller.defaultSettingsURL(),
        managedDirectory: URL = AppPaths.applicationSupportDirectory
            .appendingPathComponent("Claude", isDirectory: true),
        fileManager: FileManager = .default,
        bridgeSource: @escaping @Sendable () throws -> URL = ClaudeStatusLineInstaller.resolveBundledBridge
    ) {
        self.settingsURL = settingsURL
        self.managedDirectory = managedDirectory
        self.fileManager = fileManager
        self.bridgeSource = bridgeSource
    }

    func install() throws {
        try AppPaths.prepareOwnerOnlyDirectory(at: managedDirectory, fileManager: fileManager)
        let installedBridge = managedDirectory.appendingPathComponent("CodexMeterClaudeBridge")
        try installBridge(from: bridgeSource(), to: installedBridge)
        let output = managedDirectory.appendingPathComponent("ClaudeLimits.json")
        let command = "\(shellQuote(installedBridge.path)) --output \(shellQuote(output.path))"

        var settings = try readJSONObject(at: settingsURL) ?? [:]
        let stateURL = managedDirectory.appendingPathComponent("StatusLineState.json")
        guard statusLineCommand(settings["statusLine"]) != command else { return }

        // Capture the user's real status line exactly once. On any later install
        // (an app move that changes the helper path, or a status line the user
        // edited while connected) keep the first-captured original so uninstall
        // still restores it instead of stranding it behind a CodexMeter command.
        let existingState = try? readJSONObject(at: stateURL)
        let alreadyInstalled = (existingState?["installedCommand"] as? String).map { !$0.isEmpty } ?? false
        let currentIsManaged = statusLineCommand(settings["statusLine"])?
            .contains(installedBridge.path) ?? false
        let state: [String: Any]
        if alreadyInstalled, let existingState {
            state = [
                "version": 1,
                "installedCommand": command,
                "hadOriginal": existingState["hadOriginal"] as? Bool ?? false,
                "originalStatusLine": existingState["originalStatusLine"] ?? NSNull()
            ]
        } else {
            state = [
                "version": 1,
                "installedCommand": command,
                "hadOriginal": !currentIsManaged && settings["statusLine"] != nil,
                "originalStatusLine": currentIsManaged ? NSNull() : (settings["statusLine"] ?? NSNull())
            ]
        }
        try writeJSONObject(state, to: stateURL, permissions: 0o600)
        settings["statusLine"] = ["type": "command", "command": command]
        try writeJSONObject(settings, to: settingsURL, permissions: 0o600)
    }

    func uninstall() throws {
        let stateURL = managedDirectory.appendingPathComponent("StatusLineState.json")
        guard let state = try readJSONObject(at: stateURL),
              let installedCommand = state["installedCommand"] as? String,
              var settings = try readJSONObject(at: settingsURL)
        else { return }

        if statusLineCommand(settings["statusLine"]) == installedCommand {
            if state["hadOriginal"] as? Bool == true,
               let original = state["originalStatusLine"], !(original is NSNull) {
                settings["statusLine"] = original
            } else {
                settings.removeValue(forKey: "statusLine")
            }
            try writeJSONObject(settings, to: settingsURL, permissions: 0o600)
        }
        try? fileManager.removeItem(at: stateURL)
    }

    static func defaultSettingsURL(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        if let configured = environment["CLAUDE_CONFIG_DIR"], configured.hasPrefix("/"),
           !configured.contains("\0") {
            return URL(fileURLWithPath: configured, isDirectory: true)
                .appendingPathComponent("settings.json")
        }
        return home.appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    static func resolveBundledBridge() throws -> URL {
        let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent()
        let candidates = [
            Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/CodexMeterClaudeBridge"),
            executableDirectory?.appendingPathComponent("CodexMeterClaudeBridge")
        ].compactMap { $0 }
        guard let source = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) else {
            throw ClaudeIntegrationError.bridgeNotFound
        }
        return source
    }

    private func installBridge(from source: URL, to destination: URL) throws {
        guard fileManager.isExecutableFile(atPath: source.path) else {
            throw ClaudeIntegrationError.bridgeNotFound
        }
        if bridgeMatches(source: source, destination: destination) {
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: destination.path)
            return
        }
        let temporary = destination.deletingLastPathComponent()
            .appendingPathComponent(".CodexMeterClaudeBridge-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: temporary) }
        try fileManager.copyItem(at: source, to: temporary)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: temporary.path)
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }
    }

    private func bridgeMatches(source: URL, destination: URL) -> Bool {
        guard fileManager.fileExists(atPath: destination.path),
              let sourceSize = try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              let destinationSize = try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              sourceSize == destinationSize,
              let sourceData = try? Data(contentsOf: source, options: .mappedIfSafe),
              let destinationData = try? Data(contentsOf: destination, options: .mappedIfSafe)
        else { return false }
        return sourceData == destinationData
    }

    private func readJSONObject(at url: URL) throws -> [String: Any]? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count <= 1_048_576,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw ClaudeIntegrationError.invalidSettings }
        return object
    }

    private func writeJSONObject(_ object: [String: Any], to url: URL, permissions: Int) throws {
        guard JSONSerialization.isValidJSONObject(object) else { throw ClaudeIntegrationError.invalidSettings }
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: permissions], ofItemAtPath: url.path)
    }

    private func statusLineCommand(_ value: Any?) -> String? {
        (value as? [String: Any])?["command"] as? String
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

@MainActor
final class ClaudeIntegrationStore: ObservableObject {
    private static let maximumFreshLimitAge: TimeInterval = 15 * 60

    @Published private(set) var isEnabled: Bool
    @Published private(set) var isConnected = false
    @Published private(set) var detectedAccount: ClaudeAccount?
    @Published private(set) var account: ClaudeAccount?
    @Published private(set) var snapshot: AccountLimitsSnapshot?
    @Published private(set) var status: ClaudeIntegrationStatus
    @Published private(set) var statusMessage: String
    @Published private(set) var isRefreshing = false

    var onAvailabilityChanged: ((Bool) -> Void)?

    private let authenticator: ClaudeAuthenticating
    private let installer: ClaudeStatusLineInstalling
    private let defaults: UserDefaults
    private let limitsURL: URL
    private let now: @Sendable () -> Date
    private var pollingTask: Task<Void, Never>?
    private var lastAvailability = false
    private var operationGeneration = 0

    init(
        authenticator: ClaudeAuthenticating = ClaudeCLIService(),
        installer: ClaudeStatusLineInstalling = ClaudeStatusLineInstaller(),
        defaults: UserDefaults = .standard,
        limitsURL: URL = AppPaths.applicationSupportDirectory
            .appendingPathComponent("Claude/ClaudeLimits.json"),
        now: @escaping @Sendable () -> Date = Date.init,
        automaticallyRefresh: Bool = true
    ) {
        self.authenticator = authenticator
        self.installer = installer
        self.defaults = defaults
        self.limitsURL = limitsURL
        self.now = now
        let enabled = defaults.bool(forKey: "claudeEnabled")
        isEnabled = enabled
        status = enabled ? .checking : .disabled
        statusMessage = enabled ? "Checking Claude account…" : "Claude is turned off"
        guard automaticallyRefresh else { return }
        startAutomaticRefresh()
    }

    func startAutomaticRefresh() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            await self?.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(120))
                guard !Task.isCancelled else { return }
                await self?.refresh()
            }
        }
    }

    deinit { pollingTask?.cancel() }

    var isAvailable: Bool { isEnabled && isConnected }

    func setEnabled(_ enabled: Bool) async {
        guard isEnabled != enabled else { return }
        if enabled {
            isEnabled = true
            defaults.set(true, forKey: "claudeEnabled")
            status = .checking
            statusMessage = "Checking Claude account…"
            await refresh()
        } else {
            cancelCurrentOperation()
            do {
                try await performUninstall()
            } catch {
                status = .unavailable
                statusMessage = "Claude could not be turned off safely. Try again."
                return
            }
            isEnabled = false
            defaults.set(false, forKey: "claudeEnabled")
            isConnected = false
            detectedAccount = nil
            account = nil
            snapshot = nil
            status = .disabled
            statusMessage = "Claude is turned off"
            defaults.set(UsageProvider.codex.rawValue, forKey: "usageProvider")
            notifyAvailabilityIfNeeded()
        }
    }

    func addCurrentAccount() async {
        guard isEnabled, !isRefreshing else { return }
        let operation = beginOperation()
        status = .checking
        statusMessage = "Checking Claude account…"
        defer { finishOperation(operation) }
        do {
            let detected = try await authenticator.accountStatus()
            guard isCurrent(operation), isEnabled else { return }
            guard let found = detected else {
                detectedAccount = nil
                account = nil
                isConnected = false
                status = .needsAccount
                statusMessage = "Sign in to Claude Code first"
                notifyAvailabilityIfNeeded()
                return
            }
            clearLimitsCache()
            try await performInstall()
            defaults.set(true, forKey: "claudeAccountLinked")
            defaults.set(found.linkIdentifier, forKey: "claudeLinkedAccountID")
            detectedAccount = found
            account = found
            isConnected = true
            loadLimits()
            notifyAvailabilityIfNeeded()
        } catch {
            if isCurrent(operation) { fail(error) }
        }
    }

    func disconnect() async {
        cancelCurrentOperation()
        do {
            try await performUninstall()
        } catch {
            status = .unavailable
            statusMessage = "Claude could not be disconnected safely. Try again."
            return
        }
        defaults.set(false, forKey: "claudeAccountLinked")
        defaults.removeObject(forKey: "claudeLinkedAccountID")
        clearLimitsCache()
        isConnected = false
        account = nil
        snapshot = nil
        status = .needsAccount
        statusMessage = "Add a Claude account to continue"
        defaults.set(UsageProvider.codex.rawValue, forKey: "usageProvider")
        notifyAvailabilityIfNeeded()
        await refresh()
    }

    func refresh() async {
        guard isEnabled, !isRefreshing else { return }
        let operation = beginOperation()
        status = .checking
        defer { finishOperation(operation) }
        do {
            let found = try await authenticator.accountStatus()
            guard isCurrent(operation), isEnabled else { return }
            detectedAccount = found
            let linkedIdentifier = defaults.string(forKey: "claudeLinkedAccountID")
            guard defaults.bool(forKey: "claudeAccountLinked"),
                  let found,
                  linkedIdentifier == found.linkIdentifier
            else {
                isConnected = false
                account = nil
                snapshot = nil
                status = .needsAccount
                statusMessage = found == nil
                    ? "Sign in to Claude Code, then add the account"
                    : "Add this Claude account to CodexMeter"
                notifyAvailabilityIfNeeded()
                return
            }
            try await performInstall()
            account = found
            isConnected = true
            loadLimits()
            notifyAvailabilityIfNeeded()
        } catch {
            if isCurrent(operation) { fail(error) }
        }
    }

    private func loadLimits() {
        guard let data = try? Data(contentsOf: limitsURL, options: .mappedIfSafe),
              data.count <= 131_072,
              let bridgeSnapshot = try? ClaudeRateLimitCodec.decode(data)
        else {
            snapshot = nil
            status = .waitingForLimits
            statusMessage = "Use Claude Code once, then refresh"
            return
        }
        var windows: [AccountLimitWindow] = []
        if let weekly = bridgeSnapshot.sevenDay {
            windows.append(limitWindow(id: "claude-seven-day", duration: 10_080, source: weekly))
        }
        if let session = bridgeSnapshot.fiveHour {
            windows.append(limitWindow(id: "claude-five-hour", duration: 300, source: session))
        }
        snapshot = AccountLimitsSnapshot(windows: windows, resetCredits: nil, fetchedAt: bridgeSnapshot.fetchedAt)
        guard !windows.isEmpty else {
            status = .waitingForLimits
            statusMessage = "Use Claude Code once, then refresh"
            return
        }
        let currentDate = now()
        let age = currentDate.timeIntervalSince(bridgeSnapshot.fetchedAt)
        let resetHasPassed = windows.contains { window in
            window.resetsAt.map { $0 <= currentDate } ?? false
        }
        if age > Self.maximumFreshLimitAge || age < -300 || resetHasPassed {
            status = .stale
            statusMessage = "Use Claude Code to update limits"
        } else {
            status = .ready
            statusMessage = "Claude limits updated"
        }
    }

    // Status-line install touches the settings file and byte-compares the bundled
    // helper. Keep that off the main actor so a 2-minute refresh never stutters UI.
    private func performInstall() async throws {
        let installer = self.installer
        try await Task.detached(priority: .utility) { try installer.install() }.value
    }

    private func performUninstall() async throws {
        let installer = self.installer
        try await Task.detached(priority: .utility) { try installer.uninstall() }.value
    }

    private func clearLimitsCache() {
        try? FileManager.default.removeItem(at: limitsURL)
        snapshot = nil
    }

    private func limitWindow(
        id: String,
        duration: Int,
        source: ClaudeRateLimitWindow
    ) -> AccountLimitWindow {
        AccountLimitWindow(
            id: id,
            limitID: "claude",
            displayName: duration == 10_080 ? "Weekly" : "Session",
            windowDurationMinutes: duration,
            usedPercent: source.usedPercentage,
            resetsAt: source.resetsAt
        )
    }

    private func fail(_ error: Error) {
        if isConnected, account != nil {
            status = .stale
            statusMessage = snapshot == nil
                ? "Claude account check failed. Try again."
                : "Showing last known Claude limits"
            return
        }
        isConnected = false
        account = nil
        snapshot = nil
        status = .unavailable
        statusMessage = (error as? LocalizedError)?.errorDescription ?? "Claude is unavailable"
        notifyAvailabilityIfNeeded()
    }

    private func notifyAvailabilityIfNeeded() {
        guard isAvailable != lastAvailability else { return }
        lastAvailability = isAvailable
        onAvailabilityChanged?(isAvailable)
    }

    private func beginOperation() -> Int {
        operationGeneration += 1
        isRefreshing = true
        return operationGeneration
    }

    private func finishOperation(_ operation: Int) {
        guard operationGeneration == operation else { return }
        isRefreshing = false
    }

    private func cancelCurrentOperation() {
        operationGeneration += 1
        isRefreshing = false
    }

    private func isCurrent(_ operation: Int) -> Bool {
        operationGeneration == operation
    }
}

private enum ClaudeCommandRunner {
    static func run(
        executable: URL,
        arguments: [String],
        timeout: Duration,
        maximumOutputBytes: Int,
        acceptsNonzeroExit: Bool = false
    ) async throws -> Data {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("codexmeter-claude-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let outputURL = directory.appendingPathComponent("stdout")
        FileManager.default.createFile(atPath: outputURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        let output = try FileHandle(forWritingTo: outputURL)
        defer { try? output.close() }

        let box = ClaudeRunningProcessBox(executable: executable, arguments: arguments)
        box.process.standardOutput = output
        box.process.standardError = FileHandle.nullDevice
        do { try box.process.run() } catch { throw ClaudeIntegrationError.processFailed }

        let status = try await withThrowingTaskGroup(of: Int32.self) { group in
            group.addTask { box.process.waitUntilExit(); return box.process.terminationStatus }
            group.addTask {
                try await Task.sleep(for: timeout)
                box.stop()
                throw ClaudeIntegrationError.timedOut
            }
            guard let first = try await group.next() else { throw ClaudeIntegrationError.processFailed }
            group.cancelAll()
            return first
        }
        try output.synchronize()
        let data = try Data(contentsOf: outputURL, options: .mappedIfSafe)
        guard data.count <= maximumOutputBytes else { throw ClaudeIntegrationError.responseTooLarge }
        guard status == 0 || acceptsNonzeroExit else { throw ClaudeIntegrationError.processFailed }
        return data
    }
}

private final class ClaudeRunningProcessBox: @unchecked Sendable {
    let process = Process()

    init(executable: URL, arguments: [String]) {
        process.executableURL = executable
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.environment = ClaudeProcessEnvironment.sanitized
    }

    func stop() {
        guard process.isRunning else { return }
        process.terminate()
    }
}

private enum ClaudeProcessEnvironment {
    static var sanitized: [String: String] {
        let inherited = ProcessInfo.processInfo.environment
        let allowed = [
            "HOME", "TMPDIR", "USER", "LOGNAME", "LANG", "LC_ALL", "LC_CTYPE",
            "__CF_USER_TEXT_ENCODING", "CLAUDE_CONFIG_DIR", "HTTP_PROXY", "HTTPS_PROXY",
            "NO_PROXY", "http_proxy", "https_proxy", "no_proxy"
        ]
        return allowed.reduce(into: ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]) { result, key in
            result[key] = inherited[key]
        }
    }
}
