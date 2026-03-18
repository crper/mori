# Handoff

<!-- Append a new phase section after each phase completes. -->

## Phase 1: Window Semantic Tags — COMPLETE

### Summary
Implemented window semantic tags (tasks 1.1-1.6) across 6 commits. Windows now carry a `WindowTag` enum describing their role (shell, editor, agent, server, logs, tests).

### What was done
1. **WindowTag enum** (`Packages/MoriCore/Sources/MoriCore/Models/WindowTag.swift`) — 6 cases with String raw values, SF Symbol mapping, and name-based inference heuristic.
2. **RuntimeWindow.tag** — Optional `WindowTag?` field added, default nil. Preserved across poll cycles.
3. **WindowBadge.longRunning** — New badge case mapping to `AlertState.warning`. StatusAggregator and WindowRowView updated.
4. **WindowTemplate.tag** — Templates carry explicit tags. TemplateRegistry updated: basic (shell/shell/logs), go (editor/server/tests/logs), agent (editor/agent/server/logs).
5. **Auto-assignment** — `WorkspaceManager.updateRuntimeState` and `refreshRuntimeState` infer tags from window names on first creation, preserve existing tags on subsequent polls.
6. **Sidebar + command palette** — WindowRowView icon reflects tag's SF Symbol. CommandPaletteItem.window carries tag in subtitle. `tag:<name>` prefix filtering in command palette search.
7. **Tests** — 55 new assertions (189 total MoriCore, 336 across all packages). Covers raw values, Codable, symbol names, inference, case-insensitivity, RuntimeWindow tag, longRunning badge, template tags.

### Files changed
- `Packages/MoriCore/Sources/MoriCore/Models/WindowTag.swift` (new)
- `Packages/MoriCore/Sources/MoriCore/Models/RuntimeWindow.swift`
- `Packages/MoriCore/Sources/MoriCore/Models/WindowBadge.swift`
- `Packages/MoriCore/Sources/MoriCore/Models/SessionTemplate.swift`
- `Packages/MoriCore/Sources/MoriCore/Models/TemplateRegistry.swift`
- `Packages/MoriCore/Sources/MoriCore/Models/StatusAggregator.swift`
- `Packages/MoriCore/Tests/MoriCoreTests/main.swift`
- `Packages/MoriUI/Sources/MoriUI/WindowRowView.swift`
- `Sources/Mori/App/WorkspaceManager.swift`
- `Sources/Mori/App/CommandPaletteItem.swift`
- `Sources/Mori/App/CommandPaletteDataSource.swift`
- `Sources/Mori/App/AppDelegate.swift`

### Build status
- Zero warnings under Swift 6 strict concurrency
- All 336 test assertions passing (189 core + 105 tmux + 42 persistence)

### Notes for next phase
- `WindowTag.infer(from:)` is in MoriCore, testable independently
- Tags are preserved across polls via `previousTags` lookup in WorkspaceManager
- The `tag:` prefix in command palette is case-insensitive and prefix-matches against tag raw values
- `WindowBadge.longRunning` is wired into StatusAggregator but not yet produced by any detection logic (that comes in Phase 2)

## Phase 2: Agent State Detection — COMPLETE

### Summary
Implemented agent state detection (tasks 2.1-2.7) across 7 commits. The coordinated poll now detects what's running in each pane, identifies agent states from output patterns, and assigns richer window badges.

