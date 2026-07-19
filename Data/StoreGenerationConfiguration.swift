import Foundation
import SwiftData

/// Keeps product-data storage under an app-owned generation directory.
/// Generation switching and journal recovery are introduced before the first public data migration.
public struct StoreGenerationConfiguration: Sendable {
    public static let storeFileName = "SomedayBox.store"

    public let applicationSupportURL: URL

    public init(applicationSupportURL: URL) {
        self.applicationSupportURL = applicationSupportURL
    }

    public func generationURL(id: UUID) -> URL {
        applicationSupportURL
            .appendingPathComponent("StoreGenerations", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
    }

    public var generationsURL: URL {
        applicationSupportURL.appendingPathComponent("StoreGenerations", isDirectory: true)
    }

    public var activeManifestURL: URL {
        applicationSupportURL.appendingPathComponent(StoreGenerationBootstrap.manifestFileName)
    }

    public var operationJournalURL: URL {
        applicationSupportURL.appendingPathComponent("generation-operation.json")
    }

    public func storeURL(generationID: UUID) -> URL {
        generationURL(id: generationID).appendingPathComponent(Self.storeFileName)
    }

    public func modelConfiguration(generationID: UUID) -> ModelConfiguration {
        // SwiftData's explicit-URL initializer selects GroupContainer.none and does not
        // expose a groupContainer parameter. The postcondition guards that local-only contract.
        let configuration = ModelConfiguration(
            "SomedayBox-\(generationID.uuidString)",
            schema: Schema(versionedSchema: SomedayBoxSchemaV1.self),
            url: storeURL(generationID: generationID),
            allowsSave: true,
            cloudKitDatabase: .none
        )
        precondition(configuration.groupAppContainerIdentifier == nil)
        precondition(configuration.cloudKitContainerIdentifier == nil)
        return configuration
    }

    public static func inMemoryModelConfiguration() -> ModelConfiguration {
        ModelConfiguration(
            "SomedayBox-InMemory",
            schema: Schema(versionedSchema: SomedayBoxSchemaV1.self),
            isStoredInMemoryOnly: true,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
    }
}
