import Foundation

enum DrivingSessionState: Equatable { case idle, driving(startedAt: Date) }
protocol DrivingSessionManaging { var state: DrivingSessionState { get }; func start(); func stop() }
final class NoOpDrivingSessionManager: DrivingSessionManaging {
    private(set) var state: DrivingSessionState = .idle
    func start() { state = .driving(startedAt: .now) }
    func stop() { state = .idle }
}
