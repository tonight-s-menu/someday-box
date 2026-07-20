import Foundation
import Testing
@testable import SomedayBox

@Suite("Core Box stable projection")
struct CoreBoxProjectionTests {
    @Test func countIncludesUnsupportedActivePaperButExcludesCurrentAndUnresolved() {
        let now = Date(timeIntervalSince1970: 10_000)
        let items = [
            Self.makeItem(index: 0, duration: DurationBucket.upTo10Minutes.rawValue, now: now),
            Self.makeItem(index: 1, duration: "future-duration", now: now),
            Self.makeItem(index: 2, duration: DurationBucket.upTo30Minutes.rawValue, now: now),
            Self.makeItem(index: 3, duration: DurationBucket.upTo60Minutes.rawValue, now: now)
        ]
        let state = PersistedProductState(
            items: items,
            currentPick: CurrentPick(itemID: items[2].id, acceptedAt: now),
            sessions: [DrawSession(id: CoreBoxTestIdentity.sessionID, startedAt: now, context: DrawContext(preset: .fewMinutes))],
            attempts: [DrawAttempt(id: CoreBoxTestIdentity.attemptID, sessionID: CoreBoxTestIdentity.sessionID, sequence: 1, itemID: items[3].id, eligibleCount: 1, shownAt: now, outcome: .unresolved)]
        )
        var unresolved = items[3]
        unresolved.lastShownAt = now
        var fixedState = state
        fixedState.items[3] = unresolved

        let snapshot = CoreBoxSceneSnapshotBuilder().build(
            state: fixedState,
            inputs: .fixture(rendererTier: .full3D, drawContext: DrawContext(preset: .fewMinutes), now: now),
            snapshotVersion: 7
        )

        #expect(snapshot.inBoxCount == 2)
        #expect(snapshot.drawAvailability.totalSupportedCount == 1)
        #expect(snapshot.drawAvailability.selectedContextEligibleCount == 1)
        #expect(snapshot.snapshotVersion == 7)
    }

    @Test func noSelectedContextKeepsAvailabilityVisibleButDoesNotArmDraw() {
        let now = Date(timeIntervalSince1970: 10_000)
        let state = PersistedProductState(items: [
            Self.makeItem(index: 0, duration: DurationBucket.upTo10Minutes.rawValue, now: now),
            Self.makeItem(index: 1, duration: DurationBucket.upTo60Minutes.rawValue, now: now),
            Self.makeItem(index: 2, duration: "future-duration", now: now)
        ])
        let snapshot = CoreBoxSceneSnapshotBuilder().build(
            state: state,
            inputs: .fixture(rendererTier: .full3D, drawContext: nil, now: now),
            snapshotVersion: 8
        )
        #expect(snapshot.inBoxCount == 3)
        #expect(snapshot.drawAvailability.totalSupportedCount == 2)
        #expect(snapshot.drawAvailability.selectedContextEligibleCount == 0)
        #expect(snapshot.drawAvailability.presetCounts.first { $0.preset == DrawPresentationPreset.fewMinutes }?.count == 1)
    }

    @Test func slotMappingIsStableAndLiteIsTheFullPrefix() {
        let now = Date(timeIntervalSince1970: 10_000)
        let state = PersistedProductState(items: (0..<30).map { Self.makeItem(index: $0, duration: DurationBucket.upTo30Minutes.rawValue, now: now) })
        let full = CoreBoxSceneSnapshotBuilder().build(state: state, inputs: .fixture(rendererTier: .full3D, now: now), snapshotVersion: 1)
        let lite = CoreBoxSceneSnapshotBuilder().build(state: state, inputs: .fixture(rendererTier: .lite3D, now: now), snapshotVersion: 2)

        #expect(full.papers.count == 24)
        #expect(lite.papers.count == 10)
        #expect(Array(full.papers.prefix(10)).map { $0.visualSeed } == lite.papers.map { $0.visualSeed })
    }

    @Test func frozenUUIDSeedAndAgeBoundaryAreExact() {
        let now = Date(timeIntervalSince1970: 10_000_000)
        let state = PersistedProductState(items: [CoreBoxTestFixtures.item(id: CoreBoxTestIdentity.itemID)])
        var dated = state.items[0]
        dated = BoxItem(id: dated.id, title: dated.title, durationBucketRaw: dated.durationBucketRaw, createdAt: now.addingTimeInterval(-7 * 24 * 60 * 60), updatedAt: now)
        let snapshot = CoreBoxSceneSnapshotBuilder().build(
            state: PersistedProductState(items: [dated]),
            inputs: .fixture(rendererTier: .full3D, now: now),
            snapshotVersion: 3
        )
        #expect(snapshot.papers.first?.visualSeed == 8_296_213_676_016_154_585)
        #expect(snapshot.papers.first?.ageBand == 1)
    }

    private static func makeItem(index: Int, duration: String, now: Date) -> BoxItem {
        BoxItem(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!,
            title: "Paper \(index)",
            durationBucketRaw: duration,
            createdAt: now.addingTimeInterval(TimeInterval(index)),
            updatedAt: now
        )
    }
}

private extension CoreBoxProjectionInputs {
    static func fixture(
        rendererTier: CoreBoxRendererTier,
        drawContext: DrawContext? = nil,
        now: Date = Date(timeIntervalSince1970: 10_000)
    ) -> CoreBoxProjectionInputs {
        CoreBoxProjectionInputs(rendererTier: rendererTier, motionMode: .normal, drawContext: drawContext, now: now)
    }
}
