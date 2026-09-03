import Foundation

public struct SnapConfiguration: Equatable, Sendable {
    public var isEnabled: Bool
    public var gridSpacing: Double
    public var pointTolerance: Double
    public var angleIncrementDegrees: Double

    public init(
        isEnabled: Bool = true,
        gridSpacing: Double = 10,
        pointTolerance: Double = 6,
        angleIncrementDegrees: Double = 15
    ) {
        self.isEnabled = isEnabled
        self.gridSpacing = gridSpacing
        self.pointTolerance = pointTolerance
        self.angleIncrementDegrees = angleIncrementDegrees
    }
}

public struct SnapResult: Equatable, Sendable {
    public let point: TechnicalPoint
    public let snappedX: Bool
    public let snappedY: Bool

    public init(point: TechnicalPoint, snappedX: Bool, snappedY: Bool) {
        self.point = point
        self.snappedX = snappedX
        self.snappedY = snappedY
    }
}

public struct SnapEngine: Sendable {
    public var configuration: SnapConfiguration

    public init(configuration: SnapConfiguration = SnapConfiguration()) {
        self.configuration = configuration
    }

    public func snap(
        _ point: TechnicalPoint,
        alignmentCandidates: [TechnicalPoint] = []
    ) -> SnapResult {
        guard configuration.isEnabled,
              configuration.gridSpacing.isFinite,
              configuration.gridSpacing > 0,
              configuration.pointTolerance.isFinite,
              configuration.pointTolerance >= 0,
              point.x.isFinite,
              point.y.isFinite else {
            return SnapResult(point: point, snappedX: false, snappedY: false)
        }

        var x = point.x
        var y = point.y
        var snappedX = false
        var snappedY = false
        let gridX = (x / configuration.gridSpacing).rounded() * configuration.gridSpacing
        let gridY = (y / configuration.gridSpacing).rounded() * configuration.gridSpacing
        if abs(gridX - x) <= configuration.pointTolerance {
            x = gridX
            snappedX = true
        }
        if abs(gridY - y) <= configuration.pointTolerance {
            y = gridY
            snappedY = true
        }

        for candidate in alignmentCandidates where candidate.x.isFinite && candidate.y.isFinite {
            if abs(candidate.x - point.x) <= configuration.pointTolerance {
                x = candidate.x
                snappedX = true
            }
            if abs(candidate.y - point.y) <= configuration.pointTolerance {
                y = candidate.y
                snappedY = true
            }
        }
        return SnapResult(point: TechnicalPoint(x: x, y: y), snappedX: snappedX, snappedY: snappedY)
    }

    public func snapAngle(_ angleDegrees: Double) -> Double {
        guard configuration.isEnabled,
              angleDegrees.isFinite,
              configuration.angleIncrementDegrees.isFinite,
              configuration.angleIncrementDegrees > 0 else {
            return angleDegrees
        }
        return (angleDegrees / configuration.angleIncrementDegrees).rounded()
            * configuration.angleIncrementDegrees
    }
}
