import RealityKit
import SwiftUI

/// The entity graph the RealityKit layer owns. It is built once and then diff-applied from
/// `BoxSceneSnapshot`; it holds no product truth and opens no ModelContext (ADR 0004).
///
/// WP-04 attaches the box, paper stack, and focus rigs to the same root.
@MainActor
final class BoxSceneStage {
    enum NodeName {
        static let root = "BoxSceneRoot"
    }

    private var environment: EnvironmentRig?
    private var camera: CameraRig?
    private(set) var box: BoxGeometry?
    private var papers: PaperStackLayer?
    private var lidCapture: LidCaptureSceneAnimator?
    private var drawAnimator: DrawPaperAnimator?
    private var idleAnimator: BoxIdleAnimator?
    private var appliedLight: LightRig?
    private var appliedColorScheme: ColorScheme?
    private var appliedCameraState: BoxSceneCameraState?
    private var appliedPapers: [BoxScenePaper]?

    func build() throws -> Entity {
        let root = Entity()
        root.name = NodeName.root

        let environment = try EnvironmentRig()
        let camera = CameraRig()
        let box = try BoxGeometry()
        let papers = PaperStackLayer()
        let lidCapture = LidCaptureSceneAnimator(box: box)

        root.addChild(environment.root)
        root.addChild(camera.root)
        root.addChild(box.root)
        // The stack rides inside the box, so opening the lid or moving the box carries it.
        box.root.addChild(papers.root)
        box.root.addChild(lidCapture.root)

        let drawAnimator = DrawPaperAnimator(box: box)
        root.addChild(drawAnimator.root)
        self.drawAnimator = drawAnimator

        self.environment = environment
        self.camera = camera
        self.box = box
        self.papers = papers
        self.lidCapture = lidCapture
        idleAnimator = BoxIdleAnimator(box: box)
        appliedLight = nil
        appliedColorScheme = nil
        appliedCameraState = .frontIdle
        appliedPapers = nil
        return root
    }

    func animateIdle(at time: TimeInterval) {
        idleAnimator?.apply(time: time)
    }

    /// Applies only what changed.
    func apply(
        snapshot: BoxSceneSnapshot,
        cameraState: BoxSceneCameraState,
        lidCapturePhase: LidCapturePhase,
        reduceMotion: Bool,
        colorScheme: ColorScheme,
        drawTime: TimeInterval? = nil
    ) {
        if appliedLight != snapshot.light || appliedColorScheme != colorScheme {
            environment?.apply(snapshot.light, colorScheme: colorScheme)
            appliedLight = snapshot.light
            appliedColorScheme = colorScheme
        }
        if appliedPapers != snapshot.visiblePapers {
            papers?.apply(papers: snapshot.visiblePapers)
            appliedPapers = snapshot.visiblePapers
        }
        if appliedCameraState != cameraState {
            camera?.apply(cameraState, animated: !reduceMotion)
            appliedCameraState = cameraState
        }
        if reduceMotion || cameraState != .frontIdle || lidCapturePhase != .idle {
            idleAnimator?.apply(time: 0)
        }
        lidCapture?.apply(lidCapturePhase, reduceMotion: reduceMotion)
        if let drawTime { drawAnimator?.apply(time: drawTime) }
    }
}

/// Hosts the box scene inside the app's SwiftUI shell.
///
/// The scene builds asynchronously behind a calm placeholder so the overlay controls above
/// it stay interactive from the first frame (§15.5, FST-01), and a construction failure is
/// contained here rather than reaching any product data path (§15.6, DGR-04).
struct BoxSceneView: View {
    let snapshot: BoxSceneSnapshot
    var cameraState: BoxSceneCameraState = .frontIdle
    var lidCapturePhase: LidCapturePhase = .idle
    var drawTime: TimeInterval? = nil
    var onLidTap: () -> Void = {}
    var onLidLongPress: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @State private var stage = BoxSceneStage()
    @State private var buildAttempt = 0
    @State private var constructionFailed = false
    @State private var transitionVeil = 0.0

