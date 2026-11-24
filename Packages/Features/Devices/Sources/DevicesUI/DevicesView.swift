#if canImport(SwiftUI)
    import DesignSystem
    import DevicesCore
    import Domain
    import SwiftUI

    /// Trainers in reach, and the connection state.
    public struct DevicesView: View {
        let viewModel: DevicesViewModel

        public init(viewModel: DevicesViewModel) {
            self.viewModel = viewModel
        }

        public var body: some View {
            List {
                Section("Trainers") {
                    ForEach(viewModel.devices) { device in
                        DeviceRow(device: device, viewModel: viewModel)
                    }
                }
                Section {
                    Text(
                        "Spinline talks to smart trainers through the Bluetooth Fitness Machine Service. "
                            + "The virtual trainer speaks the same protocol, so everything works without hardware."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Devices")
            .task { await viewModel.scan() }
        }
    }

    private struct DeviceRow: View {
        let device: TrainerDevice
        let viewModel: DevicesViewModel

        var body: some View {
            HStack {
                Image(systemName: device.kind == .virtual ? "cpu" : "bicycle")
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading) {
                    Text(device.name)
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("device-status-\(device.id)")
                }
                Spacer()
                action
            }
        }

        private var status: String {
            switch viewModel.state {
            case .connecting(let current) where current == device: "Connecting..."
            case .connected(let current) where current == device: "Connected"
            case .failed(let current, let message) where current == device: message
            default: device.kind == .virtual ? "Software trainer" : "Bluetooth trainer"
            }
        }

        @ViewBuilder private var action: some View {
            if viewModel.connectedDevice == device {
                Button("Disconnect") { Task { await viewModel.disconnect() } }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("disconnect-\(device.id)")
            } else {
                Button("Connect") { Task { await viewModel.connect(to: device) } }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .accessibilityIdentifier("connect-\(device.id)")
            }
        }
    }
#endif
