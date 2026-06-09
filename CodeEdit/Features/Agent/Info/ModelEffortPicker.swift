import SwiftUI

/// Model / effort menus + thinking indicator for the Agent inspector.
struct ModelEffortPicker: View {
    @ObservedObject var model: ClaudeInfoModel
    private let modelNames = ["opus", "sonnet", "haiku"]
    private let effortLevels = ["low", "medium", "high", "xhigh", "max"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Model") {
                Menu(model.currentModel ?? "default") {
                    ForEach(modelNames, id: \.self) { name in
                        Button(name) { model.setModel(name) }
                    }
                }
            }
            LabeledContent("Effort") {
                Menu(model.currentEffort ?? "default") {
                    ForEach(effortLevels, id: \.self) { level in
                        Button(level) { model.setEffort(level) }
                    }
                }
            }
            LabeledContent("Thinking") {
                Text(model.liveState.thinkingEnabled == true ? "On" : "Off")
                    .foregroundStyle(.secondary)
            }
            Text("Higher effort = more thinking. Effort applies to new sessions.")
                .font(.caption).foregroundStyle(.tertiary)
        }
    }
}
