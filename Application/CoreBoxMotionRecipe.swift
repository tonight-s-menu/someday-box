import Foundation

/// Named, deterministic terminal poses used only when RealityKit cannot expose
/// composed USD animation resources. The public names stay identical to the USD contract.
struct CoreBoxMotionRecipe: Equatable, Sendable {
    let name: String
    let controlledEntityName: String
    let durationMilliseconds: Int
    /// Offset from the USDZ's validated rest transform, in metres.
    let terminalTranslationYOffset: Double

    /// The full vocabulary retains the public contract while Task 5 proves only
    /// its representative three-motion subset on Simulator and physical hardware.
    static let allPublicMotions: [CoreBoxMotionRecipe] = [
        .init(name: "idle.blink", controlledEntityName: "BoxRoot", durationMilliseconds: 340, terminalTranslationYOffset: 0),
        .init(name: "idle.listen", controlledEntityName: "BoxRoot", durationMilliseconds: 1_000, terminalTranslationYOffset: 0),
        .init(name: "idle.paperRustle", controlledEntityName: "PaperPool", durationMilliseconds: 900, terminalTranslationYOffset: 0),
        .init(name: "idle.currentGlance", controlledEntityName: "CurrentPaperAnchor", durationMilliseconds: 820, terminalTranslationYOffset: 0),
        .init(name: "react.touch", controlledEntityName: "BoxRoot", durationMilliseconds: 200, terminalTranslationYOffset: 0),
        .init(name: "react.notice.single", controlledEntityName: "BoxRoot", durationMilliseconds: 460, terminalTranslationYOffset: 0),
        .init(name: "react.notice.aggregate", controlledEntityName: "BoxRoot", durationMilliseconds: 620, terminalTranslationYOffset: 0),
        .init(name: "capture.receive", controlledEntityName: "LidPivot", durationMilliseconds: 300, terminalTranslationYOffset: 0.015),
        .init(name: "capture.deposit", controlledEntityName: "LidPivot", durationMilliseconds: 560, terminalTranslationYOffset: 0.015),
        .init(name: "draw.reveal", controlledEntityName: "PaperReveal", durationMilliseconds: 750, terminalTranslationYOffset: 0.080),
        .init(name: "current.attach", controlledEntityName: "CurrentPaperAnchor", durationMilliseconds: 420, terminalTranslationYOffset: 0),
        .init(name: "paper.return", controlledEntityName: "PaperPool", durationMilliseconds: 500, terminalTranslationYOffset: 0),
        .init(name: "memory.stamp", controlledEntityName: "MemorySeam", durationMilliseconds: 650, terminalTranslationYOffset: 0)
    ]

    static let proofMotions = allPublicMotions.filter {
        ["idle.listen", "capture.deposit", "draw.reveal"].contains($0.name)
    }
}