### What was done
1. **TmuxPane extended** — Added `currentCommand` and `startTime` fields. TmuxParser pane format now includes `#{pane_current_command}` and `#{pane_start_time}`. Backward-compatible with shorter output.
2. **DetectedAgentState + PaneState** (`Packages/MoriTmux/Sources/MoriTmux/PaneState.swift`) — `DetectedAgentState` enum with String raw values mirroring MoriCore's `AgentState`. `PaneState` struct aggregates command, isRunning, isLongRunning, detectedAgentState, exitCode.
3. **PaneStateDetector** (`Packages/MoriTmux/Sources/MoriTmux/PaneStateDetector.swift`) — Static `detect(pane:capturedOutput:now:)` method. Pattern matching for waitingForInput (prompt suffixes `>`, `?`, `[Y/n]`, "Press any key", "waiting for input"), error (`error:`, `FAILED`, `panic:`, `fatal:`), completed (`Done`, `Complete`, `Finished`). Shell filtering (bash, zsh, fish, sh, -bash, -zsh). Long-running threshold 30s. Best-effort exit code parsing.
4. **capturePaneOutput** — Added to `TmuxControlling` protocol and `TmuxBackend`. Uses `tmux capture-pane -p -t <paneId> -S -<lineCount>`.
5. **Coordinated poll integration** — `WorkspaceManager.detectAgentStates` runs after tmux scan. Agent-tagged windows get full capture+detection. Non-agent windows derive running/idle from `currentCommand`. Maps `DetectedAgentState` to `AgentState`. Updates `RuntimeWindow.badge` and `Worktree.agentState`.
6. **Richer StatusAggregator** — New `windowBadge(hasUnreadOutput:isRunning:isLongRunning:agentState:)` with priority: error > waiting > longRunning > running > unread > idle.
7. **Tests** — 70 new tmux assertions (175 total), 8 new core assertions (197 total). Total: 414 across all packages.

### Files changed
- `Packages/MoriTmux/Sources/MoriTmux/TmuxPane.swift`
- `Packages/MoriTmux/Sources/MoriTmux/TmuxParser.swift`
- `Packages/MoriTmux/Sources/MoriTmux/PaneState.swift` (new)
- `Packages/MoriTmux/Sources/MoriTmux/PaneStateDetector.swift` (new)
- `Packages/MoriTmux/Sources/MoriTmux/TmuxBackend.swift`
- `Packages/MoriTmux/Sources/MoriTmux/TmuxControlling.swift`
- `Packages/MoriTmux/Tests/MoriTmuxTests/main.swift`
- `Packages/MoriCore/Sources/MoriCore/Models/StatusAggregator.swift`
- `Packages/MoriCore/Tests/MoriCoreTests/main.swift`
- `Sources/Mori/App/WorkspaceManager.swift`

### Build status
- Zero warnings under Swift 6 strict concurrency
- All 414 test assertions passing (197 core + 175 tmux + 42 persistence)

### Notes for next phase
- `PaneStateDetector.isShellProcess` and `longRunningThreshold` are public for use by WorkspaceManager
- `DetectedAgentState` raw values intentionally mirror `AgentState` for easy mapping; the separate type avoids MoriTmux depending on MoriCore
- Prompt suffix matching checks both raw line (with trailing space) and trimmed version (tmux may strip trailing whitespace)
- `Worktree.agentState` is updated with highest-priority agent state across its agent-tagged windows
- Phase 3 (Worktree Status Enhancements) should add `isRunning`, `isLongRunning`, `lastExitCode`, per-window `agentState` fields to `RuntimeWindow` and propagate from all panes, not just the active one

## Phase 3: Worktree Status Enhancements — COMPLETE

### Summary
Implemented worktree status enhancements (tasks 3.1-3.4) across 4 commits. RuntimeWindow now carries per-window runtime state fields, pane states are aggregated across all panes per window, sidebar views show distinct badge icons, and worktree agentState is properly reset each poll cycle.

