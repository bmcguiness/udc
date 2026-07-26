enum OBDConnectionState: Equatable {
    case unsupported, disconnected, scanning, connecting, connected, failed(message: String)
}
protocol OBDProviding { var connectionState: OBDConnectionState { get }; var engineRPM: Double? { get } }
struct NoOpOBDProvider: OBDProviding { var connectionState: OBDConnectionState { .unsupported }; var engineRPM: Double? { nil } }
