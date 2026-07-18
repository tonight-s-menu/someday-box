// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SomedayBoxDomain",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "SomedayBoxDomain", targets: ["SomedayBoxDomain"]),
        .executable(name: "someday-box-domain-checks", targets: ["SomedayBoxDomainChecks"]),
    ],
    targets: [
        .target(name: "SomedayBoxDomain", path: "Domain"),
        .executableTarget(
            name: "SomedayBoxDomainChecks",
            dependencies: ["SomedayBoxDomain"],
            path: "Verification"
        ),
    ]
)
