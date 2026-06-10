import SwiftUI

/// Model / effort menus + thinking indicator for the Agent inspector.
struct ModelEffortPicker: View {
    @ObservedObject var model: ClaudeInfoModel

    private let modelOptions: [(value: String, label: String)] = [
        ("claude-fable-5", "Fable 5"),
        ("opus", "Opus"),
        ("sonnet", "Sonnet"),
        ("haiku", "Haiku")
    ]
    /// Effort levels in increasing order (`max` is omitted — unsupported on Opus; `ultracode`
    /// is xhigh + dynamic-workflow orchestration, a session-only mode that requires workflows).
    private let effortOptions: [(value: String, label: String)] = [
        ("low", "Low"),
        ("medium", "Medium"),
        ("high", "High"),
        ("xhigh", "Extra High"),
        ("ultracode", "Ultracode")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Model") {
                Menu(modelLabel(model.currentModel)) {
                    ForEach(modelOptions, id: \.value) { option in
                        Button(option.label) { model.setModel(option.value) }
                    }
                }
            }
            LabeledContent("Effort") {
                Menu(effortLabel(model.currentEffort)) {
                    ForEach(effortOptions, id: \.value) { option in
                        Button(option.label) { model.setEffort(option.value) }
                    }
                }
            }
            LabeledContent("Thinking") {
                Text(model.liveState.thinkingEnabled == true ? "On" : "Off")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func modelLabel(_ value: String?) -> String {
        modelOptions.first { $0.value == value }?.label ?? (value ?? "default")
    }

    private func effortLabel(_ value: String?) -> String {
        effortOptions.first { $0.value == value }?.label ?? (value ?? "default")
    }
}
