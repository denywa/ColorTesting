import SwiftUI

struct MixingBowlView: View {
    let size: CGFloat
    var mix: Mix?
    var color: SIMD3<Double>?
    var emptyMessage = "Add a color"

    var body: some View {
        ZStack {
            Circle().fill(.white).shadow(color: .black.opacity(0.10), radius: 12, y: 5)
            Circle().strokeBorder(PlaytestStyle.ink.opacity(0.08), lineWidth: 2)
            if let mix {
                ColorBarView(mix: mix).padding(14)
            } else if let color {
                Circle().fill(Color(red: color.x, green: color.y, blue: color.z)).padding(14)
                    .accessibilityLabel("Blended color")
                    .accessibilityValue("Red \(Int((color.x * 100).rounded())) percent, green \(Int((color.y * 100).rounded())) percent, blue \(Int((color.z * 100).rounded())) percent")
            } else {
                Circle().fill(PlaytestStyle.canvas).padding(14)
                Text(emptyMessage).multilineTextAlignment(.center).padding(25)
                    .font(.subheadline).foregroundStyle(PlaytestStyle.muted)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(mix == nil && color == nil ? "Empty mixing bowl" : "Mixing bowl")
    }
}
