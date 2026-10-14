import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: GameViewModel
    let coordinator: LocalPlayCoordinator?
    var embedded = false
    @State private var showingAddRequest = false
    @State private var editingRequest: ColorRequest?

    init(viewModel: GameViewModel, coordinator: LocalPlayCoordinator? = nil, embedded: Bool = false) {
        self.viewModel = viewModel
        self.coordinator = coordinator
        self.embedded = embedded
    }

    var canStartRound: Bool {
        coordinator?.canStartRun ?? viewModel.canStartRun
    }

    var body: some View {
        Group {
            if embedded { settingsContent }
            else {
                ScrollView(.vertical) { settingsContent }
                    #if os(iOS)
                    .scrollDismissesKeyboard(.interactively)
                    #endif
            }
        }
        .sheet(isPresented: $showingAddRequest) {
            RequestEditorView(viewModel: viewModel)
        }
        .sheet(item: $editingRequest) { request in
            RequestEditorView(viewModel: viewModel, request: request)
        }
    }
    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let coordinator, coordinator.role != .host {
                Text("Waiting for the host to start the round")
                Text("Players connected: \(coordinator.seatStatus.filter { $0.status == .connected }.count) of 3")
            } else {
                PlaytestHeading(title: "Color Mixing", subtitle: "Set the round. Make something together.")

                VStack(alignment: .leading, spacing: 10) {
                    Text("Palette: RYB")
                        .font(.headline)
                    Picker("Mix Mode", selection: Binding(
                        get: { viewModel.selectedMixMode },
                        set: { viewModel.selectMixMode($0) }
                    )) {
                        Text("Manual Mix").tag(MixMode.manual)
                        Text("Auto Mix").tag(MixMode.auto)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityValue(viewModel.selectedMixMode == .manual ? "Manual Mix" : "Auto Mix")
                }

                .playtestCard()

                DisclosureGroup("Request Library") { requestLibrary }
                    .font(.subheadline.bold())
                    .playtestCard()

                RunSettingsView(viewModel: viewModel)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Game Settings")
                        .font(.headline)
                
                    DurationSettingView(title: "Random Reassignment Duration",
                                        totalSeconds: $viewModel.reassignmentDuration,
                                        maximumSeconds: 3600)
                
                    Toggle("Show Target Color Hint", isOn: $viewModel.showTargetColor)
                }
                .playtestCard()

                if !viewModel.missingRequestLevels.isEmpty {
                    Text("Add a request for \(viewModel.missingRequestLevels.map { "Level \($0.rawValue)" }.joined(separator: ", ")) before starting, or change the Day schedule.")
                        .font(.caption).foregroundStyle(PlaytestStyle.accent)
                }
                Button("Start Run") {
                    if let coordinator {
                        coordinator.perform(.startRun)
                    } else {
                        viewModel.startEndlessRun()
                    }
                }
                .buttonStyle(PlaytestButtonStyle())
                .disabled(!canStartRound)
            }
        }
        .padding()
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
    }

    private var requestLibrary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Difficulty Level", selection: $viewModel.selectedRequestLevel) {
                ForEach(RequestDifficulty.allCases, id: \.self) { difficulty in
                    Text(difficulty.title)
                        .font(.caption)
                        .tag(difficulty)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityValue(viewModel.selectedRequestLevel.title)
            Text("\(viewModel.requestsForSelectedLevel.count) requests · Days use their configured levels")
                .font(.caption).foregroundStyle(PlaytestStyle.muted)
            DisclosureGroup("View requests in this level") {
                ForEach(viewModel.requestsForSelectedLevel) { request in
                    HStack(spacing: 12) {
                        Text(request.text).font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            editingRequest = request
                        } label: {
                            Label("Edit", systemImage: "pencil")
                                .labelStyle(.iconOnly)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Edit request: \(request.text)")
                        Button(role: .destructive) {
                            viewModel.deleteRequest(id: request.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                                .labelStyle(.iconOnly)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Delete request: \(request.text)")
                    }
                }
            }
            HStack {
                Button {
                    showingAddRequest = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Add color request")
            }
        }

    }

}

private struct RequestEditorView: View {
    let viewModel: GameViewModel
    let request: ColorRequest?
    @Environment(\.dismiss) private var dismiss
    @State private var requestText: String
    @State private var hex: String
    @State private var difficulty: RequestDifficulty
    @State private var saveFailed = false
    @FocusState private var inputFocused: Bool

    init(viewModel: GameViewModel, request: ColorRequest? = nil) {
        self.viewModel = viewModel
        self.request = request
        _requestText = State(initialValue: request?.text ?? "")
        _hex = State(initialValue: request.map { ColorHex.string(from: $0.targetSRGB) } ?? "")
        _difficulty = State(initialValue: request?.difficulty ?? viewModel.selectedRequestLevel)
    }

    private var color: SIMD3<Double>? { ColorHex.sRGB(hex) }
    private var canSave: Bool {
        !requestText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && color != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Difficulty Level", selection: $difficulty) {
                    ForEach(RequestDifficulty.allCases, id: \.self) { level in
                        Text(level.title).tag(level)
                    }
                }
                .accessibilityValue(difficulty.title)
                TextField("Request text", text: $requestText,
                          prompt: Text("e.g. Sunset red"))
                    .focused($inputFocused)
                TextField("Hex color", text: $hex, prompt: Text("#FF8C32"))
                    .focused($inputFocused)

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
            #if os(iOS)
            .scrollDismissesKeyboard(.interactively)
            .submitLabel(.done)
            .onSubmit { inputFocused = false }
            #endif
            .navigationTitle(request == nil ? "Add Color Request" : "Edit Color Request")
            .toolbar {
                #if os(iOS)
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { inputFocused = false }
                }
                #endif
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(request == nil ? "Add" : "Save") {
                        let saved: Bool
                        if let request {
                            saved = viewModel.editRequest(id: request.id, text: requestText, hex: hex, difficulty: difficulty)
                        } else {
                            saved = viewModel.addCustomRequest(text: requestText, hex: hex, difficulty: difficulty)
                        }
                        if saved { dismiss() } else { saveFailed = true }
                    }
                    .disabled(!canSave)
                }
            }
            .alert("Request could not be saved", isPresented: $saveFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Return to the settings lobby and try again.")
            }
        }
        .tint(PlaytestStyle.accent)
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 320)
        #endif
    }
}

#Preview {
    SettingsView(viewModel: GameViewModel())
}
