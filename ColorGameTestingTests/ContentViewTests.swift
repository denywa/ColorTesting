import AppKit
import SwiftUI
import XCTest
@testable import ColorGameTesting

@MainActor
final class ContentViewTests: XCTestCase {
    func testAppRootInitiallyRendersModeSelection() throws {
        let appRoot = try renderedPixels(of: ContentView())
        let expectedSelection = try renderedPixels(of: ModeSelectionView(onSelect: { _ in }))

        XCTAssertEqual(appRoot, expectedSelection,
                       "A new app window must show mode selection")
    }

    func testSoloRouteKeepsNetworkIdleAndShowsSettings() throws {
        let model = GameViewModel()
        let transport = FakePeerNetwork().makePeer()
        let coordinator = LocalPlayCoordinator(viewModel: model, transport: transport)
        let content = ContentView(viewModel: model, coordinator: coordinator,
                                  selectedMode: .singleDevice)

        XCTAssertNotEqual(try renderedPixels(of: content),
                          try renderedPixels(of: ModeSelectionView(onSelect: { _ in })))
        XCTAssertTrue(transport.connected.isEmpty)
        XCTAssertNil(coordinator.sessionID)
        XCTAssertEqual(model.phase, .settings)
        content.handleScenePhaseChange(.inactive)
        content.handleScenePhaseChange(.active)
        XCTAssertEqual(transport.resumeCount, 0)
    }

    func testThreeDeviceRouteShowsLobbyThenHostSettingsAndGuestStatus() async throws {
        let network = FakePeerNetwork()
        let hostModel = GameViewModel()
        let host = LocalPlayCoordinator(viewModel: hostModel, transport: network.makePeer())
        let guestModel = GameViewModel()
        let guest = LocalPlayCoordinator(viewModel: guestModel, transport: network.makePeer())

        let waiting = try renderedPixels(of: ContentView(viewModel: hostModel,
            coordinator: host, selectedMode: .threeDevices))
        XCTAssertEqual(waiting, try renderedPixels(of: LocalLobbyView(coordinator: host)))

        try host.startHosting()
        let hosting = try renderedPixels(of: ContentView(viewModel: hostModel,
            coordinator: host, selectedMode: .threeDevices))
        XCTAssertNotEqual(hosting, try renderedPixels(of: LocalLobbyView(coordinator: host)),
                          "Host must see settings below the lobby seats")

        guest.startBrowsing()
        guest.join(try XCTUnwrap(guest.discoveredSessions.first))
        for _ in 0..<100 where guest.role == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(guest.role, .player2)
        XCTAssertEqual(try renderedPixels(of: ContentView(viewModel: guestModel,
            coordinator: guest, selectedMode: .threeDevices)),
            try renderedPixels(of: LocalLobbyView(coordinator: guest)))
    }

    func testEndingLocalSessionReturnsLiveRootToModeSelection() async throws {
        let model = GameViewModel()
        let transport = FakePeerNetwork().makePeer()
        let coordinator = LocalPlayCoordinator(viewModel: model, transport: transport)
        try coordinator.startHosting()
        let hostingView = NSHostingView(rootView: ContentView(viewModel: model,
            coordinator: coordinator, selectedMode: .threeDevices))
        hostingView.frame = NSRect(x: 0, y: 0, width: 720, height: 600)
        hostingView.layoutSubtreeIfNeeded()

        await coordinator.leaveSession()
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(try renderedPixels(of: hostingView),
                       try renderedPixels(of: ModeSelectionView(onSelect: { _ in })))
        XCTAssertNil(coordinator.sessionID)
        XCTAssertNil(model.round)
        XCTAssertEqual(model.phase, .settings)
    }

    func testActiveLocalPhasesShowSessionExitControl() throws {
        let model = GameViewModel()
        let coordinator = LocalPlayCoordinator(viewModel: model,
                                               transport: FakePeerNetwork().makePeer())
        try coordinator.startHosting()
        let content = ContentView(viewModel: model, coordinator: coordinator,
                                  selectedMode: .threeDevices)
        XCTAssertEqual(content.localSessionExitTitle, "End Session")

        for phase in [GamePhase.playing, .result, .score] {
            model.phase = phase
            let phaseOnly: Data = switch phase {
            case .playing: try renderedPixels(of: GameView(viewModel: model, coordinator: coordinator))
            case .result: try renderedPixels(of: ResultView(viewModel: model, coordinator: coordinator))
            case .score: try renderedPixels(of: ScoreView(viewModel: model, coordinator: coordinator))
            case .settings: try renderedPixels(of: SettingsView(viewModel: model, coordinator: coordinator))
            }
            XCTAssertNotEqual(try renderedPixels(of: content),
                              phaseOnly,
                              "The \(phase) phase must display a session exit control")
        }
    }

