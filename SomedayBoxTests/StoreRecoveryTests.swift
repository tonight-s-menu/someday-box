import Foundation
import XCTest
@testable import SomedayBox

final class StoreRecoveryTests: XCTestCase {
    func testRecoveryImportsIndependentGenerationAndRetainsPriorBytes() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let configuration = StoreGenerationConfiguration(applicationSupportURL: root)
        var repository: GenerationProductRepository? = try await .open(configuration: configuration)
        let priorValue = await repository?.activeGeneration()
        let prior = try XCTUnwrap(priorValue)
        repository = nil
        let instant = Date(timeIntervalSince1970: 2_000_000)
        let item = BoxItem(title: "Recovered paper", durationBucketRaw: DurationBucket.upTo30Minutes.rawValue, createdAt: instant, updatedAt: instant)
        let state = PersistedProductState(items: [item])
        let data = try BackupDocumentCodecV3().encode(
            state: state,
            pendingEnvelopes: [],
            metadata: .init(exportedAt: instant, appMarketingVersion: "test", appBuild: "1", schemaVersion: .init(major: 3, minor: 0, patch: 0), selectionPolicyVersion: DrawSelectionPolicy.version)
        )

        try await StoreRecoveryService(configuration: configuration).recover(from: data)
        repository = try await .open(configuration: configuration)
        let recovered = try await repository?.snapshot()
        XCTAssertEqual(recovered, state)
        XCTAssertTrue(FileManager.default.fileExists(atPath: configuration.generationURL(id: prior.id).path))
    }

    func testRecoveryRejectsInvalidBackupWithoutSwitchingGeneration() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let configuration = StoreGenerationConfiguration(applicationSupportURL: root)
        let repository = try await GenerationProductRepository.open(configuration: configuration)
        let prior = await repository.activeGeneration()

        do {
            try await StoreRecoveryService(configuration: configuration).recover(from: Data("not-json".utf8))
            XCTFail("Expected recovery validation to fail")
        } catch {}
        XCTAssertEqual(try StoreGenerationBootstrap(configuration: configuration).loadOrCreateActiveGeneration(), prior)
    }
}