### What was done
1. **RuntimeWindow enhanced fields** (`Packages/MoriCore/Sources/MoriCore/Models/RuntimeWindow.swift`) — Added `lastExitCode: Int?`, `isRunning: Bool`, `isLongRunning: Bool`, `agentState: AgentState` with sensible defaults. Fully Codable.
2. **Pane state propagation** (`Sources/Mori/App/WorkspaceManager.swift`) — `detectAgentStates` now iterates ALL panes per window (not just active), aggregating running/longRunning/agentState/exitCode. Worktree `agentState` is reset to `.none` at the start of each poll cycle before re-aggregating (fixes Phase 2 review finding). Agent-tagged windows still get full `capture-pane` detection; non-agent windows derive state from command metadata.
3. **Richer sidebar badges** — WindowRowView uses distinct SF Symbol icons: error (xmark.circle.fill, red), waiting (exclamationmark.bubble.fill, yellow), longRunning (clock.fill, orange), running (bolt.fill, green), unread (blue dot), idle (hidden). WorktreeRowView shows aggregated agent state badge.
4. **Tests** — 33 new assertions (230 total MoriCore, 447 across all packages). Covers enhanced field defaults/init/Codable, all windowBadge input combinations, worktree aggregation with running/error/longRunning badges, AlertState mapping for longRunning, interaction with git dirty status.

### Files changed
- `Packages/MoriCore/Sources/MoriCore/Models/RuntimeWindow.swift`
- `Packages/MoriCore/Tests/MoriCoreTests/main.swift`
- `Packages/MoriUI/Sources/MoriUI/WindowRowView.swift`
- `Packages/MoriUI/Sources/MoriUI/WorktreeRowView.swift`
- `Sources/Mori/App/WorkspaceManager.swift`

### Build status
- Zero warnings under Swift 6 strict concurrency
- All 447 test assertions passing (230 core + 175 tmux + 42 persistence)

### Notes for next phase
- RuntimeWindow now has per-window `agentState` — Phase 4 (Notifications) can use `NotificationDebouncer` to detect badge transitions on `RuntimeWindow.badge`
- Worktree `agentState` resets each poll cycle and re-aggregates — no stale state accumulation
- Sidebar badge icons are SF Symbols — consistent with macOS design language
- `lastExitCode` is best-effort (only populated for agent-tagged windows via output pattern matching)

## Phase 4: Notifications — COMPLETE

### Summary
Implemented macOS notifications for badge state transitions (tasks 4.1-4.6) across 6 commits. The app now fires native notifications when windows transition to attention-worthy states and displays an aggregate unread count on the dock badge.

### What was done
1. **NotificationDebouncer** (`Packages/MoriCore/Sources/MoriCore/Models/NotificationDebouncer.swift`) — Pure-logic struct in MoriCore that detects notification-worthy badge transitions (idle/running->waiting = agentWaiting, any->error = commandError, running/longRunning->idle = longRunningComplete). Suppresses re-fire for same window+event within 30s. Fully testable without UNUserNotificationCenter.
2. **NotificationManager** (`Sources/Mori/App/NotificationManager.swift`) — UNUserNotificationCenter wrapper. Requests permission on first use. Posts notifications with windowId/worktreeId in userInfo. Sets up notification category for click handling.
3. **WorkspaceManager wiring** — Stores `previousBadges: [String: WindowBadge]` dictionary and `NotificationDebouncer` instance. After badge updates in `coordinatedPoll`, compares with previous badges and fires notifications for approved transitions.
4. **Dock badge** — `updateDockBadge()` method computes total unread across all projects via `NSApp.dockTile.badgeLabel`. Called at end of `coordinatedPoll` and `clearUnread`.
5. **Notification click handling** — AppDelegate conforms to `UNUserNotificationCenterDelegate`. On click, extracts windowId from userInfo, brings app to front via `NSApp.activate`, and calls `selectWindow` to focus the relevant pane. Banners show even when app is in foreground.
6. **Tests** — 22 new assertions (252 total MoriCore, 469 across all packages). Covers state transitions, debounce suppression within 30s, non-transitions, multiple independent windows, nil old badge handling, NotificationEvent raw values, error->idle non-trigger.

### Files changed
- `Packages/MoriCore/Sources/MoriCore/Models/NotificationDebouncer.swift` (new)
- `Packages/MoriCore/Tests/MoriCoreTests/main.swift`
- `Sources/Mori/App/NotificationManager.swift` (new)
- `Sources/Mori/App/WorkspaceManager.swift`
- `Sources/Mori/App/AppDelegate.swift`

