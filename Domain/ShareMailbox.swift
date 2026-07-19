import CryptoKit
import Foundation

public enum ShareCaptureLimits {
    public static let envelopeBytes = 16 * 1_024
    public static let incomingCount = 256
    public static let incomingBytes = 4 * 1_024 * 1_024
    public static let temporaryCount = 64
    public static let temporaryBytes = 1 * 1_024 * 1_024
}

public enum ShareCaptureError: Error, Equatable, Sendable {
    case invalidEnvelope
    case invalidChecksum
    case nonCanonicalEncoding
    case unsupportedEnvelopeVersion(Int)
    case mailboxBusy
    case mailboxFull
    case protectedDataUnavailable
    case publicationFailed
}

private struct MailboxManifestV1: Codable {
    let formatVersion: Int
    let activeGenerationID: UUID
    let epoch: Int64
    let state: String
    let operationID: UUID?
    let stagedGenerationID: UUID?
    let checksumSHA256: String

    static func make(activeGenerationID: UUID, epoch: Int64 = 0) -> Self {
        make(activeGenerationID: activeGenerationID, epoch: epoch, state: "idle", operationID: nil, stagedGenerationID: nil)
    }

    static func maintenance(
        activeGenerationID: UUID,
        stagedGenerationID: UUID,
        epoch: Int64,
        operationID: UUID
    ) -> Self {
        make(
            activeGenerationID: activeGenerationID,
            epoch: epoch,
            state: "maintenance",
            operationID: operationID,
            stagedGenerationID: stagedGenerationID
        )
    }

    private static func make(
        activeGenerationID: UUID,
        epoch: Int64,
        state: String,
        operationID: UUID?,
        stagedGenerationID: UUID?
    ) -> Self {
        let payload = Payload(
            formatVersion: 1,
            activeGenerationID: activeGenerationID,
            epoch: epoch,
            state: state,
            operationID: operationID,
            stagedGenerationID: stagedGenerationID
        )
        let checksum = SHA256.hash(data: (try? ShareCaptureEnvelopeV1.encoder.encode(payload)) ?? Data())
            .map { String(format: "%02x", $0) }.joined()
        return Self(
            formatVersion: payload.formatVersion,
            activeGenerationID: payload.activeGenerationID,
            epoch: payload.epoch,
            state: payload.state,
            operationID: payload.operationID,
            stagedGenerationID: payload.stagedGenerationID,
            checksumSHA256: checksum
        )
    }

    func validatedGenerationID() throws -> UUID {
        let payload = try validatedPayload()
        guard payload.state == "idle" else { throw ShareCaptureError.mailboxBusy }
        return payload.activeGenerationID
    }

    func validatedPayload() throws -> Payload {
        let payload = Payload(
            formatVersion: formatVersion,
            activeGenerationID: activeGenerationID,
            epoch: epoch,
            state: state,
            operationID: operationID,
            stagedGenerationID: stagedGenerationID
        )
        let checksum = SHA256.hash(data: try ShareCaptureEnvelopeV1.encoder.encode(payload))
            .map { String(format: "%02x", $0) }.joined()
        guard formatVersion == 1, checksum == checksumSHA256 else {
            throw ShareCaptureError.invalidChecksum
        }
        guard state == "idle" || state == "maintenance" else { throw ShareCaptureError.invalidEnvelope }
        return payload
    }

    struct Payload: Codable {
        let formatVersion: Int
        let activeGenerationID: UUID
        let epoch: Int64
        let state: String
        let operationID: UUID?
        let stagedGenerationID: UUID?
    }
}

public struct ShareCaptureEnvelopeV1: Codable, Equatable, Sendable {
    public static let formatVersion = 1
    public static let canonicalizationVersion = 1

    public let envelopeFormatVersion: Int
    public let envelopeID: UUID
    public let createdAtMilliseconds: Int64
    public let appBuild: String
    public let title: String
    public let note: String?
    public let durationBucketRaw: String
    public let acceptedURLString: String?
    public let sourceKindRaw: String
    public let canonicalizationVersion: Int
    public let checksumSHA256: String

