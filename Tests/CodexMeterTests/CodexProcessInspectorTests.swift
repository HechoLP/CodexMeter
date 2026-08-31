import Darwin
import Foundation
import XCTest
@testable import CodexMeter

final class CodexProcessInspectorTests: XCTestCase {
    private let userID: uid_t = 501

    func testUnreadableBrowserHelpersAndWidgetDoNotBlockSwitching() throws {
        let inspector = fixture(commands: ["chrome-native-host", "ChatGPT for Chrome", "CodexBarWidget"])
        XCTAssertEqual(try CodexProcessGate.runningCodexPIDs(using: inspector, userID: userID), [])
        XCTAssertNoThrow(try CodexProcessGate.requireStopped(using: inspector, userID: userID))
    }

    func testRootTerminalLoginIsIgnoredEvenWhenSignalPermissionSucceeds() throws {
        var inspector = fixture(commands: ["login"])
        inspector.entries[1] = CodexProcessMetadata(userID: 0, status: UInt32(SRUN), command: "login")
        inspector.onPath = { _ in XCTFail("Other users must be excluded before executable lookup"); return nil }
        XCTAssertTrue(inspector.isAlive(1))
        XCTAssertNoThrow(try CodexProcessGate.requireStopped(using: inspector, userID: userID))
    }

    func testKnownCodexPathStillBlocksEvenWithDifferentCommandMetadata() throws {
        var inspector = fixture(commands: ["unrelated-name"])
        inspector.paths[1] = "/Applications/ChatGPT.app/Contents/Resources/codex"
        XCTAssertEqual(try CodexProcessGate.runningCodexPIDs(using: inspector, userID: userID), [1])
        assertGateError(.codexRunning, inspector: inspector)
    }

    func testArchitectureSpecificCodexPathsStillBlock() throws {
        for name in ["codex-aarch64-apple-darwin", "codex-x86_64-apple-darwin"] {
            var inspector = fixture(commands: [name])
            inspector.paths[1] = "/synthetic/\(name)"
            assertGateError(.codexRunning, inspector: inspector)
        }
    }

    func testMissingCodexPathDoesNotBypassTheGateIncludingTruncatedNames() throws {
        for name in ["codex", "codex-aarch64-apple-darwin", "codex-x86_64-apple-darwin",
                     "codex-aarch64-ap", "codex-x86_64-app", "codex-unknown"] {
            assertGateError(.codexRunning, inspector: fixture(commands: [name]))
        }
    }

    func testSuspendedCodexStillBlocks() throws {
        var inspector = fixture(commands: ["codex"])
        inspector.entries[1] = CodexProcessMetadata(userID: userID, status: UInt32(SSTOP), command: "codex")
        assertGateError(.codexRunning, inspector: inspector)
    }

    func testZombieCodexCannotUseTheLoginAndDoesNotBlock() throws {
        var inspector = fixture(commands: ["codex"])
        inspector.entries[1] = CodexProcessMetadata(userID: userID, status: UInt32(SZOMB), command: "codex")
        inspector.onPath = { _ in XCTFail("A zombie has no executable to inspect"); return nil }
        XCTAssertNoThrow(try CodexProcessGate.requireStopped(using: inspector, userID: userID))
    }

    func testUnidentifiedLiveProcessFailsClosedWithAnAccurateError() {
        var inspector = fixture(commands: ["codex"])
        inspector.entries = [:]
        assertGateError(.processInspectionFailed, inspector: inspector)
    }

    func testEmptyCommandAndMissingPathFailClosed() {
        assertGateError(.processInspectionFailed, inspector: fixture(commands: [""]))
    }

    func testAlreadyExitedProcessWithoutMetadataDoesNotBlock() throws {
        var inspector = fixture(commands: ["codex"])
        inspector.entries = [:]
        inspector.alive = []
        XCTAssertNoThrow(try CodexProcessGate.requireStopped(using: inspector, userID: userID))
    }

    func testRechecksIdentityWhenPathLookupFails() {
        var inspector = fixture(commands: ["chrome-native-host"])
        var reads = 0
        let userID = userID
        inspector.onMetadata = { _ in
            reads += 1
            return CodexProcessMetadata(userID: userID, status: UInt32(SRUN),
                                        command: reads == 1 ? "chrome-native-host" : "codex")
        }
        assertGateError(.codexRunning, inspector: inspector)
        XCTAssertEqual(reads, 2)
    }

    func testExitDuringPathLookupDoesNotBecomeAnInspectionFailure() throws {
        var inspector = fixture(commands: ["codex"])
        var reads = 0
        let entry = inspector.entries[1]
        inspector.onMetadata = { _ in reads += 1; return reads == 1 ? entry : nil }
        inspector.alive = []
        XCTAssertNoThrow(try CodexProcessGate.requireStopped(using: inspector, userID: userID))
        XCTAssertEqual(reads, 2)
    }

    func testEnumerationFailureDoesNotAllowSwitching() {
        var inspector = fixture(commands: [])
        inspector.listError = .processInspectionFailed
        assertGateError(.processInspectionFailed, inspector: inspector)
    }

    func testLiveKernelMetadataFallbackIdentifiesTheTestProcess() throws {
        let inspector = SystemCodexProcessInspector()
        let kernel = try XCTUnwrap(inspector.kernelMetadata(for: getpid()))
        let primary = try XCTUnwrap(inspector.metadata(for: getpid()))
        XCTAssertEqual(kernel.userID, getuid())
        XCTAssertEqual(kernel.userID, primary.userID)
        XCTAssertFalse(kernel.command.isEmpty)
        XCTAssertNotEqual(kernel.status, UInt32(SZOMB))
        XCTAssertTrue(inspector.isAlive(getpid()))
        XCTAssertNotNil(inspector.executablePath(for: getpid()))
    }

    func testMissingKernelProcessHasNoMetadata() {
        let inspector = SystemCodexProcessInspector()
        XCTAssertNil(inspector.kernelMetadata(for: Int32.max))
        XCTAssertFalse(inspector.isAlive(Int32.max))
    }

    private func fixture(commands: [String]) -> ProcessInspectorFixture {
        let pids = commands.indices.map { pid_t($0 + 1) }
        return ProcessInspectorFixture(ids: pids, entries: Dictionary(uniqueKeysWithValues:
            zip(pids, commands).map { ($0, CodexProcessMetadata(userID: userID, status: UInt32(SRUN), command: $1)) }
        ), alive: Set(pids))
    }

    private func assertGateError(_ error: AccountSwitchError, inspector: ProcessInspectorFixture,
                                 file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try CodexProcessGate.requireStopped(using: inspector, userID: userID), file: file, line: line) {
            XCTAssertEqual($0 as? AccountSwitchError, error, file: file, line: line)
        }
    }
}

private struct ProcessInspectorFixture: CodexProcessInspecting {
    var ids: [pid_t]
    var entries: [pid_t: CodexProcessMetadata]
    var alive: Set<pid_t>
    var paths: [pid_t: String] = [:]
    var listError: AccountSwitchError?
    var onMetadata: ((pid_t) -> CodexProcessMetadata?)?
    var onPath: ((pid_t) -> String?)?

    func processIDs() throws -> [pid_t] {
        if let listError { throw listError }
        return ids
    }
    func metadata(for pid: pid_t) -> CodexProcessMetadata? {
        if let onMetadata { return onMetadata(pid) }
        return entries[pid]
    }
    func executablePath(for pid: pid_t) -> String? {
        if let onPath { return onPath(pid) }
        return paths[pid]
    }
    func isAlive(_ pid: pid_t) -> Bool { alive.contains(pid) }
}
