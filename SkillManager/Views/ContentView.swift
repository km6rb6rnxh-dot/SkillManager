import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(SkillListViewModel.self) private var viewModel
    @State private var leftWidth: CGFloat = 420
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.onboardingCompleted)

    private let minLeft: CGFloat = 340
    private let maxLeft: CGFloat = 550
    private let minRight: CGFloat = 340

    var body: some View {
        @Bindable var vm = viewModel

        GeometryReader { geo in
            HStack(spacing: 0) {
                SkillListPanel()
                    .frame(width: leftWidth)

                DividerHandle()
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                let proposed = leftWidth + value.translation.width
                                let rightAvailable = geo.size.width - proposed - 6
                                if proposed >= minLeft && proposed <= maxLeft && rightAvailable >= minRight {
                                    leftWidth = proposed
                                }
                            }
                    )

                SkillDetailPanel()
                    .frame(minWidth: minRight)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !viewModel.skillsWithUpdates.isEmpty {
                    Button {
                        Task { await viewModel.updateAll() }
                    } label: {
                        Label("Update All (\(viewModel.skillsWithUpdates.count))", systemImage: "arrow.down.circle.fill")
                    }
                    .tint(.orange)
                }

                Button {
                    Task { await viewModel.checkForUpdates() }
                } label: {
                    Label("Check Updates", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isCheckingUpdates)

                Button {
                    viewModel.showFindSheet = true
                } label: {
                    Label("Find Skills", systemImage: "magnifyingglass")
                }

                Button {
                    viewModel.showAddSheet = true
                } label: {
                    Label("Add Skill", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $vm.showAddSheet) {
            AddSkillSheet {
                Task { await viewModel.loadSkills() }
            }
        }
        .sheet(isPresented: $vm.showFindSheet) {
            FindSkillSheet {
                Task { await viewModel.loadSkills() }
            }
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .task {
            await viewModel.loadSkills()
        }
    }
}

struct DividerHandle: View {
    @State private var isHovering = false

    var body: some View {
        Rectangle()
            .fill(isHovering ? Color.accentColor.opacity(0.3) : Color.clear)
            .frame(width: 6)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 1)
                    .fill(.separator)
                    .frame(width: 1)
            }
    }
}

struct SkillListPanel: View {
    @Environment(SkillListViewModel.self) private var viewModel

    var body: some View {
        @Bindable var vm = viewModel

        VStack(spacing: 0) {
            HStack {
                Text("Skills")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.filteredSkills.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                TextField("Search", text: $vm.searchText)
                    .textFieldStyle(.roundedBorder)
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            List(viewModel.filteredSkills, selection: $vm.selectedSkillID) { skill in
                SkillRowView(
                    skill: skill,
                    isSelected: viewModel.selectedSkillID == skill.id,
                    isUpdating: viewModel.updatingSkillID == skill.id,
                    updateProgress: viewModel.updatingSkillID == skill.id ? viewModel.updateProgress : 0
                )
                    .tag(skill.id)
                    .listRowSeparator(.visible)
                    .contextMenu {
                        if case .updateAvailable = skill.updateStatus {
                            Button {
                                Task { await viewModel.updateSkill(skill) }
                            } label: {
                                Label("Update", systemImage: "arrow.down.circle")
                            }
                        }

                        Button {
                            viewModel.revealInFinder(skill)
                        } label: {
                            Label("Reveal in Finder", systemImage: "folder")
                        }

                        if skill.repoURL != nil {
                            Button {
                                viewModel.openInGitHub(skill)
                            } label: {
                                Label("Open in GitHub", systemImage: "link")
                            }
                        }

                        Divider()

                        Button(role: .destructive) {
                            Task { await viewModel.removeSkill(skill) }
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                } else if viewModel.skills.isEmpty {
                    ContentUnavailableView {
                        Label("No Skills", systemImage: "puzzlepiece")
                    } description: {
                        Text("Click + to add skills.")
                    }
                }
            }
        }
        .background(.background)
    }
}

struct SkillDetailPanel: View {
    @Environment(SkillListViewModel.self) private var viewModel

    var body: some View {
        Group {
            if let skill = viewModel.selectedSkill {
                SkillDetailView(skill: skill)
            } else {
                EmptyStateView()
            }
        }
        .background(.background)
    }
}
