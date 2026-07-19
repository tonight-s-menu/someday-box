import Foundation

public protocol BoxItemRepository: Sendable {
    func save(_ item: BoxItem) async throws
}

public enum CapturePaperError: Error, Equatable, Sendable {
    case invalidContent(BoxItemValidationFailure)
    case unsupportedDuration
}

public struct CapturePaperUseCase: Sendable {
    private let repository: any BoxItemRepository
    private let now: @Sendable () -> Date

    public init(repository: any BoxItemRepository, now: @escaping @Sendable () -> Date = Date.init) {
        self.repository = repository
        self.now = now
    }

    public func execute(title: String, note: String?, durationBucketRaw: String) async throws {
        let content: ValidatedPaperContent
        do {
            content = try PaperContentValidator().validate(title: title, note: note)
        } catch let failure as BoxItemValidationFailure {
            throw CapturePaperError.invalidContent(failure)
        }
        guard DurationBucket(rawValue: durationBucketRaw) != nil else {
            throw CapturePaperError.unsupportedDuration
        }
        let timestamp = now()
        try await repository.save(
            BoxItem(
                title: content.title,
                note: content.note,
                durationBucketRaw: durationBucketRaw,
                createdAt: timestamp,
                updatedAt: timestamp
            )
        )
    }
}
