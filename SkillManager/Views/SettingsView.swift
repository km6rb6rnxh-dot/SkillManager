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

    var body: some View {
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
        .frame(width: 500)
        .padding()
        .onAppear {
            tokenInput = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.githubToken) ?? ""
        }
    }

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
}
