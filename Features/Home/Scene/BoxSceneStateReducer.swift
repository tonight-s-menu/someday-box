import Foundation

/// Everything the reducer is allowed to read. Nothing else may reach the scene:
/// persisted product state, an injected clock and time zone, and the §16.2 presentation
/// preferences (SCN-01).
struct BoxSceneInput: Equatable, Sendable {
    var state: PersistedProductState
    var now: Date
    var timeZone: TimeZone
    /// True while an exclusive data operation (restore, erase) holds the arbiter.
    var isExclusiveDataOperationInProgress: Bool
    /// §16.2 环境随时间变化 / Ambience follows the clock.
    var ambienceFollowsClock: Bool

    init(
        state: PersistedProductState,
        now: Date,
        timeZone: TimeZone = .current,
        isExclusiveDataOperationInProgress: Bool = false,
        ambienceFollowsClock: Bool = true
    ) {
        self.state = state
        self.now = now
        self.timeZone = timeZone
        self.isExclusiveDataOperationInProgress = isExclusiveDataOperationInProgress
        self.ambienceFollowsClock = ambienceFollowsClock
    }
}

/// `box-scene-v1`: the pure derivation from persisted truth to what the scene may show.
///
/// Every rule here is named by the feature specification — density bands §6.2, seeded
/// layout §6.3, gates §6.4, forms and age tiers §8 — and changing any of them requires a
/// new version identifier plus updated fixtures, exactly like the draw policy.
enum BoxSceneStateReducer {
    private enum Elapsed {
        static let day: TimeInterval = 86_400
        static let fresh: TimeInterval = 7 * day
        static let aged: TimeInterval = 90 * day
        static let longKept: TimeInterval = 180 * day
        static let longKeptQuiet: TimeInterval = 90 * day
    }

    static func reduce(_ input: BoxSceneInput) -> BoxSceneSnapshot {
        let state = input.state
        // Compared as a raw value: building an enum for each of a full journal's attempts
        // is the difference between a cheap scan and a measurable one.
        let unresolvedRaw = DrawAttemptOutcome.unresolved.rawValue
        let unresolvedAttempt = state.attempts.first { $0.outcomeRaw == unresolvedRaw }
        let importedItemIDs = Set(state.sources.map(\.itemID))

        // BOX-01: Active, with a supported duration, minus the Current Pick and the item a
        // pending attempt reserves. The scene never redefines this count; it visualises it.
        //
        // Indices travel instead of records: only the sampled handful is ever materialised,
        // so a five-thousand-paper box costs one scan and one sort of small keys (PRF-02).
        var drawableIndices: [Int] = []
        drawableIndices.reserveCapacity(state.items.count)
        for index in state.items.indices {
            let item = state.items[index]
            guard item.lifecycle == .active,
                  item.supportedDuration != nil,
                  item.id != state.currentPick?.itemID,
                  item.id != unresolvedAttempt?.itemID
            else { continue }
            drawableIndices.append(index)
        }

        let drawableCount = drawableIndices.count
        let ordered = stackOrder(of: drawableIndices, in: state.items, now: input.now)
        let visible = sample(ordered, count: visibleInstanceCount(drawableCount: drawableCount))

        return BoxSceneSnapshot(
            drawableCount: drawableCount,
            visiblePapers: visible.enumerated().map { stackIndex, itemIndex in
                paper(
                    for: state.items[itemIndex],
                    stackIndex: stackIndex,
                    now: input.now,
                    importedItemIDs: importedItemIDs
                )
            },
            isStackPressedFull: drawableCount > 200,
            // The Current Pick sits at the lid rather than in the stack, so its stack index
            // carries no meaning; its seeded offsets are still its resting place for the
            // put-back drop (§7.5).
            currentPick: state.currentPick
                .flatMap { pick in state.items.first { $0.id == pick.itemID } }
                .map { paper(for: $0, stackIndex: 0, now: input.now, importedItemIDs: importedItemIDs) },
            memoryCount: state.memories.count,
            gate: gate(
                isExclusiveDataOperationInProgress: input.isExclusiveDataOperationInProgress,
                unresolvedAttempt: unresolvedAttempt
            ),
            light: TimeOfDayLightDriver.rig(
                at: input.now,
                timeZone: input.timeZone,
                followsClock: input.ambienceFollowsClock
            )
        )
    }

    // MARK: - Density (§6.2)

    /// The §6.2 band table. The count is an honest impression of the drawable total, which
    /// stays displayed and authoritative alongside it (SCN-02).
    static func visibleInstanceCount(drawableCount n: Int) -> Int {
        switch n {
        case ...0: 0
        case 1...12: n
        case 13...48: 12 + ceilingDivide(n - 12, 4)
        case 49...200: 21 + ceilingDivide(n - 48, 16)
        default: 32
        }
    }

    private static func ceilingDivide(_ dividend: Int, _ divisor: Int) -> Int {
        (dividend + divisor - 1) / divisor
    }

    // MARK: - Stack order and sampling (§6.3, §8)

    /// Bottom to top: long-kept papers sunk, fresh papers on top (§8). Within a tier the
    /// older paper lies deeper, and the UUID bytes break exact ties so the order is total
    /// and reproducible.
    ///
    /// The sort carries small keys rather than whole records: comparing papers directly
    /// would copy strings and allocate a UUID description on every tie.
    static func stackOrder(of indices: [Int], in items: [BoxItem], now: Date) -> [Int] {
        struct StackKey {
            let depth: Int
            let createdAt: Date
            let itemIndex: Int
        }

        var keys: [StackKey] = []
        keys.reserveCapacity(indices.count)
        for index in indices {
            keys.append(
                StackKey(
                    depth: depth(of: ageTier(for: items[index], now: now)),
                    createdAt: items[index].createdAt,
                    itemIndex: index
                )
            )
        }

        keys.sort { left, right in
            if left.depth != right.depth { return left.depth > right.depth }
            if left.createdAt != right.createdAt { return left.createdAt < right.createdAt }
            return isOrderedBefore(items[left.itemIndex].id, items[right.itemIndex].id)
        }

        return keys.map(\.itemIndex)
    }

