#if canImport(SwiftUI)
    import SwiftUI

    /// One live value on the ride screen: a label, a big number and its unit.
    public struct MetricTile: View {
        let title: String
        let value: String
        let unit: String
        let tint: Color

        public init(title: String, value: String, unit: String, tint: Color = .primary) {
            self.title = title
            self.value = value
            self.unit = unit
            self.tint = tint
        }

        public var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.metric)
                        .foregroundStyle(tint)
                        .contentTransition(.numericText())
                    Text(unit)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Theme.tileBackground, in: RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .combine)
        }
    }

    #Preview {
        MetricTile(title: "Power", value: "250", unit: "W", tint: Theme.accent)
            .padding()
    }
#endif
