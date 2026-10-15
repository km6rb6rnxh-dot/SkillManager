import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0

    private let steps: [OnboardingStep] = [
        OnboardingStep(
            icon: "puzzlepiece.extension.fill",
            iconColor: .accentColor,
            title: "Welcome to SkillManager",
            subtitle: "Manage Claude Code and Cowork skills\nwithout touching the terminal.",
            details: [
                .init(icon: "magnifyingglass", text: "Find skills on GitHub"),
                .init(icon: "arrow.down.circle", text: "Install and update with one click"),
                .init(icon: "slider.horizontal.3", text: "Choose where each skill is active"),
            ]
        ),
        OnboardingStep(
            icon: "rectangle.topthird.inset.filled",
            iconColor: .secondary,
            title: "The Toolbar",
            subtitle: "All main actions live in the toolbar\nat the top of the window.",
            details: [
                .init(icon: "magnifyingglass", text: "Find Skills — search GitHub for skills and resources"),
                .init(icon: "plus", text: "Add Skill — install from a specific GitHub repo"),
                .init(icon: "arrow.clockwise", text: "Check Updates — see if newer versions are available"),
                .init(icon: "arrow.down.circle.fill", text: "Update All — update every skill at once"),
            ]
        ),
        OnboardingStep(
            icon: "magnifyingglass.circle.fill",
            iconColor: .blue,
            title: "Finding Skills",
            subtitle: "Search by name or keyword.\nResults include two types:",
            details: [
                .init(icon: "puzzlepiece.fill", color: .blue, text: "Skills — ready to use, have a SKILL.md"),
                .init(icon: "doc.text.fill", color: .orange, text: "Resources — content repos, SKILL.md is generated"),
                .init(icon: "terminal", color: .blue, text: "Choose to install for Claude Code, Cowork, or both"),
            ]
        ),
        OnboardingStep(
            icon: "circle.lefthalf.filled",
            iconColor: .purple,
            title: "Themes",
            subtitle: "SkillManager supports light and dark mode.",
            details: [
                .init(icon: "gear", text: "Open Settings (⌘,) to change theme"),
                .init(icon: "sun.max", text: "Light — clean liquid glass appearance"),
                .init(icon: "moon", text: "Dark — comfortable for night sessions"),
                .init(icon: "laptopcomputer", text: "System — follows your Mac settings"),
            ]
        ),
        OnboardingStep(
            icon: "key.fill",
            iconColor: .orange,
            title: "GitHub Token",
            subtitle: "A token unlocks better search results\nand higher API limits.",
            details: [
                .init(icon: "1.circle", text: "Go to GitHub → Settings → Developer settings"),
                .init(icon: "2.circle", text: "Create a Personal Access Token (fine-grained)"),
                .init(icon: "3.circle", text: "No special permissions needed — public repos only"),
                .init(icon: "4.circle", text: "Paste it in Settings → GitHub → Save"),
            ]
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Content
            TabView(selection: $currentStep) {
                ForEach(steps.indices, id: \.self) { index in
                    stepView(steps[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.automatic)
            .frame(height: 340)

            Divider()

            // Footer
            HStack {
                // Dots
                HStack(spacing: 6) {
                    ForEach(steps.indices, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 7, height: 7)
                            .onTapGesture { withAnimation { currentStep = index } }
                    }
                }

                Spacer()

                if currentStep > 0 {
                    Button("Back") {
                        withAnimation { currentStep -= 1 }
                    }
                    .controlSize(.small)
                }

                if currentStep < steps.count - 1 {
                    Button("Next") {
                        withAnimation { currentStep += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else {
                    Button("Get Started") {
                        UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.onboardingCompleted)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(.bar)
        }
        .frame(width: 480, height: 420)
        .background(.background)
    }

    private func stepView(_ step: OnboardingStep) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: step.icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(step.iconColor)
                .frame(height: 50)

            Text(step.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(step.subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(step.details) { detail in
                    HStack(spacing: 10) {
                        Image(systemName: detail.icon)
                            .font(.system(size: 13))
                            .foregroundStyle(detail.color ?? .secondary)
                            .frame(width: 20, alignment: .center)
                        Text(detail.text)
                            .font(.callout)
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 4)

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

private struct OnboardingStep {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let details: [Detail]

    struct Detail: Identifiable {
        let id = UUID()
        let icon: String
        var color: Color? = nil
        let text: String
    }
}
