import Foundation

/// Runtime model representing a parsed tmux pane.
public struct TmuxPane: Identifiable, Equatable, Sendable {
    public var id: String { paneId }
    public let paneId: String
    public let tty: String?
    public let isActive: Bool
    public let currentPath: String?
    public let title: String?
    /// Unix timestamp (seconds since epoch) of last pane activity, from `#{pane_activity}`.
    public let lastActivity: TimeInterval?
    /// The current command running in the pane, from `#{pane_current_command}`.
    public let currentCommand: String?
    /// Unix timestamp (seconds since epoch) of when the pane's current command started, from `#{pane_start_time}`.
    public let startTime: TimeInterval?

    public init(
        paneId: String,
        tty: String? = nil,
        isActive: Bool = false,
        currentPath: String? = nil,
        title: String? = nil,
        lastActivity: TimeInterval? = nil,
        currentCommand: String? = nil,
        startTime: TimeInterval? = nil
    ) {
        self.paneId = paneId
        self.tty = tty
        self.isActive = isActive
        self.currentPath = currentPath
        self.title = title
        self.lastActivity = lastActivity
        self.currentCommand = currentCommand
        self.startTime = startTime
    }
}
