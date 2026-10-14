import SwiftUI

struct DurationSettingView: View {
    let title: String
    @Binding var totalSeconds: Int
    var maximumSeconds = 86_400
    @FocusState private var fieldFocused: Bool

    var minutes: Binding<Int> {
        Binding(get: { totalSeconds / 60 }, set: { value in
            totalSeconds = min(maximumSeconds, max(1,
                min(maximumSeconds / 60, max(0, value)) * 60 + totalSeconds % 60))
        })
    }

    var seconds: Binding<Int> {
        Binding(get: { totalSeconds % 60 }, set: { value in
            totalSeconds = min(maximumSeconds, max(1,
                totalSeconds / 60 * 60 + min(59, max(0, value))))
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.bold())
            HStack(spacing: 12) {
                field("Minutes", value: minutes)
                field("Seconds", value: seconds)
            }
            Text("Minimum 1 second · Maximum \(maximumSeconds / 60) minutes")
                .font(.caption).foregroundStyle(PlaytestStyle.muted)
        }
        #if os(iOS)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if fieldFocused {
                    Spacer()
                    Button("Done") { fieldFocused = false }
                }
            }
        }
        #endif
    }

    private func field(_ label: String, value: Binding<Int>) -> some View {
        HStack(spacing: 8) {
            TextField(label, value: value, format: .number.grouping(.never))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .accessibilityLabel("\(title), \(label)")
                .focused($fieldFocused)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
            Text(label.lowercased()).font(.caption)
        }
    }
}
