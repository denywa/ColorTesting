import Foundation

enum ColorConverter {
    private static let referenceWhite = SIMD3(0.95046, 1.0, 1.08906)
    private static let epsilon = 216.0 / 24389.0
    private static let kappa = 24389.0 / 27.0

    static func sRGBToLab(_ srgb: SIMD3<Double>) -> SIMD3<Double> {
        let r = linearize(srgb.x)
        let g = linearize(srgb.y)
        let b = linearize(srgb.z)

        let xyz = SIMD3(
            0.4124564 * r + 0.3575761 * g + 0.1804375 * b,
            0.2126729 * r + 0.7151522 * g + 0.0721750 * b,
            0.0193339 * r + 0.1191920 * g + 0.9503041 * b
        )
        let fx = labFunction(xyz.x / referenceWhite.x)
        let fy = labFunction(xyz.y / referenceWhite.y)
        let fz = labFunction(xyz.z / referenceWhite.z)
        return SIMD3(116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))
    }

    static func labToSRGB(_ lab: SIMD3<Double>) -> SIMD3<Double> {
        let fy = (lab.x + 16) / 116
        let fx = fy + lab.y / 500
        let fz = fy - lab.z / 200
        let x = inverseLabFunction(fx) * referenceWhite.x
        let y = inverseLabFunction(fy) * referenceWhite.y
        let z = inverseLabFunction(fz) * referenceWhite.z

        // Inverse of the linear RGB → XYZ matrix used above.
        let r = 3.240454836021409 * x - 1.537138850102575 * y - 0.498531546868481 * z
        let g = -0.969266389875654 * x + 1.876010928842491 * y + 0.041556082346674 * z
        let b = 0.055643419604214 * x - 0.204025854267698 * y + 1.057225162457929 * z
        return SIMD3(clamp(encode(r)), clamp(encode(g)), clamp(encode(b)))
    }

    private static func linearize(_ component: Double) -> Double {
        component <= 0.04045
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }

    private static func encode(_ component: Double) -> Double {
        component <= 0.0031308
            ? 12.92 * component
            : 1.055 * pow(component, 1.0 / 2.4) - 0.055
    }

    private static func labFunction(_ value: Double) -> Double {
        value > epsilon
            ? pow(value, 1.0 / 3.0)
            : (kappa * value + 16) / 116
    }

    private static func inverseLabFunction(_ value: Double) -> Double {
        let cube = value * value * value
        return cube > epsilon ? cube : (116 * value - 16) / kappa
    }

    private static func clamp(_ component: Double) -> Double {
        min(max(component, 0), 1)
    }
}
