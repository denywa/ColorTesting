import SwiftUI

struct RunSettingsView: View {
    let viewModel: GameViewModel
    @State private var editingSchedule = false

    private var config: EndlessRunConfiguration { viewModel.runConfiguration }
    private func binding<Value>(_ path: WritableKeyPath<EndlessRunConfiguration, Value>) -> Binding<Value> {
        Binding(get: { viewModel.runConfiguration[keyPath: path] }, set: { value in
            var updated = viewModel.runConfiguration
            updated[keyPath: path] = value
            viewModel.runConfiguration = updated
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Endless Days").font(.title2.bold())
            Text("Complete the Day's clients. Keep going until time or mistakes end the run.")
                .font(.caption).foregroundStyle(PlaytestStyle.muted)
            Picker("Timer Mode", selection: binding(\.timerMode)) {
                Text("Day Timer").tag(RunTimerMode.day)
                Text("Client Timer").tag(RunTimerMode.client)
            }
            .pickerStyle(.segmented)
            .accessibilityValue(config.timerMode.title)
            if config.timerMode == .day {
                Stepper("Day time: \(config.dayDuration / 60) min", value: binding(\.dayDuration), in: 60...86_400, step: 60)
            } else {
                Stepper("Client time: \(config.clientDuration / 60) min", value: binding(\.clientDuration), in: 60...86_400, step: 60)
            }
            HStack {
                Text("Passing score")
                Spacer()
                Text("\(Int(config.passingScore))%").font(.headline.monospacedDigit())
            }
            Slider(value: binding(\.passingScore), in: 0...100, step: 1)
                .accessibilityLabel("Passing score").accessibilityValue("\(Int(config.passingScore)) percent")
            Toggle("Unlimited mistakes", isOn: Binding(get: { config.mistakeLimit == nil }, set: { unlimited in
                var updated = config
                updated.mistakeLimit = unlimited ? nil : 3
                viewModel.runConfiguration = updated
            }))
            if config.mistakeLimit != nil {
                Stepper("Mistakes per Day: \(config.mistakeLimit ?? 3)", value: Binding(get: { config.mistakeLimit ?? 3 }, set: { value in
                    var updated = config; updated.mistakeLimit = value; viewModel.runConfiguration = updated
                }), in: 1...100)
                Text("Reaching this limit ends the run.").font(.caption).foregroundStyle(PlaytestStyle.muted)
            } else if config.timerMode == .client {
                Text("No automatic Game Over from client timeouts; new clients can continue indefinitely.")
                    .font(.caption).foregroundStyle(PlaytestStyle.muted)
            }
            Button("Configure Day targets & difficulty") { editingSchedule = true }
                .buttonStyle(PlaytestButtonStyle(primary: false))
            Text("7 stages · Day 8 onward repeats stages 5–7")
                .font(.caption).foregroundStyle(PlaytestStyle.muted)
        }
        .playtestCard()
        .sheet(isPresented: $editingSchedule) { scheduleEditor }
    }

    private var scheduleEditor: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Each client has one request level. Day 8 onward reuses stages 5, 6 and 7, including their targets.")
                        .font(.callout).foregroundStyle(PlaytestStyle.muted)
                    ForEach(0..<7, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Stage \(index + 1)\(index >= 4 ? " · repeats after Day 7" : "")").font(.headline)
                            Stepper("Target: \(config.templates[index].target) clients", value: Binding(get: {
                                config.templates[index].target
                            }, set: { count in
                                var updated = config
                                updated.templates[index].setTarget(count)
                                viewModel.runConfiguration = updated
                            }), in: 1...100)
                            ForEach(config.templates[index].levels.indices, id: \.self) { slot in
                                Picker("Client \(slot + 1)", selection: Binding(get: {
                                    let levels = viewModel.runConfiguration.templates[index].levels
                                    return levels.indices.contains(slot) ? levels[slot] : .level1
                                }, set: { level in
                                    var updated = config
                                    guard updated.templates[index].levels.indices.contains(slot) else { return }
                                    updated.templates[index].levels[slot] = level
                                    viewModel.runConfiguration = updated
                                })) {
                                    ForEach(RequestDifficulty.allCases, id: \.self) { level in Text(level.title).tag(level) }
                                }
                            }
                        }
                        .playtestCard()
                    }
                }
                .padding(20)
            }
            .background(PlaytestStyle.canvas)
            .navigationTitle("Day Schedule")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { editingSchedule = false } }
            }
        }
        .tint(PlaytestStyle.accent)
        #if os(macOS)
        .frame(minWidth: 560, minHeight: 480)
        #endif
    }
}
