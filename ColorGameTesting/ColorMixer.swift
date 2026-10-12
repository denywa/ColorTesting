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
            result = rybToSRGB(units)
        }
        return SIMD3((0..<3).map { min(1, max(0, result[$0])) })
    }

    private static func rybToSRGB(_ units: [ColorUnit]) -> SIMD3<Double> {
        var primaries = SIMD3<Double>(repeating: 0)
        var primaryCount = 0.0
        var whiteCount = 0.0
        for unit in units {
            guard let components = unit.color.rybComponents else {
                preconditionFailure("RYB mix contains a color without RYB components")
            }
            if components == SIMD3(repeating: 0) {
                whiteCount += 1
            } else if components != SIMD3(repeating: 1) {
                primaries += components
                primaryCount += 1
            }
        }

        let count = Double(units.count)
        guard primaryCount > 0 else { return SIMD3(repeating: whiteCount / count) }

        let shares = primaries / (primaries.x + primaries.y + primaries.z)
        let center = min(shares.x, min(shares.y, shares.z))
        let centerWeight = 3 * center
        let residual = shares - SIMD3(repeating: center)
        let palette = ColorData.rybPalette
        let red = palette[0].sRGB, yellow = palette[1].sRGB, blue = palette[2].sRGB
        let first: SIMD3<Double>, middle: SIMD3<Double>, last: SIMD3<Double>, lastWeight: Double
        // The overlap colors match the reference diagram while palette colors stay unchanged.
        if shares.z == center {
            first = red; middle = SIMD3(243, 177, 61) / 255; last = yellow
            lastWeight = residual.y
        } else if shares.y == center {
            first = red; middle = SIMD3(171, 41, 220) / 255; last = blue
            lastWeight = residual.z
        } else {
            first = yellow; middle = SIMD3(96, 200, 60) / 255; last = blue
            lastWeight = residual.z
        }

        let edgeTotal = residual.x + residual.y + residual.z
        let edgeFraction = edgeTotal > 0 ? lastWeight / edgeTotal : 0
        let edge = edgeFraction <= 0.5
            ? first + (middle - first) * (2 * edgeFraction)
            : middle + (last - middle) * (2 * edgeFraction - 1)
        let color = edge * (1 - centerWeight) + SIMD3(74, 74, 74) / 255 * centerWeight
        return color * (primaryCount / count) + SIMD3(repeating: whiteCount / count)
    }
}
