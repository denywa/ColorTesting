import Foundation

enum ScoreCalculator {
    private static let degreesToRadians = Double.pi / 180
    private static let twentyFiveToSeventh = pow(25.0, 7.0)
    private static let scoreMidpoint = 23.0
    private static let scoreNearDifferenceScale = 200.0
    private static let scoreCutoff = 100.0

    static func matchPercentage(_ lab1: SIMD3<Double>, _ lab2: SIMD3<Double>) -> Double {
        // ΔE00 is a perceptual distance, not a percentage. Calibrate the game
        // score so a different shade of the same hue stays fairly close, while
        // large color-family differences fall quickly. The linear term still
        // distinguishes near-perfect matches; the fourth-power term handles
        // larger differences. Normalize the endpoints to exactly 100% and 0%.
        let distance = min(deltaE2000(lab1, lab2), scoreCutoff)
        let similarity = scoreSimilarity(at: distance)
        let zeroPoint = scoreSimilarity(at: scoreCutoff)
        return 100 * (similarity - zeroPoint) / (1 - zeroPoint)
    }

    private static func scoreSimilarity(at distance: Double) -> Double {
        1 / (1 + distance / scoreNearDifferenceScale
             + pow(distance / scoreMidpoint, 4))
    }

    static func deltaE2000(_ lab1: SIMD3<Double>, _ lab2: SIMD3<Double>) -> Double {
        if lab1 == lab2 { return 0.0 }

        // 1. Adjust a* using the mean unadjusted chroma.
        let chroma1 = hypot(lab1.y, lab1.z)
        let chroma2 = hypot(lab2.y, lab2.z)
        let meanChroma = (chroma1 + chroma2) / 2
        let meanChromaSeventh = pow(meanChroma, 7)
        let adjustment = 0.5 * (1 - sqrt(meanChromaSeventh /
                                         (meanChromaSeventh + twentyFiveToSeventh)))
        let adjustedA1 = lab1.y * (1 + adjustment)
        let adjustedA2 = lab2.y * (1 + adjustment)

        // 2. Compute adjusted chroma and hue in [0, 360) degrees.
        let adjustedChroma1 = hypot(adjustedA1, lab1.z)
        let adjustedChroma2 = hypot(adjustedA2, lab2.z)
        let hue1 = hueDegrees(b: lab1.z, a: adjustedA1)
        let hue2 = hueDegrees(b: lab2.z, a: adjustedA2)

        // 3. Choose the shortest hue difference, except when either chroma is zero.
        let deltaLightness = lab2.x - lab1.x
        let deltaChroma = adjustedChroma2 - adjustedChroma1
        var deltaHue = hue2 - hue1
        if adjustedChroma1 == 0 || adjustedChroma2 == 0 {
            deltaHue = 0
        } else if deltaHue > 180 {
            deltaHue -= 360
        } else if deltaHue < -180 {
            deltaHue += 360
        }
        let deltaHueTerm = 2 * sqrt(adjustedChroma1 * adjustedChroma2)
            * sin(deltaHue * degreesToRadians / 2)

        // 4. Compute mean values, weighting functions, and hue rotation.
        let meanLightness = (lab1.x + lab2.x) / 2
        let meanAdjustedChroma = (adjustedChroma1 + adjustedChroma2) / 2
        var meanHue: Double
        if adjustedChroma1 == 0 || adjustedChroma2 == 0 {
            meanHue = hue1 + hue2
        } else if abs(hue1 - hue2) <= 180 {
            meanHue = (hue1 + hue2) / 2
        } else if hue1 + hue2 < 360 {
            meanHue = (hue1 + hue2 + 360) / 2
        } else {
            meanHue = (hue1 + hue2 - 360) / 2
        }
        let hueRadians = meanHue * degreesToRadians
        let t = 1 - 0.17 * cos((meanHue - 30) * degreesToRadians)
            + 0.24 * cos(2 * hueRadians)
            + 0.32 * cos((3 * meanHue + 6) * degreesToRadians)
            - 0.20 * cos((4 * meanHue - 63) * degreesToRadians)
        let lightnessOffset = meanLightness - 50
        let lightnessWeight = 1 + 0.015 * lightnessOffset * lightnessOffset
            / sqrt(20 + lightnessOffset * lightnessOffset)
        let chromaWeight = 1 + 0.045 * meanAdjustedChroma
        let hueWeight = 1 + 0.015 * meanAdjustedChroma * t
        let meanAdjustedChromaSeventh = pow(meanAdjustedChroma, 7)
        let rotationChroma = 2 * sqrt(meanAdjustedChromaSeventh /
                                      (meanAdjustedChromaSeventh + twentyFiveToSeventh))
        let angleOffset = (meanHue - 275) / 25
        let rotationAngle = 30 * exp(-angleOffset * angleOffset)
        let rotationTerm = -sin(2 * rotationAngle * degreesToRadians) * rotationChroma

        // 5. Unit parametric weights (kL = kC = kH = 1).
        let lightnessTerm = deltaLightness / lightnessWeight
        let chromaTerm = deltaChroma / chromaWeight
        let hueTerm = deltaHueTerm / hueWeight
        let squaredDistance = lightnessTerm * lightnessTerm + chromaTerm * chromaTerm
            + hueTerm * hueTerm + rotationTerm * chromaTerm * hueTerm
        return sqrt(max(0, squaredDistance))
    }

    private static func hueDegrees(b: Double, a: Double) -> Double {
        let degrees = atan2(b, a) / degreesToRadians
        return degrees < 0 ? degrees + 360 : degrees
    }
}