### Build status
- Zero warnings under Swift 6 strict concurrency
- All 469 test assertions passing (252 core + 175 tmux + 42 persistence)

### Notes for next phase
- `NotificationDebouncer` is a value type (struct) — mutating methods track state; lives on WorkspaceManager
- Notification permission is requested lazily on first notification attempt
- `UNUserNotificationCenterDelegate` is set in `applicationDidFinishLaunching` before any notifications fire
- Dock badge clears automatically when all unread counts reach zero
- The `willPresent` delegate method allows banners to display even when the app is in the foreground

## Phase 5: CLI / IPC Interface -- COMPLETE

### Summary
Implemented the CLI/IPC interface (tasks 5.1-5.8) across 6 commits. The Mori app now exposes a Unix domain socket for automation, and a `ws` CLI executable communicates with the running app.

### What was done
1. **MoriIPC package** (`Packages/MoriIPC/`) -- New SPM package with no dependencies on other Mori packages. Contains shared protocol types, server, and client.
2. **IPC protocol** (`Packages/MoriIPC/Sources/MoriIPC/IPCProtocol.swift`) -- `IPCCommand` enum (6 variants: projectList, worktreeCreate, focus, send, newWindow, open). `IPCRequest`/`IPCResponse`/`IPCResponseEnvelope` wire format. `IPCFraming` utilities for newline-delimited JSON encoding/decoding/splitting.
3. **IPCServer** (`Packages/MoriIPC/Sources/MoriIPC/IPCServer.swift`) -- Actor-based server using `NWListener` with Unix domain socket at `~/Library/Application Support/Mori/mori.sock`. Accepts connections, reads newline-delimited JSON, dispatches to async handler callback. Cleans up socket file on stop.
4. **IPCClient** (`Packages/MoriIPC/Sources/MoriIPC/IPCClient.swift`) -- `NWConnection`-based client with async `send()` and synchronous `sendSync()` APIs. Uses `ContinuationBox` for thread-safe one-shot resumption and `ResultBox` for semaphore bridge. 5s timeout.
5. **`ws` CLI** (`Sources/WS/WS.swift`) -- Executable target using swift-argument-parser. Subcommands: `ws project list`, `ws worktree create`, `ws focus`, `ws send`, `ws new-window`, `ws open`. Each maps args to `IPCRequest`, sends via `IPCClient`, prints JSON result.
6. **App integration** -- IPCServer starts in `applicationDidFinishLaunching`, stops in `applicationWillTerminate`. `IPCHandler` dispatches requests to `@MainActor WorkspaceManager` methods.
7. **IPC command wiring** (`Sources/Mori/App/IPCHandler.swift`) -- All 6 commands wired: projectList returns JSON array, worktreeCreate finds project and calls createWorktree, focus selects project+worktree, send finds session/window and sends keys, newWindow creates window in session, open adds project from path. Case-insensitive name matching throughout.
8. **Tests** -- 39 new assertions. Round-trip encoding/decoding for all command variants, request/response/envelope. Framing: split single/multiple/incomplete/empty messages.

### Files changed
- `Packages/MoriIPC/Package.swift` (new)
- `Packages/MoriIPC/Sources/MoriIPC/IPCProtocol.swift` (new)
- `Packages/MoriIPC/Sources/MoriIPC/IPCServer.swift` (new)
- `Packages/MoriIPC/Sources/MoriIPC/IPCClient.swift` (new)
- `Packages/MoriIPC/Tests/MoriIPCTests/Assert.swift` (new)
- `Packages/MoriIPC/Tests/MoriIPCTests/main.swift` (new)
- `Package.swift` (added MoriIPC dep, swift-argument-parser dep, WS target)
- `Sources/WS/WS.swift` (new)
- `Sources/Mori/App/IPCHandler.swift` (new)
- `Sources/Mori/App/AppDelegate.swift` (IPC server start/stop)
- `mise.toml` (added test:ipc task)

### Build status
- Zero warnings under Swift 6 strict concurrency
- All 508 test assertions passing (252 core + 175 tmux + 42 persistence + 39 IPC)