    var body: some View {
        if constructionFailed {
            BoxSceneRecoveryPlaceholder(retry: retry)
        } else {
            scene
        }
    }

    private var canAnimateIdle: Bool {
        drawTime == nil && scenePhase == .active && !reduceMotion && cameraState == .frontIdle && lidCapturePhase == .idle
    }

    private var scene: some View {
        RealityView { content in
            // The camera stays virtual. The spatial-tracking mode opens an AR session and
            // would need a camera capability this product does not have (§3.1).
            content.camera = .virtual
            content.environment = .default
            do {
                content.add(try stage.build())
                stage.apply(
                    snapshot: snapshot,
                    cameraState: cameraState,
                    lidCapturePhase: lidCapturePhase,
                    reduceMotion: reduceMotion,
                    colorScheme: colorScheme,
                    drawTime: drawTime
                )
            } catch {
                constructionFailed = true
            }
        } update: { _ in
            stage.apply(
                snapshot: snapshot,
                cameraState: cameraState,
                lidCapturePhase: lidCapturePhase,
                reduceMotion: reduceMotion,
                colorScheme: colorScheme,
                    drawTime: drawTime
            )
        } placeholder: {
            EnvironmentRig.backdrop(for: snapshot.light, colorScheme: colorScheme)
        }
        .id(buildAttempt)
        .task(id: canAnimateIdle) {
            guard canAnimateIdle else {
                stage.animateIdle(at: 0)
                return
            }
            let clock = ContinuousClock()
            let start = clock.now
            defer { stage.animateIdle(at: 0) }
            while !Task.isCancelled {
                let duration = start.duration(to: clock.now).components
                let elapsed = Double(duration.seconds) + Double(duration.attoseconds) / 1e18
                guard elapsed < 10 else { return }
                stage.animateIdle(at: elapsed)
                do { try await Task.sleep(for: .milliseconds(33)) } catch { return }
            }
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    guard value.entity.isPartOfLid else { return }
                    onLidTap()
                }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45)
                .targetedToAnyEntity()
                .onEnded { value in
                    guard value.entity.isPartOfLid else { return }
                    onLidLongPress()
                }
        )
        .overlay {
            // Reduce Motion cuts the camera instead of travelling; the veil carries the cut
            // as a cross-fade so the change still reads as one continuous surface (§11.3).
            EnvironmentRig.backdrop(for: snapshot.light, colorScheme: colorScheme)
                .opacity(transitionVeil)
                .allowsHitTesting(false)
        }
        .onChange(of: cameraState) { _, _ in
            guard reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.12)) { transitionVeil = 1 }
            withAnimation(.easeIn(duration: 0.18).delay(0.12)) { transitionVeil = 0 }
        }
        // WP-12 replaces this with the §14.1 scene summary element and its custom actions.
        // Until then every product action lives in the visible overlay controls.
        .accessibilityHidden(true)
    }

    private func retry() {
        stage = BoxSceneStage()
        constructionFailed = false
        buildAttempt += 1
    }
}

private extension Entity {
    var isPartOfLid: Bool {
        var candidate: Entity? = self
        while let entity = candidate {
            if entity.name == BoxGeometry.NodeName.lid { return true }
            candidate = entity.parent
        }
        return false
    }
}

/// The containment skeleton for §15.6. WP-11 replaces it with the full data-safety recovery
/// surface — retry plus the complete Settings data controls — and its §17 copy. The strings
/// used here are existing, already-translated product copy.
private struct BoxSceneRecoveryPlaceholder: View {
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Your Box needs attention", systemImage: "shippingbox.and.arrow.backward")
        } actions: {
            Button("Try again", action: retry)
                .buttonStyle(.borderedProminent)
        }
    }
}
