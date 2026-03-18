import SwiftUI
import MoriCore

/// A row representing a single worktree, displayed as a section header.
public struct WorktreeRowView: View {
    let worktree: Worktree
    let isSelected: Bool
    let onSelect: () -> Void

    public init(
        worktree: Worktree,
        isSelected: Bool,
        onSelect: @escaping () -> Void
    ) {
        self.worktree = worktree
        self.isSelected = isSelected
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(worktree.branch ?? worktree.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                gitStatusBadges

                alertBadgeView

                statusIndicator
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Git Status Badges

    @ViewBuilder
    private var gitStatusBadges: some View {
        HStack(spacing: 4) {
            // Dirty indicator (uncommitted changes)
            if worktree.hasUncommittedChanges {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
                    .help("Uncommitted changes")
            }

            // Ahead/behind counts
            if worktree.aheadCount > 0 {
                HStack(spacing: 1) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 8))
                    Text("\(worktree.aheadCount)")
                        .font(.system(size: 10, design: .monospaced))
                }
                .foregroundStyle(.green)
                .help("\(worktree.aheadCount) ahead of upstream")
            }

            if worktree.behindCount > 0 {
                HStack(spacing: 1) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 8))
                    Text("\(worktree.behindCount)")
                        .font(.system(size: 10, design: .monospaced))
                }
                .foregroundStyle(.red)
                .help("\(worktree.behindCount) behind upstream")
            }

            // Unread count badge
            if worktree.unreadCount > 0 {
                Text("\(worktree.unreadCount)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.blue))
                    .help("\(worktree.unreadCount) unread")
            }
        }
    }

    // MARK: - Alert Badge

    @ViewBuilder
    private var alertBadgeView: some View {
        switch worktree.agentState {
        case .error:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.red)
                .help("Agent error")
        case .waitingForInput:
            Image(systemName: "exclamationmark.bubble.fill")
                .font(.system(size: 10))
                .foregroundStyle(.yellow)
                .help("Agent waiting for input")
        case .running:
            Image(systemName: "bolt.fill")
                .font(.system(size: 10))
                .foregroundStyle(.green)
                .help("Agent running")
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.green)
                .help("Agent completed")
        case .none:
            EmptyView()
        }
    }

    // MARK: - Status Indicator

    @ViewBuilder
    private var statusIndicator: some View {
        switch worktree.status {
        case .active:
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
        case .inactive:
            Circle()
                .fill(Color.gray)
                .frame(width: 8, height: 8)
        case .unavailable:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
        }
    }
}
