import SwiftUI

struct RequestCardView: View {
    let request: ColorRequest
    let showHint: Bool
    let height: CGFloat
    let showFullRequest: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            ViewThatFits(in: .vertical) {
                Text(request.text).font(.subheadline.bold())
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: showFullRequest) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(request.text).font(.subheadline.bold()).lineLimit(height >= 90 ? 3 : 2)
                        Text("… See more").font(.caption.bold())
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Read full request: \(request.text)")
            }
            if showHint {
                Circle().fill(Color(red: request.targetSRGB.x, green: request.targetSRGB.y, blue: request.targetSRGB.z))
                    .frame(width: 22, height: 22)
                    .overlay(Circle().strokeBorder(.black.opacity(0.15)))
                    .accessibilityLabel("Target color hint")
                    .accessibilityValue("Red \(Int((request.targetSRGB.x * 100).rounded())) percent, green \(Int((request.targetSRGB.y * 100).rounded())) percent, blue \(Int((request.targetSRGB.z * 100).rounded())) percent")
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .leading)
        .background(Color.orange.opacity(0.18), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.orange.opacity(0.6), lineWidth: 2))
    }
}
