import Foundation

struct LocationSnapshot: Equatable { var speedMetersPerSecond: Double; var date: Date }
protocol LocationProviding { var latestSnapshot: LocationSnapshot? { get } }
struct NoOpLocationProvider: LocationProviding { var latestSnapshot: LocationSnapshot? { nil } }
