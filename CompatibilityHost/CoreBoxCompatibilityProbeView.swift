import RealityKit
import SwiftUI

struct CoreBoxCompatibilityProbeView: View {
    @State private var root: Entity?
    @State private var status = "Loading proof asset"
    @State private var makeCount = 0
    @State private var updateCount = 0
    @State private var stablePoseRequested = false
    @State private var stablePoseApplied = false
    @State private var completedMotionNames = [String]()
    @State private var ribbonSamples = [Double]()
    @State private var fallbackAdapter: CoreBox2DAdapter?
    @State private var fallbackActionIDs = [String]()
    @State private var lastFallbackAction = ""

    private var tier: CoreBoxRendererTier {
        ProcessInfo.processInfo.arguments.contains("lite3D") ? .lite3D : .full3D
    }

    private var forceStructuralFailure: Bool {
        ProcessInfo.processInfo.arguments.contains("-CoreBoxProofForceInvalidAsset")
    }

    private var automaticallyAdvanceStablePose: Bool {
        ProcessInfo.processInfo.arguments.contains("--core-box-proof-advance-stable-pose")
    }

    var body: some View {
        // Bind these values at body evaluation so RealityView observes the
        // stable-pose request as an update dependency.
        let requestedStablePose = stablePoseRequested || automaticallyAdvanceStablePose
        let installedRoot = root
        let didApplyStablePose = stablePoseApplied

        VStack(spacing: 12) {
            RealityView { content in
                makeCount += 1
                do {
                    let loaded = try await CoreBoxAssetLoader(
                        source: CoreBoxCompatibilityProofSource.source(
                            forceStructuralFailure: forceStructuralFailure
                        )
                    ).load(tier: tier)
                    // The verification host is deliberately an inline non-AR scene.
                    content.camera = .virtual
                    content.cameraTarget = loaded.root.findEntity(named: "Camera_Default")
                    content.add(loaded.root)
                    root = loaded.root

                    let adapter = CoreBoxSceneAdapter(loadedAsset: loaded)
                    for recipe in CoreBoxMotionRecipe.proofMotions {
                        try await adapter.playProofMotion(named: recipe.name)
                        completedMotionNames.append(recipe.name)
                    }
                    for progress in [0.0, 0.72, 1.0] {
                        adapter.applyRibbon(progress: progress, latched: progress >= 0.72)
                        guard adapter.ribbonSampleMatches(progress) else {
                            throw CoreBoxAssetValidationError.invalidInventory("Ribbon sample did not match its audited transform.")
                        }
                        ribbonSamples.append(progress)
                    }
                    status = "Validated runtime recipes: \(completedMotionNames.joined(separator: ", "))"
                } catch {
                    // Never leave an unverified 3D root installed behind the fallback UI.
                    root?.removeFromParent()
                    root = nil
                    let adapter = CoreBox2DAdapter()
                    adapter.apply(event: .fallbackSettle(.assetValidation), sourceSnapshotVersion: 0)
                    adapter.settle(reason: .validationFailure)
                    fallbackAdapter = adapter
                    fallbackActionIDs = adapter.availableSemanticActionIDs
                    status = "2D fallback: \(String(describing: error))"
                }
            } update: { _ in
                guard requestedStablePose, !didApplyStablePose, let installedRoot else { return }
                // Move the existing root to its second stable pose without loading
                // or adding another entity.
                var stableTransform = installedRoot.transform
                stableTransform.translation.y += 0.001
                installedRoot.transform = stableTransform

                // Mutate observability state after RealityView completes its update.
                // Synchronous mutation here terminates the UI-test host.
                Task { @MainActor in
                    guard !stablePoseApplied else { return }
                    stablePoseApplied = true
                    updateCount += 1
                }
            }
            .accessibilityIdentifier("probe.reality")

            Text(status)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("probe.status")
            Text("make:\(makeCount),update:\(updateCount),roots:\(root == nil ? 0 : 1)")
                .accessibilityIdentifier("probe.reality.counts")

            ForEach(completedMotionNames, id: \.self) { name in
                Text(name)
                    .accessibilityIdentifier("probe.motion.\(name).complete")
            }
            Text(ribbonSamples.map { String($0) }.joined(separator: ","))
                .accessibilityIdentifier("probe.ribbon.samples")

            Button("Advance stable pose") {
                stablePoseRequested = true
            }
            .accessibilityIdentifier("probe.advance.stable-pose")

            ForEach(fallbackActionIDs, id: \.self) { actionID in
                Button(actionID) {
                    fallbackAdapter?.performSemanticAction(actionID)
                    lastFallbackAction = fallbackAdapter?.lastSemanticAction ?? ""
                }
                .accessibilityIdentifier("probe.2d.\(actionID)")
            }
            Text(lastFallbackAction)
                .accessibilityIdentifier("probe.2d.last-action")
        }
    }
}
