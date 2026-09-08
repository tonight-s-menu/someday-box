import RealityKit
import UIKit

/// Shared PBR surfaces for the character, paper contents, and stage.
@MainActor
enum BoxMaterials {
    /// Warm kraft stock, packing tape, printed features, and stage tones.
    enum Tone {
        static let body = UIColor(red: 0.68, green: 0.46, blue: 0.26, alpha: 1)
        static let lid = UIColor(red: 0.76, green: 0.55, blue: 0.33, alpha: 1)
        /// Recessed structures read as shadow, not as paint.
        static let recess = UIColor(red: 0.44, green: 0.26, blue: 0.15, alpha: 1)
        static let tape = UIColor(red: 0.86, green: 0.68, blue: 0.43, alpha: 1)
        static let ink = UIColor(red: 0.22, green: 0.14, blue: 0.12, alpha: 1)
        static let blush = UIColor(red: 0.95, green: 0.43, blue: 0.35, alpha: 1)
        static let paper = UIColor(red: 0.97, green: 0.95, blue: 0.90, alpha: 1)
        static let ground = UIColor(red: 0.86, green: 0.83, blue: 0.79, alpha: 1)
        static let groundDark = UIColor(red: 0.17, green: 0.15, blue: 0.14, alpha: 1)
    }

    static func ceramic(_ tint: UIColor) -> PhysicallyBasedMaterial {
        material(tint: tint, roughness: 0.82, specular: 0.35)
    }

    static func paper(_ tint: UIColor = Tone.paper) -> PhysicallyBasedMaterial {
        material(tint: tint, roughness: 0.90, specular: 0.15)
    }

    private static var kraftTexture: TextureResource?

    /// A shared, deterministic 512 px fibre map, generated once per process.
    static func cardboard(_ tint: UIColor) throws -> PhysicallyBasedMaterial {
        if kraftTexture == nil {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let image = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512), format: format).image { context in
                let cg = context.cgContext
                UIColor(white: 0.88, alpha: 1).setFill()
                cg.fill(CGRect(x: 0, y: 0, width: 512, height: 512))
                var seed: UInt64 = 731
                func random() -> CGFloat {
                    seed = seed &* 6364136223846793005 &+ 1
                    return CGFloat(seed >> 40) / CGFloat(1 << 24)
                }
                for _ in 0..<24_000 {
                    let x = random() * 512
                    let y = random() * 512
                    let shade = 0.58 + random() * 0.4
                    cg.setStrokeColor(UIColor(white: shade, alpha: 0.55).cgColor)
                    cg.setLineWidth(0.3 + random() * 0.65)
                    cg.move(to: CGPoint(x: x, y: y))
                    cg.addLine(to: CGPoint(x: x + 0.7 + random() * 3.5, y: y + random() - 0.5))
                    cg.strokePath()
                }
                // Broad, low-contrast pressing lines under the finer paper fibres.
                for column in stride(from: 0, to: 512, by: 8) {
                    cg.setFillColor(UIColor(white: 0.55, alpha: 0.055).cgColor)
                    cg.fill(CGRect(x: column, y: 0, width: 1, height: 512))
                }
            }
            guard let cgImage = image.cgImage else { throw CocoaError(.fileReadCorruptFile) }
            kraftTexture = try TextureResource(image: cgImage, options: .init(semantic: .color))
        }
        var surface = material(tint: tint, roughness: 0.97, specular: 0.08)
        surface.baseColor.texture = kraftTexture.map { .init($0) }
        return surface
    }

    static func packingTape() throws -> PhysicallyBasedMaterial {
        var surface = try cardboard(Tone.tape)
        surface.roughness = .init(floatLiteral: 0.63)
        surface.specular = .init(floatLiteral: 0.22)
        return surface
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
