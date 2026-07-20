import Foundation
import Testing
@testable import SomedayBox

@Suite("Core Box preference v2 migration")
struct CoreBoxPreferenceMigrationTests {
    @Test(arguments: [
        ("lite3D", CoreBoxRendererPreference.automatic),
        ("full3D", CoreBoxRendererPreference.full3D),
        ("swiftUI2D", CoreBoxRendererPreference.simplified2D),
        ("invalid", CoreBoxRendererPreference.automatic)
    ])
    func mapsLegacyRenderer(_ source: String, _ expected: CoreBoxRendererPreference) {
        let suite = "CoreBoxPreferenceMigrationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: CoreBoxPresentationPreferenceStore.migrationCompletedKey)
        defaults.set(source, forKey: "\(CoreBoxPresentationPreferences.legacyNamespace).renderer")

        let value = CoreBoxPresentationPreferenceStore(defaults: defaults).loadMigratingIfNeeded()

        #expect(value.renderer == expected)
    }

    @Test func markerIsWrittenLastAndMigrationIsIdempotent() {
        let suite = "CoreBoxPreferenceMigrationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: CoreBoxPresentationPreferenceStore.migrationCompletedKey)
        let legacy = CoreBoxPresentationPreferences.legacyNamespace
        defaults.set("lite3D", forKey: "\(legacy).renderer")
        defaults.set(true, forKey: "\(legacy).quick")
        defaults.set(false, forKey: "\(legacy).sound")
        defaults.set(true, forKey: "\(legacy).haptics")
        defaults.set(false, forKey: "\(legacy).ambience")
        defaults.set("preset:few_minutes", forKey: "\(legacy).last-context")
        defaults.set(true, forKey: "\(legacy).first-animation")

        let writes = CoreBoxPreferenceMigrator().v2Writes(from: defaults)
        #expect(writes.last?.key == CoreBoxPresentationPreferenceStore.migrationCompletedKey)

        let store = CoreBoxPresentationPreferenceStore(defaults: defaults)
        let first = store.loadMigratingIfNeeded()
        let second = store.loadMigratingIfNeeded()
        #expect(first == second)
        #expect(first.renderer == .automatic)
        #expect(first.quickAnimations)
        #expect(first.soundEnabled == false)
        #expect(first.hapticsEnabled)
        #expect(first.ambienceEnabled == false)
        #expect(first.lastDrawContext == "preset:few_minutes")
        #expect(first.hasSeenFirstAnimation)
        #expect(defaults.object(forKey: "\(legacy).renderer") == nil)
    }
}
