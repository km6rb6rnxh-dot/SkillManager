import SwiftUI

struct SkillRowView: View {
    let skill: Skill
    var isSelected: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "puzzlepiece.fill")
                    .font(.caption)
                    .foregroundStyle(.tint)

                Text(skill.id)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                updateBadge

                Spacer(minLength: 4)

                environmentBadges
            }

            HStack(spacing: 8) {
                Text(skill.ownerRepo)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if let date = skill.updateDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .foregroundStyle(.tertiary)
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private var updateBadge: some View {
        switch skill.updateStatus {
        case .checking:
            ProgressView()
                .controlSize(.mini)
        case .updateAvailable:
            Text("UPDATE")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(AppTheme.warningOrange, in: Capsule())
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.yellow)
        case .upToDate:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(AppTheme.successGreen)
        case .unknown:
            EmptyView()
        }
    }

    private var environmentBadges: some View {
        HStack(spacing: 3) {
            if skill.environment.code {
                Text("Code")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isSelected ? .white : AppTheme.skillBlue)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        (isSelected ? Color.white : AppTheme.skillBlue).opacity(0.2),
                        in: Capsule()
                    )
            }
            if skill.environment.cowork {
                Text("Cowork")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isSelected ? .white : AppTheme.coworkPurple)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        (isSelected ? Color.white : AppTheme.coworkPurple).opacity(0.2),
                        in: Capsule()
                    )
            }
        }
    }
}
