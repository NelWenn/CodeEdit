import SwiftUI

/// The Inspector content shown in Agent mode: account, plan, live usage, and controls.
struct ClaudeInfoInspectorView: View {
    @ObservedObject var model: ClaudeInfoModel

    var body: some View {
        Form {
            Section {
                LabeledContent("Account", value: model.account?.email ?? "—")
                LabeledContent("Plan", value: model.account?.planDisplayName ?? "—")
            }
            Section("Usage") {
                UsageMeter(title: "Session (5h)", window: model.usage.session)
                UsageMeter(title: "Weekly (7d)", window: model.usage.weekly)
                UsageMeter(title: "Weekly Sonnet", window: model.usage.weeklySonnet)
                if model.usageIsStale {
                    Text("Usage unavailable — run an Agent session or refresh.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button("Refresh") { Task { await model.refreshUsage() } }
            }
            Section("Model") { ModelEffortPicker(model: model) }
        }
        .formStyle(.grouped)
    }
}
