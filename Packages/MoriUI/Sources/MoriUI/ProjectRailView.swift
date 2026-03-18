import SwiftUI
import MoriCore

/// Narrow rail displaying projects as first-letter circle icons with names,
/// plus action buttons at the bottom.
public struct ProjectRailView: View {
    private let projects: [Project]
    private let selectedProjectId: UUID?
    private let onSelect: (UUID) -> Void
    private let onAddProject: (() -> Void)?
    private let onOpenSettings: (() -> Void)?
    private let onToggleSidebar: (() -> Void)?

    public init(
        projects: [Project],
        selectedProjectId: UUID?,
        onSelect: @escaping (UUID) -> Void,
        onAddProject: (() -> Void)? = nil,
        onOpenSettings: (() -> Void)? = nil,
        onToggleSidebar: (() -> Void)? = nil
    ) {
        self.projects = projects
        self.selectedProjectId = selectedProjectId
        self.onSelect = onSelect
        self.onAddProject = onAddProject
        self.onOpenSettings = onOpenSettings
        self.onToggleSidebar = onToggleSidebar
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical) {
                LazyVStack(spacing: MoriTokens.Spacing.lg) {
                    ForEach(projects) { project in
                        ProjectRailRow(
                            project: project,
                            isSelected: project.id == selectedProjectId,
                            onSelect: { onSelect(project.id) }
                        )
                    }
                }
                .padding(.vertical, MoriTokens.Spacing.lg)
            }

            Spacer(minLength: 0)

            railFooter
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var railFooter: some View {
        VStack(spacing: MoriTokens.Spacing.lg) {
            Divider()

            if let onToggleSidebar {
                Button(action: onToggleSidebar) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: MoriTokens.Size.avatarFont))
                        .foregroundStyle(MoriTokens.Color.muted)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .help("Toggle Sidebar (⌘0)")
                .accessibilityLabel("Toggle Sidebar")
            }

            if let onAddProject {
                Button(action: onAddProject) {
                    Image(systemName: "plus.rectangle.on.folder")
                        .font(.system(size: MoriTokens.Size.avatarFont))
                        .foregroundStyle(MoriTokens.Color.muted)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .help("Add Project")
                .accessibilityLabel("Add Project")
            }

            if let onOpenSettings {
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: MoriTokens.Size.avatarFont))
                        .foregroundStyle(MoriTokens.Color.muted)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .help("Settings (⌘,)")
                .accessibilityLabel("Settings")
            }
        }
        .padding(.bottom, MoriTokens.Spacing.lg)
    }
}

// MARK: - Row

private struct ProjectRailRow: View {
    let project: Project
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: MoriTokens.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(isSelected ? MoriTokens.Color.active : MoriTokens.Color.muted.opacity(MoriTokens.Opacity.medium))
                        .frame(width: MoriTokens.Size.avatar, height: MoriTokens.Size.avatar)

                    Text(firstLetter)
                        .font(.system(size: MoriTokens.Size.avatarFont, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                }

                Text(project.name)
                    .font(MoriTokens.Font.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(isSelected ? MoriTokens.Color.active : MoriTokens.Color.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, MoriTokens.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var firstLetter: String {
        String(project.name.prefix(1)).uppercased()
    }
}