    public init(
        envelopeID: UUID = UUID(),
        createdAt: Date = Date(),
        appBuild: String,
        title: String,
        note: String?,
        durationBucketRaw: String,
        acceptedURLString: String?,
        sourceKindRaw: String
    ) throws {
        _ = try PaperContentValidator().validate(title: title, note: note)
        guard DurationBucket(rawValue: durationBucketRaw) != nil,
              sourceKindRaw.utf8.count <= 64,
              !sourceKindRaw.isEmpty,
              acceptedURLString?.utf8.count ?? 0 <= 4_096
        else { throw ShareCaptureError.invalidEnvelope }
        let milliseconds = Int64((createdAt.timeIntervalSince1970 * 1_000).rounded())
        let payload = Payload(
            envelopeFormatVersion: Self.formatVersion,
            envelopeID: envelopeID,
            createdAtMilliseconds: milliseconds,
            appBuild: appBuild,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note,
            durationBucketRaw: durationBucketRaw,
            acceptedURLString: acceptedURLString,
            sourceKindRaw: sourceKindRaw,
            canonicalizationVersion: Self.canonicalizationVersion
        )
        self.init(payload: payload, checksumSHA256: Self.checksum(for: payload))
    }

    public func canonicalData() throws -> Data {
        let data = try Self.encoder.encode(self)
        guard data.count <= ShareCaptureLimits.envelopeBytes else { throw ShareCaptureError.invalidEnvelope }
        return data
    }

    public static func decode(_ data: Data) throws -> Self {
        guard data.count <= ShareCaptureLimits.envelopeBytes else { throw ShareCaptureError.invalidEnvelope }
        let envelope = try Self.decoder.decode(Self.self, from: data)
        guard envelope.envelopeFormatVersion == formatVersion else {
            throw ShareCaptureError.unsupportedEnvelopeVersion(envelope.envelopeFormatVersion)
        }
        guard envelope.canonicalizationVersion == canonicalizationVersion else { throw ShareCaptureError.invalidEnvelope }
        guard try envelope.canonicalData() == data else { throw ShareCaptureError.nonCanonicalEncoding }
        let payload = envelope.payload
        guard envelope.checksumSHA256 == checksum(for: payload) else { throw ShareCaptureError.invalidChecksum }
        _ = try Self(
            envelopeID: envelope.envelopeID,
            createdAt: Date(timeIntervalSince1970: Double(envelope.createdAtMilliseconds) / 1_000),
            appBuild: envelope.appBuild,
            title: envelope.title,
            note: envelope.note,
            durationBucketRaw: envelope.durationBucketRaw,
            acceptedURLString: envelope.acceptedURLString,
            sourceKindRaw: envelope.sourceKindRaw
        )
        return envelope
    }

    private struct Payload: Codable, Equatable, Sendable {
        let envelopeFormatVersion: Int
        let envelopeID: UUID
        let createdAtMilliseconds: Int64
        let appBuild: String
        let title: String
        let note: String?
        let durationBucketRaw: String
        let acceptedURLString: String?
        let sourceKindRaw: String
        let canonicalizationVersion: Int
    }

    private var payload: Payload {
        Payload(envelopeFormatVersion: envelopeFormatVersion, envelopeID: envelopeID, createdAtMilliseconds: createdAtMilliseconds, appBuild: appBuild, title: title, note: note, durationBucketRaw: durationBucketRaw, acceptedURLString: acceptedURLString, sourceKindRaw: sourceKindRaw, canonicalizationVersion: canonicalizationVersion)
    }

    private init(payload: Payload, checksumSHA256: String) {
        envelopeFormatVersion = payload.envelopeFormatVersion
        envelopeID = payload.envelopeID
        createdAtMilliseconds = payload.createdAtMilliseconds
        appBuild = payload.appBuild
        title = payload.title
        note = payload.note
        durationBucketRaw = payload.durationBucketRaw
        acceptedURLString = payload.acceptedURLString
        sourceKindRaw = payload.sourceKindRaw
        canonicalizationVersion = payload.canonicalizationVersion
        self.checksumSHA256 = checksumSHA256
    }

