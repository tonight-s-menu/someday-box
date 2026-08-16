import Foundation
import XCTest
#if canImport(SomedayBox)
@testable import SomedayBox
#else
@testable import SomedayBoxDomain
#endif

/// `box-scene-v1` fixtures: specification §6.2 density bands, §6.3 seeded layout,
/// §6.4 gates, §8 forms and age tiers, §9.1 light driver.
/// Acceptance SCN-01/02/03, PAPR-01/03/04, PRF-02 (reducer half).
final class BoxSceneDerivationTests: XCTestCase {
    // MARK: - Density bands (§6.2, SCN-02)

    func testVisibleInstanceCountFollowsTheBandTableAtEveryBoundary() {
        let expected = [
            0: 0,
            1: 1,
            12: 12,
            13: 13,
            48: 21,
            49: 22,
            200: 31,
            201: 32,
            5_000: 32,
        ]
        for (drawable, instances) in expected {
            XCTAssertEqual(
                BoxSceneStateReducer.visibleInstanceCount(drawableCount: drawable),
                instances,
                "Band table broke at \(drawable) drawable papers."
            )
        }
    }

    func testVisibleStackNeverGrowsFasterThanTheBandTable() {
        var previous = 0
        for drawable in 0...260 {
            let instances = BoxSceneStateReducer.visibleInstanceCount(drawableCount: drawable)
            XCTAssertGreaterThanOrEqual(instances, previous)
            XCTAssertLessThanOrEqual(instances, 32)
            XCTAssertLessThanOrEqual(instances, max(drawable, 0))
            previous = instances
        }
    }

    func testStackRendersTheBandCountAndKeepsTheNumericCountAuthoritative() {
        let snapshot = reduce(items: (0..<60).map { activeItem(index: $0) })
        XCTAssertEqual(snapshot.drawableCount, 60)
        XCTAssertEqual(snapshot.visiblePapers.count, 22)
        XCTAssertFalse(snapshot.isStackPressedFull)
    }

    func testStackReadsPressedFullOnlyAboveTwoHundred() {
        XCTAssertFalse(reduce(items: (0..<200).map { activeItem(index: $0) }).isStackPressedFull)
        XCTAssertTrue(reduce(items: (0..<201).map { activeItem(index: $0) }).isStackPressedFull)
    }

    func testSampledStackHasNoRepeatedPaper() {
        let snapshot = reduce(items: (0..<5_000).map { activeItem(index: $0) })
        XCTAssertEqual(snapshot.visiblePapers.count, 32)
        XCTAssertEqual(Set(snapshot.visiblePapers.map(\.id)).count, 32)
    }

    // MARK: - Drawable count (BOX-01)

    func testDrawableCountMatchesTheProductDefinition() {
        let drawable = activeItem(index: 1)
        let picked = activeItem(index: 2)
        let reserved = activeItem(index: 3)
        let unknownDuration = BoxItem(
            id: deterministicID(4),
            title: "Paper",
            durationBucketRaw: "future_duration",
            createdAt: now,
            updatedAt: now
        )
        var archived = activeItem(index: 5)
        archived.lifecycle = .archived
        var completed = activeItem(index: 6)
        completed.lifecycle = .completed

        let snapshot = BoxSceneStateReducer.reduce(
            BoxSceneInput(
                state: PersistedProductState(
                    items: [drawable, picked, reserved, unknownDuration, archived, completed],
                    currentPick: CurrentPick(itemID: picked.id, acceptedAt: now),
                    attempts: [
                        DrawAttempt(
                            sessionID: deterministicID(900),
                            sequence: 1,
                            itemID: reserved.id,
                            eligibleCount: 3,
                            shownAt: now,
                            outcome: .unresolved
                        )
                    ]
                ),
                now: now,
                timeZone: fixedTimeZone
            )
        )

        XCTAssertEqual(snapshot.drawableCount, 1)
        XCTAssertEqual(snapshot.visiblePapers.map(\.id), [drawable.id])
        XCTAssertEqual(snapshot.currentPick?.id, picked.id)
    }

    func testUnknownDurationRendersAsANeutralSlipAndNeverJoinsTheStack() {
        let unknownDuration = BoxItem(
            id: deterministicID(1),
            title: "Paper",
            durationBucketRaw: "future_duration",
            createdAt: now,
            updatedAt: now
        )
        let snapshot = reduce(items: [unknownDuration])
        XCTAssertEqual(snapshot.drawableCount, 0)
        XCTAssertTrue(snapshot.visiblePapers.isEmpty)
        XCTAssertEqual(BoxSceneStateReducer.form(for: unknownDuration.supportedDuration), .unknownDuration)
    }

