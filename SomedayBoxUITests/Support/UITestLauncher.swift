import XCTest

enum CoreBoxUITestFixture: Equatable {
    case emptyBox
    case activePapers(Int)
    case drawReady

    var launchValue: String {
        switch self {
        case .emptyBox: "empty-box"
        case let .activePapers(count): "active-papers:\(count)"
        case .drawReady: "draw-ready"
        }
    }
}

struct CoreBoxUITestLaunchOptions {
    var assetFailure: String?
    var projectionFailures = 0
    var renderer: String?
    var motionMode: String?
    var lowPowerCap = false

    init(
        assetFailure: String? = nil,
        projectionFailures: Int = 0,
        renderer: String? = nil,
        motionMode: String? = nil,
        lowPowerCap: Bool = false
    ) {
        self.assetFailure = assetFailure
        self.projectionFailures = projectionFailures
        self.renderer = renderer
        self.motionMode = motionMode
        self.lowPowerCap = lowPowerCap
    }
}

extension XCTestCase {
    @MainActor
    func launchFixture(
        _ fixture: CoreBoxUITestFixture,
        options: CoreBoxUITestLaunchOptions = .init()
    ) -> XCUIApplication {
        let app = XCUIApplication()
        let runID = UUID().uuidString.lowercased()
        var environment = [
            "SOMEDAY_BOX_UI_TESTING": "1",
            "SOMEDAY_BOX_UI_TEST_RUN_ID": runID,
            "SOMEDAY_BOX_UI_TEST_FIXTURE": fixture.launchValue,
            "SOMEDAY_BOX_UI_TEST_PROJECTION_FAILURES": String(options.projectionFailures),
            "SOMEDAY_BOX_UI_TEST_LOW_POWER_CAP": options.lowPowerCap ? "1" : "0",
        ]
        if let value = options.assetFailure { environment["SOMEDAY_BOX_UI_TEST_ASSET_FAILURE"] = value }
        if let value = options.renderer { environment["SOMEDAY_BOX_UI_TEST_RENDERER"] = value }
        if let value = options.motionMode { environment["SOMEDAY_BOX_UI_TEST_MOTION_MODE"] = value }
        app.launchEnvironment = environment
        app.launch()
        addTeardownBlock { app.terminate() }
        return app
    }
}
