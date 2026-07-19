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
    let checksumSHA256: String

    static func make(activeGenerationID: UUID) -> Self {
        let payload = Payload(formatVersion: 1, activeGenerationID: activeGenerationID, epoch: 0, state: "idle")
        let checksum = SHA256.hash(data: (try? ShareCaptureEnvelopeV1.encoder.encode(payload)) ?? Data())
            .map { String(format: "%02x", $0) }.joined()
        return Self(formatVersion: payload.formatVersion, activeGenerationID: payload.activeGenerationID, epoch: payload.epoch, state: payload.state, checksumSHA256: checksum)
    }

    func validatedGenerationID() throws -> UUID {
        let payload = Payload(formatVersion: formatVersion, activeGenerationID: activeGenerationID, epoch: epoch, state: state)
        let checksum = SHA256.hash(data: try ShareCaptureEnvelopeV1.encoder.encode(payload))
            .map { String(format: "%02x", $0) }.joined()
        guard formatVersion == 1, checksum == checksumSHA256 else {
            throw ShareCaptureError.invalidChecksum
        }
        guard state == "idle" else { throw ShareCaptureError.mailboxBusy }
        return activeGenerationID
    }

    private struct Payload: Codable { let formatVersion: Int; let activeGenerationID: UUID; let epoch: Int64; let state: String }
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

public struct ShareMailboxReader {
    public init() {}

    public func entries(at groupContainerURL: URL) throws -> [ShareMailboxEntry] {
        let root = groupContainerURL.appendingPathComponent("ShareMailbox", isDirectory: true)
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        var result: Result<[ShareMailboxEntry], Error> = .failure(ShareCaptureError.publicationFailed)
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: root, options: [], error: &coordinationError) { coordinatedRoot in
            result = Result { try readCoordinated(root: coordinatedRoot) }
        }
        if coordinationError != nil { throw ShareCaptureError.mailboxBusy }
        return try result.get()
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

    private func readCoordinated(root: URL) throws -> [ShareMailboxEntry] {
        let incoming = try activeGeneration(in: root).appendingPathComponent("incoming", isDirectory: true)
        guard FileManager.default.fileExists(atPath: incoming.path) else { return [] }
        let urls = try FileManager.default.contentsOfDirectory(at: incoming, includingPropertiesForKeys: [.isRegularFileKey])
            .filter { $0.pathExtension == "capture" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return try urls.map { url in
            let envelope = try ShareCaptureEnvelopeV1.decode(Data(contentsOf: url, options: [.mappedIfSafe]))
            guard url.deletingPathExtension().lastPathComponent == envelope.envelopeID.uuidString.lowercased() else {
                throw ShareCaptureError.invalidEnvelope
            }
            return ShareMailboxEntry(envelope: envelope, fileURL: url)
        }
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
