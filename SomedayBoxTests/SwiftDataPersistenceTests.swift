import Foundation
import XCTest

#if canImport(SomedayBox)
@testable import SomedayBox

final class SwiftDataPersistenceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000)

    func testDomainMappingRoundTripsProductRecords() throws {
        let item = makeItem()
        XCTAssertEqual(try SomedayBoxSchemaV1.ItemRecord(domain: item).domainValue(), item)

        let pick = CurrentPick(itemID: item.id, acceptedAt: now)
        XCTAssertEqual(SomedayBoxSchemaV1.CurrentPickRecord(domain: pick).domainValue(), pick)

        let memory = CompletionMemory(
            sourceItemID: item.id,
            titleSnapshot: item.title,
            durationSnapshotRaw: item.durationBucketRaw,
            completedAt: now
        )
        XCTAssertEqual(SomedayBoxSchemaV1.MemoryRecord(domain: memory).domainValue(), memory)
        let source = SourceReference(
            itemID: item.id,
            importEnvelopeID: UUID(),
            acceptedURLString: "https://example.com/paper",
            sourceKindRaw: "url",
            capturedAt: now
        )
        XCTAssertEqual(SomedayBoxSchemaV2.SourceRecord(domain: source).domainValue(), source)
    }

    func testRepositoryCommitsAndRollsBackAsOneStateTransaction() async throws {
        let repository = SwiftDataProductRepository(
            container: try StoreGenerationBootstrap.makeInMemoryContainer()
        )
        let item = makeItem()

        let committed = try await repository.withTransaction { state in
            state.items.append(item)
        }
        XCTAssertEqual(committed.state.items, [item])
        let completionTime = now

        do {
            _ = try await repository.withTransaction { state in
                state.items[0].lifecycle = .completed
                state.items[0].completedAt = completionTime
            }
            XCTFail("An invalid completed state must not commit")
        } catch {
            XCTAssertEqual(
                error as? PersistedStateValidationIssue,
                .completedItemHasNoMatchingMemory(itemID: item.id)
            )
        }

        let afterFailure = try await repository.snapshot()
        XCTAssertEqual(afterFailure.items, [item])
        XCTAssertTrue(afterFailure.memories.isEmpty)
    }

    func testGenerationBootstrapReusesChecksummedManifestAndDiskStore() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let bootstrap = StoreGenerationBootstrap(
            configuration: StoreGenerationConfiguration(applicationSupportURL: root)
        )
        let item = makeItem()
        let firstGeneration: ActiveStoreGeneration
        do {
            let opened = try bootstrap.openOrCreateContainer()
            firstGeneration = opened.generation
            let repository = SwiftDataProductRepository(container: opened.container)
            _ = try await repository.withTransaction { $0.items.append(item) }
        }

        let second = try bootstrap.openOrCreateContainer()
        XCTAssertEqual(second.generation, firstGeneration)
        let secondRepository = SwiftDataProductRepository(container: second.container)
        let reopenedState = try await secondRepository.snapshot()
        XCTAssertEqual(reopenedState.items, [item])
    }

    func testRepositoryPersistsSourceReferenceWithItemTransaction() async throws {
        let repository = SwiftDataProductRepository(container: try StoreGenerationBootstrap.makeInMemoryContainer())
        let item = makeItem()
        let source = SourceReference(
            itemID: item.id,
            importEnvelopeID: UUID(),
            acceptedURLString: "https://example.com/paper",
            sourceKindRaw: "url",
            capturedAt: now
        )

        _ = try await repository.withTransaction { state in
            state.items.append(item)
            state.sources.append(source)
        }
        let reopened = try await repository.snapshot()
        XCTAssertEqual(reopened.items, [item])
        XCTAssertEqual(reopened.sources, [source])
    }

    private func makeItem() -> BoxItem {
        BoxItem(
            title: "Read by the window",
            durationBucketRaw: DurationBucket.upTo30Minutes.rawValue,
            createdAt: now,
            updatedAt: now
        )
    }
}
#endif
