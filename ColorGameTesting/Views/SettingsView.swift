import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: GameViewModel
    @State private var showingAddRequest = false

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
                Text("Choose a color request")
                    .font(.headline)
                HStack {
                    Picker("Color Request", selection: $viewModel.selectedRequestID) {
                        Text("Random").tag(nil as UUID?)
                        ForEach(viewModel.availableRequests) { request in
                            Text(request.text).tag(request.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        showingAddRequest = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Add color request")
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
        .sheet(isPresented: $showingAddRequest) {
            AddRequestView(viewModel: viewModel)
        }
    }
}

private struct AddRequestView: View {
    let viewModel: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var requestText = ""
    @State private var hex = ""

    private var color: SIMD3<Double>? { ColorHex.sRGB(hex) }
    private var canAdd: Bool {
        !requestText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && color != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Request text", text: $requestText,
                          prompt: Text("e.g. Sunset red"))
                TextField("Hex color", text: $hex, prompt: Text("#FF8C32"))

                if let color {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: color.x, green: color.y, blue: color.z))
                            .frame(width: 44, height: 44)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(.primary, lineWidth: 1)
                            }
                        Text(ColorHex.normalized(hex) ?? "")
                            .monospaced()
                    }
                } else {
                    Text("Enter six hex digits, with or without #.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Color Request")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if viewModel.addCustomRequest(text: requestText, hex: hex) {
                            dismiss()
                        }
                    }
                    .disabled(!canAdd)
                }
            }
        }
        .frame(minWidth: 320, minHeight: 280)
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
