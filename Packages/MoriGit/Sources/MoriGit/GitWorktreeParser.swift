import Foundation

/// Parses output from `git worktree list --porcelain`.
///
/// The porcelain format outputs entries separated by blank lines.
/// Each entry has lines like:
/// ```
/// worktree /path/to/worktree
/// HEAD abc123def456
/// branch refs/heads/main
/// ```
/// A detached HEAD entry has `detached` instead of `branch ...`.
/// A bare repository entry has `bare` instead of `branch ...`.
public enum GitWorktreeParser {

    /// Parse the full output of `git worktree list --porcelain`.
    public static func parse(_ output: String) -> [GitWorktreeInfo] {
        guard !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        // Split into blocks separated by blank lines
        let blocks = splitIntoBlocks(output)

        return blocks.compactMap { block in
            parseBlock(block)
        }
    }

    // MARK: - Private

    /// Split the output into blocks separated by blank lines.
    private static func splitIntoBlocks(_ output: String) -> [[String]] {
        var blocks: [[String]] = []
        var currentBlock: [String] = []

        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if !currentBlock.isEmpty {
                    blocks.append(currentBlock)
                    currentBlock = []
                }
            } else {
                currentBlock.append(trimmed)
            }
        }

        // Don't forget the last block if there's no trailing newline
        if !currentBlock.isEmpty {
            blocks.append(currentBlock)
        }

        return blocks
    }

    /// Parse a single worktree block into a GitWorktreeInfo.
    private static func parseBlock(_ lines: [String]) -> GitWorktreeInfo? {
        var path: String?
        var head: String?
        var branch: String?
        var isDetached = false
        var isBare = false

        for line in lines {
            if line.hasPrefix("worktree ") {
                path = String(line.dropFirst("worktree ".count))
            } else if line.hasPrefix("HEAD ") {
                head = String(line.dropFirst("HEAD ".count))
            } else if line.hasPrefix("branch ") {
                branch = String(line.dropFirst("branch ".count))
            } else if line == "detached" {
                isDetached = true
            } else if line == "bare" {
                isBare = true
            }
        }

        guard let path, let head else {
            return nil
        }

        return GitWorktreeInfo(
            path: path,
            head: head,
            branch: branch,
            isDetached: isDetached,
            isBare: isBare
        )
    }
}
