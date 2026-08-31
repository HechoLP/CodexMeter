import AppKit
import SwiftUI
import Vision
import XCTest
@testable import CodexMeter

@MainActor
final class CodexAccountsLayoutTests: XCTestCase {
    func testEmptyAccountsFitNativeWindowSizesAndAppearances() async throws {
        try await assertLayouts(for: .empty)
    }

    func testPopulatedAccountsFitNativeWindowSizesAndAppearances() async throws {
        try await assertLayouts(for: .populated)
    }

    func testLongEmailsFitNativeWindowSizesAndAppearances() async throws {
        try await assertLayouts(for: .longEmail)
    }

    func testErrorMessageFitsNativeWindowSizesAndAppearances() async throws {
        try await assertLayouts(for: .error)
    }

    func testSignInKeepsCancelVisibleAtNativeWindowSizesAndAppearances() async throws {
        try await assertLayouts(for: .busy)
    }

    private func assertLayouts(for state: AccountLayoutState) async throws {
        _ = NSApplication.shared
        for size in [NSSize(width: 560, height: 400), NSSize(width: 500, height: 300)] {
            for dark in [false, true] {
                let fixture = try AccountLayoutFixture(state: state)
                defer { fixture.finishPendingOperations() }
                if state == .error {
                    fixture.runtime.policyError = .unsupportedStorage
                    await fixture.store.saveCurrent()
                    XCTAssertTrue(fixture.store.isError)
                } else if state == .busy {
                    fixture.store.addAccount()
                    XCTAssertTrue(fixture.store.isBusy)
                    XCTAssertTrue(fixture.store.isSigningIn)
                }

                let name = "accounts-\(state.rawValue)-\(dark ? "dark" : "light")-\(Int(size.width))x\(Int(size.height))"
                let hostingView = NSHostingView(rootView:
                    CodexAccountsView(accounts: fixture.store)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .environment(\.colorScheme, dark ? .dark : .light)
                )
                // Disable host-driven window resizing: these are the production
                // default and minimum content sizes, not unconstrained fitting sizes.
                hostingView.sizingOptions = []
                hostingView.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                                      styleMask: [.borderless], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.appearance = hostingView.appearance
                window.contentView = hostingView
                defer { window.contentView = nil }
                // The private test window is never ordered front or activated.
                for _ in 0..<8 {
                    window.setContentSize(size)
                    hostingView.setFrameSize(size)
                    hostingView.layoutSubtreeIfNeeded()
                    await Task.yield()
                }

                let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
                hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
                try captureIfRequested(bitmap, name: name)
                let text = try recognizedText(in: bitmap)
                XCTAssertEqual(hostingView.bounds.size, size, name)
                assertAction("Save Current Account", identifier: "accounts.saveCurrent",
                             enabled: state != .busy, in: hostingView, text: text, context: name)
                assertAction("Add Account…", identifier: "accounts.add",
                             enabled: state != .busy, in: hostingView, text: text, context: name)
                assertAction(state == .busy ? "Cancel" : "Open Codex",
                             enabled: true, in: hostingView, text: text, context: name)
                assertNoHorizontalControlOverflow(in: hostingView, context: name)
                assertFixedTextIsVisible(text, message: fixture.store.message, context: name)
                XCTAssertEqual(fixture.login.replaceCount, 0, "\(name): rendering must not change a login")
                XCTAssertEqual(fixture.vault.saveCount, 0, "\(name): rendering must not save an account")
                XCTAssertEqual(fixture.runtime.applicationActionCount, 0, "\(name): rendering must not operate Codex")
            }
        }
    }

