import Foundation
import XCTest
@testable import CodexMeter

final class UpdateServiceTests: XCTestCase {
    private var validInfo: [String: Any] {
        ["SUFeedURL": "https://raw.githubusercontent.com/HechoLP/CodexMeter/update-feed/appcast.xml",
         "SUPublicEDKey": "public-key",
         "SURequireSignedFeed": true,
         "SUVerifyUpdateBeforeExtraction": true,
         "SUSignedFeedFailureExpirationInterval": 0]
    }

    func testPackagedAppWithHTTPSFeedAndPublicKeyCanStartUpdater() {
        XCTAssertTrue(
            UpdateService.canStartUpdater(
                bundleURL: URL(fileURLWithPath: "/Applications/CodexMeter.app"),
                infoDictionary: validInfo
            )
        )
    }

    func testUnbundledExecutableCannotStartUpdater() {
        XCTAssertFalse(
            UpdateService.canStartUpdater(
                bundleURL: URL(fileURLWithPath: "/tmp/CodexMeter"),
                infoDictionary: validInfo
            )
        )
    }

    func testUpdaterRejectsMissingKeyAndNonHTTPSFeed() {
        let appURL = URL(fileURLWithPath: "/Applications/CodexMeter.app")
        var missingKey = validInfo
        missingKey.removeValue(forKey: "SUPublicEDKey")
        XCTAssertFalse(
            UpdateService.canStartUpdater(
                bundleURL: appURL,
                infoDictionary: missingKey
            )
        )
        var insecureFeed = validInfo
        insecureFeed["SUFeedURL"] = "http://example.com/appcast.xml"
        XCTAssertFalse(
            UpdateService.canStartUpdater(
                bundleURL: appURL,
                infoDictionary: insecureFeed
            )
        )
    }

    func testMissingDisabledOrMalformedSignaturePoliciesPreventUpdaterStartup() {
        let appURL = URL(fileURLWithPath: "/Applications/CodexMeter.app")
        for key in ["SURequireSignedFeed", "SUVerifyUpdateBeforeExtraction"] {
            for value in [nil, false, "true", NSNull()] as [Any?] {
                var info = validInfo
                info[key] = value
                XCTAssertFalse(UpdateService.canStartUpdater(bundleURL: appURL, infoDictionary: info), key)
            }
        }
        for value in [nil, 1_728_000, 1, -1, "0", false, true, Double.nan, Double.infinity, NSNull()] as [Any?] {
            var info = validInfo
            info["SUSignedFeedFailureExpirationInterval"] = value
            XCTAssertFalse(UpdateService.canStartUpdater(bundleURL: appURL, infoDictionary: info))
        }
    }

    func testProductionPlistKeepsFeedAuthenticationMandatoryIndefinitely() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("Config/Info.plist"))
        let info = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertTrue(UpdateService.canStartUpdater(bundleURL: URL(fileURLWithPath: "/Applications/CodexMeter.app"),
                                                   infoDictionary: info))
        XCTAssertEqual((info["SUSignedFeedFailureExpirationInterval"] as? NSNumber)?.doubleValue, 0)
    }
}
