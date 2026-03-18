import Foundation
import MoriCore
import MoriTmux

/// Applies a `SessionTemplate` to an existing tmux session by creating windows
/// and optionally sending commands. The first window in the template reuses
/// the session's default window (renaming it); subsequent windows are created.
struct TemplateApplicator: Sendable {

    private let tmux: TmuxBackend

    init(tmux: TmuxBackend) {
        self.tmux = tmux
    }

    /// Apply a template to the session identified by `sessionId`.
    /// The session must already exist and have at least one default window.
    /// - Parameters:
    ///   - template: The session template to apply.
    ///   - sessionId: The tmux session ID (e.g. "$0") or session name.
    ///   - cwd: Working directory for new windows.
    func apply(template: SessionTemplate, sessionId: String, cwd: String) async throws {
        guard !template.windows.isEmpty else { return }

        // Fetch the session's current windows to find the default (first) window.
        let sessions = try await tmux.scanAll()
        guard let session = sessions.first(where: {
            $0.sessionId == sessionId || $0.name == sessionId
        }) else { return }

        let effectiveSessionId = session.name

        // First template window: rename the existing default window.
        let firstTemplate = template.windows[0]
        if let defaultWindow = session.windows.first {
            try await tmux.renameWindow(
                sessionId: effectiveSessionId,
                windowId: defaultWindow.windowId,
                newName: firstTemplate.name
            )
            if let command = firstTemplate.command,
               let pane = defaultWindow.panes.first {
                try await tmux.sendKeys(
                    sessionId: effectiveSessionId,
                    paneId: pane.paneId,
                    keys: command
                )
            }
        }

        // Remaining template windows: create new windows.
        for windowTemplate in template.windows.dropFirst() {
            let newWindow = try await tmux.createWindow(
                sessionId: effectiveSessionId,
                name: windowTemplate.name,
                cwd: cwd
            )
            if let command = windowTemplate.command {
                // Use the window ID as target — tmux sends to the active pane
                // of that window, which is the only pane in a freshly created window.
                try await tmux.sendKeys(
                    sessionId: effectiveSessionId,
                    paneId: newWindow.windowId,
                    keys: command
                )
            }
        }

        // Select the first window so the user starts there.
        if let defaultWindow = session.windows.first {
            try? await tmux.selectWindow(
                sessionId: effectiveSessionId,
                windowId: defaultWindow.windowId
            )
        }
    }
}
