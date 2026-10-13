import SwiftUI

// Shared presentation only; gameplay and voting remain in their existing owners.
enum PlaytestStyle {
    #if os(macOS)
    static let maximumBowlSize: CGFloat = 320
    static let soloBowlAllowance: CGFloat = 240
    static let soloKeyboardRowHeight: CGFloat = 108
    static let maximumComparisonHeight: CGFloat = 260
    #else
    static let maximumBowlSize: CGFloat = 230
    static let soloBowlAllowance: CGFloat = 200
    static let soloKeyboardRowHeight: CGFloat = 0
    static let maximumComparisonHeight: CGFloat = 140
    #endif
    static let ink = Color(red: 0.12, green: 0.14, blue: 0.23)
    static let accent = Color(red: 0.36, green: 0.31, blue: 0.86)
    static let success = Color(red: 0.10, green: 0.45, blue: 0.22)
    static let failure = Color(red: 0.75, green: 0.08, blue: 0.14)
    static let canvas = Color(red: 0.96, green: 0.95, blue: 0.92)
    static let muted = Color(red: 0.40, green: 0.42, blue: 0.49)
}

struct PlaytestButtonStyle: ButtonStyle {
    var primary = true
    var compact = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(compact ? .caption.bold() : .headline)
            .padding(.horizontal, compact ? 10 : 22)
            .frame(minHeight: 44)
            .foregroundStyle(primary ? .white : PlaytestStyle.ink)
            .background(primary ? PlaytestStyle.accent : Color.white, in: Capsule())
            .overlay(Capsule().strokeBorder(PlaytestStyle.ink.opacity(primary ? 0 : 0.12)))
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.35)
    }
}

extension View {
    func playtestCard(inset: CGFloat? = nil) -> some View {
        let paddingInset = inset ?? 12
        return padding(paddingInset)
            .background(.white, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(PlaytestStyle.ink.opacity(0.06)))
    }
}

struct PlaytestHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            Text(subtitle).font(.subheadline).foregroundStyle(PlaytestStyle.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ColorSwatch: View {
    let color: SIMD3<Double>
    let name: String
    var height: CGFloat = 120

    var body: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(Color(red: color.x, green: color.y, blue: color.z))
            .frame(height: height)
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.black.opacity(0.12)))
            .accessibilityLabel(name)
            .accessibilityValue("Red \(Int((color.x * 100).rounded())) percent, green \(Int((color.y * 100).rounded())) percent, blue \(Int((color.z * 100).rounded())) percent")
    }
}
