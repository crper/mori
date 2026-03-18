# Handoff

## Goal

Implement PRD Phase 3 ("Agent-first") for Mori, the macOS native workspace terminal. Phases 1 (Foundation) and 2 (Product 化) are complete, plus post-Phase 2 bugfixes and terminal upgrade.

## Progress

Phase 1 and Phase 2 are **fully complete** with 75 tasks across 11 implementation phases:

- **Phase 1** (30 tasks): Project scaffolding, tmux backend, AppKit shell, PTY terminal, state restoration
- **Phase 2** (47 tasks, 45 commits): MoriGit package, create/remove worktree, templates, git status polling, badges, unread output tracking, command palette

**Post-Phase 2 fixes** (this session):
- Fixed SIGTRAP crash: GCD dispatch source closures inherited `@MainActor` isolation in Swift 6; extracted to `nonisolated static` method
- Fixed tmux session naming: changed separator from `::` to `__` because tmux reserves `:` for session:window notation
- Fixed tmux attach: use `has-session` check before attach to handle pre-existing sessions
- Fixed app activation: set `NSApp.setActivationPolicy(.regular)` so the app receives focus and key events when launched via `swift run`
- **Integrated SwiftTerm** as terminal backend: full VT100/xterm emulator with cursor, colors, mouse support, and proper tmux rendering (replaces basic PTY/NSTextView fallback)

**380 test assertions** passing (134 core + 42 GRDB + 105 tmux + 99 git). Zero build warnings under Swift 6 strict concurrency.

## Key Decisions

