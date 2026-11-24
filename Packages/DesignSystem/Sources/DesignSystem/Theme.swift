#if canImport(SwiftUI)
    import Domain
    import SwiftUI

    /// Colours used across the app.
    public enum Theme {
        public static let accent = Color(red: 0.95, green: 0.42, blue: 0.13)
        public static let tileBackground = Color.secondary.opacity(0.12)

        /// One colour per training zone, from cool to hot.
        public static func color(for zone: PowerZone) -> Color {
            switch zone {
            case .recovery: .gray
            case .endurance: .blue
            case .tempo: .green
            case .threshold: .yellow
            case .vo2Max: .orange
            case .anaerobic: .red
            }
        }
    }

    extension Font {
        /// Large numbers on the ride screen: rounded and with fixed-width digits,
        /// so values do not jump around as they change.
        public static let metric = Font.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit()
    }
#endif