    private func assertAction(_ title: String, identifier: String? = nil, enabled: Bool,
                              in host: NSView, text: [VNRecognizedTextObservation], context: String) {
        let buttons = descendants(of: NSButton.self, in: host)
        if let button = buttons.first(where: {
            $0.title == title || $0.accessibilityLabel() == title ||
                (identifier != nil && $0.accessibilityIdentifier() == identifier)
        }) {
            let frame = host.convert(button.bounds, from: button)
            XCTAssertFalse(button.isHiddenOrHasHiddenAncestor, "\(context): \(title)")
            XCTAssertTrue(host.bounds.insetBy(dx: -1, dy: -1).contains(frame),
                          "\(context): \(title) \(frame) must fit within \(host.bounds)")
            XCTAssertEqual(button.isEnabled, enabled, "\(context): \(title)")
        }
        // SwiftUI may draw native-styled buttons without backing NSButtons and
        // omit the accessibility tree for unshown test windows. Inspect the real
        // bitmap locally as well, without enabling accessibility or activating UI.
        let search = title.replacingOccurrences(of: "…", with: "")
        let frames: [NSRect] = text.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first,
                  let range = candidate.string.range(of: search, options: .caseInsensitive) else { return nil }
            let box = (try? candidate.boundingBox(for: range))?.boundingBox ?? observation.boundingBox
            return NSRect(x: box.minX * host.bounds.width,
                          y: (1 - box.maxY) * host.bounds.height,
                          width: box.width * host.bounds.width, height: box.height * host.bounds.height)
        }
        guard let frame = frames.first else {
            XCTFail("\(context): action label \(title) must be fully visible")
            return
        }
        XCTAssertTrue(host.bounds.insetBy(dx: 4, dy: 4).contains(frame),
                      "\(context): \(title) label must retain space inside the window: \(frame)")
        XCTAssertGreaterThan(frame.height, 0, "\(context): \(title)")
    }

    private func assertNoHorizontalControlOverflow(in host: NSView, context: String) {
        for button in descendants(of: NSButton.self, in: host) {
            let frame = host.convert(button.bounds, from: button)
            XCTAssertGreaterThanOrEqual(frame.minX, -1, "\(context): \(button.title)")
            XCTAssertLessThanOrEqual(frame.maxX, host.bounds.maxX + 1, "\(context): \(button.title)")
        }
        for scroll in descendants(of: NSScrollView.self, in: host) {
            let frame = host.convert(scroll.bounds, from: scroll)
            XCTAssertTrue(host.bounds.insetBy(dx: -1, dy: -1).contains(frame),
                          "\(context): account list viewport must fit in the window")
            XCTAssertGreaterThan(frame.height, 0, "\(context): account list must retain a visible viewport")
            if let document = scroll.documentView {
                XCTAssertLessThanOrEqual(document.bounds.width, scroll.contentView.bounds.width + 1,
                                         "\(context): account list must not scroll horizontally")
            }
        }
    }

    private func assertFixedTextIsVisible(_ text: [VNRecognizedTextObservation], message: String?, context: String) {
        let lines = text.compactMap { $0.topCandidates(1).first?.string }
        let contents = normalized(lines.joined(separator: " "))
        XCTAssertTrue(contents.contains(normalized("Saved logins stay in this Mac’s Keychain.")),
                      "\(context): the credential storage notice must be visible")
        XCTAssertTrue(contents.contains(normalized("Switching restarts Codex; finish your work first.")),
                      "\(context): the restart safety notice must be fully visible")
        if let message {
            XCTAssertTrue(contents.contains(normalized(message)),
                          "\(context): the complete status message must fit; recognized lines: \(lines)")
        }
    }

    private func normalized(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func recognizedText(in bitmap: NSBitmapImageRep) throws -> [VNRecognizedTextObservation] {
        // Vision's accurate mode can merge adjacent text baselines beside an
        // SF Symbol. Its fast mode provides independent line segmentation while
        // the assertions still require the complete rendered status sentence.
        let requests = [VNRequestTextRecognitionLevel.accurate, .fast].map { level in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = level
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = false
            request.customWords = ["Codex", "Keychain"]
            return request
        }
        try VNImageRequestHandler(cgImage: XCTUnwrap(bitmap.cgImage), options: [:]).perform(requests)
        return requests.flatMap { $0.results ?? [] }
    }

    private func captureIfRequested(_ bitmap: NSBitmapImageRep, name: String) throws {
        guard let path = ProcessInfo.processInfo.environment["CODEXMETER_ACCOUNT_CAPTURE_DIR"],
              !path.isEmpty else { return }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: directory.appendingPathComponent("\(name).png"), options: .atomic)
    }

    private func descendants<T: NSView>(of type: T.Type, in view: NSView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { descendants(of: type, in: $0) }
    }
}

