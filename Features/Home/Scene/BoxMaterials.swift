import RealityKit
import UIKit

/// The material families of specification §15.4: warm, matte, no exposed machinery. Every
/// surface in the scene comes from here so the box reads as one object, and so WP-11 has a
/// single place to simplify when the quality tier drops.
///
/// B1 is procedural (no binary assets), so these are parametric PBR materials rather than
/// authored textures.
@MainActor
enum BoxMaterials {
    /// The soft wood/ceramic family the box body and lid are cut from.
    enum Tone {
        static let body = UIColor(red: 0.72, green: 0.44, blue: 0.25, alpha: 1)
        static let lid = UIColor(red: 0.78, green: 0.52, blue: 0.31, alpha: 1)
        /// Recessed structures read as shadow, not as paint.
        static let recess = UIColor(red: 0.44, green: 0.26, blue: 0.15, alpha: 1)
        /// The strap is fabric: same warmth, less light, more tooth.
        static let strap = UIColor(red: 0.62, green: 0.34, blue: 0.22, alpha: 1)
        static let paper = UIColor(red: 0.97, green: 0.95, blue: 0.90, alpha: 1)
        static let ground = UIColor(red: 0.86, green: 0.83, blue: 0.79, alpha: 1)
        static let groundDark = UIColor(red: 0.17, green: 0.15, blue: 0.14, alpha: 1)
    }

    static func ceramic(_ tint: UIColor) -> PhysicallyBasedMaterial {
        material(tint: tint, roughness: 0.82, specular: 0.35)
    }

    static func fabric(_ tint: UIColor) -> PhysicallyBasedMaterial {
        material(tint: tint, roughness: 0.96, specular: 0.10)
    }

    static func paper(_ tint: UIColor = Tone.paper) -> PhysicallyBasedMaterial {
        material(tint: tint, roughness: 0.90, specular: 0.15)
    }

    private static func material(
        tint: UIColor,
        roughness: Float,
        specular: Float
    ) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: tint)
        material.roughness = .init(floatLiteral: roughness)
        material.metallic = 0.0
        material.specular = .init(floatLiteral: specular)
        return material
    }
}
