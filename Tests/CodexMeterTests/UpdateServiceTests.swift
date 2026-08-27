import Foundation
import XCTest
@testable import CodexMeter

final class UpdateServiceTests: XCTestCase {
    func testPackagedAppWithHTTPSFeedAndPublicKeyCanStartUpdater() {
        XCTAssertTrue(
            UpdateService.canStartUpdater(
                bundleURL: URL(fileURLWithPath: "/Applications/CodexMeter.app"),
                infoDictionary: [
                    "SUFeedURL": "https://raw.githubusercontent.com/HechoLP/CodexMeter-Releases/update-feed/appcast.xml",
                    "SUPublicEDKey": "public-key"
                ]
            )
        )
    }

    func testUnbundledExecutableCannotStartUpdater() {
        XCTAssertFalse(
            UpdateService.canStartUpdater(
                bundleURL: URL(fileURLWithPath: "/tmp/CodexMeter"),
                infoDictionary: [
                    "SUFeedURL": "https://example.com/appcast.xml",
                    "SUPublicEDKey": "public-key"
                ]
            )
        )
    }

    func testUpdaterRejectsMissingKeyAndNonHTTPSFeed() {
        let appURL = URL(fileURLWithPath: "/Applications/CodexMeter.app")

        XCTAssertFalse(
            UpdateService.canStartUpdater(
                bundleURL: appURL,
                infoDictionary: ["SUFeedURL": "https://example.com/appcast.xml"]
            )
        )
        XCTAssertFalse(
            UpdateService.canStartUpdater(
                bundleURL: appURL,
                infoDictionary: [
                    "SUFeedURL": "http://example.com/appcast.xml",
                    "SUPublicEDKey": "public-key"
                ]
            )
        )
    }
}
