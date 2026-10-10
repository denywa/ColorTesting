import SwiftUI

struct LocalLobbyView: View {
    let coordinator: LocalPlayCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Local Wi-Fi Lobby")
                    .font(.largeTitle)
                    .bold()

                if let role = coordinator.role {
                    Text("Your role: \(role.name)")
                        .accessibilityLabel("Your role: \(role.name)")
                }

                if coordinator.role == nil {
                    Button("Create Session") { try? coordinator.startHosting() }
                    Button("Find Sessions") { coordinator.startBrowsing() }

                    if coordinator.discoveredSessions.isEmpty {
                        Text("No sessions found yet")
                    } else {
                        ForEach(coordinator.discoveredSessions) { session in
                            sessionButton(session)
                        }
                    }
                } else {
                    Text("Players")
                        .font(.headline)
                    seatRow(.host)
                    seatRow(.player2)
                    seatRow(.player3)

                    if coordinator.role != .host {
                        Text("Waiting for the host to start the round")
                    }
                    if let missing = SessionRole.allCases.first(where: { status(for: $0) == .disconnected }) {
                        Text("Waiting for \(missing == .host ? "host" : missing.name) to reconnect")
                    }
                }

                if let error = coordinator.error {
                    Text(error.message)
                        .accessibilityLabel(error.message)
                    Button("Try Again") {
                        if coordinator.role != nil {
                            coordinator.appDidBecomeActive()
                        } else {
                            coordinator.startBrowsing()
                        }
                    }
                }

                Button(coordinator.role == .host ? "End Session" : "Leave Session") {
                    Task { await coordinator.leaveSession() }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func status(for role: SessionRole) -> SessionStatus {
        if role == .host, coordinator.role != .host, coordinator.role != nil {
            return coordinator.connectionStatus == .disconnected ? .disconnected :
                (coordinator.seatStatus.first { $0.player == .player1 }?.status ?? .connected)
        }
        return coordinator.seatStatus.first { $0.player == role.playerID }?.status ??
            (role == coordinator.role ? .connected : .waiting)
    }

    func sessionButton(_ session: DiscoveredSession) -> Button<Text> {
        Button("Join \(session.name)") { coordinator.join(session) }
    }

    private func seatRow(_ role: SessionRole) -> some View {
        Text("\(role.name): \(status(for: role).name)")
            .accessibilityLabel("\(role.name): \(status(for: role).name)")
    }
}

private extension SessionRole {
    var name: String {
        switch self {
        case .host: "Player 1 (Host)"
        case .player2: "Player 2"
        case .player3: "Player 3"
        }
    }
}

private extension SessionStatus {
    var name: String {
        switch self {
        case .waiting: "Waiting"
        case .connected: "Connected"
        case .disconnected: "Disconnected"
        }
    }
}

private extension LocalPlayError {
    var message: String {
        switch self {
        case .permissionDenied: "Local network access is denied. Allow access in Settings, then try again."
        case .wifiUnavailable: "Wi-Fi is unavailable. Connect to local Wi-Fi, then try again."
        case .sessionNotFound: "This session is not available. Find sessions and try again."
        case .sessionFull: "This session is full. Choose another session and try again."
        case .versionMismatch: "The host uses a different app version. Update the apps and try again."
        case .invalidMessage, .invalidSession: "The session could not be joined. Try again."
        case .disconnected: "Connection lost. Check Wi-Fi and try again."
        }
    }
}
