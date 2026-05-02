import Combine
import Network
import Foundation

/// Observes device connectivity and fires `onReconnect` when the device
/// transitions from offline → online. Consumers use this to flush any
/// pending cloud sync work.
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue   = DispatchQueue(label: "com.fortis.network", qos: .utility)

    @Published private(set) var isConnected = true

    /// Called on the main thread whenever connectivity is restored.
    var onReconnect: (() -> Void)?

    private var previouslyConnected = true

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            DispatchQueue.main.async {
                guard let self else { return }
                if !self.previouslyConnected && connected {
                    self.onReconnect?()
                }
                self.previouslyConnected = connected
                self.isConnected = connected
            }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}