    // MARK: - Forms and origin (§8, PAPR-01/02/04)

    func testFormDerivesOnlyFromTheDurationBucket() {
        XCTAssertEqual(BoxSceneStateReducer.form(for: .upTo10Minutes), .smallSlip)
        XCTAssertEqual(BoxSceneStateReducer.form(for: .upTo30Minutes), .smallSlip)
        XCTAssertEqual(BoxSceneStateReducer.form(for: .upTo60Minutes), .standardFold)
        XCTAssertEqual(BoxSceneStateReducer.form(for: .upTo120Minutes), .standardFold)
        XCTAssertEqual(BoxSceneStateReducer.form(for: .upTo240Minutes), .doubleFold)
        XCTAssertEqual(BoxSceneStateReducer.form(for: .upTo480Minutes), .doubleFold)
        XCTAssertEqual(BoxSceneStateReducer.form(for: nil), .unknownDuration)
    }

    func testOriginComesFromAPersistedSourceReference() {
        let imported = activeItem(index: 1)
        let manual = activeItem(index: 2)
        let snapshot = BoxSceneStateReducer.reduce(
            BoxSceneInput(
                state: PersistedProductState(
                    items: [imported, manual],
                    sources: [
                        SourceReference(
                            id: deterministicID(700),
                            itemID: imported.id,
                            importEnvelopeID: deterministicID(701),
                            acceptedURLString: "https://example.invalid/page",
                            sourceKindRaw: "url",
                            capturedAt: now
                        )
                    ]
                ),
                now: now,
                timeZone: fixedTimeZone
            )
        )
        let origins = Dictionary(uniqueKeysWithValues: snapshot.visiblePapers.map { ($0.id, $0.origin) })
        XCTAssertEqual(origins[imported.id], .shareImported)
        XCTAssertEqual(origins[manual.id], .manualCapture)
    }

    /// PAPR-01: no derivation path may read a title or a note.
    func testTitleAndNoteChangesCannotChangeAnyDerivedValue() {
        let plain = (0..<40).map { activeItem(index: $0) }
        let rewritten = plain.map { item -> BoxItem in
            var copy = item
            copy.title = "完全不同的标题 with different content and length"
            copy.note = String(repeating: "note ", count: 60)
            return copy
        }
        XCTAssertEqual(reduce(items: plain), reduce(items: rewritten))
    }

    // MARK: - Age tiers (§8, PAPR-03)

    func testAgeTiersUseExactSevenNinetyAndOneHundredEightyDayThresholds() {
        XCTAssertEqual(tier(createdDaysAgo: 0), .fresh)
        XCTAssertEqual(tier(createdSecondsAgo: 7 * day - 1), .fresh)
        XCTAssertEqual(tier(createdSecondsAgo: 7 * day), .settled)
        XCTAssertEqual(tier(createdSecondsAgo: 90 * day), .settled)
        XCTAssertEqual(tier(createdSecondsAgo: 90 * day + 1), .aged)
        XCTAssertEqual(tier(createdSecondsAgo: 180 * day - 1), .aged)
        XCTAssertEqual(tier(createdSecondsAgo: 180 * day), .longKept)
    }

    func testLongKeptAlsoRequiresTheProductToHaveBeenQuiet() {
        XCTAssertEqual(
            tier(createdSecondsAgo: 200 * day, lastShownSecondsAgo: 90 * day - 1),
            .aged
        )
        XCTAssertEqual(
            tier(createdSecondsAgo: 200 * day, lastShownSecondsAgo: 90 * day),
            .longKept
        )
    }

    func testFutureCreationDateClampsToFresh() {
        XCTAssertEqual(tier(createdSecondsAgo: -30 * day), .fresh)
    }

    func testLongKeptPapersSinkAndFreshPapersRiseInTheStack() {
        let fresh = activeItem(index: 1, createdSecondsAgo: 0)
        let settled = activeItem(index: 2, createdSecondsAgo: 30 * day)
        let aged = activeItem(index: 3, createdSecondsAgo: 120 * day)
        let longKept = activeItem(index: 4, createdSecondsAgo: 400 * day)
        let snapshot = reduce(items: [settled, longKept, fresh, aged])
        XCTAssertEqual(
            snapshot.visiblePapers.map(\.ageTier),
            [.longKept, .aged, .settled, .fresh]
        )
        XCTAssertEqual(snapshot.visiblePapers.map(\.transform.stackIndex), [0, 1, 2, 3])
    }

