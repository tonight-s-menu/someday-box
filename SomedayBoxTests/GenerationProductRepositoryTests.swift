import Foundation
import XCTest

#if canImport(SomedayBox)
@testable import SomedayBox

final class GenerationProductRepositoryTests: XCTestCase {
    private let instant = Date(timeIntervalSince1970: 2_000_000)

    func testRestoreSwitchesToFreshVerifiedGenerationAndCleansPriorGeneration() async throws {
        let root = temporaryRoot()
        var repository: GenerationProductRepository? = try await .open(configuration: configuration(root))
        let oldItem = item(title: "Old paper")
        _ = try await repository?.withTransaction { $0.items = [oldItem] }
        let priorGenerationValue = await repository?.activeGeneration()
        let priorGeneration = try XCTUnwrap(priorGenerationValue)
        let replacement = PersistedProductState(items: [item(title: "Restored paper")])

        let restored = try await repository?.restore(validatedState: replacement)
        XCTAssertEqual(restored, replacement)
        let newGenerationValue = await repository?.activeGeneration()
        let newGeneration = try XCTUnwrap(newGenerationValue)
        XCTAssertNotEqual(newGeneration.id, priorGeneration.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: configuration(root).generationURL(id: priorGeneration.id).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: configuration(root).operationJournalURL.path))

        repository = nil
        try FileManager.default.removeItem(at: root)
    }

    func testInvalidRestoreFailsBeforeSwitchAndPreservesPriorTruth() async throws {
        let root = temporaryRoot()
        var repository: GenerationProductRepository? = try await .open(configuration: configuration(root))
        let oldState = PersistedProductState(items: [item(title: "Kept paper")])
        _ = try await repository?.withTransaction { $0 = oldState }
        let priorGenerationValue = await repository?.activeGeneration()
        let priorGeneration = try XCTUnwrap(priorGenerationValue)
        var invalidItem = item(title: "Invalid completed paper")
        invalidItem.lifecycle = .completed
        invalidItem.completedAt = instant

        await XCTAssertThrowsErrorAsync(
            try await repository?.restore(validatedState: PersistedProductState(items: [invalidItem]))
        )
        let afterFailure = try await repository?.snapshot()
        let generationAfterFailure = await repository?.activeGeneration()
        XCTAssertEqual(afterFailure, oldState)
        XCTAssertEqual(generationAfterFailure, priorGeneration)
        XCTAssertFalse(FileManager.default.fileExists(atPath: configuration(root).operationJournalURL.path))

        repository = nil
        try FileManager.default.removeItem(at: root)
    }

    func testEraseUsesVerifiedEmptyGenerationThenCleansPriorGeneration() async throws {
        let root = temporaryRoot()
        var repository: GenerationProductRepository? = try await .open(configuration: configuration(root))
        let eraseItem = item(title: "Erase me")
        _ = try await repository?.withTransaction { $0.items = [eraseItem] }
        let priorGenerationValue = await repository?.activeGeneration()
        let priorGeneration = try XCTUnwrap(priorGenerationValue)

        let erased = try await repository?.eraseAll()
        let generationAfterErase = await repository?.activeGeneration()
        XCTAssertEqual(erased, PersistedProductState(items: []))
        XCTAssertNotEqual(generationAfterErase, priorGeneration)
        XCTAssertFalse(FileManager.default.fileExists(atPath: configuration(root).generationURL(id: priorGeneration.id).path))

        repository = nil
        try FileManager.default.removeItem(at: root)
    }

    func testGenerationOperationGateRejectsMutationAndExportDuringStaging() async throws {
        let root = temporaryRoot()
        var repository: GenerationProductRepository? = try await .open(configuration: configuration(root))
        let replacement = PersistedProductState(
            items: (0..<BackupFormatV1Limits.itemCount).map { index in
                item(title: "Paper \(index)")
            }
        )
        do {
            let activeRepository = try XCTUnwrap(repository)
            let restoreTask = Task {
                try await activeRepository.restore(validatedState: replacement)
            }
            try await waitForJournal(at: configuration(root).operationJournalURL)

            await XCTAssertThrowsErrorAsync(try await activeRepository.withTransaction { _ in }) { error in
                XCTAssertEqual(error as? GenerationRepositoryError, .operationInProgress)
            }
            await XCTAssertThrowsErrorAsync(try await activeRepository.exportSnapshot()) { error in
                XCTAssertEqual(error as? GenerationRepositoryError, .operationInProgress)
            }
            let restored = try await restoreTask.value
            XCTAssertEqual(restored, replacement)
        }

        repository = nil
        try FileManager.default.removeItem(at: root)
    }

    func testUnresolvedRevealBlocksExportRestoreAndEraseBeforeJournalWrite() async throws {
        let root = temporaryRoot()
        var repository: GenerationProductRepository? = try await .open(configuration: configuration(root))
        let revealState = unresolvedRevealState()
        _ = try await repository?.withTransaction { $0 = revealState }
        do {
            let activeRepository = try XCTUnwrap(repository)

            await XCTAssertThrowsErrorAsync(try await activeRepository.exportSnapshot()) { error in
                XCTAssertEqual(error as? ApplicationError, .drawResolutionRequired)
            }
            await XCTAssertThrowsErrorAsync(
                try await activeRepository.restore(validatedState: PersistedProductState(items: []))
            ) { error in
                XCTAssertEqual(error as? ApplicationError, .drawResolutionRequired)
            }
            await XCTAssertThrowsErrorAsync(try await activeRepository.eraseAll()) { error in
                XCTAssertEqual(error as? ApplicationError, .drawResolutionRequired)
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: configuration(root).operationJournalURL.path))
            let preserved = try await activeRepository.snapshot()
            XCTAssertEqual(preserved, revealState)
        }

        repository = nil
        try FileManager.default.removeItem(at: root)
    }

    private func item(title: String) -> BoxItem {
        BoxItem(
            title: title,
            durationBucketRaw: DurationBucket.upTo30Minutes.rawValue,
            createdAt: instant,
            updatedAt: instant
        )
    }

    private func configuration(_ root: URL) -> StoreGenerationConfiguration {
        StoreGenerationConfiguration(applicationSupportURL: root)
    }

    private func unresolvedRevealState() -> PersistedProductState {
        var paper = item(title: "Resolve this first")
        paper.lastShownAt = instant
        let session = DrawSession(startedAt: instant, availableTime: .upTo30Minutes)
        let attempt = DrawAttempt(
            sessionID: session.id,
            sequence: 1,
            itemID: paper.id,
            eligibleCount: 1,
            shownAt: instant,
            outcome: .unresolved
        )
        return PersistedProductState(items: [paper], sessions: [session], attempts: [attempt])
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func waitForJournal(at url: URL) async throws {
        for _ in 0..<5_000 {
            if FileManager.default.fileExists(atPath: url.path) { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        XCTFail("Generation operation journal was not created")
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void = { _ in },
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
#endif
