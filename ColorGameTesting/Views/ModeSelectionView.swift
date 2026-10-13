import SwiftUI

struct ModeSelectionView: View {
    let onSelect: (PlayMode) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PlaytestHeading(title: "Choose How to Play", subtitle: "A shared bowl. Three players. Find your perfect color.")
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 18) { choices }
                    VStack(spacing: 18) { choices }
                }
            }
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private var choices: some View {
        choice("Three players on one device", detail: "Share one screen and all six colors.", icon: "person.3.fill", mode: .singleDevice)
        choice("Three devices on local Wi-Fi", detail: "Your own two colors. One group mix.", icon: "wifi", mode: .threeDevices)
    }

    private func choice(_ title: String, detail: String, icon: String, mode: PlayMode) -> some View {
        Button { onSelect(mode) } label: {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: icon).font(.title).foregroundStyle(PlaytestStyle.accent)
                Text(title).font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
                Text(detail).font(.body).foregroundStyle(PlaytestStyle.muted)
                Label("Let's play", systemImage: "arrow.right").font(.headline).foregroundStyle(PlaytestStyle.accent)
            }
            .frame(minWidth: 240, maxWidth: .infinity, alignment: .leading)
            .playtestCard()
            .contentShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
    }
}
