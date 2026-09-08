import Foundation
import RealityKit
import XCTest
@testable import SomedayBox

/// WP-04 fixtures: the render half of the density bands and the seeded layout (SCN-02,
/// SCN-03), and the hidden-by-default growth structures (TRC-08).
@MainActor
final class BoxRenderingTests: XCTestCase {
    // MARK: - Paper stack (§6.2, §6.3 render halves)

    func testStackRendersExactlyTheInstancesTheSnapshotDescribes() {
        let layer = PaperStackLayer()
        layer.apply(papers: papers(count: 12))
        XCTAssertEqual(layer.root.children.count, 12)

        layer.apply(papers: papers(count: 5))
        XCTAssertEqual(layer.root.children.count, 5)

        layer.apply(papers: [])
        XCTAssertEqual(layer.root.children.count, 0)
    }

    /// A paper that survives a snapshot change keeps its entity, which is what makes the
    /// arrangement stable when other papers enter or leave (SCN-03).
    func testSurvivingPapersKeepTheirEntity() {
        let layer = PaperStackLayer()
        let all = papers(count: 6)
        layer.apply(papers: all)
        let before = Set(layer.root.children.map { ObjectIdentifier($0) })

        layer.apply(papers: Array(all.dropLast()))
        let after = Set(layer.root.children.map { ObjectIdentifier($0) })

        XCTAssertEqual(after.count, 5)
        XCTAssertTrue(after.isSubset(of: before), "Surviving papers were rebuilt instead of kept.")
    }

    func testEveryPaperRestsInsideTheBoxCavity() {
        let layer = PaperStackLayer()
        layer.apply(papers: papers(count: 32))

        let halfWidth = BoxGeometry.Metrics.interiorWidth / 2
        let halfDepth = BoxGeometry.Metrics.interiorDepth / 2
        for paper in layer.root.children {
            XCTAssertLessThan(abs(paper.position.x), halfWidth)
            XCTAssertLessThan(abs(paper.position.z), halfDepth)
            XCTAssertGreaterThanOrEqual(paper.position.y, BoxGeometry.Metrics.interiorFloor)
            XCTAssertLessThan(
                paper.position.y,
                BoxGeometry.Metrics.bodyHeight / 2,
                "A paper rose above the rim, so the lid would not close on it."
            )
        }
    }

    /// However full the box gets, the stack has to stay under the lid.
    func testAFullStackStillFitsUnderTheLid() {
        let layer = PaperStackLayer()
        layer.apply(papers: papers(count: 32))
        let highest = layer.root.children.map(\.position.y).max() ?? 0
        XCTAssertLessThan(highest, BoxGeometry.Metrics.bodyHeight / 2)
    }

    // MARK: - Growth structures (TRC-08)

    func testGrowthStructuresAreHiddenUntilTheirPredicatesHold() throws {
        let box = try BoxGeometry()
        for name in [
            BoxGeometry.NodeName.memorySeam,
            BoxGeometry.NodeName.letterSlot,
            BoxGeometry.NodeName.bottomSeam,
        ] {
            XCTAssertFalse(box.isStructureVisible(name), "\(name) was visible before its predicate held.")
        }
    }

    func testAStructureDisappearsAgainWhenItsPredicateStopsHolding() throws {
        let box = try BoxGeometry()
        box.setStructure(BoxGeometry.NodeName.memorySeam, visible: true)
        XCTAssertTrue(box.isStructureVisible(BoxGeometry.NodeName.memorySeam))
        box.setStructure(BoxGeometry.NodeName.memorySeam, visible: false)
        XCTAssertFalse(box.isStructureVisible(BoxGeometry.NodeName.memorySeam))
    }

    // MARK: - Box shell

    func testTheBoxIsAContainerRatherThanASolidBlock() throws {
        let box = try BoxGeometry()
        let body = try XCTUnwrap(box.root.findEntity(named: BoxGeometry.NodeName.body))
        XCTAssertNotNil(body.findEntity(named: "Floor"))
        for wall in ["WallFront", "WallBack", "WallLeft", "WallRight"] {
            XCTAssertNotNil(body.findEntity(named: wall), "\(wall) is missing, so papers would be buried.")
        }
    }

    func testLidOpensOnItsHingeAndReturns() throws {
        let box = try BoxGeometry()
        let pivot = try XCTUnwrap(box.root.findEntity(named: BoxGeometry.NodeName.lidPivot))
        let closed = pivot.transform.rotation

        box.setLid(openness: 1)
        XCTAssertNotEqual(pivot.transform.rotation.angle, closed.angle)

        let front = try XCTUnwrap(box.root.findEntity(named: "FrontFlapPivot"))
        XCTAssertGreaterThan(front.orientation.angle, Float.pi / 2, "Front flap must fold outward, clear of capture paper.")
        box.setLid(openness: 0)
        XCTAssertEqual(pivot.transform.rotation.angle, closed.angle, accuracy: 1e-5)
        XCTAssertEqual(front.orientation.angle, 0, accuracy: 1e-5)
    }

