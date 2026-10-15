import SwiftUI

struct AddSkillSheet: View {
    @State private var viewModel = AddSkillViewModel()
    @Environment(\.dismiss) private var dismiss
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Skill")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            switch viewModel.state {
            case .idle, .error:
                inputStep
            case .fetching:
                loadingStep("Fetching repository...")
            case .selectingSkills:
                selectionStep
            case .installing:
                loadingStep(viewModel.installProgress)
            case .completed(let count):
                completedStep(count: count)
            }
        }
        .frame(width: 400, height: 320)
    }

    private var inputStep: some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 36))
                .foregroundStyle(.tint)

            Text("GitHub Repository")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField("owner/repo", text: $viewModel.repoInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await viewModel.fetch() } }

                Button("Fetch") {
                    Task { await viewModel.fetch() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.repoInput.isEmpty)
            }
            .padding(.horizontal, 32)

            if case .error(let message) = viewModel.state {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

    private func loadingStep(_ message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var selectionStep: some View {
        VStack(spacing: 0) {
            if let repo = viewModel.repoInfo {
                HStack {
                    Text(repo.fullName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Label("\(repo.stargazersCount)", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                Divider()
            }

            List {
                ForEach(viewModel.candidates) { candidate in
                    Toggle(isOn: Binding(
                        get: { viewModel.selectedCandidateIDs.contains(candidate.id) },
                        set: { isOn in
                            if isOn {
                                viewModel.selectedCandidateIDs.insert(candidate.id)
                            } else {
                                viewModel.selectedCandidateIDs.remove(candidate.id)
                            }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(candidate.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(candidate.folderPath)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }
            .listStyle(.plain)

            Divider()

            HStack {
                Button("Back") { viewModel.reset() }
                    .controlSize(.small)
                Spacer()
                Button("Install") {
                    Task { await viewModel.installSelected() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(viewModel.selectedCandidateIDs.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }

    private func completedStep(count: Int) -> some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)

            Text("\(count) skill\(count == 1 ? "" : "s") installed")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("Available in Claude Code and Cowork")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let error = viewModel.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Button("Done") {
                onComplete()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Spacer()
        }
    }
}
