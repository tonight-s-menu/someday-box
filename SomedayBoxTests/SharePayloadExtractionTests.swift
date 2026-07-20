import XCTest
@testable import SomedayBox

final class SharePayloadExtractionTests: XCTestCase {
    private let extractor = SharePayloadExtractor()

    func testExplicitHTTPSURLWinsOverTextURLWithoutRewritingIt() throws {
        let candidate = try extractor.extract(from: SharedPayload(
            explicitURLString: "https://example.com/Path?utm=kept",
            plainText: "https://other.example/first\nA title",
            attributedTitle: "A confirmed host title"
        ))

        XCTAssertEqual(candidate.acceptedURLString, "https://example.com/Path?utm=kept")
        XCTAssertEqual(candidate.titleCandidate, "A confirmed host title")
    }

    func testTextURLUsesFirstHTTPSubstringAndDerivesTitleFromNextLine() throws {
        let candidate = try extractor.extract(from: SharedPayload(
            plainText: "https://example.com/one\nTry this walk\nhttps://example.com/two"
        ))

        XCTAssertEqual(candidate.acceptedURLString, "https://example.com/one")
        XCTAssertEqual(candidate.titleCandidate, "Try this walk")
    }

    func testUnsupportedSchemeDoesNotBecomeAnAcceptedURL() throws {
        let candidate = try extractor.extract(from: SharedPayload(
            explicitURLString: "javascript:alert(1)",
            plainText: "A safe title"
        ))

        XCTAssertNil(candidate.acceptedURLString)
        XCTAssertEqual(candidate.titleCandidate, "A safe title")
    }

    func testOversizedPlainTextIsRejected() {
        XCTAssertThrowsError(try extractor.extract(from: SharedPayload(plainText: String(repeating: "a", count: 32 * 1_024 + 1)))) { error in
            XCTAssertEqual(error as? SharePayloadValidationFailure, .textTooLarge(limit: 32 * 1_024, actual: 32 * 1_024 + 1))
        }
    }

    func testMailboxReaderReturnsPublishedEnvelopeAndRemovesOnlyMatchingFile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let envelope = try ShareCaptureEnvelopeV1(
            appBuild: "1",
            title: "Read this later",
            note: nil,
            durationBucketRaw: DurationBucket.upTo30Minutes.rawValue,
            acceptedURLString: "https://example.com/read",
            sourceKindRaw: "url"
        )

