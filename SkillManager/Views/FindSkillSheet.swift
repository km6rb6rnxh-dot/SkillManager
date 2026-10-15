import SwiftUI

struct FindSkillSheet: View {
    @State private var viewModel = FindSkillViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    var onInstalled: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchBar
            Divider()
            content
        }
        .frame(width: 540, height: 480)
        .background(.background)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tint)
                Text("Find Skills")
                    .font(.headline)
            }
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
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search skills and resources...", text: $viewModel.searchQuery)
                .textFieldStyle(.roundedBorder)
                .onSubmit { Task { await viewModel.search() } }

            if viewModel.state == .searching {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("Search") {
                    Task { await viewModel.search() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            idleView
        case .searching:
            VStack(spacing: 10) {
                Spacer()
                ProgressView()
                Text("Searching GitHub...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .results:
            resultsList
        case .noResults:
            noResultsView
        }
    }

    private var idleView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "command")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(.quaternary)
            Text("Search for Claude skills on GitHub")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !viewModel.hasToken {
                Label("Add a GitHub token in Settings for better results", systemImage: "key")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "puzzlepiece.slash")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(.quaternary)
            Text("No results for \"\(viewModel.searchQuery)\"")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Try different keywords")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Results List

    private var resultsList: some View {
        VStack(spacing: 0) {
            if let success = viewModel.installSuccess {
                statusBanner(
                    icon: "checkmark.circle.fill",
                    text: "'\(success)' installed",
                    color: AppTheme.successGreen,
                    bgColor: AppTheme.successGreenSoft
                )
            }

            if let error = viewModel.errorMessage {
                statusBanner(
                    icon: "exclamationmark.triangle.fill",
                    text: error,
                    color: AppTheme.warningOrange,
                    bgColor: AppTheme.warningOrangeSoft
                )
            }

            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(viewModel.results) { result in
                        SearchResultRow(
                            result: result,
                            isInstalling: viewModel.installingSkillID == result.id,
                            installProgress: viewModel.installingSkillID == result.id ? viewModel.installProgress : 0,
                            isPendingInstall: viewModel.pendingInstall?.id == result.id,
                            installToCode: $viewModel.installToCode,
                            installToCowork: $viewModel.installToCowork,
                            onInstall: {
                                viewModel.requestInstall(result)
                            },
                            onConfirm: {
                                Task {
                                    await viewModel.confirmInstall()
                                    onInstalled()
                                }
                            },
                            onCancel: {
                                viewModel.cancelInstall()
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }

            Divider()

            HStack {
                Text("\(viewModel.results.count) result\(viewModel.results.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Export") { exportResults() }
                    .controlSize(.small)
                Button("Done") { dismiss() }
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }

    private func statusBanner(icon: String, text: String, color: Color, bgColor: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(text)
                .font(.caption)
                .foregroundStyle(color)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(bgColor)
    }
}

// MARK: - Export

extension FindSkillSheet {
    func exportResults() {
        var text = "SkillManager Search Results\n"
        text += "Query: \(viewModel.searchQuery)\n"
        text += "Count: \(viewModel.results.count)\n\n"
        for (i, result) in viewModel.results.enumerated() {
            text += "\(i + 1). \(result.skillName) [\(result.repoType.rawValue)]\n"
            text += "   Repo: \(result.repoFullName)\n"
            text += "   Stars: \(result.stars)\n"
            text += "   Path: \(result.skillPath)\n"
            text += "   Desc: \(result.skillDescription.prefix(100))\n"
            if !result.contentFiles.isEmpty {
                text += "   Content files: \(result.contentFiles.joined(separator: ", "))\n"
            }
            text += "\n"
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "search-results.txt"
        panel.allowedContentTypes = [.plainText]
        if panel.runModal() == .OK, let url = panel.url {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: SkillSearchResult
    let isInstalling: Bool
    let installProgress: Double
    let isPendingInstall: Bool
    @Binding var installToCode: Bool
    @Binding var installToCowork: Bool
    let onInstall: () -> Void
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                typeIcon
                Text(result.skillName)
                    .font(.system(size: 13, weight: .medium))
                typeBadge
                Spacer()

                if isInstalling {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("Install") { onInstall() }
                        .controlSize(.mini)
                        .popover(isPresented: .constant(isPendingInstall)) {
                            installPopover
                        }
                }
            }

            if !result.skillDescription.isEmpty {
                Text(result.skillDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                Text(result.repoFullName)
                    .foregroundStyle(.tertiary)

                if result.stars > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                        Text("\(result.stars)")
                    }
                    .foregroundStyle(AppTheme.starYellow)
                }

                if !result.folderPath.isEmpty {
                    Text(result.folderPath)
                        .foregroundStyle(.tertiary)
                }
            }
            .font(.caption2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
        )
        .overlay(alignment: .bottom) {
            if isInstalling && installProgress > 0 {
                GeometryReader { geo in
                    AppTheme.successGreen
                        .frame(width: geo.size.width * installProgress, height: 2.5)
                        .clipShape(Capsule())
                }
                .frame(height: 2.5)
            }
        }
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
    }

    private var typeIcon: some View {
        Group {
            switch result.repoType {
            case .skill:
                Image(systemName: "puzzlepiece.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.skillBlue)
                    .frame(width: 26, height: 26)
                    .background(AppTheme.skillBlueSoft, in: RoundedRectangle(cornerRadius: 6))
            case .resource:
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.resourceAmber)
                    .frame(width: 26, height: 26)
                    .background(AppTheme.resourceAmberSoft, in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var typeBadge: some View {
        Group {
            switch result.repoType {
            case .skill:
                Text("Skill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.skillBlue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.skillBlueSoft, in: RoundedRectangle(cornerRadius: 4))
            case .resource:
                Text("Resource")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.resourceAmber)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.resourceAmberSoft, in: RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    private var installPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Install to")
                .font(.subheadline)
                .fontWeight(.medium)

            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: $installToCode) {
                    HStack(spacing: 6) {
                        Image(systemName: "terminal")
                            .font(.caption)
                            .foregroundStyle(AppTheme.skillBlue)
                        Text("Claude Code")
                            .font(.callout)
                    }
                }
                .toggleStyle(.checkbox)

                Toggle(isOn: $installToCowork) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2")
                            .font(.caption)
                            .foregroundStyle(AppTheme.coworkPurple)
                        Text("Cowork")
                            .font(.callout)
                    }
                }
                .toggleStyle(.checkbox)
            }

            if result.repoType == .resource {
                Label("SKILL.md will be generated from repo content", systemImage: "wand.and.stars")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Button("Cancel") { onCancel() }
                    .controlSize(.small)
                Spacer()
                Button("Confirm") { onConfirm() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!installToCode && !installToCowork)
            }
        }
        .padding(12)
        .frame(width: 240)
    }
}