    // MARK: - Seeded layout (§6.3, SCN-03)

    func testIdenticalRecordSetsProduceIdenticalLayout() {
        let items = (0..<40).map { activeItem(index: $0) }
        XCTAssertEqual(reduce(items: items), reduce(items: items))
    }

    func testLayoutIsIndependentOfTheOrderRecordsArriveIn() {
        let items = (0..<40).map { activeItem(index: $0) }
        XCTAssertEqual(reduce(items: items), reduce(items: items.reversed()))
    }

    func testEachPaperKeepsItsOwnSeededRestingPlaceWhenTheStackChanges() {
        let items = (0..<20).map { activeItem(index: $0) }
        let before = reduce(items: items)
        let after = reduce(items: Array(items.dropLast()))
        let survivor = items[0].id
        XCTAssertEqual(
            before.visiblePapers.first { $0.id == survivor }?.transform.lateralOffset,
            after.visiblePapers.first { $0.id == survivor }?.transform.lateralOffset
        )
    }

    func testSeededTransformsStayInsideTheBoxAndDifferBetweenPapers() {
        let snapshot = reduce(items: (0..<32).map { activeItem(index: $0) })
        for paper in snapshot.visiblePapers {
            XCTAssertLessThanOrEqual(abs(paper.transform.lateralOffset), 0.035)
            XCTAssertLessThanOrEqual(abs(paper.transform.depthOffset), 0.028)
            XCTAssertLessThanOrEqual(abs(paper.transform.yawRadians), 0.22)
            XCTAssertTrue((0...1).contains(paper.transform.bend))
        }
        XCTAssertEqual(
            Set(snapshot.visiblePapers.map(\.transform.lateralOffset)).count,
            snapshot.visiblePapers.count,
            "Seeded offsets collided, so papers would stack in visible columns."
        )
    }

    // MARK: - Gates (§6.4, SCN-07/08)

    func testUnresolvedAttemptOpensTheSceneInRevealFocus() {
        let reserved = activeItem(index: 1)
        let snapshot = BoxSceneStateReducer.reduce(
            BoxSceneInput(
                state: PersistedProductState(
                    items: [reserved],
                    attempts: [
                        DrawAttempt(
                            sessionID: deterministicID(900),
                            sequence: 1,
                            itemID: reserved.id,
                            eligibleCount: 1,
                            shownAt: now,
                            outcome: .unresolved
                        )
                    ]
                ),
                now: now,
                timeZone: fixedTimeZone
            )
        )
        XCTAssertEqual(snapshot.gate, .unresolvedAttempt(itemID: reserved.id))
    }

    func testExclusiveDataOperationOutranksEveryOtherGate() {
        let reserved = activeItem(index: 1)
        let snapshot = BoxSceneStateReducer.reduce(
            BoxSceneInput(
                state: PersistedProductState(
                    items: [reserved],
                    attempts: [
                        DrawAttempt(
                            sessionID: deterministicID(900),
                            sequence: 1,
                            itemID: reserved.id,
                            eligibleCount: 1,
                            shownAt: now,
                            outcome: .unresolved
                        )
                    ]
                ),
                now: now,
                timeZone: fixedTimeZone,
                isExclusiveDataOperationInProgress: true
            )
        )
        XCTAssertEqual(snapshot.gate, .exclusiveDataOperation)
    }

    func testResolvedAttemptsLeaveTheSceneOpen() {
        XCTAssertEqual(reduce(items: [activeItem(index: 1)]).gate, .open)
    }

    // MARK: - Time of day (§9.1)

    func testEveryBandBoundaryClassifiesExactly() {
        XCTAssertEqual(TimeOfDayLightDriver.band(atMinuteOfDay: 4 * 60 + 59), .night)
        XCTAssertEqual(TimeOfDayLightDriver.band(atMinuteOfDay: 5 * 60), .dawn)
        XCTAssertEqual(TimeOfDayLightDriver.band(atMinuteOfDay: 7 * 60 + 59), .dawn)
        XCTAssertEqual(TimeOfDayLightDriver.band(atMinuteOfDay: 8 * 60), .day)
        XCTAssertEqual(TimeOfDayLightDriver.band(atMinuteOfDay: 16 * 60 + 59), .day)
        XCTAssertEqual(TimeOfDayLightDriver.band(atMinuteOfDay: 17 * 60), .dusk)
        XCTAssertEqual(TimeOfDayLightDriver.band(atMinuteOfDay: 19 * 60 + 59), .dusk)
        XCTAssertEqual(TimeOfDayLightDriver.band(atMinuteOfDay: 20 * 60), .night)
    }

