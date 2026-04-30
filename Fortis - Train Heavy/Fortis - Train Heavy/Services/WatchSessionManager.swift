import Foundation
import WatchConnectivity

final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()

    @Published private(set) var isReachable = false
    @Published private(set) var isPaired = false

    private let session: WCSession = .default

    private override init() {
        super.init()
        activateSession()
    }

    private func activateSession() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    func startWatchWorkout(named workoutName: String) {
        guard session.isReachable else { return }
        let message: [String: Any] = [
            WatchMessage.commandKey: WatchMessage.startWorkout,
            WatchMessage.workoutNameKey: workoutName
        ]
        session.sendMessage(message, replyHandler: nil) { error in
            debugPrint("Watch start workout error: \(error.localizedDescription)")
        }
    }

    func endWatchWorkout() {
        guard session.isReachable else { return }
        let message: [String: Any] = [WatchMessage.commandKey: WatchMessage.endWorkout]
        session.sendMessage(message, replyHandler: nil) { error in
            debugPrint("Watch end workout error: \(error.localizedDescription)")
        }
    }
}

extension WatchSessionManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            debugPrint("WCSession activation failed: \(error.localizedDescription)")
        }
        isPaired = session.isPaired
        isReachable = session.isReachable
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        isReachable = session.isReachable
    }
}