    fileprivate static let encoder: JSONEncoder = { let value = JSONEncoder(); value.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]; return value }()
    private static let decoder = JSONDecoder()
    private static func checksum(for payload: Payload) -> String {
        let digest = SHA256.hash(data: (try? encoder.encode(payload)) ?? Data())
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

public struct ShareMailboxWriter {
    public init() {}

    @discardableResult
    public func publish(_ envelope: ShareCaptureEnvelopeV1, at groupContainerURL: URL) throws -> URL {
        let root = groupContainerURL.appendingPathComponent("ShareMailbox", isDirectory: true)
        var result: Result<URL, Error> = .failure(ShareCaptureError.publicationFailed)
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: root, options: [], error: &coordinationError) { coordinatedRoot in
            result = Result { try publishCoordinated(envelope, root: coordinatedRoot) }
        }
        if coordinationError != nil { throw ShareCaptureError.mailboxBusy }
        return try result.get()
    }

    private func publishCoordinated(_ envelope: ShareCaptureEnvelopeV1, root: URL) throws -> URL {
        let manager = FileManager.default
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        let generation = try activeGeneration(in: root)
        let incoming = generation.appendingPathComponent("incoming", isDirectory: true)
        let temporary = generation.appendingPathComponent("temporary", isDirectory: true)
        try manager.createDirectory(at: incoming, withIntermediateDirectories: true)
        try manager.createDirectory(at: temporary, withIntermediateDirectories: true)
        let finalFiles = try manager.contentsOfDirectory(at: incoming, includingPropertiesForKeys: [.fileSizeKey])
        let finalBytes = try byteCount(of: finalFiles)
        guard finalFiles.count < ShareCaptureLimits.incomingCount,
              finalBytes <= ShareCaptureLimits.incomingBytes else { throw ShareCaptureError.mailboxFull }
        let data = try envelope.canonicalData()
        guard finalBytes + data.count <= ShareCaptureLimits.incomingBytes else { throw ShareCaptureError.mailboxFull }
        let final = incoming.appendingPathComponent(envelope.envelopeID.uuidString.lowercased() + ".capture")
        if manager.fileExists(atPath: final.path) {
            guard try ShareCaptureEnvelopeV1.decode(Data(contentsOf: final)) == envelope else { throw ShareCaptureError.publicationFailed }
            return final
        }
        let temporaryURL = temporary.appendingPathComponent(UUID().uuidString.lowercased() + ".tmp")
        try data.write(to: temporaryURL, options: [.atomic])
        try manager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: temporaryURL.path)
        do {
            try manager.moveItem(at: temporaryURL, to: final)
        } catch {
            try? manager.removeItem(at: temporaryURL)
            throw ShareCaptureError.publicationFailed
        }
        do {
            guard try ShareCaptureEnvelopeV1.decode(Data(contentsOf: final)) == envelope else { throw ShareCaptureError.publicationFailed }
        } catch {
            throw ShareCaptureError.publicationFailed
        }
        return final
    }

    private func activeGeneration(in root: URL) throws -> URL {
        let generations = root.appendingPathComponent("generations", isDirectory: true)
        try FileManager.default.createDirectory(at: generations, withIntermediateDirectories: true)
        let manifest = root.appendingPathComponent("manifest-v1.json")
        if FileManager.default.fileExists(atPath: manifest.path) {
            let value = try JSONDecoder().decode(MailboxManifestV1.self, from: Data(contentsOf: manifest))
            let generationID = try value.validatedGenerationID()
            return generations.appendingPathComponent(generationID.uuidString.lowercased(), isDirectory: true)
        }
        let generationID = UUID()
        let generation = generations.appendingPathComponent(generationID.uuidString.lowercased(), isDirectory: true)
        try FileManager.default.createDirectory(at: generation, withIntermediateDirectories: true)
        let data = try ShareCaptureEnvelopeV1.encoder.encode(MailboxManifestV1.make(activeGenerationID: generationID))
        try data.write(to: manifest, options: [.atomic])
        return generation
    }

    private func byteCount(of urls: [URL]) throws -> Int {
        try urls.reduce(0) { total, url in
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            return total + size
        }
    }
}

public struct ShareMailboxEntry: Equatable, Sendable {
    public let envelope: ShareCaptureEnvelopeV1
    public let fileURL: URL

    public init(envelope: ShareCaptureEnvelopeV1, fileURL: URL) {
        self.envelope = envelope
        self.fileURL = fileURL
    }
}

public enum ShareMailboxProblemKind: String, Equatable, Sendable {
    case corruptEnvelope
    case unsupportedEnvelopeVersion
    case filenameMismatch
}

