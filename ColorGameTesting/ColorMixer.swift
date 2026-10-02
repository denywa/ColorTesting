import Foundation

enum ColorMixer {
    static func blend(_ units: [ColorUnit], model: ColorModel) -> SIMD3<Double> {
        guard let first = units.first else { return SIMD3(0, 0, 0) }
        if units.allSatisfy({ $0.color.id == first.color.id }) {
            return first.color.sRGB
        }

        let count = Double(units.count)
        let result: SIMD3<Double>
        switch model {
        case .cmyk:
            var sum = SIMD4<Double>(0, 0, 0, 0)
            for unit in units {
                guard let components = unit.color.cmykComponents else {
                    preconditionFailure("CMYK mix contains a color without CMYK components")
                }
                sum += components
            }
            let blend = sum / count
            result = SIMD3(
                (1 - blend.x) * (1 - blend.w),
                (1 - blend.y) * (1 - blend.w),
                (1 - blend.z) * (1 - blend.w)
            )
        case .ryb:
            var sum = SIMD3<Double>(0, 0, 0)
            for unit in units {
                guard let components = unit.color.rybComponents else {
                    preconditionFailure("RYB mix contains a color without RYB components")
                }
                sum += components
            }
            let blend = sum / count
            result = rybToSRGB(blend)
        }
        return SIMD3((0..<3).map { min(1, max(0, result[$0])) })
    }

    private static func rybToSRGB(_ components: SIMD3<Double>) -> SIMD3<Double> {
        let corners: [(r: Int, y: Int, b: Int, rgb: SIMD3<Double>)] = [
            (0, 0, 0, SIMD3(1, 1, 1)),
            (1, 0, 0, SIMD3(1, 0, 0)),
            (0, 1, 0, SIMD3(1, 1, 0)),
            (0, 0, 1, SIMD3(0, 0, 1)),
            (1, 1, 0, SIMD3(1, 0.5, 0)),
            (1, 0, 1, SIMD3(0.5, 0, 0.5)),
            (0, 1, 1, SIMD3(0, 1, 0)),
            (1, 1, 1, SIMD3(0, 0, 0))
        ]

        var rgb = SIMD3<Double>(0, 0, 0)
        for corner in corners {
            let rWeight = corner.r == 1 ? components.x : 1 - components.x
            let yWeight = corner.y == 1 ? components.y : 1 - components.y
            let bWeight = corner.b == 1 ? components.z : 1 - components.z
            rgb += corner.rgb * (rWeight * yWeight * bWeight)
        }
        return rgb
    }
}
