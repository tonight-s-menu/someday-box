import Foundation

/// Keeps product-data storage under an app-owned generation directory.
/// Generation switching and journal recovery are introduced before the first public data migration.
public struct StoreGenerationConfiguration: Sendable {
    public let applicationSupportURL: URL

    public init(applicationSupportURL: URL) {
        self.applicationSupportURL = applicationSupportURL
    }

    public func generationURL(id: UUID) -> URL {
        applicationSupportURL
            .appendingPathComponent("StoreGenerations", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
    }
}
