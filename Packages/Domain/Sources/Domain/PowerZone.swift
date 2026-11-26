/// Training zones by power, as a share of FTP (the common six-zone model).
///
/// | Zone | Share of FTP |
/// |---|---|
/// | 1 Recovery | below 55 % |
/// | 2 Endurance | 55 to 75 % |
/// | 3 Tempo | 75 to 90 % |
/// | 4 Threshold | 90 to 105 % |
/// | 5 VO2 max | 105 to 120 % |
/// | 6 Anaerobic | 120 % and above |
public enum PowerZone: Int, CaseIterable, Comparable, Sendable {
    case recovery = 1
    case endurance
    case tempo
    case threshold
    case vo2Max
    case anaerobic

    /// The zone for `watts` at `ftp`. A zone's lower bound belongs to it.
    public init(watts: Int, ftp: Int) {
        let share = ftp > 0 ? Double(watts) / Double(ftp) : 0
        self = Self.allCases.last { share >= $0.lowerBound } ?? .recovery
    }

    /// Lowest share of FTP in this zone.
    public var lowerBound: Double {
        switch self {
        case .recovery: 0
        case .endurance: 0.55
        case .tempo: 0.75
        case .threshold: 0.90
        case .vo2Max: 1.05
        case .anaerobic: 1.20
        }
    }

    public var name: String {
        switch self {
        case .recovery: "Recovery"
        case .endurance: "Endurance"
        case .tempo: "Tempo"
        case .threshold: "Threshold"
        case .vo2Max: "VO2 max"
        case .anaerobic: "Anaerobic"
        }
    }

    public static func < (lhs: PowerZone, rhs: PowerZone) -> Bool { lhs.rawValue < rhs.rawValue }
}