    func testAnchorMinutesProduceTheirExactAnchorValues() {
        XCTAssertEqual(TimeOfDayLightDriver.rig(atMinuteOfDay: 750).colorTemperatureKelvin, 6_500)
        XCTAssertEqual(TimeOfDayLightDriver.rig(atMinuteOfDay: 750).relativeIntensity, 1)
        XCTAssertEqual(TimeOfDayLightDriver.rig(atMinuteOfDay: 30).colorTemperatureKelvin, 2_700)
        XCTAssertEqual(TimeOfDayLightDriver.rig(atMinuteOfDay: 390).colorTemperatureKelvin, 2_900)
        XCTAssertEqual(TimeOfDayLightDriver.rig(atMinuteOfDay: 1_110).colorTemperatureKelvin, 3_200)
    }

    func testTheRigInterpolatesSmoothlyAndStaysInsideItsStatedRanges() {
        var previous = TimeOfDayLightDriver.rig(atMinuteOfDay: 0)
        for minute in 0..<1_440 {
            let rig = TimeOfDayLightDriver.rig(atMinuteOfDay: minute)
            XCTAssertTrue((2_700...6_500).contains(rig.colorTemperatureKelvin))
            XCTAssertTrue((0...1).contains(rig.relativeIntensity))
            XCTAssertTrue((0...1).contains(rig.shadowSoftness))
            XCTAssertLessThan(abs(rig.colorTemperatureKelvin - previous.colorTemperatureKelvin), 40)
            previous = rig
        }
    }

    func testTheRigWrapsAcrossMidnightWithoutAJump() {
        let lastMinute = TimeOfDayLightDriver.rig(atMinuteOfDay: 1_439)
        let firstMinute = TimeOfDayLightDriver.rig(atMinuteOfDay: 0)
        XCTAssertLessThan(abs(lastMinute.colorTemperatureKelvin - firstMinute.colorTemperatureKelvin), 40)
    }

    func testTheSameWallClockTimeAlwaysProducesTheSameRig() {
        let morning = Date(timeIntervalSince1970: 1_760_000_000)
        XCTAssertEqual(
            TimeOfDayLightDriver.rig(at: morning, timeZone: fixedTimeZone),
            TimeOfDayLightDriver.rig(at: morning.addingTimeInterval(day), timeZone: fixedTimeZone)
        )
    }

    func testSwitchingOffClockAmbienceHoldsOneSteadyRig() {
        let night = Date(timeIntervalSince1970: 1_760_000_000)
        let held = TimeOfDayLightDriver.rig(at: night, timeZone: fixedTimeZone, followsClock: false)
        XCTAssertEqual(
            held,
            TimeOfDayLightDriver.rig(
                at: night.addingTimeInterval(9 * 3_600),
                timeZone: fixedTimeZone,
                followsClock: false
            )
        )
        XCTAssertEqual(held.band, .day)
    }

    // MARK: - Budget (PRF-02, reducer half)

    /// The reducer must hold its budget on a dataset shaped like the baseline §12.4
    /// `performance-v1` fixture: 5,000 items (4,000 Active, 500 Completed, 500 Archived),
    /// 1,000 ended sessions owning 25,000 resolved attempts, and 5,000 memories.
    ///
    /// This builds that shape in the test rather than loading the frozen, digest-identified
    /// fixture artifact, which does not exist in the repository yet. Timing on a simulator
    /// is indicative, not device evidence.
    func testFullPassOverAPerformanceShapedDatasetStaysInsideItsBudget() {
        let input = BoxSceneInput(
            state: performanceShapedState(),
            now: now,
            timeZone: fixedTimeZone
        )

        _ = BoxSceneStateReducer.reduce(input)  // warm caches, then measure a full pass
        let elapsed = ContinuousClock().measure { _ = BoxSceneStateReducer.reduce(input) }

        XCTAssertLessThan(
            elapsed,
            .milliseconds(50),
            "Reducer full pass exceeded the §15.5 budget: \(elapsed)"
        )
        XCTAssertEqual(BoxSceneStateReducer.reduce(input).drawableCount, 4_000)
        XCTAssertEqual(BoxSceneStateReducer.reduce(input).visiblePapers.count, 32)
    }