    /// Total order over UUIDs by their bytes, which matches their canonical string order
    /// without building a string.
    private static func isOrderedBefore(_ lhs: UUID, _ rhs: UUID) -> Bool {
        withUnsafeBytes(of: lhs.uuid) { left in
            withUnsafeBytes(of: rhs.uuid) { right in
                for offset in 0..<16 where left[offset] != right[offset] {
                    return left[offset] < right[offset]
                }
                return false
            }
        }
    }

    /// How deep in the stack a tier rests; larger sinks further.
    private static func depth(of tier: PaperAgeTier) -> Int {
        switch tier {
        case .fresh: 0
        case .settled: 1
        case .aged: 2
        case .longKept: 3
        }
    }

    /// When more papers are drawable than the band allows instances, the visible set is an
    /// even stride across the ordered stack — endpoints included — rather than its top
    /// slice, so the tier mix a box actually holds stays visible and both the deepest and
    /// the newest paper have a place (§6.2 impression honesty).
    ///
    /// The stride is at least one whole index because the band count never exceeds the
    /// drawable count here, so no paper is selected twice.
    static func sample<Element>(_ ordered: [Element], count: Int) -> [Element] {
        guard count > 0, !ordered.isEmpty else { return [] }
        guard count < ordered.count else { return ordered }
        guard count > 1 else { return [ordered[ordered.count - 1]] }
        return (0..<count).map { ordered[$0 * (ordered.count - 1) / (count - 1)] }
    }

    // MARK: - Per-paper derivation (§8)

    private static func paper(
        for item: BoxItem,
        stackIndex: Int,
        now: Date,
        importedItemIDs: Set<UUID>
    ) -> BoxScenePaper {
        BoxScenePaper(
            id: item.id,
            origin: importedItemIDs.contains(item.id) ? .shareImported : .manualCapture,
            form: form(for: item.supportedDuration),
            ageTier: ageTier(for: item, now: now),
            transform: restingTransform(itemID: item.id, stackIndex: stackIndex)
        )
    }

    static func form(for duration: DurationBucket?) -> PaperForm {
        switch duration {
        case .upTo10Minutes, .upTo30Minutes: .smallSlip
        case .upTo60Minutes, .upTo120Minutes: .standardFold
        case .upTo240Minutes, .upTo480Minutes: .doubleFold
        case nil: .unknownDuration
        }
    }

    /// §8 age tiers with exact thresholds. A `createdAt` in the future clamps to fresh
    /// rather than producing a negative age (PAPR-03).
    static func ageTier(for item: BoxItem, now: Date) -> PaperAgeTier {
        let age = max(0, now.timeIntervalSince(item.createdAt))
        let quiet = item.lastShownAt.map { now.timeIntervalSince($0) >= Elapsed.longKeptQuiet } ?? true
        if age >= Elapsed.longKept, quiet { return .longKept }
        if age < Elapsed.fresh { return .fresh }
        if age <= Elapsed.aged { return .settled }
        return .aged
    }

    // MARK: - Seeded layout (§6.3)

    /// A paper's resting transform is a deterministic function of its UUID, so the same
    /// record set arranges identically across relaunches and membership changes move only
    /// the papers that entered or left (SCN-03).
    static func restingTransform(itemID: UUID, stackIndex: Int) -> PaperRestingTransform {
        var seed = SeededLayoutSource(itemID: itemID)
        return PaperRestingTransform(
            lateralOffset: seed.nextSigned() * 0.035,
            depthOffset: seed.nextSigned() * 0.028,
            yawRadians: seed.nextSigned() * 0.22,
            bend: seed.nextUnit(),
            stackIndex: stackIndex
        )
    }

    // MARK: - Gates (§6.4)

    private static func gate(
        isExclusiveDataOperationInProgress: Bool,
        unresolvedAttempt: DrawAttempt?
    ) -> BoxSceneGate {
        if isExclusiveDataOperationInProgress { return .exclusiveDataOperation }
        if let unresolvedAttempt { return .unresolvedAttempt(itemID: unresolvedAttempt.itemID) }
        return .open
    }
}

/// A deterministic value source seeded from a record's UUID.
///
/// `Hasher` is seeded per process and would rearrange the box on every launch, so the
/// layout uses FNV-1a over the UUID bytes followed by a SplitMix64 stream: stable across
/// launches, devices, and OS versions, and free of any product meaning.
struct SeededLayoutSource {
    private var state: UInt64

    init(itemID: UUID) {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        withUnsafeBytes(of: itemID.uuid) { bytes in
            for byte in bytes {
                hash ^= UInt64(byte)
                hash &*= 0x0000_0100_0000_01b3
            }
        }
        state = hash
    }

    /// The next value in 0…1.
    mutating func nextUnit() -> Float {
        state &+= 0x9e37_79b9_7f4a_7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58_476d_1ce4_e5b9
        z = (z ^ (z >> 27)) &* 0x94d0_49bb_1331_11eb
        z = z ^ (z >> 31)
        return Float(z >> 40) / Float(1 << 24)
    }

    /// The next value in −1…1.
    mutating func nextSigned() -> Float {
        nextUnit() * 2 - 1
    }
}
