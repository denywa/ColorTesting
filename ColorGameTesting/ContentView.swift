//
//  ContentView.swift
//  ColorGameTesting
//
//  Created by Deny Wahyudi Asaloei  on 02/10/26.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel: GameViewModel
    @State private var coordinator: LocalPlayCoordinator
    @State private var selectedMode: PlayMode?

    init() {
        let model = GameViewModel()
        _viewModel = State(initialValue: model)
        _coordinator = State(initialValue: LocalPlayCoordinator(viewModel: model,
                                                                 transport: LocalNetworkTransport()))
        _selectedMode = State(initialValue: nil)
    }

    init(viewModel: GameViewModel, coordinator: LocalPlayCoordinator, selectedMode: PlayMode?) {
        _viewModel = State(initialValue: viewModel)
        _coordinator = State(initialValue: coordinator)
        _selectedMode = State(initialValue: selectedMode)
    }

    var body: some View {
        Group {
            if let selectedMode {
                if selectedMode == .threeDevices {
                    localContent
                } else {
                    VStack(spacing: 0) {
                        Button("Choose Mode") {
                            viewModel.endLocalPlay()
                            self.selectedMode = nil
                        }
                        .padding(.top)
                        phaseContent(coordinator: nil)
                    }
                }
            } else {
                ModeSelectionView { mode in
                    coordinator.chooseMode(mode)
                    selectedMode = mode
                }
            }
        }
        .onChange(of: coordinator.mode) { _, mode in
            if selectedMode == .threeDevices && mode == .singleDevice {
                selectedMode = nil
            }
        }
    }

    @ViewBuilder
    private var localContent: some View {
        if viewModel.phase == .settings {
            if coordinator.role == .host {
                VStack(spacing: 0) {
                    LocalLobbyView(coordinator: coordinator)
                        .frame(maxHeight: 280)
                    ScrollView {
                        SettingsView(viewModel: viewModel, coordinator: coordinator)
                    }
                }
            } else {
                LocalLobbyView(coordinator: coordinator)
            }
        } else {
            phaseContent(coordinator: coordinator)
        }
    }

    @ViewBuilder
    private func phaseContent(coordinator: LocalPlayCoordinator?) -> some View {
        switch viewModel.phase {
        case .settings:
            SettingsView(viewModel: viewModel, coordinator: coordinator)
        case .playing:
            GameView(viewModel: viewModel, coordinator: coordinator)
        case .result:
            ResultView(viewModel: viewModel, coordinator: coordinator)
        case .score:
            ScoreView(viewModel: viewModel, coordinator: coordinator)
        }
    }
}

#Preview {
    ContentView()
}
