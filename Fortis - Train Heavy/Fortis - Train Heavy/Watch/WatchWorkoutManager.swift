#if os(watchOS)
import Foundation
import SwiftUI
import WatchConnectivity
import HealthKit

final class WatchWorkoutManager: NSObject, ObservableObject {
    static let shared = WatchWorkoutManager()

    @Published private(set) var isWorkoutActive = false
    @Published private(set) var currentHeartRate: Double = 0

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

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

    private func requestHealthKitAuthorization() {
        let read: Set = [HKObjectType.quantityType(forIdentifier: .heartRate)!]
        let share: Set = [HKObjectType.workoutType()]
        healthStore.requestAuthorization(toShare: share, read: read) { success, error in
            if let error {
                debugPrint("HealthKit auth failed: \(error.localizedDescription)")
            }
        }
    }

    func handleIncomingMessage(_ message: [String: Any]) {
        guard let command = message[WatchMessage.commandKey] as? String else { return }
        switch command {
        case WatchMessage.startWorkout:
            let workoutName = message[WatchMessage.workoutNameKey] as? String ?? "Strength Training"
            startWorkout(named: workoutName)
        case WatchMessage.endWorkout:
            endWorkout()
        default:
            break
        }
    }

    private func startWorkout(named workoutName: String) {
        guard !isWorkoutActive else { return }
        guard HKHealthStore.isHealthDataAvailable() else { return }
        requestHealthKitAuthorization()

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = workoutSession?.associatedWorkoutBuilder()

            workoutSession?.delegate = self
            builder?.delegate = self
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

            builder?.beginCollection(at: Date()) { _, error in
                if let error {
                    debugPrint("Workout builder begin failed: \(error.localizedDescription)")
                }
            }

            workoutSession?.startActivity(with: Date())
            isWorkoutActive = true
        } catch {
            debugPrint("Failed to start watch workout: \(error.localizedDescription)")
        }
    }

    private func endWorkout() {
        guard isWorkoutActive else { return }
        workoutSession?.stopActivity(with: Date())
        workoutSession?.end()
        isWorkoutActive = false
    }
}

extension WatchWorkoutManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            debugPrint("Watch WCSession activation failed: \(error.localizedDescription)")
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.handleIncomingMessage(message)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}

extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {}
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        debugPrint("Workout session failed: \(error.localizedDescription)")
    }
}

extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
#else
// Placeholder file for watchOS watch app integration.
#endif
