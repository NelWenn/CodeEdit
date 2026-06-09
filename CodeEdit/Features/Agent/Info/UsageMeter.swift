import SwiftUI

/// One usage window rendered as a labeled progress bar + reset countdown.
struct UsageMeter: View {
    let title: String
    let window: UsageWindow?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.callout.weight(.medium))
                Spacer()
                Text(window.map { "\(Int($0.usedPercent))%" } ?? "—")
                    .font(.callout).foregroundStyle(.secondary).monospacedDigit()
            }
            ProgressView(value: (window?.usedPercent ?? 0) / 100)
                .tint((window?.usedPercent ?? 0) > 90 ? .red : .accentColor)
            if let resets = window?.resetsAt {
                Text("Resets \(resets, format: .relative(presentation: .named))")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
    }
}
