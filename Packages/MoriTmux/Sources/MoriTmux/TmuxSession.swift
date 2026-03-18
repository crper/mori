import Foundation

/// Runtime model representing a parsed tmux session.
/// Kept separate from MoriCore models; mapping happens at a higher layer.
public struct TmuxSession: Identifiable, Equatable, Sendable {
    public var id: String { sessionId }
    public let sessionId: String
    public let name: String
    public let windowCount: Int
    public let isAttached: Bool
    public var windows: [TmuxWindow]

    public init(
        sessionId: String,
        name: String,
        windowCount: Int = 0,
        isAttached: Bool = false,
        windows: [TmuxWindow] = []
    ) {
        self.sessionId = sessionId
        self.name = name
        self.windowCount = windowCount
        self.isAttached = isAttached
        self.windows = windows
    }

    /// Whether this session follows the Mori naming convention `<project>/<branch>`.
    public var isMoriSession: Bool {
        SessionNaming.isMoriSession(name)
    }

    /// Extract the project short name from a Mori session name.
    public var projectShortName: String? {
        SessionNaming.parse(name)?.projectShortName
    }

    /// Extract the branch slug from a Mori session name.
    public var branchSlug: String? {
        SessionNaming.parse(name)?.branchSlug
    }
}