    // MARK: - Fixtures

    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let day: TimeInterval = 86_400
    private let fixedTimeZone = TimeZone(secondsFromGMT: 0)!

    private func reduce(items: [BoxItem]) -> BoxSceneSnapshot {
        BoxSceneStateReducer.reduce(
            BoxSceneInput(
                state: PersistedProductState(items: items),
                now: now,
                timeZone: fixedTimeZone
            )
        )
    }

    private func tier(
        createdDaysAgo days: Int = 0,
        lastShownSecondsAgo: TimeInterval? = nil
    ) -> PaperAgeTier {
        tier(createdSecondsAgo: Double(days) * day, lastShownSecondsAgo: lastShownSecondsAgo)
    }

    private func tier(
        createdSecondsAgo seconds: TimeInterval,
        lastShownSecondsAgo: TimeInterval? = nil
    ) -> PaperAgeTier {
        BoxSceneStateReducer.ageTier(
            for: activeItem(index: 1, createdSecondsAgo: seconds, lastShownSecondsAgo: lastShownSecondsAgo),
            now: now
        )
    }

    private func activeItem(
        index: Int,
        createdSecondsAgo: TimeInterval = 0,
        lastShownSecondsAgo: TimeInterval? = nil,
        duration: DurationBucket = .upTo30Minutes
    ) -> BoxItem {
        BoxItem(
            id: deterministicID(index),
            title: "Paper \(index)",
            durationBucketRaw: duration.rawValue,
            createdAt: now.addingTimeInterval(-createdSecondsAgo),
            updatedAt: now,
            lastShownAt: lastShownSecondsAgo.map { now.addingTimeInterval(-$0) }
        )
    }

    private func performanceShapedState() -> PersistedProductState {
        let title = String(repeating: "记录 note ", count: 8)
        let note = String(repeating: "内容 content ", count: 40)
        let durations = DurationBucket.allCases

        var items: [BoxItem] = []
        items.reserveCapacity(5_000)
        for index in 0..<5_000 {
            let lifecycle: PaperLifecycle = switch index {
            case ..<4_000: .active
            case ..<4_500: .completed
            default: .archived
            }
            items.append(
                BoxItem(
                    id: deterministicID(index),
                    title: title,
                    note: note,
                    durationBucketRaw: durations[index % durations.count].rawValue,
                    lifecycle: lifecycle,
                    createdAt: now.addingTimeInterval(-Double(index % 400) * day),
                    updatedAt: now,
                    completedAt: lifecycle == .completed ? now : nil,
                    lastShownAt: index.isMultiple(of: 3) ? now.addingTimeInterval(-Double(index % 200) * day) : nil
                )
            )
        }

        var sessions: [DrawSession] = []
        var attempts: [DrawAttempt] = []
        sessions.reserveCapacity(1_000)
        attempts.reserveCapacity(25_000)
        for sessionIndex in 0..<1_000 {
            let sessionID = deterministicID(100_000 + sessionIndex)
            sessions.append(
                DrawSession(
                    id: sessionID,
                    startedAt: now.addingTimeInterval(-Double(sessionIndex) * day),
                    endedAt: now.addingTimeInterval(-Double(sessionIndex) * day + 600),
                    availableTime: .notSure
                )
            )
            for sequence in 0..<25 {
                attempts.append(
                    DrawAttempt(
                        id: deterministicID(200_000 + sessionIndex * 25 + sequence),
                        sessionID: sessionID,
                        sequence: sequence,
                        itemID: items[(sessionIndex * 25 + sequence) % 4_000].id,
                        eligibleCount: 4_000,
                        shownAt: now.addingTimeInterval(-Double(sessionIndex) * day),
                        outcome: .dismissed
                    )
                )
            }
        }

        let memories = (0..<5_000).map { index in
            CompletionMemory(
                id: deterministicID(400_000 + index),
                sourceItemID: items[index].id,
                titleSnapshot: title,
                noteSnapshot: note,
                durationSnapshotRaw: durations[index % durations.count].rawValue,
                completedAt: now.addingTimeInterval(-Double(index % 900) * day)
            )
        }

        return PersistedProductState(
            items: items,
            currentPick: nil,
            sessions: sessions,
            attempts: attempts,
            memories: memories
        )
    }

    private func deterministicID(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index))!
    }
}