- **AppKit-first, SwiftUI for leaf views** — Terminal embedding needs NSView/NSResponder control
- **SwiftTerm for terminal rendering** — Full VT100/xterm via `SwiftTermAdapter` implementing `TerminalHost` protocol. `NativeTerminalAdapter` (basic PTY) kept as fallback.
- **Root Package.swift** — Builds via `swift build`; Xcode now available for XCFramework support if needed
- **Executable test targets** — Custom assertion helpers (no XCTest dependency)
- **WorkspaceManager decomposed** — Extracted `GitStatusCoordinator`, `UnreadTracker`, `TemplateApplicator` as focused helpers
- **Single coordinated 5s polling timer** — WorkspaceManager drives both tmux scan + git status concurrently via TaskGroup
- **Manual worktree management** — No auto-discovery; user adds/removes worktrees explicitly
- **Worktree path convention**: `~/.mori/{project-slug}/{branch-slug}`
- **tmux session naming**: `ws__<slug>__<slug>` (double underscore, not colon)
- **Cmd+K for command palette** (overrides PRD's clear-pane assignment)
- **WindowBadge.none renamed to .idle**; AlertState.none kept (deferred to avoid migration)
- **AlertState priority**: error > waiting > warning > unread > dirty > info > none
- **UnreadTracker is in-memory only** — on restart all windows treated as "seen"
- **Templates**: always "basic" (shell/run/logs) for now; template selection UI deferred

## Current State

The app builds and runs via `mise run dev`. It:
- Launches a 3-column window (project rail | worktree sidebar | terminal)
- Lets users add projects via File > Open Project (validates git repo)
- Creates/removes worktrees (git worktree add/remove + tmux session + template)
- Shows full-featured terminal (SwiftTerm) attached to tmux session with cursor, colors, and mouse
- Displays git status badges (dirty, ahead/behind) and unread indicators
- Tracks unread output across non-active windows, clears on select
- Provides command palette (Cmd+K) with fuzzy search over projects/worktrees/windows/actions
- Persists and restores state across launches
- Activates as foreground app with Dock icon

### Architecture

```
Sources/Mori/App/          — AppDelegate, MainWindowController, RootSplitViewController,
                             TerminalAreaViewController, WorkspaceManager,
                             GitStatusCoordinator, UnreadTracker, TemplateApplicator,
                             CommandPaletteController, CommandPaletteDataSource,
                             CommandPaletteItem, HostingControllers
Packages/MoriCore/         — Models (Project, Worktree, RuntimeWindow, RuntimePane, UIState,
                             WindowBadge, AlertState, AgentState, WorktreeStatus,
                             SessionTemplate, TemplateRegistry, StatusAggregator,
                             FuzzyMatcher, SidebarMode) + AppState
Packages/MoriPersistence/  — GRDB/SQLite (WAL), Records, Repositories
Packages/MoriTmux/         — TmuxBackend (actor), TmuxParser, TmuxCommandRunner, SessionNaming
Packages/MoriGit/          — GitBackend (actor), GitCommandRunner, GitWorktreeParser,
                             GitStatusParser, GitControlling protocol
Packages/MoriTerminal/     — TerminalHost protocol, SwiftTermAdapter (primary), NativeTerminalAdapter (fallback),
                             ANSIParser, SurfaceCache
Packages/MoriUI/           — ProjectRailView, WorktreeSidebarView, WorktreeRowView, WindowRowView
```

### Build & Test

```bash
mise run build           # Debug build (swift build | xcbeautify)
mise run build:release   # Release build
mise run dev             # Build + run
mise run test            # All tests (parallel)
mise run test:core       # MoriCore tests (134 assertions)
mise run test:persistence # MoriPersistence tests (42 assertions)
mise run test:tmux       # MoriTmux tests (105 assertions)
mise run test:git        # MoriGit tests (99 assertions)
mise run clean           # Clean artifacts
```

## Blockers / Gotchas

- **AlertState.none ambiguity** — `.none` case collides with `Optional.none`. Deferred rename to avoid GRDB migration.
- **Window badge derivation is simple** — Currently only unread/idle. No running/error detection from pane commands yet.
- **Git status polls all active worktrees every 5s** — Could optimize with reduced frequency for non-selected.
- **Template selection is always "basic"** — No UI picker yet.
- **Session folders** — Phase 1: `.agents/sessions/2026-03-18-phase1-foundation/`, Phase 2: `.agents/sessions/2026-03-18-phase2-product/`

## Next Steps: PRD Phase 3 (Agent-first)

From PRD sections 22, 26, 27, 33-34, Phase 3 covers:

1. **Agent state detection** — Infer AgentState (running, waitingForInput, error, completed) from pane markers, shell prompt hooks, tmux user options, or output pattern matching. The `AgentState` enum already exists in MoriCore. Window-level `agent waiting` badge already modeled.

2. **Window semantic tags** — Tag windows with semantic roles (editor, agent, server, logs, tests). Enable filtering/grouping in sidebar and command palette. Extend RuntimeWindow or template system.

3. **Automation hooks** — Event system for worktree/window lifecycle: on-create, on-focus, on-close. Enable running scripts or sending tmux commands in response to events.

4. **CLI / IPC interface** — Local Unix socket or XPC for automation:
   - `ws open /path/to/repo`
   - `ws project list`
   - `ws worktree create <project> <branch>`
   - `ws focus <project> <worktree>`
   - `ws send <project> <worktree> <window> "command"`
   - `ws new-window <project> <worktree> <name>`

5. **Notifications** — macOS native notifications for: agent waiting, command error, long-running command complete. Dock badge for unread count.

6. **Worktree status enhancements** — Richer metadata: long-running command detection, exit code tracking, agent state in badges.

### Suggested implementation order
1. Window semantic tags (extend template + RuntimeWindow)
2. Agent state detection (output pattern matching as first pass)
3. Worktree status enhancements (running/error/long-running badges)
4. Notifications (NSUserNotificationCenter / UNUserNotificationCenter)
5. CLI / IPC interface (Unix socket + lightweight CLI tool)
6. Automation hooks (event system + config)

### Key PRD references
- Section 22: Agent state design (AgentState enum, detection sources)
- Section 26: CLI / IPC design (commands, unix socket / XPC)
- Section 27: macOS native integration (notifications, Dock, Finder)
- Section 20: Status aggregation (window semantic state: running/idle/error/agent-waiting/long-running)
- Section 33-34: MVP-3 scope and Phase 3 milestones
