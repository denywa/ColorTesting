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
