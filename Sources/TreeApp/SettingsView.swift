import SwiftUI
import TreeCore

/// The preferences form. Edits a working copy; `onSave` persists it. Array
/// fields (apps / types / terminals) are edited as newline-separated text.
struct SettingsView: View {
    @State private var draft: AppSettings
    let onSave: (AppSettings) -> Void

    init(initial: AppSettings, onSave: @escaping (AppSettings) -> Void) {
        _draft = State(initialValue: initial)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $draft.launchAtLogin)
                intRow("History size (items)", $draft.maxItems)
                intRow("Auto-delete after (days · 0 = never)", $draft.maxAgeDays)
                TextField("Clipboard check interval (s)", value: $draft.checkInterval, format: .number)
            }
            Section("Agent handoff") {
                intRow("Hand off text over (lines)", $draft.handoffMaxLines)
                intRow("Hand off text over (characters)", $draft.handoffMaxChars)
                linesRow("Terminal apps (one bundle id per line)", lines(\.terminalApps))
            }
            Section("Privacy / ignore") {
                linesRow("Ignored apps (bundle ids)", lines(\.ignoredApps))
                linesRow("Ignored pasteboard types", lines(\.ignoredTypes))
                TextField("Ignore regex (text matching is dropped)", text: $draft.ignoreRegex)
            }
            Section {
                Text("Some changes apply after restarting Tree.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("Save") { onSave(draft) }.keyboardShortcut(.defaultAction)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 470, height: 600)
    }

    private func intRow(_ label: String, _ binding: Binding<Int>) -> some View {
        TextField(label, value: binding, format: .number)
    }

    private func linesRow(_ label: String, _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextEditor(text: binding)
                .font(.system(size: 12, design: .monospaced))
                .frame(height: 70)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(.quaternary))
        }
    }

    private func lines(_ keyPath: WritableKeyPath<AppSettings, [String]>) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath].joined(separator: "\n") },
            set: {
                draft[keyPath: keyPath] = $0.split(separator: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            }
        )
    }
}