### Notes for next phase
- IPCServer socket path is `~/Library/Application Support/Mori/mori.sock` (same dir as SQLite DB)
- `IPCHandler` uses case-insensitive name matching for projects and worktrees
- `IPCClient.sendSync()` uses a semaphore+ResultBox pattern safe under Swift 6 strict concurrency
- The `ws` CLI uses `@main` attribute with `ParsableCommand` -- no separate `main.swift` needed
- `IPCResponseEnvelope` wraps `IPCResponse` + `requestId` for wire format; the `IPCResponse` enum itself doesn't carry the ID
- `send` command sends keys to a window by name; it uses the window's tmux ID as the pane target (works for single-pane windows; multi-pane targeting may need enhancement later)
- Network.framework `NWListener` with Unix domain socket requires the endpoint to be set via `parameters.requiredLocalEndpoint`

## Phase 6: Automation Hooks -- COMPLETE

### Summary
Implemented per-project automation hooks (tasks 6.1-6.6) across 4 commits. Projects can now define lifecycle hooks in `.mori/hooks.json` that fire shell commands or send tmux keys on worktree/window create, focus, and close events.

### What was done
1. **HookConfig schema** (`Packages/MoriCore/Sources/MoriCore/Models/HookConfig.swift`) -- `HookEvent` enum (6 lifecycle events), `HookAction` struct (shell + tmuxSend), `HookEntry` struct, `HookConfig` struct with `actions(for:)` lookup. All Codable + Sendable.
2. **HookRunner** (`Sources/Mori/App/HookRunner.swift`) -- `@MainActor` class that reads `.mori/hooks.json` from project root. Caches parsed config per project with 60s TTL. Graceful failure on parse errors (logs warning, returns empty config). `HookContext` struct carries MORI_* env vars.
3. **Shell execution** -- Shell actions run via `Process("/bin/zsh", "-c", command)` with env vars (MORI_PROJECT, MORI_WORKTREE, MORI_SESSION, MORI_CWD, MORI_WINDOW). Non-blocking via `Task.detached` with 10s timeout using structured concurrency. `tmuxSend` actions forward keys via `TmuxBackend.sendKeys`.
4. **WorkspaceManager wiring** -- `hookRunner` property initialized with tmuxBackend. Hooks fire at 6 lifecycle points: `onWorktreeCreate` (after createWorktree), `onWorktreeFocus` (after selectWorktree), `onWorktreeClose` (before removeWorktree cleanup), `onWindowCreate` (after createNewWindow), `onWindowFocus` (after selectWindow), `onWindowClose` (before closeCurrentWindow kill). Helper methods `buildHookContext` and `fireHook` centralize context creation.
5. **Tests** -- 45 new assertions (297 total MoriCore, 553 across all packages). Covers event raw values, Codable round-trips, action variants (shell/tmuxSend/both), full JSON decode, actions(for:) matching and aggregation, empty config, invalid JSON handling, entry filtering by event.

### Files changed
- `Packages/MoriCore/Sources/MoriCore/Models/HookConfig.swift` (new)
- `Packages/MoriCore/Tests/MoriCoreTests/main.swift`
- `Sources/Mori/App/HookRunner.swift` (new)
- `Sources/Mori/App/WorkspaceManager.swift`

### Build status
- Zero warnings under Swift 6 strict concurrency
- All 553 test assertions passing (297 core + 175 tmux + 42 persistence + 39 IPC)

### Notes
- Hook config file path: `<project-root>/.mori/hooks.json`
- Cache invalidation: automatic after 60s TTL, or explicit via `hookRunner.invalidateCache()`
- Shell timeout: 10 seconds; process is terminated if it exceeds this
- `tmuxSend` uses empty paneId to target the active pane in the session
- `SendableProcess` wrapper bridges `Process` across isolation boundaries
- Module-level `hookShellTimeout` constant avoids `@MainActor` isolation issues in static methods
- All hooks are fire-and-forget; failures are logged but don't propagate errors
