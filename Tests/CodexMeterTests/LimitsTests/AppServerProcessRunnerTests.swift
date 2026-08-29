import Foundation
import XCTest
@testable import CodexMeter

final class AppServerProcessRunnerTests: XCTestCase {
    private let input = Data("{}\n{}\n".utf8)

    func testOversizedStandardOutputStopsAtTheConfiguredBound() async {
        await assertResponseTooLarge(
            script: "IFS= read -r first; /usr/bin/yes x | /usr/bin/head -c 2048"
        )
    }

    func testOversizedStandardErrorStopsAtTheConfiguredBound() async {
        await assertResponseTooLarge(
            script: "IFS= read -r first; printf '{\"id\":1}\\n{\"id\":2,\"result\":{}}\\n'; "
                + "/usr/bin/yes x | /usr/bin/head -c 2048 >&2"
        )
    }

    private func assertResponseTooLarge(script: String) async {
        do {
            _ = try await AppServerProcessRunner().run(
                executable: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", script],
                standardInput: input,
                timeout: .seconds(2),
                maximumOutputBytes: 1_024
            )
            XCTFail("Expected bounded output rejection")
        } catch {
            XCTAssertEqual(error as? AccountLimitError, .responseTooLarge)
        }
    }
}
