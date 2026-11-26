#if canImport(SwiftUI)
    import DesignSystem
    import Domain
    import RideEngine
    import SwiftUI
    import WorkoutsCore

    /// A workout in progress: where you are, what to push, what you push.
    public struct WorkoutSessionView: View {
        let viewModel: WorkoutSessionViewModel
        let bars: [TimelineBar]
        let onClose: () -> Void

        public init(viewModel: WorkoutSessionViewModel, onClose: @escaping () -> Void) {
            self.viewModel = viewModel
            bars = TimelineBar.bars(for: viewModel.plan)
            self.onClose = onClose
        }

        public var body: some View {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    stepCard
                    metrics
                    #if canImport(Charts)
                        WorkoutChart(bars: bars, ftp: viewModel.plan.ftp, elapsed: viewModel.elapsed)
                    #endif
                    controls
                }
                .padding()
            }
            .task { await viewModel.run() }
            .task { await viewModel.listen() }
        }

        private var header: some View {
            VStack(spacing: 8) {
                Text(viewModel.plan.workout.name)
                    .font(.title2.bold())
                ProgressView(value: viewModel.progress)
                    .tint(Theme.accent)
                HStack {
                    Text(clockText(viewModel.elapsed))
                        .accessibilityIdentifier("session-elapsed")
                    Spacer()
                    Text("-" + clockText(viewModel.remaining))
                }
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }

        @ViewBuilder private var stepCard: some View {
            if let position = viewModel.position {
                VStack(spacing: 4) {
                    Text(position.step.label ?? "Free ride")
                        .font(.title.bold())
                        .accessibilityIdentifier("session-step")
                    Text("\(clockText(Int(position.remainingInStep.rounded(.up)))) left in this step")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if let cadence = position.step.cadence {
                        Text("Cadence \(cadence) rpm")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.tileBackground, in: RoundedRectangle(cornerRadius: 16))
            } else if viewModel.state == .finished {
                Text("Workout complete")
                    .font(.title.bold())
                    .accessibilityIdentifier("session-complete")
            }
        }

        private var metrics: some View {
            let sample = viewModel.sample
            let target = viewModel.position?.targetPower
            let zone = sample.power.map { PowerZone(watts: $0, ftp: viewModel.plan.ftp) }
            return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricTile(title: "Target", value: target.map(String.init) ?? "Free", unit: target == nil ? "" : "W")
                MetricTile(
                    title: "Power",
                    value: sample.power.map(String.init) ?? "--",
                    unit: "W",
                    tint: zone.map(Theme.color(for:)) ?? .primary
                )
                .accessibilityIdentifier("session-power")
                MetricTile(title: "Cadence", value: sample.cadence.map { String(Int($0)) } ?? "--", unit: "rpm")
                MetricTile(title: "Heart rate", value: sample.heartRate.map(String.init) ?? "--", unit: "bpm")
            }
        }

        @ViewBuilder private var controls: some View {
            switch viewModel.state {
            case .ready, .running, .paused:
                HStack {
                    if viewModel.state == .paused {
                        Button("Resume") { Task { await viewModel.resume() } }
                    } else {
                        Button("Pause") { Task { await viewModel.pause() } }
                            .disabled(viewModel.state != .running)
                    }
                    Button("End workout", role: .destructive) {
                        Task {
                            await viewModel.finish()
                            onClose()
                        }
                    }
                }
                .buttonStyle(.bordered)
            case .finished:
                Button("Close", action: onClose)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .accessibilityIdentifier("session-close")
            case .failed(let message):
                VStack {
                    Text(message)
                        .foregroundStyle(.red)
                    Button("Close", action: onClose)
                }
            }
        }
    }
#endif
