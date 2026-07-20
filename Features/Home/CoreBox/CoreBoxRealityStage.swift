import RealityKit
import SwiftUI

struct CoreBoxRealityStage: View {
    let snapshot: CoreBoxSceneSnapshot
    let event: CoreBoxCorrelatedEvent?
    let controller: CoreBoxStageController

    var body: some View {
        let replacementGeneration = controller.replacementGeneration
        RealityView { content in
            do {
                let loaded = try await controller.load(tier: snapshot.rendererTier)
                content.camera = .virtual
                content.add(loaded.root)
                content.cameraTarget = loaded.root.findEntity(named: "Camera_Default")
                controller.install(loaded)
                controller.update(snapshot: snapshot, event: event)
            } catch {
                controller.reject3DForLaunch(error)
            }
        } update: { content in
            _ = replacementGeneration
            if let loaded = controller.takePreparedReplacement() {
                for entity in content.entities { content.remove(entity) }
                content.add(loaded.root)
                content.camera = .virtual
                content.cameraTarget = loaded.root.findEntity(named: "Camera_Default")
                controller.install(loaded)
            }
            controller.update(snapshot: snapshot, event: event)
        }
        .task(id: snapshot.rendererTier) {
            guard controller.hasInstalledAsset else { return }
            await controller.prepareReplacement(tier: snapshot.rendererTier)
        }
        .onDisappear { controller.teardown() }
        .accessibilityHidden(true)
    }
}
