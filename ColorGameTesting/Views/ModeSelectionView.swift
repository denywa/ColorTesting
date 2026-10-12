import SwiftUI

struct ModeSelectionView: View {
    let onSelect: (PlayMode) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Choose How to Play")
                .font(.largeTitle)
                .bold()

            Button("Three players on one device") { onSelect(.singleDevice) }
                .buttonStyle(.borderedProminent)

            Button("Three devices on local Wi-Fi") { onSelect(.threeDevices) }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