private enum AccountLayoutState: String {
    case empty, populated, longEmail = "long-email", error, busy
}

@MainActor
private struct AccountLayoutFixture {
    let store: CodexAccountStore
    let vault: AccountLayoutVault
    let login: AccountLayoutLogin
    let runtime: AccountLayoutRuntime

    init(state: AccountLayoutState) throws {
        let saved: [SavedCodexAccount]
        switch state {
        case .empty:
            saved = []
        case .longEmail:
            let longEmail = "a.very.long.account.name.for.layout.verification@a-long-team-subdomain.example.com"
            saved = try [Self.account(email: longEmail, workspace: "workspace-personal"),
                         Self.account(email: longEmail, workspace: "workspace-research")]
        case .populated:
            saved = try [Self.account(email: "alex@example.com", workspace: "workspace-personal"),
                         Self.account(email: "alex@example.com", workspace: "workspace-research"),
                         Self.account(email: "jamie@example.com", workspace: "workspace-design"),
                         Self.account(email: "morgan@example.com", workspace: "workspace-product")]
        case .error, .busy:
            saved = try [Self.account(email: "alex@example.com", workspace: "workspace-personal"),
                         Self.account(email: "jamie@example.com", workspace: "workspace-research")]
        }
        vault = AccountLayoutVault(accounts: saved)
        login = AccountLayoutLogin(data: saved.first?.loginData)
        runtime = AccountLayoutRuntime()
        // Every dependency is synthetic, including the lock. Never construct the
        // production Keychain vault, auth-file store, runtime, or shared store.
        store = CodexAccountStore(vault: vault, login: login, runtime: runtime, acquireLock: { nil })
        store.load()
    }

    func finishPendingOperations() {
        store.cancelSignIn()
        runtime.finishSignIn()
    }

    private static func account(email: String, workspace: String) throws -> SavedCodexAccount {
        let claims: [String: Any] = ["sub": "synthetic-layout-user", "email": email,
                                     "https://api.openai.com/auth": ["chatgpt_account_id": workspace]]
        let payload = try JSONSerialization.data(withJSONObject: claims).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let data = try JSONSerialization.data(withJSONObject: ["tokens": [
            "access_token": "synthetic-layout-access", "refresh_token": "synthetic-layout-refresh",
            "id_token": "synthetic.\(payload).signature", "account_id": workspace
        ]])
        return try SavedCodexAccount(loginData: data)
    }
}

private final class AccountLayoutVault: AccountVault {
    private var accounts: [SavedCodexAccount]
    private(set) var saveCount = 0
    init(accounts: [SavedCodexAccount]) { self.accounts = accounts }
    func load() throws -> [SavedCodexAccount] { accounts }
    func save(_ accounts: [SavedCodexAccount]) throws { saveCount += 1; self.accounts = accounts }
}

private final class AccountLayoutLogin: CodexLoginStoring {
    private var data: Data?
    private(set) var replaceCount = 0
    init(data: Data?) { self.data = data }
    func read() throws -> Data? { data }
    func replace(with data: Data, expecting original: Data?) throws {
        replaceCount += 1
        guard self.data == original else { throw AccountSwitchError.changedLogin }
        self.data = data
    }
}

@MainActor
private final class AccountLayoutRuntime: CodexAccountRuntime {
    var policyError: AccountSwitchError?
    private(set) var applicationActionCount = 0
    private var signInContinuation: CheckedContinuation<SavedCodexAccount, Error>?

    func checkPolicy(for workspaceID: String?) async throws {
        try Task.checkCancellation()
        if let policyError { throw policyError }
    }

    func signIn() async throws -> SavedCodexAccount {
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { signInContinuation = $0 }
    }

    func finishSignIn() {
        signInContinuation?.resume(throwing: AccountSwitchError.loginCancelled)
        signInContinuation = nil
    }

    func quitCodex() async throws { try unexpectedApplicationAction() }
    func requireStopped() throws { try unexpectedApplicationAction() }
    func openCodex() async throws { try unexpectedApplicationAction() }

    private func unexpectedApplicationAction() throws {
        applicationActionCount += 1
        XCTFail("Layout rendering must not launch, quit, or switch a real application")
        throw AccountSwitchError.unavailable
    }
}
