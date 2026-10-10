import XCTest
@testable import ColorGameTesting

@MainActor
final class LocalPlayCoordinatorTests: XCTestCase {
    private final class RetryingHostTransport: LocalPeerTransport {
        var onEvent: (@MainActor (TransportEvent) -> Void)?
        var sent: [WireMessage] = []
        var heartbeatSessionID: UUID?

        func host(serviceName: String) throws { throw LocalPlayError.wifiUnavailable }
        func browse() {}
        func connect(_ session: DiscoveredSession) {}
        func send(_ message: WireMessage, to peer: PeerHandle) async throws { sent.append(message) }
        func disconnect(_ peer: PeerHandle) {}
        func startHeartbeats(sessionID: UUID) { heartbeatSessionID = sessionID }
        func resume() {}
        func stop() {}
    }

    private func makeCoordinator(_ network: FakePeerNetwork) -> LocalPlayCoordinator {
        LocalPlayCoordinator(viewModel: GameViewModel(requestDefaults: UserDefaults(suiteName: UUID().uuidString)!),
                             transport: network.makePeer())
    }

    private func waitUntil(_ predicate: @escaping () -> Bool) async {
        for _ in 0..<100 {
            if predicate() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Expected lobby state did not arrive")
    }

    func testHostAssignsThreeUniqueSeatsAndStartGate() async throws {
        let network = FakePeerNetwork()
        let host = makeCoordinator(network)
        let second = makeCoordinator(network)
        let third = makeCoordinator(network)

        try host.startHosting()
        XCTAssertEqual(host.role, .host)
        XCTAssertFalse(host.canStartRound)

        second.startBrowsing()
        let session = try XCTUnwrap(second.discoveredSessions.first)
        second.join(session)
        await waitUntil { second.role == .player2 }
        XCTAssertFalse(host.canStartRound)

        third.startBrowsing()
        third.join(try XCTUnwrap(third.discoveredSessions.first))
        await waitUntil { third.role == .player3 }
        XCTAssertEqual(host.session?.seats.map(\.role), [.host, .player2, .player3])
        XCTAssertTrue(host.canStartRound)
    }

    func testHostRetainsRoleWhenTransportThrowsThenRetries() async throws {
        let transport = RetryingHostTransport()
        let host = LocalPlayCoordinator(viewModel: GameViewModel(), transport: transport)
        XCTAssertThrowsError(try host.startHosting()) { error in
            XCTAssertEqual(error as? LocalPlayError, .wifiUnavailable)
        }
        XCTAssertEqual(host.role, .host)
        XCTAssertEqual(transport.heartbeatSessionID, host.sessionID)
        let peer = PeerHandle(id: UUID())
        transport.onEvent?(.connected(peer))
        transport.onEvent?(.received(.hello(.init(protocolVersion: LocalPlayProtocol.version,
                                                 clientID: UUID(), sessionID: nil,
                                                 reconnectToken: nil)), from: peer))
        await waitUntil { !transport.sent.isEmpty }
        guard case .welcome(let welcome) = transport.sent.first else {
            return XCTFail("Expected Welcome after transport retry")
        }
        XCTAssertEqual(welcome.role, .player2)
        XCTAssertEqual(welcome.sessionID, host.sessionID)
        XCTAssertEqual(host.session?.seats.count, 2)
    }

    func testFourthPeerAndWrongVersionAreRejectedWithoutChangingSeats() async throws {
        let network = FakePeerNetwork()
        let host = makeCoordinator(network)
        let second = makeCoordinator(network)
        let third = makeCoordinator(network)
        let fourth = makeCoordinator(network)
        try host.startHosting()
        for client in [second, third] {
            client.startBrowsing()
            client.join(try XCTUnwrap(client.discoveredSessions.first))
            await waitUntil { client.role != nil }
        }
        let occupied = host.session?.seats.map(\.clientID)
        fourth.startBrowsing()
        fourth.join(try XCTUnwrap(fourth.discoveredSessions.first))
        await waitUntil { fourth.error == .sessionFull }
        XCTAssertNil(fourth.role)
        XCTAssertEqual(fourth.discoveredSessions.count, 1)
        XCTAssertEqual(host.session?.seats.map(\.clientID), occupied)

        let wrong = network.makePeer()
        var wrongVersionRejection: LocalPlayError?
        wrong.onEvent = { event in
            if case .received(.reject(let rejection), from: _) = event {
                wrongVersionRejection = rejection.reason
            }
        }
        wrong.connect(try XCTUnwrap(second.discoveredSessions.first))
        let hostHandle = try XCTUnwrap(wrong.connected.first)
        try await wrong.send(.hello(.init(protocolVersion: LocalPlayProtocol.version + 1,
                                          clientID: UUID(), sessionID: nil, reconnectToken: nil)),
                             to: hostHandle)
        await waitUntil { wrongVersionRejection == .versionMismatch }
        XCTAssertEqual(host.session?.seats.map(\.clientID), occupied)
    }

    func testReconnectTokenReplacesStalePeerWithoutReleasingSeat() async throws {
        let network = FakePeerNetwork()
        let host = makeCoordinator(network)
        let original = makeCoordinator(network)
        try host.startHosting()
        original.startBrowsing()
        let discovery = try XCTUnwrap(original.discoveredSessions.first)
        original.join(discovery)
        await waitUntil { original.role == .player2 }
        let seat = try XCTUnwrap(host.session?.seats.first { $0.role == .player2 })
        let token = try XCTUnwrap(seat.reconnectToken)

        let replacement = network.makePeer()
        var replacementRole: SessionRole?
        replacement.onEvent = { event in
            if case .received(.welcome(let welcome), from: _) = event {
                replacementRole = welcome.role
            }
        }
        replacement.connect(discovery)
        try await replacement.send(.hello(.init(protocolVersion: LocalPlayProtocol.version,
                                                clientID: seat.clientID,
                                                sessionID: host.sessionID,
                                                reconnectToken: token)),
                                   to: try XCTUnwrap(replacement.connected.first))
        await waitUntil { replacementRole == .player2 }
        XCTAssertEqual(original.connectionStatus, .disconnected)
        XCTAssertEqual(host.session?.seats.first { $0.role == .player2 }?.status, .connected)
        XCTAssertEqual(host.session?.seats.first { $0.role == .player2 }?.clientID, seat.clientID)
        XCTAssertEqual(host.session?.seats.count, 2)
    }

    func testDisconnectedSeatRetainsIdentityAndCanReconnect() async throws {
        let network = FakePeerNetwork()
        let host = makeCoordinator(network)
        let secondTransport = network.makePeer()
        let second = LocalPlayCoordinator(viewModel: GameViewModel(), transport: secondTransport)
        try host.startHosting()
        second.startBrowsing()
        second.join(try XCTUnwrap(second.discoveredSessions.first))
        await waitUntil { second.role == .player2 }
        let seat = try XCTUnwrap(host.session?.seats.first { $0.role == .player2 })
        XCTAssertNotNil(seat.reconnectToken)

        secondTransport.stop()
        XCTAssertFalse(host.canStartRound)
        XCTAssertEqual(host.session?.seats.first { $0.role == .player2 }?.status, .disconnected)
        second.startBrowsing()
        second.join(try XCTUnwrap(second.discoveredSessions.first))
        await waitUntil { host.session?.seats.first { $0.role == .player2 }?.status == .connected }
        XCTAssertEqual(host.session?.seats.first { $0.role == .player2 }?.clientID, seat.clientID)
        XCTAssertEqual(second.role, .player2)
    }

    private func activeGame() async throws -> (host: LocalPlayCoordinator, hostModel: GameViewModel,
                                                second: LocalPlayCoordinator, secondModel: GameViewModel,
                                                secondTransport: FakePeerTransport,
                                                third: LocalPlayCoordinator, thirdTransport: FakePeerTransport) {
        let network = FakePeerNetwork()
        let hostModel = GameViewModel(requestDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let host = LocalPlayCoordinator(viewModel: hostModel, transport: network.makePeer())
        let secondModel = GameViewModel(requestDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let secondTransport = network.makePeer()
        let second = LocalPlayCoordinator(viewModel: secondModel, transport: secondTransport)
        let thirdTransport = network.makePeer()
        let third = LocalPlayCoordinator(viewModel: GameViewModel(), transport: thirdTransport)
        try host.startHosting()
        for client in [second, third] {
            client.startBrowsing()
            client.join(try XCTUnwrap(client.discoveredSessions.first))
            await waitUntil { client.role != nil }
        }
        hostModel.selectModel(.ryb)
        hostModel.confirmSettings()
        return (host, hostModel, second, secondModel, secondTransport, third, thirdTransport)
    }

    private func input(for host: LocalPlayCoordinator, model: GameViewModel,
                       player: PlayerID, slot: ColorSlot = .primary,
                       actionID: UUID = UUID(), epoch: Int? = nil,
                       colorID: UUID? = nil, sessionID: UUID? = nil,
                       roundID: UUID? = nil) -> WireMessage {
        let assignment = model.round!.assignments[player]!
        let color = slot == .primary ? assignment.primaryColor : assignment.secondaryColor
        return .input(.init(sessionID: sessionID ?? host.sessionID!,
                            roundID: roundID ?? model.roundID!, actionID: actionID,
                            action: .addColor(slot: slot, observedColorID: colorID ?? color.id,
                                              assignmentEpoch: epoch ?? model.assignmentEpoch!)))
    }

    func testAcceptedPeerInputsAreSeatBoundAndDeduplicated() async throws {
        let game = try await activeGame()
        let secondInput = input(for: game.host, model: game.hostModel, player: .player2)
        let thirdInput = input(for: game.host, model: game.hostModel, player: .player3,
                               slot: .secondary)
        let hostHandle = try XCTUnwrap(game.secondTransport.connected.first)
        try await game.secondTransport.send(secondInput, to: hostHandle)
        try await game.thirdTransport.send(thirdInput, to: hostHandle)
        try await game.secondTransport.send(secondInput, to: hostHandle)
        XCTAssertEqual(game.hostModel.round?.mix.units.map(\.color.id), [
            game.hostModel.round!.assignments[.player2]!.primaryColor.id,
            game.hostModel.round!.assignments[.player3]!.secondaryColor.id
        ])

        // A peer cannot use a color outside its own two slots, even with a fresh action ID.
        let secondAssignment = game.hostModel.round!.assignments[.player2]!
        let otherColor = ColorData.colors(for: .ryb).first {
            $0.id != secondAssignment.primaryColor.id && $0.id != secondAssignment.secondaryColor.id
        }!
        try await game.secondTransport.send(input(for: game.host, model: game.hostModel,
                                                 player: .player2, colorID: otherColor.id), to: hostHandle)
        XCTAssertEqual(game.hostModel.round?.mix.units.count, 2)

        game.secondTransport.stop()
        try await game.thirdTransport.send(input(for: game.host, model: game.hostModel,
                                                player: .player3), to: hostHandle)
        XCTAssertEqual(game.hostModel.round?.mix.units.count, 2)
    }

    func testConcurrentPeerInputsEachReachHostExactlyOnce() async throws {
        let game = try await activeGame()
        let hostHandle = try XCTUnwrap(game.secondTransport.connected.first)
        let secondColor = game.hostModel.round!.assignments[.player2]!.primaryColor.id
        let thirdAssignment = game.hostModel.round!.assignments[.player3]!
        let thirdSlot: ColorSlot = thirdAssignment.primaryColor.id == secondColor ? .secondary : .primary
        let thirdColor = thirdSlot == .primary ? thirdAssignment.primaryColor.id : thirdAssignment.secondaryColor.id
        let secondInput = input(for: game.host, model: game.hostModel, player: .player2)
        let thirdInput = input(for: game.host, model: game.hostModel, player: .player3,
                               slot: thirdSlot)

        async let secondSend: Void = game.secondTransport.send(secondInput, to: hostHandle)
        async let thirdSend: Void = game.thirdTransport.send(thirdInput, to: hostHandle)
        try await secondSend
        try await thirdSend

        let actual = game.hostModel.round!.mix.units.map(\.color.id.uuidString).sorted()
        XCTAssertEqual(actual, [secondColor.uuidString, thirdColor.uuidString].sorted())
        try await game.secondTransport.send(secondInput, to: hostHandle)
        XCTAssertEqual(game.hostModel.round?.mix.units.count, 2)
    }

    func testInvalidContextAndLockedPhaseCannotChangeMix() async throws {
        let game = try await activeGame()
        let hostHandle = try XCTUnwrap(game.secondTransport.connected.first)
        let valid = input(for: game.host, model: game.hostModel, player: .player2)
        let invalidMessages = [
            input(for: game.host, model: game.hostModel, player: .player2, sessionID: UUID()),
            input(for: game.host, model: game.hostModel, player: .player2, roundID: UUID()),
            input(for: game.host, model: game.hostModel, player: .player2, epoch: 999),
            input(for: game.host, model: game.hostModel, player: .player2, colorID: UUID())
        ]
        for message in invalidMessages { try await game.secondTransport.send(message, to: hostHandle) }
        XCTAssertTrue(game.hostModel.round!.mix.units.isEmpty)

        try await game.secondTransport.send(valid, to: hostHandle)
        game.hostModel.pressMixButton()
        try await game.secondTransport.send(input(for: game.host, model: game.hostModel,
                                                  player: .player2), to: hostHandle)
        XCTAssertEqual(game.hostModel.round?.mix.units.count, 1)
        game.hostModel.selectFinish()
        try await game.secondTransport.send(input(for: game.host, model: game.hostModel,
                                                  player: .player2), to: hostHandle)
        XCTAssertEqual(game.hostModel.round?.mix.units.count, 1)
    }

    func testEarlierAssignmentEpochUsesColorVisibleBeforeReassignment() async throws {
        let game = try await activeGame()
        let old = input(for: game.host, model: game.hostModel, player: .player2)
        let oldColor = game.hostModel.round!.assignments[.player2]!.primaryColor.id
        game.hostModel.triggerReassignment()
        let hostHandle = try XCTUnwrap(game.secondTransport.connected.first)
        try await game.secondTransport.send(old, to: hostHandle)
        XCTAssertEqual(game.hostModel.round?.mix.units.map(\.color.id), [oldColor])
    }

    func testLocalInputsAreRestrictedToOwnTwoSlots() async throws {
        let game = try await activeGame()
        game.hostModel.addColor(player: .player2, slot: .primary)
        XCTAssertTrue(game.hostModel.round!.mix.units.isEmpty)
        game.hostModel.addColor(player: .player1, slot: .secondary)
        XCTAssertEqual(game.hostModel.round?.mix.units.map(\.color.id), [
            game.hostModel.round!.assignments[.player1]!.secondaryColor.id
        ])

        game.secondModel.applyRemoteState(game.hostModel.gameState, phase: .playing,
                                           timerSecondsRemaining: 30, reassignmentDuration: 45,
                                           showTargetColor: false, roundID: game.hostModel.roundID,
                                           assignmentEpoch: game.hostModel.assignmentEpoch)
        game.secondModel.addColor(player: .player3, slot: .primary)
        XCTAssertEqual(game.hostModel.round?.mix.units.count, 1)
        game.secondModel.addColor(player: .player2, slot: .primary)
        await waitUntil { game.hostModel.round?.mix.units.count == 2 }
        XCTAssertEqual(game.hostModel.round?.mix.units.last?.color.id,
                       game.hostModel.round?.assignments[.player2]?.primaryColor.id)
        XCTAssertEqual(game.secondModel.round?.mix.units.count, 1)
    }
}
