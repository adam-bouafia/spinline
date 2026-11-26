#if canImport(SwiftUI)
    import DesignSystem
    import Domain
    import RideEngine
    import SwiftUI
    import WorkoutsCore

    /// The workout library, with a detail screen per workout.
    public struct WorkoutListView: View {
        let workouts: [Workout]
        let ftp: Int
        let canStart: Bool
        let onStart: (Workout) -> Void

        /// - Parameters:
        ///   - canStart: whether a trainer is connected.
        ///   - onStart: called when the rider starts a workout.
        public init(workouts: [Workout], ftp: Int, canStart: Bool, onStart: @escaping (Workout) -> Void) {
            self.workouts = workouts
            self.ftp = ftp
            self.canStart = canStart
            self.onStart = onStart
        }

        public var body: some View {
            List(workouts) { workout in
                NavigationLink(value: workout.id) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout.name)
                            .font(.headline)
                        Text("\(clockText(workout.duration)) - \(workout.steps.count) steps")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("workout-\(workout.id)")
            }
            .navigationTitle("Workouts")
            .navigationDestination(for: String.self) { id in
                if let workout = workouts.first(where: { $0.id == id }) {
                    WorkoutDetailView(workout: workout, ftp: ftp, canStart: canStart) { onStart(workout) }
                }
            }
        }
    }

    struct WorkoutDetailView: View {
        let plan: WorkoutPlan
        let bars: [TimelineBar]
        let canStart: Bool
        let onStart: () -> Void

        init(workout: Workout, ftp: Int, canStart: Bool, onStart: @escaping () -> Void) {
            plan = WorkoutPlan(workout: workout, ftp: ftp)
            bars = TimelineBar.bars(for: plan)
            self.canStart = canStart
            self.onStart = onStart
        }

        var body: some View {
            List {
                Section {
                    #if canImport(Charts)
                        WorkoutChart(bars: bars, ftp: plan.ftp)
                    #endif
                    LabeledContent("Duration", value: clockText(plan.duration))
                    LabeledContent("FTP", value: "\(plan.ftp) W")
                }
                Section("Steps") {
                    ForEach(plan.segments) { segment in
                        HStack {
                            Text(segment.step.label ?? "Free ride")
                            Spacer()
                            Text(targetText(segment))
                                .foregroundStyle(.secondary)
                            Text(clockText(segment.step.seconds))
                                .monospacedDigit()
                                .frame(minWidth: 56, alignment: .trailing)
                        }
                    }
                }
                Section {
                    Button("Start workout", action: onStart)
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                        .disabled(!canStart)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("start-workout")
                    if !canStart {
                        Text("Connect a trainer on the Devices tab first.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(plan.workout.name)
        }

        private func targetText(_ segment: WorkoutPlan.Segment) -> String {
            switch (segment.startPower, segment.endPower) {
            case (let start?, let end?) where start != end: "\(start) to \(end) W"
            case (let watts?, _): "\(watts) W"
            default: "free"
            }
        }
    }
#endif
