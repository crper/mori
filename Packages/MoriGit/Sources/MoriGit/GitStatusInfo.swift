import Foundation

/// Parsed information from `git status --porcelain=v2 --branch`.
public struct GitStatusInfo: Equatable, Sendable {
    /// Whether the working tree has any uncommitted changes (staged, modified, or untracked).
    public var isDirty: Bool {
        stagedCount > 0 || modifiedCount > 0 || untrackedCount > 0
    }

    /// Number of untracked files.
    public let untrackedCount: Int

    /// Number of files with unstaged modifications.
    public let modifiedCount: Int

    /// Number of staged (index) changes.
    public let stagedCount: Int

    /// Number of commits ahead of upstream.
    public let ahead: Int

    /// Number of commits behind upstream.
    public let behind: Int

    /// Current branch name (from `# branch.head`).
    public let branch: String?

    /// Upstream branch name (from `# branch.upstream`).
    public let upstream: String?

    public init(
        untrackedCount: Int = 0,
        modifiedCount: Int = 0,
        stagedCount: Int = 0,
        ahead: Int = 0,
        behind: Int = 0,
        branch: String? = nil,
        upstream: String? = nil
    ) {
        self.untrackedCount = untrackedCount
        self.modifiedCount = modifiedCount
        self.stagedCount = stagedCount
        self.ahead = ahead
        self.behind = behind
        self.branch = branch
        self.upstream = upstream
    }

    /// A clean status with no changes, no branch info.
    public static let clean = GitStatusInfo()
}
