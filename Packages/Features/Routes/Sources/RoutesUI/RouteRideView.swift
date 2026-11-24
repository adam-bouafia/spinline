#if canImport(SwiftUI) && canImport(AVKit)
    import AVKit
    import DesignSystem
    import RideEngine
    import RoutesCore
    import SwiftUI

    /// The route video with live values. Four times a second the view model
    /// advances the ride and the player follows its command.
    public struct RouteRideView: View {
        let viewModel: RouteRideViewModel
        @State private var player: AVPlayer

        public init(viewModel: RouteRideViewModel, videoURL: URL) {
            self.viewModel = viewModel
            _player = State(initialValue: AVPlayer(url: videoURL))
        }

        public var body: some View {
            VStack(spacing: 16) {
                VideoPlayer(player: player)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("route-video")
                ProgressView(value: viewModel.progress)
                    .tint(Theme.accent)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MetricTile(title: "Power", value: "\(viewModel.power)", unit: "W", tint: Theme.accent)
                    MetricTile(
                        title: "Speed",
                        value: viewModel.speed.kilometresPerHour.formatted(.number.precision(.fractionLength(1))),
                        unit: "km/h"
                    )
                    MetricTile(
                        title: "Gradient",
                        value: viewModel.grade.percent.formatted(.number.precision(.fractionLength(1))),
                        unit: "%"
                    )
                    .accessibilityIdentifier("route-grade")
                    MetricTile(
                        title: "Distance",
                        value: (viewModel.distance / 1000).formatted(.number.precision(.fractionLength(2))),
                        unit: "km"
                    )
                }
                if !viewModel.isRiding {
                    Button(viewModel.command == .finished ? "Route complete" : "Start riding") {
                        Task { await viewModel.start() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(viewModel.command == .finished)
                    .accessibilityIdentifier("route-start")
                }
                if let message = viewModel.errorMessage {
                    Text(message).foregroundStyle(.red)
                }
                Spacer()
            }
            .padding()
            .navigationTitle(viewModel.name)
            .task { await viewModel.listen() }
            .task { await drive() }
            .onDisappear { player.pause() }
        }

        private func drive() async {
            let clock = ContinuousClock()
            let start = clock.now
            let tick = 0.25
            while !Task.isCancelled {
                try? await clock.sleep(for: .milliseconds(250))
                let now = (clock.now - start) / .seconds(1)
                await viewModel.step(seconds: tick, videoTime: player.currentTime().seconds, now: now)
                apply(viewModel.command)
            }
        }

        private func apply(_ command: VideoSync.Command) {
            switch command {
            case .play(let rate):
                player.rate = Float(rate)
            case .seek(let time, let rate):
                player.seek(
                    to: CMTime(seconds: time, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
                player.rate = Float(rate)
            case .pause, .finished:
                player.pause()
            }
        }
    }

    extension Duration {
        fileprivate static func / (lhs: Duration, rhs: Duration) -> Double {
            let l = lhs.components
            let r = rhs.components
            return (Double(l.seconds) + Double(l.attoseconds) / 1e18)
                / (Double(r.seconds) + Double(r.attoseconds) / 1e18)
        }
    }
#endif
