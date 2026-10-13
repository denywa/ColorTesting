import SwiftUI

struct RequestNoticeView: View {
    let request: String
    let message: String
    var title = "CLIENT REQUEST"
    var targetHint: SIMD3<Double>?
    let dismiss: () -> Void

    private var requestText: some View {
        Text(request).font(.title3.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.55).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(title, systemImage: "person.crop.circle.fill")
                            .font(.headline).accessibilityAddTraits(.isHeader)
                        Spacer()
                        Button("Dismiss request", systemImage: "xmark", action: dismiss)
                            .labelStyle(.iconOnly)
                            .frame(width: 44, height: 44)
                            .buttonStyle(.plain)
                    }
                    HStack(spacing: 12) {
                        Text(message).font(.caption.bold()).foregroundStyle(PlaytestStyle.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let targetHint {
                            ColorSwatch(color: targetHint, name: "Target color hint", height: 44)
                                .frame(width: 44)
                        }
                    }
                    ViewThatFits(in: .vertical) {
                        requestText
                        ScrollView(.vertical) { requestText }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }
                .padding(20)
                .frame(width: min(520, max(200, geometry.size.width - 32)),
                       height: min(300, max(160, geometry.size.height - 24)))
                .foregroundStyle(PlaytestStyle.ink)
                .background(Color(red: 1, green: 0.94, blue: 0.84), in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.orange.opacity(0.6), lineWidth: 2))
                .shadow(radius: 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityAddTraits(.isModal)
    }
}
