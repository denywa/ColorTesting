import Foundation
import Network

@MainActor
final class LocalNetworkTransport: LocalPeerTransport {
    var onEvent: (@MainActor (TransportEvent) -> Void)?

    private let queue = DispatchQueue(label: "ColorGameTesting.localNetwork")
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var endpoints: [UUID: NWEndpoint] = [:]
    private var endpointIDs: [NWEndpoint: UUID] = [:]
    private var connections: [PeerHandle: NWConnection] = [:]
    private var readyPeers: Set<PeerHandle> = []
    private var decoders: [PeerHandle: LocalMessageCodec] = [:]

    private static func parameters() -> NWParameters {
        let parameters = NWParameters.tcp
        parameters.requiredInterfaceType = .wifi
        parameters.includePeerToPeer = false
        return parameters
    }

    func host(serviceName: String) throws {
        stop()
        let listener: NWListener
        do {
            listener = try NWListener(using: Self.parameters())
        } catch {
            throw Self.map(error, fallback: .wifiUnavailable)
        }
        listener.service = NWListener.Service(name: serviceName, type: "_colorgame._tcp")
        self.listener = listener
        listener.stateUpdateHandler = { [weak self, weak listener] state in
            guard let self, let listener else { return }
            Task { @MainActor in
                guard self.listener === listener else { return }
                if case .failed(let error) = state {
                    self.onEvent?(.failure(Self.map(error, fallback: .wifiUnavailable)))
                    self.stop()
                } else if case .waiting(let error) = state {
                    self.onEvent?(.failure(Self.map(error, fallback: .wifiUnavailable)))
                    self.stop()
                }
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            Task { @MainActor in self.accept(connection) }
        }
        listener.start(queue: queue)
    }

    func browse() {
        stop()
        let browser = NWBrowser(for: .bonjour(type: "_colorgame._tcp", domain: nil), using: Self.parameters())
        self.browser = browser
        browser.stateUpdateHandler = { [weak self, weak browser] state in
            guard let self, let browser else { return }
            Task { @MainActor in
                guard self.browser === browser else { return }
                if case .failed(let error) = state {
                    self.onEvent?(.failure(Self.map(error, fallback: .sessionNotFound)))
                    self.stop()
                } else if case .waiting(let error) = state {
                    self.onEvent?(.failure(Self.map(error, fallback: .sessionNotFound)))
                    self.stop()
                }
            }
        }
        browser.browseResultsChangedHandler = { [weak self, weak browser] results, _ in
            guard let self, let browser else { return }
            Task { @MainActor in
                guard self.browser === browser else { return }
                for result in results where self.endpointIDs[result.endpoint] == nil {
                    let id = UUID()
                    self.endpointIDs[result.endpoint] = id
                    self.endpoints[id] = result.endpoint
                    guard case .service(let name, _, _, _) = result.endpoint else { continue }
                    self.onEvent?(.discovered(.init(id: id, name: name)))
                }
                let available = Set(results.map(\.endpoint))
                for endpoint in Array(self.endpointIDs.keys) where !available.contains(endpoint) {
                    if let id = self.endpointIDs.removeValue(forKey: endpoint) {
                        self.endpoints.removeValue(forKey: id)
                    }
                }
            }
        }
        browser.start(queue: queue)
    }

    func connect(_ session: DiscoveredSession) {
        guard let endpoint = endpoints[session.id] else {
            onEvent?(.failure(.sessionNotFound))
            return
        }
        for connection in connections.values { connection.cancel() }
        connections.removeAll()
        readyPeers.removeAll()
        decoders.removeAll()
        let connection = NWConnection(to: endpoint, using: Self.parameters())
        track(connection, fallback: .sessionNotFound)
    }

    func send(_ message: WireMessage, to peer: PeerHandle) async throws {
        guard let connection = connections[peer], readyPeers.contains(peer) else {
            throw LocalPlayError.disconnected
        }
        let frame = try LocalMessageCodec().encode(message)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: frame, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: Self.map(error, fallback: .disconnected))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        browser?.cancel()
        browser = nil
        for connection in connections.values { connection.cancel() }
        connections.removeAll()
        readyPeers.removeAll()
        decoders.removeAll()
        endpoints.removeAll()
        endpointIDs.removeAll()
    }

    private func accept(_ connection: NWConnection) {
        guard listener != nil, connections.count < 2 else {
            connection.cancel()
            return
        }
        track(connection, fallback: .disconnected)
    }

    private func track(_ connection: NWConnection, fallback: LocalPlayError) {
        let peer = PeerHandle(id: UUID())
        connections[peer] = connection
        decoders[peer] = LocalMessageCodec()
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            Task { @MainActor in
                guard self.connections[peer] === connection else { return }
                switch state {
                case .ready:
                    self.readyPeers.insert(peer)
                    self.onEvent?(.connected(peer))
                    if self.connections[peer] === connection {
                        self.receive(from: peer, on: connection)
                    }
                case .failed(let error):
                    self.onEvent?(.failure(Self.map(error, fallback: fallback)))
                    self.remove(peer)
                case .waiting(let error):
                    self.onEvent?(.failure(Self.map(error, fallback: fallback)))
                    self.remove(peer)
                case .cancelled:
                    self.remove(peer)
                default:
                    break
                }
            }
        }
        connection.start(queue: queue)
    }

    private func receive(from peer: PeerHandle, on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self, weak connection] data, _, isComplete, error in
            guard let self, let connection else { return }
            Task { @MainActor in
                guard self.connections[peer] === connection else { return }
                if let error {
                    self.onEvent?(.failure(Self.map(error, fallback: .disconnected)))
                    self.remove(peer)
                    return
                }
                if let data, !data.isEmpty {
                    do {
                        var decoder = self.decoders[peer] ?? LocalMessageCodec()
                        let messages = try decoder.append(data)
                        self.decoders[peer] = decoder
                        for message in messages {
                            guard self.connections[peer] === connection else { return }
                            self.onEvent?(.received(message, from: peer))
                        }
                    } catch {
                        self.onEvent?(.failure(error as? LocalPlayError ?? .invalidMessage))
                        self.remove(peer)
                        return
                    }
                }
                if isComplete {
                    self.remove(peer)
                } else {
                    self.receive(from: peer, on: connection)
                }
            }
        }
    }

    private func remove(_ peer: PeerHandle) {
        let wasReady = readyPeers.remove(peer) != nil
        decoders.removeValue(forKey: peer)
        connections.removeValue(forKey: peer)?.cancel()
        if wasReady { onEvent?(.disconnected(peer)) }
    }

    private nonisolated static func map(_ error: Error, fallback: LocalPlayError) -> LocalPlayError {
        if let error = error as? NWError {
            switch error {
            case .posix(.EACCES), .posix(.EPERM): return .permissionDenied
            case .posix(.ENETDOWN), .posix(.ENETUNREACH), .posix(.EHOSTUNREACH): return .wifiUnavailable
            case .dns(let code) where code == -65570: return .permissionDenied
            default: break
            }
        }
        return fallback
    }
}
