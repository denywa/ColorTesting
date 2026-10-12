import SwiftUI
import XCTest
@testable import ColorGameTesting

@MainActor
final class GameViewLocalPlayTests: XCTestCase {
    private final class TestTransport: LocalPeerTransport {
        var onEvent: (@MainActor (TransportEvent) -> Void)?
        func host(serviceName: String) throws {}
        func browse() {}
        func connect(_ session: DiscoveredSession) {}
        func send(_ message: WireMessage, to peer: PeerHandle) async throws {}
        func disconnect(_ peer: PeerHandle) {}
        func startHeartbeats(sessionID: UUID) {}
        func resume() {}
        func stop() {}
    }

    private func makeModel() -> GameViewModel {
        let colors = ColorData.rybPalette
        let model = GameViewModel()
        model.phase = .playing
        model.round = Round(
            request: ColorData.requestPool[0], colorModel: .ryb,
            mixMode: .manual,
            assignments: [
                .player1: .init(player: .player1, primaryColor: colors[0], secondaryColor: colors[1]),
                .player2: .init(player: .player2, primaryColor: colors[2], secondaryColor: colors[3]),
                .player3: .init(player: .player3, primaryColor: colors[4], secondaryColor: colors[0])
            ],
            mix: Mix(units: [ColorUnit(color: colors[0])])
        )
        return model
    }

    private func joinPeer(_ coordinator: LocalPlayCoordinator) {
        let peer = PeerHandle(id: UUID())
        coordinator.handle(.connected(peer))
        coordinator.handle(.received(.hello(.init(protocolVersion: LocalPlayProtocol.version,
                                                   clientID: UUID(), sessionID: nil,
                                                   reconnectToken: nil)), from: peer))
    }

    private func texts(in value: Any) -> [String] {
        if let text = value as? Text { return [String(describing: text)] }
        return Mirror(reflecting: value).children.flatMap { texts(in: $0.value) }
    }

    func testEachLocalRoleSeesOnlyItsTwoAssignedSlots() throws {
        for role in SessionRole.allCases {
            let model = makeModel()
            let coordinator = LocalPlayCoordinator(viewModel: model, transport: TestTransport())
            if role == .host {
                try coordinator.startHosting()
            } else {
                coordinator.startBrowsing()
                let peer = PeerHandle(id: UUID())
                coordinator.handle(.connected(peer))
                coordinator.handle(.received(.welcome(.init(sessionID: UUID(), role: role,
                                                            reconnectToken: UUID())), from: peer))
            }
            let view = GameView(viewModel: model, coordinator: coordinator)
            XCTAssertEqual(view.visiblePlayers, [role.playerID])
            XCTAssertNotNil(model.round?.assignments[role.playerID])
            XCTAssertTrue(texts(in: view.body).contains { $0.contains("Your role: Player") })
            if role != .host {
                XCTAssertFalse(view.showsMixButton)
                XCTAssertFalse(view.canMix)
            }
        }
    }

    func testHostMixRequiresAColorAndAnUnpausedSession() throws {
        let model = GameViewModel()
        let coordinator = LocalPlayCoordinator(viewModel: model, transport: TestTransport())
        try coordinator.startHosting()
        joinPeer(coordinator)
        joinPeer(coordinator)

        XCTAssertTrue(coordinator.perform(.startRound))
        let view = GameView(viewModel: model, coordinator: coordinator)
        XCTAssertTrue(view.showsMixButton)
        XCTAssertFalse(view.canMix)
        view.mix()
        XCTAssertEqual(model.phase, .playing)

        model.round?.mix.units = [ColorUnit(color: ColorData.rybPalette[0])]
        XCTAssertTrue(view.canMix)
        coordinator.setPaused(true)
        XCTAssertTrue(view.inputsDisabled)
        XCTAssertFalse(view.canMix)
        XCTAssertTrue(texts(in: view.body).contains { $0.contains("Paused") })
        model.addColor(player: .player1, slot: .primary)
        XCTAssertEqual(model.round?.mix.units.count, 1)
        view.mix()
        XCTAssertEqual(model.phase, .playing)
        coordinator.setPaused(false)
        XCTAssertFalse(view.inputsDisabled)
        XCTAssertTrue(view.canMix)
        view.mix()
        XCTAssertEqual(model.phase, .result)
        model.pauseTimer()
        model.removeKeyMonitor()
    }

    func testSoloStillShowsAllPlayersAndUsesOriginalMix() {
        let model = makeModel()
        let view = GameView(viewModel: model)
        XCTAssertEqual(view.visiblePlayers, PlayerID.allCases)
        XCTAssertTrue(view.showsMixButton)
        XCTAssertFalse(view.inputsDisabled)
        XCTAssertTrue(view.canMix)
        view.mix()
        XCTAssertEqual(model.phase, .result)
    }
}
