import Foundation
import MoriCore
import MoriTmux

/// Context passed to hook actions, providing environment variables.
struct HookContext: Sendable {
    let projectName: String
    let worktreeName: String
    let sessionName: String
    let windowName: String
    let cwd: String
}

/// Timeout for shell hook actions in seconds.
private let hookShellTimeout: TimeInterval = 10

/// Reads per-project `.mori/hooks.json`, caches configs, and fires hook actions
/// (shell commands and tmuxSend) on lifecycle events.
@MainActor
final class HookRunner {

    private let tmuxBackend: TmuxBackend

    /// Cached config per project root path, with timestamp for invalidation.
    private var cache: [String: CacheEntry] = [:]

    /// Cache entry: parsed config + load time.
    private struct CacheEntry {
        let config: HookConfig
        let loadedAt: Date
    }

    /// Cache TTL in seconds.
    private static let cacheTTL: TimeInterval = 60

    init(tmuxBackend: TmuxBackend) {
        self.tmuxBackend = tmuxBackend
    }

    /// Invalidate the cache for a specific project path, or all if nil.
    func invalidateCache(forProjectPath path: String? = nil) {
        if let path {
            cache.removeValue(forKey: path)
        } else {
            cache.removeAll()
        }
    }

    /// Fire all actions matching the given event for a project at the given root path.
    func fire(event: HookEvent, context: HookContext, projectRootPath: String) {
        let config = loadConfig(forProjectAt: projectRootPath)
        let actions = config.actions(for: event)
        guard !actions.isEmpty else { return }

        let capturedContext = context
        let capturedBackend = tmuxBackend

        for action in actions {
            if let shell = action.shell, !shell.isEmpty {
                Task.detached {
                    await HookRunner.executeShell(
                        command: shell,
                        context: capturedContext
                    )
                }
            }
            if let keys = action.tmuxSend, !keys.isEmpty {
                Task.detached {
                    await HookRunner.executeTmuxSend(
                        keys: keys,
                        context: capturedContext,
                        backend: capturedBackend
                    )
                }
            }
        }
    }

    // MARK: - Config Loading

    /// Load and cache the hook config for a project. Returns empty config on failure.
    private func loadConfig(forProjectAt projectRootPath: String) -> HookConfig {
        let now = Date()

        // Check cache
        if let entry = cache[projectRootPath],
           now.timeIntervalSince(entry.loadedAt) < Self.cacheTTL {
            return entry.config
        }

        // Load from disk
        let hooksPath = (projectRootPath as NSString)
            .appendingPathComponent(".mori/hooks.json")

        guard FileManager.default.fileExists(atPath: hooksPath) else {
            let empty = HookConfig()
            cache[projectRootPath] = CacheEntry(config: empty, loadedAt: now)
            return empty
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: hooksPath))
            let config = try JSONDecoder().decode(HookConfig.self, from: data)
            cache[projectRootPath] = CacheEntry(config: config, loadedAt: now)
            return config
        } catch {
            print("[HookRunner] Warning: failed to parse \(hooksPath): \(error)")
            let empty = HookConfig()
            cache[projectRootPath] = CacheEntry(config: empty, loadedAt: now)
            return empty
        }
    }

    // MARK: - Action Execution

    /// Execute a shell command with environment variables from context.
    /// Fire-and-forget with timeout.
    private nonisolated static func executeShell(
        command: String,
        context: HookContext
    ) async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = URL(fileURLWithPath: context.cwd)
        process.environment = ProcessInfo.processInfo.environment.merging([
            "MORI_PROJECT": context.projectName,
            "MORI_WORKTREE": context.worktreeName,
            "MORI_SESSION": context.sessionName,
            "MORI_CWD": context.cwd,
            "MORI_WINDOW": context.windowName,
        ]) { _, new in new }

        do {
            try process.run()
        } catch {
            print("[HookRunner] Warning: failed to run shell command: \(error)")
            return
        }

        // Wait with timeout using structured concurrency
        let sendableProcess = SendableProcess(process)
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    // Wait for process completion on a background thread
                    while sendableProcess.process.isRunning {
                        try Task.checkCancellation()
                        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                    }
                }
                group.addTask {
                    // Timeout
                    try await Task.sleep(nanoseconds: UInt64(hookShellTimeout * 1_000_000_000))
                    sendableProcess.process.terminate()
                    print("[HookRunner] Warning: shell command timed out: \(command)")
                }
                // Wait for first to complete, cancel the other
                _ = try await group.next()
                group.cancelAll()
            }
        } catch {
            // Task cancellation or other error — ensure process is killed
            if sendableProcess.process.isRunning {
                sendableProcess.process.terminate()
            }
        }
    }

    /// Send keys to the active tmux pane via the backend.
    private nonisolated static func executeTmuxSend(
        keys: String,
        context: HookContext,
        backend: TmuxBackend
    ) async {
        do {
            try await backend.sendKeys(
                sessionId: context.sessionName,
                paneId: "",
                keys: keys
            )
        } catch {
            print("[HookRunner] Warning: failed to send tmux keys: \(error)")
        }
    }
}

/// Wrapper to make Process reference sendable across isolation boundaries.
private final class SendableProcess: @unchecked Sendable {
    let process: Process
    init(_ process: Process) {
        self.process = process
    }
}
