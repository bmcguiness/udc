import Foundation

struct ManualDrivelineConfiguration: Codable, Equatable {
    var rearAxleRatio: Double
    var tireDiameterInches: Double
    var gearRatios: [Double]
}
