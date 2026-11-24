#if canImport(SwiftUI)
    import DesignSystem
    import Domain
    import RideCore
    import SwiftUI

    /// Live values and ERG control.
    public struct RideView: View {
        let viewModel: RideViewModel

        public init(viewModel: RideViewModel) {
            self.viewModel = viewModel
        }

        public var body: some View {
            ScrollView {
                VStack(spacing: 16) {
                    metrics
                    zoneLabel
                    ergControls
                    startStop
                    if let message = viewModel.errorMessage {
                        Text(message)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("ride-error")
                    }
                }
                .padding()
            }
            .navigationTitle("Ride")
            .task { await viewModel.listen() }
        }

        private var metrics: some View {
            let sample = viewModel.sample
            return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricTile(
                    title: "Power",
                    value: sample.power.map(String.init) ?? "--",
                    unit: "W",
                    tint: viewModel.zone.map(Theme.color(for:)) ?? .primary
                )
                .accessibilityIdentifier("tile-power")
                MetricTile(title: "Cadence", value: sample.cadence.map { String(Int($0)) } ?? "--", unit: "rpm")
                    .accessibilityIdentifier("tile-cadence")
                MetricTile(
                    title: "Speed",
                    value: sample.speed.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "--",
                    unit: "km/h"
                )
                .accessibilityIdentifier("tile-speed")
                MetricTile(title: "Heart rate", value: sample.heartRate.map(String.init) ?? "--", unit: "bpm")
                    .accessibilityIdentifier("tile-heart-rate")
            }
        }

        @ViewBuilder private var zoneLabel: some View {
            if let zone = viewModel.zone {
                Text("Zone \(zone.rawValue): \(zone.name)")
                    .font(.headline)
                    .foregroundStyle(Theme.color(for: zone))
            }
        }

        private var ergControls: some View {
            VStack(spacing: 8) {
                Text("ERG target")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                HStack(spacing: 24) {
                    Button("-10 W") { Task { await viewModel.changeTarget(by: -10) } }
                        .accessibilityIdentifier("erg-down")
                    Text(viewModel.targetPower.map { "\($0) W" } ?? "Free")
                        .font(.metric)
                        .accessibilityIdentifier("erg-target")
                    Button("+10 W") { Task { await viewModel.changeTarget(by: 10) } }
                        .accessibilityIdentifier("erg-up")
                }
                .buttonStyle(.bordered)
                Button("Ride free") { Task { await viewModel.rideFree() } }
                    .disabled(viewModel.targetPower == nil)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.tileBackground, in: RoundedRectangle(cornerRadius: 16))
        }

        private var startStop: some View {
            Button(viewModel.isRiding ? "Stop" : "Start ride") {
                Task { viewModel.isRiding ? await viewModel.stop() : await viewModel.start() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .accessibilityIdentifier("ride-start-stop")
        }
    }
#endif
