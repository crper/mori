import SwiftUI
import MoriCore

/// A row representing a single tmux window within a worktree section.
public struct WindowRowView: View {
    let window: RuntimeWindow
    let isActive: Bool
    let onSelect: () -> Void

    public init(
        window: RuntimeWindow,
        isActive: Bool,
        onSelect: @escaping () -> Void
    ) {
        self.window = window
        self.isActive = isActive
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                Image(systemName: window.tag?.symbolName ?? "terminal")
                    .font(.caption)
                    .foregroundStyle(isActive ? Color.accentColor : .secondary)

                Text(window.title.isEmpty ? "Window \(window.tmuxWindowIndex)" : window.title)
                    .font(.body)
                    .lineLimit(1)

                Spacer()

                windowBadgeView

                if isActive {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isActive ? Color.accentColor.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    @ViewBuilder
    private var windowBadgeView: some View {
        if let badge = window.badge {
            switch badge {
            case .error:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .help("Error")
            case .waiting:
                Image(systemName: "exclamationmark.bubble.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.yellow)
                    .help("Waiting for input")
            case .longRunning:
                Image(systemName: "clock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                    .help("Long running")
            case .running:
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
                    .help("Running")
            case .unread:
                Circle()
                    .fill(Color.blue)
                    .frame(width: 6, height: 6)
                    .help("Unread output")
            case .idle:
                EmptyView()
            }
        }
    }
}
