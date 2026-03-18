# Phase 3: Agent-first — Task Checklist

## Phase 1: Window Semantic Tags
- [x] 1.1 — Create `WindowTag` enum in MoriCore
- [x] 1.2 — Add `tag` to `RuntimeWindow`, add `.longRunning` to `WindowBadge`
- [x] 1.3 — Add `tag` to `WindowTemplate`, update `TemplateRegistry`
- [x] 1.4 — Auto-assign tags during template application + name inference
- [x] 1.5 — Show tags in sidebar WindowRowView and command palette
- [x] 1.6 — Tests for WindowTag, RuntimeWindow tag, tag inference, WindowBadge.longRunning

## Phase 2: Agent State Detection
- [x] 2.1 — Add `pane_current_command` and `pane_start_time` to TmuxParser/TmuxPane
- [x] 2.2 — Create `DetectedAgentState` enum and `PaneState` model in MoriTmux
- [x] 2.3 — Create `PaneStateDetector` with pattern matching
- [x] 2.4 — Add `capturePaneOutput` to TmuxBackend/TmuxControlling
- [x] 2.5 — Integrate detection into coordinated poll (agent-tagged windows only)
- [x] 2.6 — Update StatusAggregator with richer badge derivation
- [x] 2.7 — Tests for PaneStateDetector, DetectedAgentState, command filtering

## Phase 3: Worktree Status Enhancements
- [x] 3.1 — Add `lastExitCode`, `isRunning`, `isLongRunning`, `agentState` to RuntimeWindow
- [x] 3.2 — Propagate pane state to RuntimeWindow during poll
- [x] 3.3 — Update sidebar views with badge-specific icons and colors
- [x] 3.4 — Tests for enhanced status aggregation

## Phase 4: Notifications
- [x] 4.1 — Create `NotificationDebouncer` in MoriCore (pure transition + debounce logic)
- [x] 4.2 — Create `NotificationManager` in app target (UNUserNotificationCenter)
- [x] 4.3 — Wire notifications to state transitions in WorkspaceManager
- [x] 4.4 — Dock badge for aggregate unread count
- [x] 4.5 — Notification click handling (focus window on click)
- [x] 4.6 — Tests for NotificationDebouncer

## Phase 5: CLI / IPC Interface
- [x] 5.1 — Create MoriIPC SPM package
- [x] 5.2 — Define IPC protocol (IPCCommand, IPCRequest, IPCResponse)
- [x] 5.3 — Create IPCServer with Network.framework (NWListener, Unix socket)
- [x] 5.4 — Create IPCClient (NWConnection, Unix socket)
- [x] 5.5 — Create `ws` CLI executable with swift-argument-parser
- [x] 5.6 — Embed IPCServer in app (start/stop in AppDelegate)
- [x] 5.7 — Wire all IPC commands in IPCHandler
- [x] 5.8 — Tests for IPC protocol serialization

## Phase 6: Automation Hooks
- [x] 6.1 — Define `HookEvent`, `HookAction`, `HookConfig` in MoriCore
- [x] 6.2 — Create `HookRunner` (read/parse .mori/hooks.json, caching)
- [x] 6.3 — Shell execution and tmuxSend for hook actions
- [x] 6.4 — Wire hooks into WorkspaceManager lifecycle (create/focus/close)
- [x] 6.5 — Add HookRunner to WorkspaceManager initialization
- [x] 6.6 — Tests for HookConfig JSON parsing