    func testGuestSessionExitUsesLeaveLabel() async throws {
        let network = FakePeerNetwork()
        let host = LocalPlayCoordinator(viewModel: GameViewModel(), transport: network.makePeer())
        let guestModel = GameViewModel()
        let guest = LocalPlayCoordinator(viewModel: guestModel, transport: network.makePeer())
        try host.startHosting()
        guest.startBrowsing()
        guest.join(try XCTUnwrap(guest.discoveredSessions.first))
        for _ in 0..<100 where guest.role == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(guest.role, .player2)
        XCTAssertEqual(ContentView(viewModel: guestModel, coordinator: guest,
                                   selectedMode: .threeDevices).localSessionExitTitle,
                       "Leave Session")
    }

    func testSceneLifecyclePausesHostAndRecoversExistingSeats() async throws {
        let network = FakePeerNetwork()
        let hostModel = GameViewModel()
        let hostTransport = network.makePeer()
        let host = LocalPlayCoordinator(viewModel: hostModel, transport: hostTransport)
        let secondModel = GameViewModel()
        let secondTransport = network.makePeer()
        let second = LocalPlayCoordinator(viewModel: secondModel, transport: secondTransport)
        let third = LocalPlayCoordinator(viewModel: GameViewModel(), transport: network.makePeer())

        try host.startHosting()
        for client in [second, third] {
            client.startBrowsing()
            client.join(try XCTUnwrap(client.discoveredSessions.first))
            for _ in 0..<100 where client.role == nil {
                try await Task.sleep(for: .milliseconds(10))
            }
        }
        XCTAssertEqual(second.role, .player2)
        hostModel.selectModel(.ryb)
        XCTAssertTrue(host.perform(.startRound))
        let roundID = hostModel.roundID
        let remaining = hostModel.timerSecondsRemaining
        let secondSeatID = host.session?.seats.first { $0.role == .player2 }?.clientID
        let hostContent = ContentView(viewModel: hostModel, coordinator: host,
                                      selectedMode: .threeDevices)
        let secondContent = ContentView(viewModel: secondModel, coordinator: second,
                                        selectedMode: .threeDevices)
        let hostView = NSHostingView(rootView: hostContent.environment(\.scenePhase, .active))
        let secondView = NSHostingView(rootView: secondContent.environment(\.scenePhase, .background))
        hostView.frame = NSRect(x: 0, y: 0, width: 720, height: 600)
        secondView.frame = hostView.frame
        hostView.layoutSubtreeIfNeeded()
        secondView.layoutSubtreeIfNeeded()

        hostView.rootView = hostContent.environment(\.scenePhase, .inactive)
        hostView.layoutSubtreeIfNeeded()
        XCTAssertTrue(host.paused, "The host timer must pause before asynchronous snapshot delivery")
        XCTAssertEqual(hostModel.timerSecondsRemaining, remaining)
        hostView.rootView = hostContent.environment(\.scenePhase, .background)
        hostView.layoutSubtreeIfNeeded()
        for _ in 0..<100 where second.latestSnapshot?.paused != true {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(second.paused)

        secondTransport.stop()
        hostView.rootView = hostContent.environment(\.scenePhase, .active)
        hostView.layoutSubtreeIfNeeded()
        XCTAssertTrue(host.paused, "The host must wait for the disconnected seat")
        XCTAssertEqual(hostModel.timerSecondsRemaining, remaining)
        secondView.rootView = secondContent.environment(\.scenePhase, .active)
        secondView.layoutSubtreeIfNeeded()
        XCTAssertEqual(secondTransport.resumeCount, 1)
        XCTAssertEqual(second.role, .player2)
        second.startBrowsing()
        second.join(try XCTUnwrap(second.discoveredSessions.first))
        for _ in 0..<100 where host.paused || second.paused {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertFalse(host.paused)
        XCTAssertFalse(second.paused)
        XCTAssertEqual(second.role, .player2)
        XCTAssertEqual(host.session?.seats.first { $0.role == .player2 }?.clientID, secondSeatID)
        XCTAssertEqual(hostModel.roundID, roundID)
        XCTAssertEqual(secondModel.roundID, roundID)
        XCTAssertEqual(hostModel.timerSecondsRemaining, remaining)
        XCTAssertEqual(secondModel.timerSecondsRemaining, remaining)
    }

    private func renderedPixels<Content: View>(of content: Content) throws -> Data {
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(x: 0, y: 0, width: 720, height: 600)
        return try renderedPixels(of: hostingView)
    }

    private func renderedPixels<Content: View>(of hostingView: NSHostingView<Content>) throws -> Data {
        hostingView.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }
}