    func testIdlePerformanceSettlesAndKeepsGroundContact() {
        for time in stride(from: 0.0, through: 10.0, by: 0.025) {
            let pose = BoxIdlePose.sample(at: time)
            XCTAssertGreaterThanOrEqual(pose.lift, 0)
            XCTAssertGreaterThan(pose.stretch, 0.9)
            XCTAssertGreaterThan(pose.eyeOpen, 0)
        }
        for time in [0.0, 10.0, 100.0] {
            let pose = BoxIdlePose.sample(at: time)
            XCTAssertEqual(pose.stretch, 1)
            XCTAssertEqual(pose.lift, 0)
            XCTAssertEqual(pose.tilt, 0)
            XCTAssertEqual(pose.eyeOpen, 1)
        }
    }

    func testIdleResetRestoresFaceAndDoesNotTouchCaptureHinge() throws {
        let box = try BoxGeometry()
        let animator = BoxIdleAnimator(box: box)
        let eye = try XCTUnwrap(box.root.findEntity(named: "EyeLeft"))
        let rest = eye.transform
        box.setLid(openness: 1)
        let pivot = try XCTUnwrap(box.root.findEntity(named: BoxGeometry.NodeName.lidPivot))
        let openAngle = pivot.orientation.angle
        animator.apply(time: 1.44)
        XCTAssertLessThan(eye.scale.y, rest.scale.y * 0.2)
        animator.apply(time: 6.1)
        XCTAssertGreaterThan(box.root.position.y, 0)
        animator.apply(time: 0)
        XCTAssertEqual(eye.transform, rest)
        XCTAssertEqual(box.root.position, .zero)
        XCTAssertEqual(box.root.scale, .one)
        XCTAssertEqual(pivot.orientation.angle, openAngle, accuracy: 1e-5)
    }

    func testCartonUsesTexturedThinFlapsWithoutTheFabricTab() throws {
        let box = try BoxGeometry()
        XCTAssertNil(box.root.findEntity(named: "Strap"))
        XCTAssertNil(box.root.findEntity(named: "StrapAnchor"))
        for name in ["FrontFlap", "RearFlap", "WallFront"] {
            let panel = try XCTUnwrap(box.root.findEntity(named: name) as? ModelEntity)
            let surface = try XCTUnwrap(panel.model?.materials.first as? PhysicallyBasedMaterial)
            XCTAssertNotNil(surface.baseColor.texture)
        }
    }

    func testDrawFlightLeavesTheBoxAndSettlesInFrontOfCamera() throws {
        let box = try BoxGeometry()
        let animator = DrawPaperAnimator(box: box)
        let paper = try XCTUnwrap(animator.root.findEntity(named: "DrawnPaper"))
        animator.apply(time: 0.3)
        XCTAssertFalse(paper.isEnabled)
        XCTAssertNotEqual(box.root.orientation.angle, 0)
        animator.apply(time: 1.3)
        XCTAssertTrue(paper.isEnabled)
        XCTAssertGreaterThan(paper.position.y, BoxGeometry.Metrics.bodyHeight / 2)
        animator.apply(time: DrawPaperAnimator.handoffTime)
        let camera = BoxSceneCameraState.frontIdle
        let forward = simd_normalize(camera.target - camera.eye)
        XCTAssertEqual(simd_dot(paper.position - camera.eye, forward), 0.42, accuracy: 0.001)
        animator.apply(time: DrawPaperAnimator.duration)
        XCTAssertFalse(paper.isEnabled)
        XCTAssertEqual(box.root.position, .zero)
        XCTAssertEqual(box.root.orientation.angle, 0, accuracy: 1e-5)
        let hinge = try XCTUnwrap(box.root.findEntity(named: BoxGeometry.NodeName.lidPivot))
        XCTAssertEqual(hinge.orientation.angle, 0, accuracy: 1e-5)
    }

    // MARK: - Fixtures

    private func papers(count: Int) -> [BoxScenePaper] {
        (0..<count).map { index in
            let id = UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index))!
            return BoxScenePaper(
                id: id,
                origin: .manualCapture,
                form: .smallSlip,
                ageTier: .settled,
                transform: BoxSceneStateReducer.restingTransform(itemID: id, stackIndex: index)
            )
        }
    }

}
