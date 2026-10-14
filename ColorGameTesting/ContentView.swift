//
//  ContentView.swift
//  ColorGameTesting
//
//  Created by Deny Wahyudi Asaloei  on 02/10/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: GameViewModel
    @State private var coordinator: LocalPlayCoordinator
    @State private var selectedMode: PlayMode?
    @State private var lastNoticedRoundID: UUID?

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
                    if viewModel.phase == .playing || viewModel.phase == .result || viewModel.phase == .score {
                        activeContent(coordinator: nil)
                    } else {
                        soloContent
                    }
                }
            } else {
                ModeSelectionView { mode in
                    coordinator.chooseMode(mode)
                    selectedMode = mode
                }
            }
        }
        .foregroundStyle(PlaytestStyle.ink)
        .tint(PlaytestStyle.accent)
        .background(PlaytestStyle.canvas.ignoresSafeArea())
        .preferredColorScheme(.light)
        .onChange(of: coordinator.mode) { _, mode in
            if selectedMode == .threeDevices && mode == .singleDevice {
                selectedMode = nil
            }
        }
        .onChange(of: scenePhase) { _, phase in handleScenePhaseChange(phase) }
    }

    private var soloContent: some View {
        VStack(spacing: 0) {
            Button(viewModel.phase == .settings ? "Choose Mode" : "Back to Settings") {
                if viewModel.phase == .settings {
                    viewModel.endLocalPlay()
                    self.selectedMode = nil
                } else { viewModel.returnToSettings() }
            }
            .buttonStyle(PlaytestButtonStyle(primary: false))
            .padding(.top, 8)
            phaseContent(coordinator: nil)
        }
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        if selectedMode == .singleDevice {
            if phase == .active { viewModel.resumeSessionClocks() }
            else { viewModel.pauseSessionClocks() }
            return
        }
        guard selectedMode == .threeDevices else { return }
        switch phase {
        case .active:
            coordinator.appDidBecomeActive()
        case .inactive, .background:
            coordinator.hostWillEnterBackground()
            Task { await coordinator.flushBackgroundSnapshot() }
        @unknown default:
            break
        }
    }

    @ViewBuilder
    private var localContent: some View {
        if viewModel.phase == .settings {
            if coordinator.role == .host {
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        LocalLobbyView(coordinator: coordinator, embedded: true)
                        SettingsView(viewModel: viewModel, coordinator: coordinator, embedded: true)
                    }
                }
                #if os(iOS)
                .scrollDismissesKeyboard(.interactively)
                #endif
            } else {
                LocalLobbyView(coordinator: coordinator)
            }
        } else {
            if viewModel.phase == .playing || viewModel.phase == .result || viewModel.phase == .score {
                activeContent(coordinator: coordinator)
            } else { localPhaseContent }
        }
    }

    private func activeContent(coordinator: LocalPlayCoordinator?) -> some View {
        let missingData: Bool = switch viewModel.phase {
        case .playing: viewModel.round == nil
        case .result: viewModel.round == nil || viewModel.mixResult == nil
        case .score: viewModel.score == nil
        case .settings, .gameOver: false
        }
        return VStack(spacing: 0) {
            if missingData {
                RunHeaderView(run: viewModel.run, exitTitle: coordinator == nil || coordinator?.role == .host ? "Lobby" : "Leave",
                              exitAccessibilityLabel: coordinator == nil ? "Back to Settings" : coordinator?.role == .host ? "Back to Settings and Lobby" : "Leave Session", exitAction: {
                    if coordinator == nil { viewModel.returnToSettings() } else { exitLocalSession() }
                })
                .padding(12)
            }
            phaseContent(coordinator: coordinator)
        }
    }

    private func exitLocalSession() {
        if coordinator.role == .host { coordinator.perform(.returnToLobby) }
        else { Task { await coordinator.leaveSession() } }
    }

    private var localPhaseContent: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(localSessionExitTitle) {
                    if coordinator.role == .host { coordinator.perform(.returnToLobby) }
                    else { Task { await coordinator.leaveSession() } }
                }
                .buttonStyle(PlaytestButtonStyle(primary: false))
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            phaseContent(coordinator: coordinator)
        }
    }

    var localSessionExitTitle: String {
        coordinator.role == .host ? "Lobby" : "Leave Session"
    }

    @ViewBuilder
    private func phaseContent(coordinator: LocalPlayCoordinator?) -> some View {
        switch viewModel.phase {
        case .settings:
            SettingsView(viewModel: viewModel, coordinator: coordinator)
        case .playing:
            GameView(viewModel: viewModel, coordinator: coordinator, exitAction: { if coordinator == nil { viewModel.returnToSettings() } else { exitLocalSession() } }, lastNoticedRoundID: $lastNoticedRoundID)
        case .result:
            ResultView(viewModel: viewModel, coordinator: coordinator, exitAction: { if coordinator == nil { viewModel.returnToSettings() } else { exitLocalSession() } })
        case .score:
            ScoreView(viewModel: viewModel, coordinator: coordinator, exitAction: { if coordinator == nil { viewModel.returnToSettings() } else { exitLocalSession() } })
        case .gameOver:
            GameOverView(viewModel: viewModel, coordinator: coordinator)
        }
    }
}

#Preview {
    ContentView()
}
