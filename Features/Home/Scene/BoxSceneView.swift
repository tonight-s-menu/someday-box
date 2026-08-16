#if SOMEDAYBOX_SCENE_SPIKE
import RealityKit
import SwiftUI

/// WP-01 rendering spike: hosts a `RealityView` inside the app's own SwiftUI shell so the
/// ADR 0004 presentation seam is proven before WP-03 makes the scene the Home surface.
///
/// This file compiles only when `SOMEDAYBOX_SCENE_SPIKE` is defined — the app target's
/// Debug configuration. No shipped surface references it and a Release build contains
/// none of it, so the spike cannot change user-visible behaviour.
struct BoxSceneView: View {
    var body: some View {
        RealityView { content in
            // The camera stays virtual. The spatial-tracking camera mode opens an AR
            // session and would require a camera capability this product does not have
            // (specification §3.1); the local-only audit fails if it ever appears here.
            content.camera = .virtual
            content.environment = .default
            content.add(BoxSceneRealityLayer.makePlaceholderScene())
        } placeholder: {
            BoxScenePlaceholder()
        }
        .ignoresSafeArea()
    }
}

/// The calm stand-in `RealityView` shows while its asynchronous `make` closure builds the
/// scene. WP-03 keeps this seam: overlay controls must stay interactive within 400 ms of
/// cold launch while the scene is still loading (specification §15.5).
private struct BoxScenePlaceholder: View {
    var body: some View {
        SomedayBoxBrand.canvas
    }
}

#Preview {
    BoxSceneView()
}
#endif
