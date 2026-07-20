import CryptoKit
import Foundation
import Testing
@testable import SomedayBox

private final class CoreBoxProofBundleMarker {}

@Suite("Core Box proof identity")
struct CoreBoxProofIdentityTests {
    @Test func compiledIdentityMatchesBundledBytes() throws {
        let bundle = Bundle(for: CoreBoxProofBundleMarker.self)
        let reportURL = try #require(bundle.url(forResource: "CoreBoxProofReport", withExtension: "json"))
        let fullURL = try #require(bundle.url(forResource: "CoreBoxProofFull", withExtension: "usdz"))
        let liteURL = try #require(bundle.url(forResource: "CoreBoxProofLite", withExtension: "usdz"))

        #expect(Self.digest(try Data(contentsOf: reportURL)) == CoreBoxProofIdentity.reportSHA256)
        #expect(Self.digest(try Data(contentsOf: fullURL)) == CoreBoxProofIdentity.fullTierSHA256)
        #expect(Self.digest(try Data(contentsOf: liteURL)) == CoreBoxProofIdentity.liteTierSHA256)
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
