import Foundation

#if DEBUG
enum UITestEnvironmentKey {
    static let enabled = "SOMEDAY_BOX_UI_TESTING"
    static let runID = "SOMEDAY_BOX_UI_TEST_RUN_ID"
    static let fixture = "SOMEDAY_BOX_UI_TEST_FIXTURE"
    static let renderer = "SOMEDAY_BOX_UI_TEST_RENDERER"
    static let assetFailure = "SOMEDAY_BOX_UI_TEST_ASSET_FAILURE"
    static let projectionFailures = "SOMEDAY_BOX_UI_TEST_PROJECTION_FAILURES"
    static let motionMode = "SOMEDAY_BOX_UI_TEST_MOTION_MODE"
    static let lowPowerCap = "SOMEDAY_BOX_UI_TEST_LOW_POWER_CAP"
}
#endif

enum UITestFixture: Equatable, Sendable {
    case emptyBox
    case activePapers(Int)
    case drawReady

    init?(rawValue: String) {
        switch rawValue {
        case "empty-box": self = .emptyBox
        case "draw-ready": self = .drawReady
        default:
            guard let count = rawValue.split(separator: ":").dropFirst().first,
                  rawValue.hasPrefix("active-papers:"),
                  let count = Int(count), count >= 0, count <= 5_000 else { return nil }
            self = .activePapers(count)
        }
    }
}

struct UITestLaunchConfiguration: Sendable {
    let enabled: Bool
    let runID: UUID?
    let fixture: UITestFixture?
    let renderer: CoreBoxRendererPreference?
    let assetFailure: String?
    let projectionFailures: Int
    let motionMode: CoreBoxMotionMode?
    let lowPowerCap: Bool

    static let disabled = Self(
        enabled: false,
        runID: nil,
        fixture: nil,
        renderer: nil,
        assetFailure: nil,
        projectionFailures: 0,
        motionMode: nil,
        lowPowerCap: false
    )

    #if DEBUG
    static var current: Self { load() }

    static func load(environment: [String: String] = ProcessInfo.processInfo.environment) -> Self {
        guard environment[UITestEnvironmentKey.enabled] == "1",
              let rawRunID = environment[UITestEnvironmentKey.runID],
              let runID = UUID(uuidString: rawRunID),
              rawRunID == rawRunID.lowercased(),
              let rawFixture = environment[UITestEnvironmentKey.fixture],
              let fixture = UITestFixture(rawValue: rawFixture)
        else { return .disabled }

        let renderer: CoreBoxRendererPreference? = switch environment[UITestEnvironmentKey.renderer] {
        case "automatic": .automatic
        case "full3D": .full3D
        case "simplified2D": .simplified2D
        default: nil
        }
        let motionMode: CoreBoxMotionMode? = switch environment[UITestEnvironmentKey.motionMode] {
        case "normal": .normal
        case "quick": .quick
        case "reduced": .reduced
        default: nil
        }
        let failures = max(0, Int(environment[UITestEnvironmentKey.projectionFailures] ?? "0") ?? 0)
        return Self(
            enabled: true,
            runID: runID,
            fixture: fixture,
            renderer: renderer,
            assetFailure: environment[UITestEnvironmentKey.assetFailure],
            projectionFailures: failures,
            motionMode: motionMode,
            lowPowerCap: environment[UITestEnvironmentKey.lowPowerCap] == "1"
        )
    }
    #else
    static let current = Self.disabled
    #endif

    @MainActor
    func supportRoot(defaultRoot: URL) throws -> URL {
        guard enabled, let runID else { return defaultRoot }
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("someday-box-ui-tests", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let runRoot = parent.appendingPathComponent(runID.uuidString.lowercased(), isDirectory: true)
        if FileManager.default.fileExists(atPath: runRoot.path) {
            try FileManager.default.removeItem(at: runRoot)
        }
        try FileManager.default.createDirectory(at: runRoot, withIntermediateDirectories: true)
        return runRoot
    }
}
