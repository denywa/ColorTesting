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

    private final class HoldingSnapshotTransport: LocalPeerTransport {
        var onEvent: (@MainActor (TransportEvent) -> Void)?
        let peer: FakePeerTransport
        var holdFor: PeerHandle?
        private(set) var isHolding = false
        private(set) var deliveredToHeldPeer: [GameSnapshot] = []
        private var releaseSend: CheckedContinuation<Void, Never>?
        private var failOnRelease = false

        init(peer: FakePeerTransport) {
            self.peer = peer
            peer.onEvent = { [weak self] event in self?.onEvent?(event) }
        }

        func host(serviceName: String) throws { try peer.host(serviceName: serviceName) }
        func browse() { peer.browse() }
        func connect(_ session: DiscoveredSession) { peer.connect(session) }
        func send(_ message: WireMessage, to target: PeerHandle) async throws {
            if target == holdFor, case .snapshot(let snapshot) = message {
                if !isHolding {
                    isHolding = true
                    await withCheckedContinuation { releaseSend = $0 }
                }
                if failOnRelease { throw LocalPlayError.disconnected }
                try await peer.send(message, to: target)
                deliveredToHeldPeer.append(snapshot)
            } else {
                try await peer.send(message, to: target)
            }
        }
        func holdNextSnapshot(to target: PeerHandle, failOnRelease: Bool = false) {
            holdFor = target
            isHolding = false
            self.failOnRelease = failOnRelease
        }
        func release() { releaseSend?.resume(); releaseSend = nil }
        func disconnect(_ target: PeerHandle) { peer.disconnect(target) }
        func startHeartbeats(sessionID: UUID) { peer.startHeartbeats(sessionID: sessionID) }
        func resume() { peer.resume() }
        func stop() { peer.stop() }
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
        let hostModel = GameViewModel(requestDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let host = LocalPlayCoordinator(viewModel: hostModel, transport: network.makePeer())
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
        XCTAssertFalse(host.canStartRound)
        hostModel.selectModel(.ryb)
        XCTAssertTrue(host.canStartRound)
    }

    func testHostStartSharesSettingsAndCustomTargetWithoutSavingItOnClients() async throws {
        let network = FakePeerNetwork()
        let hostDefaults = UserDefaults(suiteName: UUID().uuidString)!
        let secondDefaults = UserDefaults(suiteName: UUID().uuidString)!
        let thirdDefaults = UserDefaults(suiteName: UUID().uuidString)!
        let hostModel = GameViewModel(requestDefaults: hostDefaults)
        let secondModel = GameViewModel(requestDefaults: secondDefaults)
        let thirdModel = GameViewModel(requestDefaults: thirdDefaults)
        let host = LocalPlayCoordinator(viewModel: hostModel, transport: network.makePeer())
        let second = LocalPlayCoordinator(viewModel: secondModel, transport: network.makePeer())
        let third = LocalPlayCoordinator(viewModel: thirdModel, transport: network.makePeer())

        try host.startHosting()
        hostModel.selectModel(.cmyk)
        hostModel.reassignmentDuration = 12
        hostModel.showTargetColor = true
        XCTAssertTrue(hostModel.addCustomRequest(text: "Sea glass green", hex: "#32A89B"))
        let request = try XCTUnwrap(hostModel.customRequests.last)
        XCTAssertFalse(host.perform(.startRound))
        second.startBrowsing()
        second.join(try XCTUnwrap(second.discoveredSessions.first))
        await waitUntil { second.role == .player2 }
        XCTAssertFalse(host.perform(.startRound))
        third.startBrowsing()
        third.join(try XCTUnwrap(third.discoveredSessions.first))
        await waitUntil { third.role == .player3 }
        await waitUntil { secondModel.selectedModel == .cmyk && thirdModel.selectedModel == .cmyk }

        for client in [secondModel, thirdModel] {
            XCTAssertEqual(client.reassignmentDuration, 12)
            XCTAssertTrue(client.showTargetColor)
            client.selectedModel = .ryb
            client.selectedRequestID = ColorData.requestPool[0].id
            client.reassignmentDuration = 90
            client.showTargetColor = false
            client.confirmSettings()
            XCTAssertEqual(client.selectedModel, .cmyk)
            XCTAssertNil(client.selectedRequestID)
            XCTAssertEqual(client.reassignmentDuration, 12)
            XCTAssertTrue(client.showTargetColor)
            XCTAssertEqual(client.phase, .settings)
        }
        XCTAssertFalse(second.perform(.startRound))
        XCTAssertFalse(third.perform(.startRound))

        hostModel.selectedModel = nil
        XCTAssertFalse(host.canStartRound)
        XCTAssertFalse(host.perform(.startRound))
        hostModel.selectedModel = .cmyk
        hostModel.selectedRequestID = UUID()
        XCTAssertFalse(host.canStartRound)
        XCTAssertFalse(host.perform(.startRound))
        hostModel.selectedRequestID = request.id
        hostModel.reassignmentDuration = 0
        XCTAssertFalse(host.canStartRound)
        XCTAssertFalse(host.perform(.startRound))
        hostModel.reassignmentDuration = 12

        XCTAssertTrue(host.canStartRound)
        XCTAssertTrue(host.perform(.startRound))
        await waitUntil { secondModel.phase == .playing && thirdModel.phase == .playing }
        XCTAssertEqual(hostModel.phase, .playing)
        XCTAssertFalse(host.perform(.startRound))
        for (client, model, defaults) in [(second, secondModel, secondDefaults),
                                          (third, thirdModel, thirdDefaults)] {
            XCTAssertEqual(client.latestSnapshot?.target?.id, request.id)
            XCTAssertEqual(client.latestSnapshot?.target?.text, request.text)
            XCTAssertEqual(model.round?.request.text, "Sea glass green")
            XCTAssertEqual(model.round?.request.targetSRGB, request.targetSRGB)
            XCTAssertEqual(model.selectedModel, .cmyk)
            XCTAssertEqual(model.reassignmentDuration, 12)
            XCTAssertTrue(model.showTargetColor)
            XCTAssertTrue(model.customRequests.isEmpty)
            XCTAssertTrue(CustomRequestStore(defaults: defaults).load().isEmpty)
        }
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
        await waitUntil { transport.sent.count >= 2 }
        guard case .snapshot(let initial) = transport.sent[1] else {
            return XCTFail("Expected initial snapshot after Welcome")
        }
        XCTAssertEqual(initial.seatStatus.map(\.player), [.player1, .player2])
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

    private func joinedGame() async throws -> (host: LocalPlayCoordinator, hostModel: GameViewModel,
                                                second: LocalPlayCoordinator, secondModel: GameViewModel,
                                                secondTransport: FakePeerTransport,
                                                third: LocalPlayCoordinator, thirdModel: GameViewModel,
                                                thirdTransport: FakePeerTransport) {
        let network = FakePeerNetwork()
        let hostModel = GameViewModel(requestDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let host = LocalPlayCoordinator(viewModel: hostModel, transport: network.makePeer())
        let secondModel = GameViewModel(requestDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let secondTransport = network.makePeer()
        let second = LocalPlayCoordinator(viewModel: secondModel, transport: secondTransport)
        let thirdModel = GameViewModel(requestDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let thirdTransport = network.makePeer()
        let third = LocalPlayCoordinator(viewModel: thirdModel, transport: thirdTransport)
        try host.startHosting()
        for client in [second, third] {
            client.startBrowsing()
            client.join(try XCTUnwrap(client.discoveredSessions.first))
            await waitUntil { client.role != nil }
        }
        return (host, hostModel, second, secondModel, secondTransport, third, thirdModel, thirdTransport)
    }

    private func activeGame() async throws -> (host: LocalPlayCoordinator, hostModel: GameViewModel,
                                                second: LocalPlayCoordinator, secondModel: GameViewModel,
                                                secondTransport: FakePeerTransport,
                                                third: LocalPlayCoordinator, thirdModel: GameViewModel,
                                                thirdTransport: FakePeerTransport) {
        let game = try await joinedGame()
        game.hostModel.selectModel(.ryb)
        XCTAssertTrue(game.host.perform(.startRound))
        return game
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
        await waitUntil {
            game.second.latestSnapshot?.snapshotRevision == game.host.session?.snapshotRevision &&
            game.secondModel.phase == .playing
        }
        game.hostModel.addColor(player: .player2, slot: .primary)
        XCTAssertTrue(game.hostModel.round!.mix.units.isEmpty)
        game.hostModel.addColor(player: .player1, slot: .secondary)
        XCTAssertEqual(game.hostModel.round?.mix.units.map(\.color.id), [
            game.hostModel.round!.assignments[.player1]!.secondaryColor.id
        ])

        game.secondModel.addColor(player: .player3, slot: .primary)
        XCTAssertEqual(game.hostModel.round?.mix.units.count, 1)
        game.secondModel.addColor(player: .player2, slot: .primary)
        await waitUntil { game.hostModel.round?.mix.units.count == 2 }
        XCTAssertEqual(game.hostModel.round?.mix.units.last?.color.id,
                       game.hostModel.round?.assignments[.player2]?.primaryColor.id)
        await waitUntil { game.secondModel.round?.mix.units.count == 2 }
    }

    func testHostSnapshotsKeepThreePeersInSyncThroughInputTickAndReassignment() async throws {
        let game = try await activeGame()
        let mapper = LocalGameSnapshotMapper()
        func assertConverged() async throws {
            let host = try mapper.makeSnapshot(from: game.hostModel, session: XCTUnwrap(game.host.session))
            await waitUntil {
                game.second.latestSnapshot?.snapshotRevision == host.snapshotRevision &&
                game.third.latestSnapshot?.snapshotRevision == host.snapshotRevision
            }
            for (client, model) in [(game.second, game.secondModel), (game.third, game.thirdModel)] {
                let received = try XCTUnwrap(client.latestSnapshot)
                XCTAssertEqual(received.sessionID, host.sessionID)
                XCTAssertEqual(received.seatStatus.map(\.status), host.seatStatus.map(\.status))
                XCTAssertEqual(client.seatStatus.map(\.status), game.host.seatStatus.map(\.status))
                XCTAssertEqual(received.target?.text, host.target?.text)
                XCTAssertEqual(received.timerSecondsRemaining, host.timerSecondsRemaining)
                XCTAssertEqual(received.assignmentEpoch, host.assignmentEpoch)
                XCTAssertEqual(received.assignments.map(\.primaryColorID), host.assignments.map(\.primaryColorID))
                XCTAssertEqual(received.mixEntries.map(\.count), host.mixEntries.map(\.count))
                XCTAssertEqual(model.round?.request.text, game.hostModel.round?.request.text)
                XCTAssertEqual(model.round?.mix.units.map(\.color.id), game.hostModel.round?.mix.units.map(\.color.id))
                XCTAssertEqual(model.timerSecondsRemaining, game.hostModel.timerSecondsRemaining)
            }
        }
        try await assertConverged()
        let initialRevision = try XCTUnwrap(game.host.session?.snapshotRevision)
        try await game.secondTransport.send(input(for: game.host, model: game.hostModel, player: .player2),
                                            to: XCTUnwrap(game.secondTransport.connected.first))
        XCTAssertEqual(game.host.session?.snapshotRevision, initialRevision + 1)
        try await assertConverged()
        game.hostModel.timerTick()
        try await assertConverged()
        let mixBeforeReassignment = game.hostModel.round?.mix.units.map(\.color.id)
        game.hostModel.triggerReassignment()
        try await assertConverged()
        XCTAssertEqual(game.hostModel.round?.mix.units.map(\.color.id), mixBeforeReassignment)
        game.thirdTransport.stop()
        await waitUntil {
            game.second.latestSnapshot?.seatStatus.first { $0.player == .player3 }?.status == .disconnected
        }
        XCTAssertEqual(game.second.latestSnapshot?.snapshotRevision, game.host.session?.snapshotRevision)
        game.third.startBrowsing()
        game.third.join(try XCTUnwrap(game.third.discoveredSessions.first))
        await waitUntil {
            game.host.session?.seats.first { $0.role == .player3 }?.status == .connected
        }
        try await assertConverged()
    }

    func testClientIgnoresOldAndWrongSessionSnapshots() async throws {
        let game = try await activeGame()
        await waitUntil { game.second.latestSnapshot?.phase == .playing }
        let old = try XCTUnwrap(game.second.latestSnapshot)
        game.hostModel.timerTick()
        await waitUntil { game.second.latestSnapshot?.snapshotRevision == game.host.session?.snapshotRevision }
        let currentRevision = try XCTUnwrap(game.second.latestSnapshot?.snapshotRevision)
        let currentSeconds = game.secondModel.timerSecondsRemaining
        let hostHandle = try XCTUnwrap(game.secondTransport.connected.first)
        game.second.handle(.received(.snapshot(old), from: hostHandle))
        let hostSession = try XCTUnwrap(game.host.session)
        let alienSession = try SessionState(sessionID: UUID(), seats: hostSession.seats,
                                            paused: hostSession.paused,
                                            snapshotRevision: currentRevision + 1)
        let wrongSession = try LocalGameSnapshotMapper().makeSnapshot(from: game.hostModel, session: alienSession)
        game.second.handle(.received(.snapshot(wrongSession), from: hostHandle))
        XCTAssertEqual(game.second.latestSnapshot?.snapshotRevision, currentRevision)
        XCTAssertEqual(game.secondModel.timerSecondsRemaining, currentSeconds)
    }

    func testPhaseAndPauseChangesBroadcastFullSnapshots() async throws {
        let game = try await activeGame()
        await waitUntil { game.second.latestSnapshot?.phase == .playing && game.third.latestSnapshot?.phase == .playing }
        game.host.setPaused(true)
        await waitUntil { game.second.latestSnapshot?.paused == true && game.third.latestSnapshot?.paused == true }
        XCTAssertTrue(game.second.paused)
        XCTAssertTrue(game.third.paused)
        XCTAssertEqual(game.second.latestSnapshot?.snapshotRevision, game.host.session?.snapshotRevision)
        game.host.setPaused(false)
        await waitUntil { game.second.latestSnapshot?.paused == false && game.third.latestSnapshot?.paused == false }

        game.hostModel.addColor(player: .player1, slot: .primary)
        await waitUntil { game.secondModel.round?.mix.units.count == 1 && game.thirdModel.round?.mix.units.count == 1 }
        game.hostModel.pressMixButton()
        await waitUntil { game.secondModel.phase == .result && game.thirdModel.phase == .result }
        XCTAssertEqual(game.second.latestSnapshot?.mixLocked, true)
        XCTAssertEqual(game.second.latestSnapshot?.mixResult?.red, game.third.latestSnapshot?.mixResult?.red)
        game.hostModel.selectFinish()
        await waitUntil { game.secondModel.phase == .score && game.thirdModel.phase == .score }
        XCTAssertEqual(game.secondModel.score, game.hostModel.score)
        XCTAssertEqual(game.thirdModel.score, game.hostModel.score)
        game.hostModel.startNewRound()
        await waitUntil { game.secondModel.phase == .settings && game.thirdModel.phase == .settings }
        XCTAssertEqual(game.second.latestSnapshot?.seatStatus.count, 3)
    }

    func testHostDrivesSharedMixRedoFinishAndNewRound() async throws {
        let game = try await joinedGame()
        let mapper = LocalGameSnapshotMapper()
        func assertConverged(_ phase: GamePhase) async throws {
            let host = try mapper.makeSnapshot(from: game.hostModel, session: XCTUnwrap(game.host.session))
            await waitUntil {
                game.second.latestSnapshot?.snapshotRevision == host.snapshotRevision &&
                game.third.latestSnapshot?.snapshotRevision == host.snapshotRevision
            }
            XCTAssertEqual(host.phase, phase)
            XCTAssertEqual(game.hostModel.phase, phase)
            for (client, model, role) in [(game.second, game.secondModel, SessionRole.player2),
                                          (game.third, game.thirdModel, SessionRole.player3)] {
                let received = try XCTUnwrap(client.latestSnapshot)
                XCTAssertEqual(client.role, role)
                XCTAssertEqual(client.sessionID, host.sessionID)
                XCTAssertEqual(received.phase, host.phase)
                XCTAssertEqual(received.roundID, host.roundID)
                XCTAssertEqual(received.target?.id, host.target?.id)
                XCTAssertEqual(received.target?.text, host.target?.text)
                XCTAssertEqual(received.target?.sRGB.red, host.target?.sRGB.red)
                XCTAssertEqual(received.target?.sRGB.green, host.target?.sRGB.green)
                XCTAssertEqual(received.target?.sRGB.blue, host.target?.sRGB.blue)
                XCTAssertEqual(received.timerSecondsRemaining, host.timerSecondsRemaining)
                XCTAssertEqual(received.mixEntries.map(\.colorID), host.mixEntries.map(\.colorID))
                XCTAssertEqual(received.mixEntries.map(\.count), host.mixEntries.map(\.count))
                XCTAssertEqual(received.mixLocked, host.mixLocked)
                XCTAssertEqual(received.mixResult?.red, host.mixResult?.red)
                XCTAssertEqual(received.mixResult?.green, host.mixResult?.green)
                XCTAssertEqual(received.mixResult?.blue, host.mixResult?.blue)
                XCTAssertEqual(received.score, host.score)
                XCTAssertEqual(received.seatStatus.map(\.player), host.seatStatus.map(\.player))
                XCTAssertEqual(received.seatStatus.map(\.status), host.seatStatus.map(\.status))
                XCTAssertEqual(model.phase, game.hostModel.phase)
                XCTAssertEqual(model.round?.request.id, game.hostModel.round?.request.id)
                XCTAssertEqual(model.timerSecondsRemaining, game.hostModel.timerSecondsRemaining)
                XCTAssertEqual(model.round?.mix.units.map(\.color.id), game.hostModel.round?.mix.units.map(\.color.id))
                XCTAssertEqual(model.mixResult, game.hostModel.mixResult)
                XCTAssertEqual(model.score, game.hostModel.score)
                XCTAssertEqual(client.seatStatus.map(\.status), game.host.seatStatus.map(\.status))
            }
        }
        try await assertConverged(.settings)
        game.hostModel.selectModel(.ryb)
        XCTAssertTrue(game.hostModel.addCustomRequest(text: "Session target", hex: "#32A89B"))
        let customTarget = try XCTUnwrap(game.hostModel.customRequests.last)
        XCTAssertEqual(game.hostModel.selectedRequestID, customTarget.id)
        try await assertConverged(.settings)
        XCTAssertTrue(game.host.perform(.startRound))
        try await assertConverged(.playing)
        XCTAssertEqual(game.hostModel.round?.request.id, customTarget.id)
        game.hostModel.timerTick()
        try await assertConverged(.playing)
        let sessionID = game.host.sessionID
        let roundID = game.hostModel.roundID
        let target = game.hostModel.round?.request.id
        let assignments = game.hostModel.round?.assignments
        let remaining = game.hostModel.timerSecondsRemaining
        let originalSeats = game.host.session?.seats.map(\.clientID)

        XCTAssertFalse(game.host.perform(.mix))
        XCTAssertFalse(game.second.perform(.mix))
        XCTAssertFalse(game.third.perform(.finish))
        game.hostModel.addColor(player: .player1, slot: .primary)
        try await assertConverged(.playing)
        game.secondModel.addColor(player: .player2, slot: .secondary)
        await waitUntil { game.hostModel.round?.mix.units.count == 2 }
        try await assertConverged(.playing)
        game.thirdModel.addColor(player: .player3, slot: .primary)
        await waitUntil { game.hostModel.round?.mix.units.count == 3 }
        try await assertConverged(.playing)
        XCTAssertTrue(game.host.perform(.mix))
        await waitUntil { game.secondModel.phase == .result && game.thirdModel.phase == .result }
        try await assertConverged(.result)
        XCTAssertEqual(game.hostModel.phase, .result)
        XCTAssertTrue(game.hostModel.round?.mix.isLocked == true)
        XCTAssertNotNil(game.hostModel.mixResult)
        XCTAssertEqual(game.secondModel.round?.mix.units.map(\.color.id), game.hostModel.round?.mix.units.map(\.color.id))
        XCTAssertEqual(game.thirdModel.round?.mix.units.map(\.color.id), game.hostModel.round?.mix.units.map(\.color.id))
        XCTAssertEqual(game.secondModel.mixResult, game.hostModel.mixResult)
        XCTAssertEqual(game.thirdModel.mixResult, game.hostModel.mixResult)
        XCTAssertEqual(game.secondModel.timerSecondsRemaining, remaining)
        XCTAssertFalse(game.second.perform(.redo))
        XCTAssertFalse(game.third.perform(.finish))
        XCTAssertFalse(game.host.perform(.mix))

        XCTAssertTrue(game.host.perform(.redo))
        await waitUntil { game.secondModel.phase == .playing && game.thirdModel.phase == .playing }
        try await assertConverged(.playing)
        XCTAssertTrue(game.hostModel.round?.mix.units.isEmpty == true)
        XCTAssertNil(game.hostModel.mixResult)
        XCTAssertTrue(game.secondModel.round?.mix.units.isEmpty == true)
        XCTAssertTrue(game.thirdModel.round?.mix.units.isEmpty == true)
        XCTAssertNil(game.secondModel.mixResult)
        XCTAssertNil(game.thirdModel.mixResult)
        XCTAssertEqual(game.hostModel.round?.request.id, target)
        XCTAssertEqual(game.hostModel.round?.assignments.mapValues { [$0.primaryColor.id, $0.secondaryColor.id] },
                       assignments?.mapValues { [$0.primaryColor.id, $0.secondaryColor.id] })
        XCTAssertEqual(game.hostModel.timerSecondsRemaining, remaining)
        XCTAssertEqual(game.secondModel.roundID, roundID)
        XCTAssertFalse(game.host.perform(.redo))

        let reusedActionID = UUID()
        let hostHandle = try XCTUnwrap(game.secondTransport.connected.first)
        try await game.secondTransport.send(input(for: game.host, model: game.hostModel,
                                                 player: .player2, actionID: reusedActionID), to: hostHandle)
        await waitUntil { game.hostModel.round?.mix.units.count == 1 }
        try await assertConverged(.playing)
        XCTAssertTrue(game.host.perform(.mix))
        await waitUntil { game.secondModel.phase == .result && game.thirdModel.phase == .result }
        try await assertConverged(.result)
        XCTAssertTrue(game.host.perform(.finish))
        await waitUntil { game.secondModel.phase == .score && game.thirdModel.phase == .score }
        try await assertConverged(.score)
        XCTAssertNotNil(game.hostModel.score)
        XCTAssertEqual(game.secondModel.score, game.hostModel.score)
        XCTAssertEqual(game.thirdModel.score, game.hostModel.score)
        XCTAssertFalse(game.second.perform(.newRound))
        XCTAssertFalse(game.third.perform(.newRound))
        XCTAssertFalse(game.host.perform(.finish))

        XCTAssertTrue(game.host.perform(.newRound))
        await waitUntil { game.secondModel.phase == .settings && game.thirdModel.phase == .settings }
        try await assertConverged(.settings)
        XCTAssertEqual(game.host.sessionID, sessionID)
        XCTAssertEqual(game.host.session?.seats.map(\.clientID), originalSeats)
        XCTAssertEqual(game.hostModel.phase, .settings)
        XCTAssertNil(game.hostModel.round)
        XCTAssertNil(game.secondModel.round)
        XCTAssertNil(game.thirdModel.round)
        XCTAssertEqual(game.second.latestSnapshot?.snapshotRevision, game.host.session?.snapshotRevision)
        game.hostModel.selectModel(.ryb)
        XCTAssertTrue(game.host.perform(.startRound))
        await waitUntil { game.secondModel.phase == .playing && game.thirdModel.phase == .playing }
        try await assertConverged(.playing)
        XCTAssertNotEqual(game.hostModel.roundID, roundID)
        try await game.secondTransport.send(input(for: game.host, model: game.hostModel,
                                                 player: .player2, actionID: reusedActionID), to: hostHandle)
        await waitUntil { game.hostModel.round?.mix.units.count == 1 }
        try await assertConverged(.playing)
    }

    func testHostPhaseActionsRequireActiveSeatsAndUnpausedMatchingPhase() async throws {
        let game = try await activeGame()
        XCTAssertFalse(game.host.perform(.redo))
        XCTAssertFalse(game.host.perform(.finish))
        XCTAssertFalse(game.host.perform(.newRound))
        game.hostModel.addColor(player: .player1, slot: .primary)
        game.host.setPaused(true)
        XCTAssertFalse(game.host.perform(.mix))
        game.host.setPaused(false)
        game.thirdTransport.stop()
        XCTAssertFalse(game.host.perform(.mix))
    }

    func testDisconnectPausesAndReconnectRestoresSameRound() async throws {
        let game = try await activeGame()
        game.hostModel.addColor(player: .player1, slot: .primary)
        await waitUntil { game.thirdModel.round?.mix.units.count == 1 }
        let roundID = game.hostModel.roundID
        let assignments = game.hostModel.round?.assignments
        let remaining = game.hostModel.timerSecondsRemaining
        let mix = game.hostModel.round?.mix.units.map(\.color.id)
        let seatID = game.host.session?.seats.first { $0.role == .player2 }?.clientID
        game.secondTransport.stop()

        XCTAssertTrue(game.host.paused)
        XCTAssertEqual(game.host.seatStatus.first { $0.player == .player2 }?.status, .disconnected)
        await waitUntil { game.third.latestSnapshot?.paused == true }
        game.host.setPaused(false)
        XCTAssertTrue(game.host.paused)
        XCTAssertTrue(game.second.paused)
        XCTAssertFalse(game.host.perform(.mix))
        XCTAssertFalse(game.second.perform(.addColor(slot: .primary,
            observedColorID: game.secondModel.round!.assignments[.player2]!.primaryColor.id,
            assignmentEpoch: game.secondModel.assignmentEpoch!)))
        XCTAssertFalse(game.third.perform(.addColor(slot: .primary,
            observedColorID: game.thirdModel.round!.assignments[.player3]!.primaryColor.id,
            assignmentEpoch: game.thirdModel.assignmentEpoch!)))
        XCTAssertEqual(game.hostModel.round?.mix.units.map(\.color.id), mix)
        XCTAssertEqual(game.hostModel.timerSecondsRemaining, remaining)

        game.second.startBrowsing()
        game.second.join(try XCTUnwrap(game.second.discoveredSessions.first))
        await waitUntil { game.second.connectionStatus == .connected && game.second.latestSnapshot?.paused == false }
        XCTAssertEqual(game.host.session?.seats.first { $0.role == .player2 }?.clientID, seatID)
        XCTAssertEqual(game.second.role, .player2)
        XCTAssertFalse(game.host.paused)
        XCTAssertEqual(game.secondModel.roundID, roundID)
        XCTAssertEqual(game.secondModel.round?.assignments.mapValues { [$0.primaryColor.id, $0.secondaryColor.id] },
                       assignments?.mapValues { [$0.primaryColor.id, $0.secondaryColor.id] })
        XCTAssertEqual(game.secondModel.round?.mix.units.map(\.color.id), mix)
        XCTAssertEqual(game.secondModel.timerSecondsRemaining, remaining)
    }

    func testBackgroundPauseFlushesSnapshotAndRequiresForeground() async throws {
        let game = try await activeGame()
        let remaining = game.hostModel.timerSecondsRemaining
        await game.host.hostDidEnterBackground()
        XCTAssertTrue(game.host.paused)
        XCTAssertTrue(game.second.latestSnapshot?.paused == true)
        XCTAssertTrue(game.third.latestSnapshot?.paused == true)
        XCTAssertEqual(game.second.latestSnapshot?.snapshotRevision, game.host.session?.snapshotRevision)
        game.host.setPaused(false)
        XCTAssertTrue(game.host.paused)
        XCTAssertFalse(game.host.perform(.mix))
        XCTAssertEqual(game.hostModel.timerSecondsRemaining, remaining)
        game.secondTransport.stop()
        game.second.startBrowsing()
        game.second.join(try XCTUnwrap(game.second.discoveredSessions.first))
        await waitUntil { game.host.seatStatus.first { $0.player == .player2 }?.status == .connected }
        XCTAssertTrue(game.host.paused)
        await waitUntil { game.second.latestSnapshot?.paused == true }
        game.host.appDidBecomeActive()
        await waitUntil { game.second.latestSnapshot?.paused == false && game.third.latestSnapshot?.paused == false }
        XCTAssertFalse(game.host.paused)
        XCTAssertEqual(game.hostModel.timerSecondsRemaining, remaining)
    }

    func testReconnectWaitsForFullSnapshotDeliveryBeforeHostResumes() async throws {
        let network = FakePeerNetwork()
        let hostModel = GameViewModel(requestDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let hostTransport = HoldingSnapshotTransport(peer: network.makePeer())
        let host = LocalPlayCoordinator(viewModel: hostModel, transport: hostTransport)
        let secondModel = GameViewModel(requestDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let secondTransport = network.makePeer()
        let second = LocalPlayCoordinator(viewModel: secondModel, transport: secondTransport)
        let third = makeCoordinator(network)
        try host.startHosting()
        for client in [second, third] {
            client.startBrowsing()
            client.join(try XCTUnwrap(client.discoveredSessions.first))
            await waitUntil { client.role != nil }
        }
        hostModel.selectModel(.ryb)
        XCTAssertTrue(host.perform(.startRound))
        hostModel.addColor(player: .player1, slot: .primary)
        await waitUntil { second.latestSnapshot?.snapshotRevision == host.session?.snapshotRevision }
        let roundID = hostModel.roundID
        let mix = hostModel.round?.mix.units.map(\.color.id)
        let remaining = hostModel.timerSecondsRemaining
        secondTransport.stop()
        XCTAssertTrue(host.paused)
        hostTransport.holdNextSnapshot(to: secondTransport.handle)
        second.startBrowsing()
        second.join(try XCTUnwrap(second.discoveredSessions.first))
        await waitUntil { hostTransport.isHolding }

        XCTAssertTrue(host.paused)
        XCTAssertFalse(host.perform(.mix))
        XCTAssertEqual(hostModel.timerSecondsRemaining, remaining)
        XCTAssertEqual(hostModel.round?.mix.units.map(\.color.id), mix)
        hostTransport.release()
        await waitUntil { !host.paused && second.latestSnapshot?.paused == false }
        XCTAssertEqual(hostTransport.deliveredToHeldPeer.first?.paused, true)
        XCTAssertEqual(secondModel.roundID, roundID)
        XCTAssertEqual(secondModel.round?.mix.units.map(\.color.id), mix)
        XCTAssertEqual(secondModel.timerSecondsRemaining, remaining)

        secondTransport.stop()
        hostTransport.holdNextSnapshot(to: secondTransport.handle, failOnRelease: true)
        second.startBrowsing()
        second.join(try XCTUnwrap(second.discoveredSessions.first))
        await waitUntil { hostTransport.isHolding }
        hostTransport.release()
        await waitUntil { host.seatStatus.first { $0.player == .player2 }?.status == .disconnected }
        XCTAssertTrue(host.paused)
        hostTransport.holdFor = nil
        second.startBrowsing()
        second.join(try XCTUnwrap(second.discoveredSessions.first))
        await waitUntil { !host.paused && second.latestSnapshot?.paused == false }
        XCTAssertEqual(secondModel.roundID, roundID)
        XCTAssertEqual(secondModel.round?.mix.units.map(\.color.id), mix)
    }

    func testHostEndNotifiesClientsAndClearsRoundAndSession() async throws {
        let network = FakePeerNetwork()
        let hostModel = GameViewModel(requestDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let hostTransport = network.makePeer()
        let host = LocalPlayCoordinator(viewModel: hostModel, transport: hostTransport)
        let second = makeCoordinator(network)
        let third = makeCoordinator(network)
        try host.startHosting()
        for client in [second, third] {
            client.startBrowsing()
            client.join(try XCTUnwrap(client.discoveredSessions.first))
            await waitUntil { client.role != nil && client.latestSnapshot != nil }
        }
        hostModel.selectModel(.ryb)
        XCTAssertTrue(host.perform(.startRound))

        await host.leaveSession()
        await waitUntil { second.mode == .singleDevice && third.mode == .singleDevice }
        for coordinator in [host, second, third] {
            XCTAssertEqual(coordinator.mode, .singleDevice)
            XCTAssertNil(coordinator.role)
            XCTAssertNil(coordinator.sessionID)
            XCTAssertNil(coordinator.session)
            XCTAssertNil(coordinator.latestSnapshot)
            XCTAssertTrue(coordinator.seatStatus.isEmpty)
        }
        XCTAssertEqual(hostModel.phase, .settings)
        XCTAssertNil(hostModel.round)
        XCTAssertNil(hostModel.roundID)
        XCTAssertTrue(hostTransport.connected.isEmpty)
        XCTAssertFalse(host.perform(.startRound))
        XCTAssertTrue(second.discoveredSessions.isEmpty)
    }

    func testDisconnectedClientCanLeaveWithoutHostAndCannotResumeOldSession() async throws {
        let game = try await activeGame()
        game.secondTransport.stop()
        XCTAssertEqual(game.second.connectionStatus, .disconnected)
        XCTAssertTrue(game.second.paused)

        await game.second.leaveSession()
        XCTAssertEqual(game.second.mode, .singleDevice)
        XCTAssertNil(game.second.role)
        XCTAssertNil(game.second.sessionID)
        XCTAssertNil(game.second.latestSnapshot)
        XCTAssertEqual(game.secondModel.phase, .settings)
        XCTAssertNil(game.secondModel.roundID)
        XCTAssertFalse(game.second.paused)
        game.second.startBrowsing()
        game.second.join(try XCTUnwrap(game.second.discoveredSessions.first))
        await waitUntil { game.second.error == .sessionFull }
        XCTAssertNil(game.second.role)
        XCTAssertNil(game.second.sessionID)
    }

    func testHostEndWaitsForQueuedSnapshotBeforeClosingTransport() async throws {
        let network = FakePeerNetwork()
        let hostModel = GameViewModel(requestDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let hostTransport = HoldingSnapshotTransport(peer: network.makePeer())
        let host = LocalPlayCoordinator(viewModel: hostModel, transport: hostTransport)
        let secondTransport = network.makePeer()
        let second = LocalPlayCoordinator(viewModel: GameViewModel(requestDefaults: UserDefaults(suiteName: UUID().uuidString)!),
                                          transport: secondTransport)
        let third = makeCoordinator(network)
        try host.startHosting()
        for client in [second, third] {
            client.startBrowsing()
            client.join(try XCTUnwrap(client.discoveredSessions.first))
            await waitUntil { client.role != nil && client.latestSnapshot != nil }
        }
        hostModel.selectModel(.ryb)
        XCTAssertTrue(host.perform(.startRound))
        hostTransport.holdNextSnapshot(to: secondTransport.handle)
        hostModel.addColor(player: .player1, slot: .primary)
        await waitUntil { hostTransport.isHolding }

        let ending = Task { await host.leaveSession() }
        await Task.yield()
        XCTAssertEqual(second.role, .player2)
        XCTAssertFalse(hostTransport.peer.connected.isEmpty)
        hostTransport.release()
        await ending.value
        await waitUntil { second.role == nil && third.role == nil }
        XCTAssertTrue(hostTransport.peer.connected.isEmpty)
        XCTAssertNil(host.sessionID)
    }

    func testAppTerminationDiscardsTemporarySessionWithoutSendingEnd() throws {
        let network = FakePeerNetwork()
        let hostModel = GameViewModel(requestDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let hostTransport = network.makePeer()
        let host = LocalPlayCoordinator(viewModel: hostModel, transport: hostTransport)
        try host.startHosting()
        let oldSessionID = host.sessionID

        host.appWillTerminate()
        XCTAssertEqual(host.mode, .singleDevice)
        XCTAssertNil(host.sessionID)
        XCTAssertNil(host.session)
        XCTAssertNil(hostModel.roundID)
        let probe = makeCoordinator(network)
        probe.startBrowsing()
        XCTAssertTrue(probe.discoveredSessions.isEmpty)
        try host.startHosting()
        XCTAssertNotEqual(host.sessionID, oldSessionID)
    }
}
