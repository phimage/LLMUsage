import SwiftUI
import LLMUsage

struct MetricRowView: View {
    let metric: UsageMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(metric.label).font(.caption)
                Spacer()
                Text(formattedValue).font(.caption).foregroundColor(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(
                            width: geo.size.width * min(metric.usedPercent / 100, 1.0),
                            height: 6
                        )
                }
            }
            .frame(height: 6)
        }
    }

    private var formattedValue: String {
        switch metric.format {
        case .percent:
            String(format: "%.0f%%", metric.usedPercent)
        case .dollars(let used, let limit):
            String(format: "$%.2f / $%.2f", used, limit)
        case .count(let used, let limit, let suffix):
            "\(used)/\(limit) \(suffix)"
        }
    }

    private var barColor: Color {
        if metric.usedPercent >= 90 { return .red }
        if metric.usedPercent >= 75 { return .orange }
        return .green
    }
}