        _ = try ShareMailboxWriter().publish(envelope, at: root)
        let reader = ShareMailboxReader()
        let entries = try reader.entries(at: root)
        XCTAssertEqual(entries.map(\.envelope), [envelope])
        try reader.remove(try XCTUnwrap(entries.first), at: root)
        XCTAssertTrue(try reader.entries(at: root).isEmpty)
    }

    func testMailboxMaintenanceSwitchesToValidatedReplacementGeneration() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try envelope(title: "First")
        let replacement = try envelope(title: "Replacement")
        _ = try ShareMailboxWriter().publish(first, at: root)

        try ShareMailboxMaintenance().replaceAll(with: [replacement], at: root)
        XCTAssertEqual(try ShareMailboxReader().entries(at: root).map(\.envelope), [replacement])

        try ShareMailboxMaintenance().eraseAll(at: root)
        XCTAssertTrue(try ShareMailboxReader().entries(at: root).isEmpty)
    }

    func testMailboxMaintenanceBlocksPublicationUntilCommitOrDiscard() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = try envelope(title: "Original")
        let replacement = try envelope(title: "Replacement")
        _ = try ShareMailboxWriter().publish(original, at: root)

        let maintenance = ShareMailboxMaintenance()
        let staged = try maintenance.stageReplacement(with: [replacement], at: root)
        XCTAssertThrowsError(try ShareMailboxWriter().publish(try envelope(title: "Racing save"), at: root)) { error in
            XCTAssertEqual(error as? ShareCaptureError, .mailboxBusy)
        }
        try maintenance.discard(staged, at: root)
        XCTAssertEqual(try ShareMailboxReader().entries(at: root).map(\.envelope), [original])

        _ = try ShareMailboxWriter().publish(try envelope(title: "After maintenance"), at: root)
        XCTAssertEqual(try ShareMailboxReader().entries(at: root).count, 2)
    }

    func testMailboxInspectionPreservesFutureEnvelopeForRawExportAndExplicitDiscard() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = try envelope(title: "Future")
        let publishedURL = try ShareMailboxWriter().publish(original, at: root)
        var raw = try XCTUnwrap(String(data: Data(contentsOf: publishedURL), encoding: .utf8))
        raw = raw.replacingOccurrences(of: "\"envelopeFormatVersion\":1", with: "\"envelopeFormatVersion\":2")
        try XCTUnwrap(raw.data(using: .utf8)).write(to: publishedURL, options: [.atomic])

        let reader = ShareMailboxReader()
        let inspection = try reader.inspect(at: root)
        XCTAssertTrue(inspection.entries.isEmpty)
        let problem = try XCTUnwrap(inspection.problems.first)
        XCTAssertEqual(problem.kind, .unsupportedEnvelopeVersion)
        XCTAssertFalse(try reader.rawRecoveryData(problem).isEmpty)

        try reader.discard(problem, at: root)
        XCTAssertEqual(try reader.inspect(at: root), ShareMailboxInspection(entries: [], problems: []))
    }

    @MainActor
    func testForegroundRefreshImportsCapturePublishedAfterInitialLoad() async throws {
        let fixture = try await makeAppModelFixture()
        let root = fixture.root
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        await fixture.appModel.load()
        let envelope = try envelope(title: "Shared while backgrounded")
        _ = try ShareMailboxWriter().publish(envelope, at: fixture.mailbox)

        XCTAssertTrue(fixture.appModel.state.items.isEmpty)
        await fixture.appModel.refreshSharedCaptures()

        XCTAssertEqual(fixture.appModel.state.items.map(\.title), ["Shared while backgrounded"])
        XCTAssertEqual(fixture.appModel.state.sources.first?.importEnvelopeID, envelope.envelopeID)
        XCTAssertTrue(try ShareMailboxReader().entries(at: fixture.mailbox).isEmpty)
    }

    @MainActor
    func testResolvingRevealImportsCaptureDeferredByGate() async throws {
        let fixture = try await makeAppModelFixture()
        let root = fixture.root
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let now = Date(timeIntervalSince1970: 4_000_000)
        var item = BoxItem(
            title: "Drawn paper",
            durationBucketRaw: DurationBucket.upTo30Minutes.rawValue,
            createdAt: now,
            updatedAt: now
        )
        let session = DrawSession(startedAt: now, availableTime: .upTo30Minutes)
        let attempt = DrawAttempt(
            sessionID: session.id,
            sequence: 1,
            itemID: item.id,
            eligibleCount: 1,
            shownAt: now,
            outcome: .unresolved
        )
        item.lastShownAt = now
        let unresolvedState = PersistedProductState(items: [item], sessions: [session], attempts: [attempt])
        _ = try await fixture.repository.withTransaction {
            $0 = unresolvedState
        }
        let envelope = try envelope(title: "Deferred share")
        _ = try ShareMailboxWriter().publish(envelope, at: fixture.mailbox)

        await fixture.appModel.load()
        XCTAssertEqual(fixture.appModel.state.items.count, 1)
        XCTAssertEqual(try ShareMailboxReader().entries(at: fixture.mailbox).count, 1)

        let dismissed = await fixture.appModel.dismissDraw()
        XCTAssertTrue(dismissed.isCommitted)
        XCTAssertEqual(Set(fixture.appModel.state.items.map(\.title)), ["Drawn paper", "Deferred share"])
        XCTAssertTrue(try ShareMailboxReader().entries(at: fixture.mailbox).isEmpty)
    }

    private func envelope(title: String) throws -> ShareCaptureEnvelopeV1 {
        try ShareCaptureEnvelopeV1(
            appBuild: "1",
            title: title,
            note: nil,
            durationBucketRaw: DurationBucket.upTo30Minutes.rawValue,
            acceptedURLString: nil,
            sourceKindRaw: "shared_text"
        )
    }

    @MainActor
    private func makeAppModelFixture() async throws -> (
        appModel: AppModel,
        repository: GenerationProductRepository,
        root: URL,
        mailbox: URL
    ) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let support = root.appendingPathComponent("support", isDirectory: true)
        let mailbox = root.appendingPathComponent("mailbox", isDirectory: true)
        let repository = try await GenerationProductRepository.open(
            configuration: StoreGenerationConfiguration(applicationSupportURL: support)
        )
        let appModel = AppModel(
            repository: repository,
            shareGroupContainerURL: mailbox,
            sharedJournalStore: SharedProductDataJournalStore(applicationSupportURL: support)
        )
        return (appModel, repository, root, mailbox)
    }
}
