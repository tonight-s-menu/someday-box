import RealityKit
import SwiftUI
import UIKit

/// The abstract stage of specification §9: a soft ground plane, a graded backdrop, and one
/// light rig driven by the `box-scene-v1` derivation. It never becomes a room or a desk.
///
/// Season accents are not part of this generation (LB-D21): a month-derived season would
/// assert a hemisphere the device does not hold. Ambience comes from the clock alone.
@MainActor
struct EnvironmentRig {
    enum NodeName {
        static let environment = "Environment"
        static let ground = "Ground"
        static let keyLight = "KeyLight"
        static let fillLight = "FillLight"
    }

    private enum Metrics {
        /// Large enough that its far edge never draws a hard horizon inside any camera
        /// state's frustum; the graded boundary above it is the SwiftUI backdrop.
        static let groundSize: Float = 6.0
        static let groundThickness: Float = 0.002
        static let groundDrop: Float = -0.066
        static let lightDistance: Float = 1.2
    }

    /// Directional-light intensity in lux across the rig's normalised 0…1 range.
    private enum Intensity {
        static let floor: Float = 900
        static let span: Float = 3_400
        static let fillFraction: Float = 0.22
        /// How far the whole rig drops in the dark appearance.
        static let darkAppearance: Float = 0.5
    }

    let root: Entity
    private let keyLight: DirectionalLight
    private let fillLight: DirectionalLight
    private let ground: ModelEntity

    /// Throws so the scene boundary has a real failure path to contain (§15.6, DGR-04).
    /// The B1 stage is procedural and does not fail today; WP-04 and WP-09 load assets
    /// through this same seam.
    init() throws {
        let root = Entity()
        root.name = NodeName.environment

        let key = DirectionalLight()
        key.name = NodeName.keyLight
        key.light.isRealWorldProxy = false
        // Without an explicit shadow the box floats off its ground plane (WP-01 finding).
        // Soft shadows are a Q0 effect; WP-11 turns them off at Q1.
        key.shadow = DirectionalLightComponent.Shadow(
            // The subject is a 0.26 m box, so a tight projection keeps the shadow map
            // sharp instead of smearing it across metres of empty ground.
            shadowProjection: .automatic(maximumDistance: 0.8),
            depthBias: 1.0
        )
        root.addChild(key)

        // A dim opposing light so the box's shadow side keeps its form at every hour.
        let fill = DirectionalLight()
        fill.name = NodeName.fillLight
        fill.light.isRealWorldProxy = false
        root.addChild(fill)

        let ground = ModelEntity(
            mesh: .generateBox(
                width: Metrics.groundSize,
                height: Metrics.groundThickness,
                depth: Metrics.groundSize,
                cornerRadius: Metrics.groundThickness / 2
            ),
            materials: [BoxMaterials.ceramic(BoxMaterials.Tone.ground)]
        )
        ground.name = NodeName.ground
        ground.position = [0, Metrics.groundDrop, 0]
        root.addChild(ground)

        self.root = root
        keyLight = key
        fillLight = fill
        self.ground = ground
    }

    /// Applies a derived rig. Elevation and azimuth place the light; temperature and
    /// intensity tint and drive it.
    ///
    /// The system appearance sets the base palette and the clock rig modulates within it
    /// (§9.4), so the ground and the light level both answer to `colorScheme`. RealityKit
    /// resolves a material colour once, at creation, so a dynamic `UIColor` would silently
    /// freeze at whichever appearance happened to be current — the tone is applied here.
    func apply(_ rig: LightRig, colorScheme: ColorScheme) {
        ground.model?.materials = [BoxMaterials.ceramic(Self.groundTone(for: colorScheme))]
        apply(rig, dimming: colorScheme == .dark ? Intensity.darkAppearance : 1)
    }

    private static func groundTone(for colorScheme: ColorScheme) -> UIColor {
        colorScheme == .dark ? BoxMaterials.Tone.groundDark : BoxMaterials.Tone.ground
    }

    private func apply(_ rig: LightRig, dimming: Float) {
        let keyDirection = Self.direction(
            elevationRadians: rig.elevationRadians,
            azimuthRadians: rig.azimuthRadians
        )
        keyLight.light.color = Self.color(kelvin: rig.colorTemperatureKelvin)
        keyLight.light.intensity = (Intensity.floor + Intensity.span * rig.relativeIntensity) * dimming
        keyLight.look(at: .zero, from: keyDirection * Metrics.lightDistance, relativeTo: nil)

        let fillDirection = Self.direction(
            elevationRadians: rig.elevationRadians * 0.5,
            azimuthRadians: rig.azimuthRadians + .pi
        )
        fillLight.light.color = Self.color(kelvin: rig.colorTemperatureKelvin)
        fillLight.light.intensity =
            (Intensity.floor + Intensity.span * rig.relativeIntensity) * Intensity.fillFraction * dimming
        fillLight.look(at: .zero, from: fillDirection * Metrics.lightDistance, relativeTo: nil)
    }

    /// `RealityView` paints no background of its own on iOS, so the graded space boundary
    /// is a SwiftUI layer beneath the scene, driven by the same derived rig (WP-01 finding).
    /// System appearance sets the base palette and the rig modulates within it (§9.4).
    static func backdrop(for rig: LightRig, colorScheme: ColorScheme) -> LinearGradient {
        let warmth = Double(warmthFraction(kelvin: rig.colorTemperatureKelvin))
        let light = Double(rig.relativeIntensity)

        let top: Color
        let bottom: Color
        switch colorScheme {
        case .dark:
            top = Color(hue: 0.62 - 0.06 * warmth, saturation: 0.24, brightness: 0.10 + 0.09 * light)
            bottom = Color(hue: 0.08 + 0.02 * warmth, saturation: 0.20, brightness: 0.16 + 0.10 * light)
        default:
            top = Color(hue: 0.58 - 0.05 * warmth, saturation: 0.10 + 0.05 * warmth, brightness: 0.88 + 0.10 * light)
            bottom = Color(hue: 0.09, saturation: 0.10 + 0.06 * warmth, brightness: 0.82 + 0.12 * light)
        }
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    private static func direction(elevationRadians: Float, azimuthRadians: Float) -> SIMD3<Float> {
        SIMD3(
            cos(elevationRadians) * sin(azimuthRadians),
            sin(elevationRadians),
            cos(elevationRadians) * cos(azimuthRadians)
        )
    }

    /// 0 at the rig's coolest temperature, 1 at its warmest.
    private static func warmthFraction(kelvin: Float) -> Float {
        min(max((6_500 - kelvin) / (6_500 - 2_700), 0), 1)
    }

    /// A light tint for the 2700–6500 K range this product uses. It interpolates between
    /// two endpoint tints rather than implementing a general colour-temperature converter,
    /// which nothing here needs.
    private static func color(kelvin: Float) -> UIColor {
        let warmth = CGFloat(warmthFraction(kelvin: kelvin))
        let cool = (red: 1.00, green: 0.98, blue: 0.96) as (red: CGFloat, green: CGFloat, blue: CGFloat)
        let warm = (red: 1.00, green: 0.76, blue: 0.52) as (red: CGFloat, green: CGFloat, blue: CGFloat)
        return UIColor(
            red: cool.red + (warm.red - cool.red) * warmth,
            green: cool.green + (warm.green - cool.green) * warmth,
            blue: cool.blue + (warm.blue - cool.blue) * warmth,
            alpha: 1
        )
    }
}
