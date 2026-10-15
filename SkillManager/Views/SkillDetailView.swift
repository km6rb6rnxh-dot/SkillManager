import SwiftUI

struct SkillDetailView: View {
    let skill: Skill
    @Environment(SkillListViewModel.self) private var viewModel
    @State private var showRemoveConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerCard
                infoCard
                actionsBar

                if let metadata = skill.metadata {
                    contentCard(metadata)
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .confirmationDialog("Remove Skill", isPresented: $showRemoveConfirmation) {
            Button("Remove", role: .destructive) {
                Task { await viewModel.removeSkill(skill) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Remove '\(skill.id)'? This deletes the skill files, symlink, and Cowork registration.")
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(skill.metadata?.name ?? skill.id)
                        .font(.title2)
                        .fontWeight(.bold)

                    if let url = skill.repoURL {
                        Link(skill.ownerRepo, destination: url)
                            .font(.subheadline)
                    } else {
                        Text(skill.ownerRepo)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                statusBadge
            }

            if let description = skill.metadata?.description, !description.isEmpty {
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch skill.updateStatus {
        case .upToDate:
            Label("Up to date", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(AppTheme.successGreen)
        case .updateAvailable:
            Label("Update available", systemImage: "arrow.down.circle.fill")
                .font(.caption)
                .foregroundStyle(AppTheme.warningOrange)
        case .checking:
            ProgressView()
                .controlSize(.small)
        case .error(let msg):
            Label(msg, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.yellow)
                .lineLimit(1)
        case .unknown:
            EmptyView()
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            infoRow("Skill Path", value: skill.entry.skillPath, mono: true)
            infoRow("Hash", value: String(skill.entry.skillFolderHash.prefix(12)) + "...", mono: true)

            if let date = skill.installDate {
                infoRow("Installed", value: date.formatted(date: .abbreviated, time: .omitted))
            }
            if let date = skill.updateDate {
                infoRow("Version", value: date.formatted(date: .abbreviated, time: .omitted))
            }

            HStack {
                Text("Environment")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .trailing)

                HStack(spacing: 6) {
                    EnvironmentToggle(
                        label: "Code",
                        isOn: skill.environment.code,
                        activeColor: AppTheme.skillBlue
                    ) {
                        Task { await viewModel.toggleCodeEnvironment(for: skill) }
                    }

                    EnvironmentToggle(
                        label: "Cowork",
                        isOn: skill.environment.cowork,
                        activeColor: AppTheme.coworkPurple
                    ) {
                        Task { await viewModel.toggleCoworkEnvironment(for: skill) }
                    }
                }
            }
        }
        .cardStyle()
    }

    private func infoRow(_ label: String, value: String, mono: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)

            if mono {
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            } else {
                Text(value)
                    .font(.caption)
            }
        }
    }

    private var actionsBar: some View {
        HStack(spacing: 10) {
            if case .updateAvailable = skill.updateStatus {
                Button {
                    Task { await viewModel.updateSkill(skill) }
                } label: {
                    Label("Update", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Button {
                viewModel.revealInFinder(skill)
            } label: {
                Label("Finder", systemImage: "folder")
            }
            .controlSize(.small)

            if skill.repoURL != nil {
                Button {
                    viewModel.openInGitHub(skill)
                } label: {
                    Label("GitHub", systemImage: "link")
                }
                .controlSize(.small)
            }

            Spacer()

            Button(role: .destructive) {
                showRemoveConfirmation = true
            } label: {
                Label("Remove", systemImage: "trash")
            }
            .controlSize(.small)
        }
    }

    private func contentCard(_ metadata: SkillMetadata) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SKILL.md")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text(metadata.rawContent)
                .font(.system(.caption2, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
        }
        .cardStyle()
    }
}

struct EnvironmentToggle: View {
    let label: String
    let isOn: Bool
    let activeColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(isOn ? activeColor : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                isOn ? activeColor.opacity(0.12) : Color.secondary.opacity(0.08),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }
}

extension View {
    func cardStyle() -> some View {
        self
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.separator, lineWidth: 0.5)
            )
    }
}
