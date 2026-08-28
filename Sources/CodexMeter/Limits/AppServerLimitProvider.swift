import Foundation
import Security

struct AppServerLimitProvider: AccountLimitProviding {
    static let maximumResponseBytes = 2_097_152

    private let executableResolver: @Sendable () throws -> URL
    private let runner: AppServerProcessRunning
    private let parser = AccountLimitsResponseParser()

    init(
        executableResolver: @escaping @Sendable () throws -> URL = TrustedCodexExecutable.resolve,
        runner: AppServerProcessRunning = AppServerProcessRunner()
    ) {
        self.executableResolver = executableResolver
        self.runner = runner
    }

    func readLimits() async throws -> AccountLimitsSnapshot {
        let executable = try executableResolver()
        let requests = [
            #"{"method":"initialize","id":1,"params":{"clientInfo":{"name":"codexmeter","title":"CodexMeter","version":"2"},"capabilities":{"optOutNotificationMethods":["remoteControl/status/changed"]}}}"#,
            #"{"method":"initialized","params":{}}"#,
            #"{"method":"account/rateLimits/read","id":2}"#
        ].joined(separator: "\n") + "\n"
        let response = try await runner.run(
            executable: executable,
            arguments: ["app-server"],
            standardInput: Data(requests.utf8),
            timeout: .seconds(15),
            maximumOutputBytes: Self.maximumResponseBytes
        )
        return try parser.parse(response)
    }
}

protocol AppServerProcessRunning: Sendable {
    func run(
        executable: URL,
        arguments: [String],
        standardInput: Data,
        timeout: Duration,
        maximumOutputBytes: Int
    ) async throws -> Data
}

struct AppServerProcessRunner: AppServerProcessRunning {
    func run(
        executable: URL,
        arguments: [String],
        standardInput: Data,
        timeout: Duration,
        maximumOutputBytes: Int
    ) async throws -> Data {
        let box = RunningProcessBox(executable: executable, arguments: arguments)
        do {
            try box.process.run()
        } catch {
            throw AccountLimitError.processLaunchFailed
        }
        defer {
            box.stop()
            box.closePipes()
        }
        guard let firstNewline = standardInput.firstIndex(of: 0x0A) else {
            box.stop()
            throw AccountLimitError.malformedResponse
        }
        let initialization = standardInput[...firstNewline]
        let remainingRequests = standardInput[standardInput.index(after: firstNewline)...]
        do {
            try box.input.fileHandleForWriting.write(contentsOf: initialization)
        } catch {
            box.stop()
            throw AccountLimitError.processLaunchFailed
        }

        return try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                do {
                    async let stderr = readToEndBounded(
                        from: box.error.fileHandleForReading,
                        maximumBytes: maximumOutputBytes
                    )
                    var output = try readLine(
                        from: box.output.fileHandleForReading,
                        maximumBytes: maximumOutputBytes
                    )
                    try box.input.fileHandleForWriting.write(contentsOf: remainingRequests)
                    while !containsResponseID2(output) {
                        let line = try readLine(
                            from: box.output.fileHandleForReading,
                            maximumBytes: maximumOutputBytes - output.count
                        )
                        guard !line.isEmpty else { throw AccountLimitError.malformedResponse }
                        output.append(line)
                    }
                    try box.input.fileHandleForWriting.close()
                    output.append(
                        try readToEndBounded(
                            from: box.output.fileHandleForReading,
                            maximumBytes: maximumOutputBytes - output.count
                        )
                    )
                    let errorOutput = try await stderr
                    box.process.waitUntilExit()
                    guard box.process.terminationStatus == 0 else {
                        let message = String(data: errorOutput.prefix(1_024), encoding: .utf8)?
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        throw AccountLimitError.server(message?.isEmpty == false ? message! : "Codex app-server exited unexpectedly.")
                    }
                    return output
                } catch {
                    box.stop()
                    throw error
                }
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                box.stop()
                throw AccountLimitError.timedOut
            }
            guard let first = try await group.next() else {
                throw AccountLimitError.processLaunchFailed
            }
            group.cancelAll()
            return first
        }
    }

    private func readLine(from handle: FileHandle, maximumBytes: Int) throws -> Data {
        guard maximumBytes > 0 else { throw AccountLimitError.responseTooLarge }
        var line = Data()
        while line.count <= maximumBytes {
            guard let chunk = try handle.read(upToCount: 1), !chunk.isEmpty else { break }
            line.append(chunk)
            if chunk[chunk.startIndex] == 0x0A { return line }
        }
        guard line.count <= maximumBytes else { throw AccountLimitError.responseTooLarge }
        return line
    }

    private func readToEndBounded(from handle: FileHandle, maximumBytes: Int) throws -> Data {
        guard maximumBytes >= 0 else { throw AccountLimitError.responseTooLarge }
        var data = Data()
        while true {
            let remaining = maximumBytes - data.count
            let requestedBytes = min(65_536, remaining + 1)
            guard let chunk = try handle.read(upToCount: requestedBytes), !chunk.isEmpty else {
                return data
            }
            data.append(chunk)
            guard data.count <= maximumBytes else {
                throw AccountLimitError.responseTooLarge
            }
        }
    }

    private func containsResponseID2(_ data: Data) -> Bool {
        data.split(separator: 0x0A).contains { line in
            guard let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                  let identifier = object["id"] as? NSNumber,
                  CFGetTypeID(identifier) != CFBooleanGetTypeID()
            else { return false }
            return identifier.intValue == 2
        }
    }
}

