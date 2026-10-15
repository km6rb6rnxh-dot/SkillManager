import SwiftUI

struct SettingsView: View {
    @AppStorage(Constants.UserDefaultsKeys.installDirectory)
    private var installDirectory: String = Constants.defaultSkillsInstallDirectory.path

    @AppStorage(Constants.UserDefaultsKeys.claudeSkillsDirectory)
    private var claudeSkillsDirectory: String = Constants.defaultClaudeSkillsDirectory.path

    @AppStorage(Constants.UserDefaultsKeys.autoCheckUpdates)
    private var autoCheckUpdates: Bool = true

    @AppStorage(Constants.UserDefaultsKeys.appearance)
    private var appearance: String = AppAppearance.system.rawValue

    @State private var tokenInput: String = ""
    @State private var tokenSaved = false
    @State private var selectedTab = "general"

    var body: some View {
        TabView(selection: $selectedTab) {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }
                .tag("general")

            logTab
                .tabItem { Label("Log", systemImage: "doc.text") }
                .tag("log")
        }
        .frame(width: 560, height: 440)
        .onAppear {
            tokenInput = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.githubToken) ?? ""
        }
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    ForEach(AppAppearance.allCases, id: \.rawValue) { option in
                        Text(option.label).tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Directories") {
                HStack {
                    Text("Install directory")
                    Spacer()
                    Text(installDirectory)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Choose...") {
                        chooseDirectory { path in
                            installDirectory = path
                        }
                    }
                }

                HStack {
                    Text("Claude skills directory")
                    Spacer()
                    Text(claudeSkillsDirectory)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Choose...") {
                        chooseDirectory { path in
                            claudeSkillsDirectory = path
                        }
                    }
                }
            }

            Section("Updates") {
                Toggle("Check for updates on launch", isOn: $autoCheckUpdates)
            }

            Section("GitHub") {
                HStack {
                    SecureField("Personal Access Token", text: $tokenInput)
                    Button(tokenSaved ? "Saved!" : "Save") {
                        UserDefaults.standard.set(tokenInput, forKey: Constants.UserDefaultsKeys.githubToken)
                        tokenSaved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            tokenSaved = false
                        }
                    }
                    .disabled(tokenInput.isEmpty)
                }
                Text("Enables precise skill search. Create a token at GitHub → Settings → Developer settings → Personal access tokens.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Log

    private var logTab: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(InstallLogger.shared.entries.count) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    exportLog()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .controlSize(.small)

                Button {
                    InstallLogger.shared.clear()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if InstallLogger.shared.entries.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundStyle(.quaternary)
                    Text("No log entries yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Install a skill to see activity here")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(InstallLogger.shared.entries) { entry in
                                LogEntryRow(entry: entry)
                                    .id(entry.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .onChange(of: InstallLogger.shared.entries.count) {
                        if let last = InstallLogger.shared.entries.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func chooseDirectory(completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            completion(url.path)
        }
    }

    private func exportLog() {
        let text = InstallLogger.shared.entries.map { entry in
            "[\(entry.formattedTime)] [\(entry.level.rawValue)] \(entry.message)"
        }.joined(separator: "\n")

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "skillmanager-log.txt"
        panel.allowedContentTypes = [.plainText]
        if panel.runModal() == .OK, let url = panel.url {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - Log Entry Row

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.formattedTime)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 60, alignment: .leading)

            levelIcon
                .frame(width: 16)

            Text(entry.message)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(textColor)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(bgColor, in: RoundedRectangle(cornerRadius: 3))
    }

    @ViewBuilder
    private var levelIcon: some View {
        switch entry.level {
        case .info:
            Image(systemName: "info.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        case .step:
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.skillBlue)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.successGreen)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.red)
        }
    }

    private var textColor: Color {
        switch entry.level {
        case .error: .red
        case .success: AppTheme.successGreen
        case .step: .primary
        case .info: .secondary
        }
    }

    private var bgColor: Color {
        switch entry.level {
        case .error: .red.opacity(0.08)
        case .success: AppTheme.successGreen.opacity(0.06)
        default: .clear
        }
    }
}