public struct ShareMailboxProblem: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let fileURL: URL
    public let kind: ShareMailboxProblemKind
    public let observedAt: Date

    public init(id: UUID, fileURL: URL, kind: ShareMailboxProblemKind, observedAt: Date) {
        self.id = id
        self.fileURL = fileURL
        self.kind = kind
        self.observedAt = observedAt
    }
}

public struct ShareMailboxInspection: Equatable, Sendable {
    public let entries: [ShareMailboxEntry]
    public let problems: [ShareMailboxProblem]

    public init(entries: [ShareMailboxEntry], problems: [ShareMailboxProblem]) {
        self.entries = entries
        self.problems = problems
    }
}

public struct ShareMailboxReader: Sendable {
    public init() {}

    public func entries(at groupContainerURL: URL) throws -> [ShareMailboxEntry] {
        let inspection = try inspect(at: groupContainerURL)
        guard inspection.problems.isEmpty else { throw ShareCaptureError.invalidEnvelope }
        return inspection.entries
    }

    public func inspect(at groupContainerURL: URL) throws -> ShareMailboxInspection {
        let root = groupContainerURL.appendingPathComponent("ShareMailbox", isDirectory: true)
        guard FileManager.default.fileExists(atPath: root.path) else {
            return ShareMailboxInspection(entries: [], problems: [])
        }
        var result: Result<ShareMailboxInspection, Error> = .failure(ShareCaptureError.publicationFailed)
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: root, options: [], error: &coordinationError) { coordinatedRoot in
            result = Result { try inspectCoordinated(root: coordinatedRoot) }
        }
        if coordinationError != nil { throw ShareCaptureError.mailboxBusy }
        return try result.get()
    }

    public func discard(_ problem: ShareMailboxProblem, at groupContainerURL: URL) throws {
        let root = groupContainerURL.appendingPathComponent("ShareMailbox", isDirectory: true)
        var result: Result<Void, Error> = .failure(ShareCaptureError.publicationFailed)
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: root, options: [], error: &coordinationError) { coordinatedRoot in
            result = Result {
                let incoming = try activeGeneration(in: coordinatedRoot).appendingPathComponent("incoming", isDirectory: true)
                let candidate = incoming.appendingPathComponent(problem.fileURL.lastPathComponent)
                guard candidate.standardizedFileURL == problem.fileURL.standardizedFileURL,
                      FileManager.default.fileExists(atPath: candidate.path) else {
                    throw ShareCaptureError.invalidEnvelope
                }
                try FileManager.default.removeItem(at: candidate)
            }
        }
        if coordinationError != nil { throw ShareCaptureError.mailboxBusy }
        try result.get()
    }

    public func rawRecoveryData(_ problem: ShareMailboxProblem) throws -> Data {
        let data = try Data(contentsOf: problem.fileURL, options: [.mappedIfSafe])
        guard data.count <= ShareCaptureLimits.envelopeBytes else { throw ShareCaptureError.invalidEnvelope }
        return data
    }

    public func remove(_ entry: ShareMailboxEntry, at groupContainerURL: URL) throws {
        let root = groupContainerURL.appendingPathComponent("ShareMailbox", isDirectory: true)
        var result: Result<Void, Error> = .failure(ShareCaptureError.publicationFailed)
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: root, options: [], error: &coordinationError) { coordinatedRoot in
            result = Result {
                let incoming = try activeGeneration(in: coordinatedRoot).appendingPathComponent("incoming", isDirectory: true)
                let expected = incoming.appendingPathComponent(entry.envelope.envelopeID.uuidString.lowercased() + ".capture")
                guard expected.standardizedFileURL == entry.fileURL.standardizedFileURL else {
                    throw ShareCaptureError.invalidEnvelope
                }
                guard FileManager.default.fileExists(atPath: expected.path) else { return }
                let stored = try ShareCaptureEnvelopeV1.decode(Data(contentsOf: expected))
                guard stored == entry.envelope else { throw ShareCaptureError.invalidEnvelope }
                try FileManager.default.removeItem(at: expected)
            }
        }
        if coordinationError != nil { throw ShareCaptureError.mailboxBusy }
        try result.get()
    }

    private func inspectCoordinated(root: URL) throws -> ShareMailboxInspection {
        let incoming = try activeGeneration(in: root).appendingPathComponent("incoming", isDirectory: true)
        guard FileManager.default.fileExists(atPath: incoming.path) else {
            return ShareMailboxInspection(entries: [], problems: [])
        }
        let urls = try FileManager.default.contentsOfDirectory(at: incoming, includingPropertiesForKeys: [.isRegularFileKey])
            .filter { $0.pathExtension == "capture" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        var entries: [ShareMailboxEntry] = []
        var problems: [ShareMailboxProblem] = []
        for url in urls {
            do {
                let envelope = try ShareCaptureEnvelopeV1.decode(Data(contentsOf: url, options: [.mappedIfSafe]))
                guard url.deletingPathExtension().lastPathComponent == envelope.envelopeID.uuidString.lowercased() else {
                    problems.append(problem(for: url, kind: .filenameMismatch))
                    continue
                }
                entries.append(ShareMailboxEntry(envelope: envelope, fileURL: url))
            } catch ShareCaptureError.unsupportedEnvelopeVersion {
                problems.append(problem(for: url, kind: .unsupportedEnvelopeVersion))
            } catch {
                problems.append(problem(for: url, kind: .corruptEnvelope))
            }
        }
        return ShareMailboxInspection(entries: entries, problems: problems)
    }

    private func problem(for url: URL, kind: ShareMailboxProblemKind) -> ShareMailboxProblem {
        let name = url.deletingPathExtension().lastPathComponent
        return ShareMailboxProblem(
            id: UUID(uuidString: name) ?? UUID(),
            fileURL: url,
            kind: kind,
            observedAt: (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
        )
    }

    private func activeGeneration(in root: URL) throws -> URL {
        let manifestURL = root.appendingPathComponent("manifest-v1.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else { return root }
        let manifest = try JSONDecoder().decode(MailboxManifestV1.self, from: Data(contentsOf: manifestURL))
        let generationID = try manifest.validatedGenerationID()
        return root.appendingPathComponent("generations", isDirectory: true)
            .appendingPathComponent(generationID.uuidString.lowercased(), isDirectory: true)
    }
}

public struct ShareMailboxMaintenance {
    public init() {}

    public struct StagedReplacement: Codable, Equatable, Sendable {
        public let operationID: UUID
        public let priorGenerationID: UUID
        public let stagedGenerationID: UUID
        public let epoch: Int64

        public init(operationID: UUID, priorGenerationID: UUID, stagedGenerationID: UUID, epoch: Int64) {
            self.operationID = operationID
            self.priorGenerationID = priorGenerationID
            self.stagedGenerationID = stagedGenerationID
            self.epoch = epoch
        }
    }

    public func replaceAll(
        with envelopes: [ShareCaptureEnvelopeV1],
        at groupContainerURL: URL
    ) throws {
        let staged = try stageReplacement(with: envelopes, at: groupContainerURL)
        do { try commit(staged, at: groupContainerURL) }
        catch {
            try? discard(staged, at: groupContainerURL)
            throw error
        }
    }

    public func eraseAll(at groupContainerURL: URL) throws {
        try replaceAll(with: [], at: groupContainerURL)
    }

    public func stageReplacement(
        with envelopes: [ShareCaptureEnvelopeV1],
        operationID: UUID = UUID(),
        stagedGenerationID: UUID = UUID(),
        at groupContainerURL: URL
    ) throws -> StagedReplacement {
        try validate(envelopes)
        let root = groupContainerURL.appendingPathComponent("ShareMailbox", isDirectory: true)
        var result: Result<StagedReplacement, Error> = .failure(ShareCaptureError.publicationFailed)
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: root, options: [], error: &coordinationError) { coordinatedRoot in
            result = Result {
                try stageCoordinated(
                    envelopes,
                    operationID: operationID,
                    stagedGenerationID: stagedGenerationID,
                    root: coordinatedRoot
                )
            }
        }
        if coordinationError != nil { throw ShareCaptureError.mailboxBusy }
        return try result.get()
    }

    public func commit(_ staged: StagedReplacement, at groupContainerURL: URL) throws {
        try coordinateWrite(groupContainerURL: groupContainerURL) { root in
            let manifestURL = root.appendingPathComponent("manifest-v1.json")
            let current = try JSONDecoder().decode(MailboxManifestV1.self, from: Data(contentsOf: manifestURL))
            let payload = try current.validatedPayload()
            guard payload.state == "maintenance",
                  payload.operationID == staged.operationID,
                  payload.activeGenerationID == staged.priorGenerationID,
                  payload.stagedGenerationID == staged.stagedGenerationID else {
                throw ShareCaptureError.mailboxBusy
            }
            let stagedURL = generationURL(staged.stagedGenerationID, root: root)
            _ = try inspectGeneration(stagedURL)
            try writeManifest(
                .make(activeGenerationID: staged.stagedGenerationID, epoch: staged.epoch),
                to: manifestURL
            )
            try cleanupGenerations(except: staged.stagedGenerationID, root: root)
        }
    }

    public func discard(_ staged: StagedReplacement, at groupContainerURL: URL) throws {
        try coordinateWrite(groupContainerURL: groupContainerURL) { root in
            let manager = FileManager.default
            let manifestURL = root.appendingPathComponent("manifest-v1.json")
            let current = try JSONDecoder().decode(MailboxManifestV1.self, from: Data(contentsOf: manifestURL))
            let payload = try current.validatedPayload()
            if payload.state == "maintenance", payload.operationID == staged.operationID {
                try writeManifest(
                    .make(activeGenerationID: staged.priorGenerationID, epoch: staged.epoch),
                    to: manifestURL
                )
            } else if payload.state == "idle", payload.activeGenerationID == staged.stagedGenerationID {
                return
            } else {
                throw ShareCaptureError.mailboxBusy
            }
            let stagedURL = generationURL(staged.stagedGenerationID, root: root)
            if manager.fileExists(atPath: stagedURL.path) { try manager.removeItem(at: stagedURL) }
        }
    }

    public func recoverAbandonedMaintenance(at groupContainerURL: URL) throws {
        try coordinateWrite(groupContainerURL: groupContainerURL) { root in
            let manifestURL = root.appendingPathComponent("manifest-v1.json")
            guard FileManager.default.fileExists(atPath: manifestURL.path) else { return }
            let current = try JSONDecoder().decode(MailboxManifestV1.self, from: Data(contentsOf: manifestURL))
            let payload = try current.validatedPayload()
            guard payload.state == "maintenance" else { return }
            try writeManifest(.make(activeGenerationID: payload.activeGenerationID, epoch: payload.epoch), to: manifestURL)
            if let stagedID = payload.stagedGenerationID {
                let stagedURL = generationURL(stagedID, root: root)
                if FileManager.default.fileExists(atPath: stagedURL.path) {
                    try FileManager.default.removeItem(at: stagedURL)
                }
            }
        }
    }

    private func stageCoordinated(
        _ envelopes: [ShareCaptureEnvelopeV1],
        operationID: UUID,
        stagedGenerationID: UUID,
        root: URL
    ) throws -> StagedReplacement {
        let manager = FileManager.default
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        let manifestURL = root.appendingPathComponent("manifest-v1.json")
        let priorGenerationID: UUID
        let nextEpoch: Int64
        if manager.fileExists(atPath: manifestURL.path) {
            let priorManifest = try JSONDecoder().decode(MailboxManifestV1.self, from: Data(contentsOf: manifestURL))
            priorGenerationID = try priorManifest.validatedGenerationID()
            nextEpoch = priorManifest.epoch + 1
        } else {
            priorGenerationID = UUID()
            nextEpoch = 0
            let prior = generationURL(priorGenerationID, root: root)
            try createGenerationDirectories(prior)
            try writeManifest(.make(activeGenerationID: priorGenerationID, epoch: -1), to: manifestURL)
        }
        let generation = generationURL(stagedGenerationID, root: root)
        let incoming = generation.appendingPathComponent("incoming", isDirectory: true)
        let temporary = generation.appendingPathComponent("temporary", isDirectory: true)
        let quarantine = generation.appendingPathComponent("quarantine", isDirectory: true)
        try manager.createDirectory(at: incoming, withIntermediateDirectories: true)
        try manager.createDirectory(at: temporary, withIntermediateDirectories: true)
        try manager.createDirectory(at: quarantine, withIntermediateDirectories: true)

        do {
            for envelope in envelopes {
                let data = try envelope.canonicalData()
                let temp = temporary.appendingPathComponent(UUID().uuidString.lowercased() + ".tmp")
                let final = incoming.appendingPathComponent(envelope.envelopeID.uuidString.lowercased() + ".capture")
                try data.write(to: temp, options: [.atomic])
                try manager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: temp.path)
                try manager.moveItem(at: temp, to: final)
                guard try ShareCaptureEnvelopeV1.decode(Data(contentsOf: final)) == envelope else {
                    throw ShareCaptureError.publicationFailed
                }
            }
            _ = try inspectGeneration(generation)
            try writeManifest(
                .maintenance(
                    activeGenerationID: priorGenerationID,
                    stagedGenerationID: stagedGenerationID,
                    epoch: nextEpoch,
                    operationID: operationID
                ),
                to: manifestURL
            )
        } catch {
            try? manager.removeItem(at: generation)
            throw error
        }
        return StagedReplacement(
            operationID: operationID,
            priorGenerationID: priorGenerationID,
            stagedGenerationID: stagedGenerationID,
            epoch: nextEpoch
        )
    }

    private func coordinateWrite(groupContainerURL: URL, operation: (URL) throws -> Void) throws {
        let root = groupContainerURL.appendingPathComponent("ShareMailbox", isDirectory: true)
        var result: Result<Void, Error> = .failure(ShareCaptureError.publicationFailed)
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: root, options: [], error: &coordinationError) { coordinatedRoot in
            result = Result { try operation(coordinatedRoot) }
        }
        if coordinationError != nil { throw ShareCaptureError.mailboxBusy }
        try result.get()
    }

    private func generationURL(_ id: UUID, root: URL) -> URL {
        root.appendingPathComponent("generations", isDirectory: true)
            .appendingPathComponent(id.uuidString.lowercased(), isDirectory: true)
    }

    private func createGenerationDirectories(_ generation: URL) throws {
        for name in ["incoming", "temporary", "quarantine"] {
            try FileManager.default.createDirectory(
                at: generation.appendingPathComponent(name, isDirectory: true),
                withIntermediateDirectories: true
            )
        }
    }

    private func inspectGeneration(_ generation: URL) throws -> [ShareCaptureEnvelopeV1] {
        let incoming = generation.appendingPathComponent("incoming", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(at: incoming, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "capture" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return try files.map {
            let envelope = try ShareCaptureEnvelopeV1.decode(Data(contentsOf: $0))
            guard $0.deletingPathExtension().lastPathComponent == envelope.envelopeID.uuidString.lowercased() else {
                throw ShareCaptureError.invalidEnvelope
            }
            return envelope
        }
    }

    private func writeManifest(_ manifest: MailboxManifestV1, to manifestURL: URL) throws {
        let manager = FileManager.default
        let data = try ShareCaptureEnvelopeV1.encoder.encode(manifest)
        let temporary = manifestURL.deletingLastPathComponent()
            .appendingPathComponent(UUID().uuidString.lowercased() + ".manifest.tmp")
        try data.write(to: temporary, options: [.atomic])
        try manager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: temporary.path)
        if manager.fileExists(atPath: manifestURL.path) {
            _ = try manager.replaceItemAt(manifestURL, withItemAt: temporary)
        } else {
            try manager.moveItem(at: temporary, to: manifestURL)
        }
        let reopened = try JSONDecoder().decode(MailboxManifestV1.self, from: Data(contentsOf: manifestURL))
        _ = try reopened.validatedPayload()
    }

    private func cleanupGenerations(except activeID: UUID, root: URL) throws {
        let generations = root.appendingPathComponent("generations", isDirectory: true)
        let activeName = activeID.uuidString.lowercased()
        for old in try FileManager.default.contentsOfDirectory(at: generations, includingPropertiesForKeys: nil)
        where old.lastPathComponent != activeName {
            try FileManager.default.removeItem(at: old)
        }
    }

    private func validate(_ envelopes: [ShareCaptureEnvelopeV1]) throws {
        guard envelopes.count <= ShareCaptureLimits.incomingCount else { throw ShareCaptureError.mailboxFull }
        var ids = Set<UUID>()
        var bytes = 0
        for envelope in envelopes {
            guard ids.insert(envelope.envelopeID).inserted else { throw ShareCaptureError.invalidEnvelope }
            let data = try envelope.canonicalData()
            bytes += data.count
            guard bytes <= ShareCaptureLimits.incomingBytes else { throw ShareCaptureError.mailboxFull }
        }
    }
}
