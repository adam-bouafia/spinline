#if canImport(SwiftUI) && canImport(Charts)
    import Charts
    import DesignSystem
    import Domain
    import SwiftUI
    import WorkoutsCore

    /// The workout as coloured bars over time, by power zone. A line marks the
    /// current second during a session.
    struct WorkoutChart: View {
        let bars: [TimelineBar]
        let ftp: Int
        var elapsed: Int?

        var body: some View {
            Chart {
                ForEach(bars) { bar in
                    RectangleMark(
                        xStart: .value("Start", bar.start / 60),
                        xEnd: .value("End", bar.end / 60),
                        yStart: .value("Floor", 0),
                        // Free-ride bars are drawn low and grey.
                        yEnd: .value("Watts", bar.watts ?? Int(Double(ftp) * 0.4))
                    )
                    .foregroundStyle(bar.zone.map(Theme.color(for:)) ?? Color.gray.opacity(0.35))
                }
                if let elapsed {
                    RuleMark(x: .value("Now", Double(elapsed) / 60))
                        .foregroundStyle(.primary)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
            .chartXAxisLabel("Minutes")
            .chartYAxisLabel("Watts")
            .frame(height: 160)
            .accessibilityLabel("Workout profile")
        }
    }
#endif
