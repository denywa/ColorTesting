import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: GameViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("Color Mixing")
                .font(.largeTitle)
                .bold()

            VStack(alignment: .leading, spacing: 10) {
                Text("Choose a color model for this round")
                    .font(.headline)
                ColorModelToggle(selectedModel: viewModel.selectedModel) { model in
                    viewModel.selectModel(model)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Game Settings")
                    .font(.headline)
                
                HStack {
                    Text("Random Reassignment Duration")
                    Spacer()
                    Picker("Duration", selection: $viewModel.reassignmentDuration) {
                        Text("15s").tag(15)
                        Text("30s").tag(30)
                        Text("45s").tag(45)
                        Text("60s").tag(60)
                        Text("90s").tag(90)
                    }
                    .frame(width: 120)
                }
                
                Toggle("Show Target Color Hint", isOn: $viewModel.showTargetColor)
            }
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

            Button("Start Round") {
                viewModel.confirmSettings()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canConfirm)
        }
        .padding()
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ColorModelToggle: View {
    let selectedModel: ColorModel?
    let onSelect: (ColorModel) -> Void

    var body: some View {
        HStack {
            ForEach(ColorModel.allCases, id: \.self) { model in
                let isSelected = selectedModel == model
                Button {
                    onSelect(model)
                } label: {
                    Label(model.rawValue, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(isSelected ? Color.accentColor : Color.secondary,
                                              lineWidth: isSelected ? 2 : 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.rawValue)
                .accessibilityValue(isSelected ? "Selected" : "Not selected")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

#Preview {
    SettingsView(viewModel: GameViewModel())
}