private final class RunningProcessBox: @unchecked Sendable {
    let process = Process()
    let input = Pipe()
    let output = Pipe()
    let error = Pipe()

    init(executable: URL, arguments: [String]) {
        process.executableURL = executable
        process.arguments = arguments
        let inherited = ProcessInfo.processInfo.environment
        let allowedEnvironmentKeys = [
            "HOME", "TMPDIR", "USER", "LOGNAME", "LANG", "LC_ALL", "LC_CTYPE",
            "__CF_USER_TEXT_ENCODING", "CODEX_HOME", "XDG_CONFIG_HOME",
            "HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY", "http_proxy", "https_proxy", "no_proxy"
        ]
        process.environment = allowedEnvironmentKeys.reduce(into: [:]) { environment, key in
            environment[key] = inherited[key]
        }
        process.standardInput = input
        process.standardOutput = output
        process.standardError = error
    }

    func stop() {
        guard process.isRunning else { return }
        process.terminate()
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self, self.process.isRunning else { return }
            kill(self.process.processIdentifier, SIGKILL)
        }
    }

    func closePipes() {
        try? input.fileHandleForWriting.close()
        try? output.fileHandleForReading.close()
        try? error.fileHandleForReading.close()
    }
}

private enum TrustedCodexExecutable {
    static func resolve() throws -> URL {
        let candidates = [
            URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/Resources/codex"),
            URL(fileURLWithPath: "/Applications/Codex.app/Contents/Resources/codex")
        ]
        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate.path) {
            if isTrusted(candidate) { return candidate }
        }
        throw AccountLimitError.trustedAppServerNotFound
    }

    private static func isTrusted(_ executable: URL) -> Bool {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(executable as CFURL, [], &code) == errSecSuccess,
              let code
        else { return false }
        var requirement: SecRequirement?
        let requirementText = #"anchor apple generic and identifier "codex" and certificate leaf[subject.OU] = "2DC432GLL2""#
        guard SecRequirementCreateWithString(requirementText as CFString, [], &requirement) == errSecSuccess,
              let requirement
        else { return false }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures)
        return SecStaticCodeCheckValidityWithErrors(code, flags, requirement, nil) == errSecSuccess
    }
}
