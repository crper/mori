# Handoff

## Goal

Implement PRD Phase 2 ("Product 化" / MVP-2) for Mori, the macOS native workspace terminal. Phase 1 (Foundation) is complete — the app has working data models, tmux backend, sidebar UI, PTY terminal, and state restoration.

## Progress

Phase 1 is **fully complete** with all 30 tasks across 5 implementation phases done and reviewed:

- **Phase 1.1**: Project scaffolding — root Package.swift, 5 local SPM packages (MoriCore, MoriPersistence, MoriTmux, MoriTerminal, MoriUI)
- **Phase 1.2**: Tmux backend — TmuxBackend actor, parser, command runner, session naming (`ws::<project>::<worktree>`), 5s polling
- **Phase 1.3**: AppKit shell — NSSplitViewController (3 columns), SwiftUI sidebar views, WorkspaceManager, Add Project via NSOpenPanel
- **Phase 1.4**: Terminal integration — PTY-based terminal (forkpty + ANSI parser), LRU surface cache (max 3), focus handling
- **Phase 1.5**: State restoration — persist/restore last selection, edge cases (missing tmux, invalid paths, stale sessions), app menu bar
- **204 test assertions** passing (67 model + 42 GRDB + 95 tmux)
- **Zero build errors/warnings** under Swift 6 strict concurrency

## Key Decisions

- **AppKit-first, SwiftUI for leaf views** — Terminal embedding needs NSView/NSResponder control
- **PTY fallback instead of libghostty** — No Xcode installed (Command Line Tools only). `TerminalHost` protocol abstracts the backend; `GhosttyAdapter` can be a drop-in replacement later
- **Root Package.swift instead of .xcodeproj** — Can't create Xcode projects from CLI. Builds via `swift build`
- **Executable test targets** — No XCTest without Xcode. Custom assertion helpers in each test package
- **WorkspaceManager in app target** — Avoids circular deps between SPM packages (it needs MoriPersistence + MoriTmux + MoriCore)
- **`@MainActor` on AppState** — Swift 6 strict concurrency; all UI state mutations on main thread
- **`WeakSendableRef`** — Bridges `@MainActor`-isolated objects into GCD dispatch source handlers safely
- **Phase 1 worktrees = one default worktree per project** (project root). Git worktree discovery is Phase 2.

## Current State

The app builds and runs via `mise run dev`. It:
- Launches a 3-column window (project rail | worktree sidebar | terminal)
- Lets users add projects via File > Open Project
- Creates tmux sessions and shows interactive terminal
- Persists and restores state across launches
- Handles edge cases (tmux missing, invalid paths)

### Architecture

```
Sources/Mori/App/          — AppDelegate, MainWindowController, RootSplitViewController,
                             TerminalAreaViewController, WorkspaceManager, HostingControllers
Packages/MoriCore/         — Models (Project, Worktree, RuntimeWindow, RuntimePane, UIState) + AppState
Packages/MoriPersistence/  — GRDB/SQLite (WAL), Records, Repositories
Packages/MoriTmux/         — TmuxBackend (actor), TmuxParser, TmuxCommandRunner, SessionNaming
Packages/MoriTerminal/     — TerminalHost protocol, NativeTerminalAdapter (PTY), ANSIParser, SurfaceCache
Packages/MoriUI/           — ProjectRailView, WorktreeSidebarView (SwiftUI)
```

### Build & Test

```bash
mise run build           # Debug build (swift build | xcbeautify)
mise run build:release   # Release build
mise run dev             # Build + run
mise run test            # All tests (parallel)
mise run test:core       # MoriCore tests
mise run test:persistence # MoriPersistence tests
mise run test:tmux       # MoriTmux tests
mise run clean           # Clean artifacts
```

## Next Steps: PRD Phase 2 (MVP-2 / "Product 化")

From the PRD (sections 12, 18.4, 19, 20, 33-34), Phase 2 covers:

1. **Git worktree discovery** — Scan `git worktree list --porcelain`, parse worktree paths/branches/HEAD, map to existing Worktree model. Trigger on project open, refresh, and worktree creation.

2. **Create worktree** — UI to input branch name → `git worktree add` → create tmux session → apply template. See PRD section 18.4.

3. **Default templates** — When creating a worktree's tmux session, batch-create windows from a template (e.g., "shell/run/logs" or "editor/server/tests/logs"). See PRD section 19.

4. **Unread output tracking** — Detect new output in non-active tmux windows/panes. Show unread count on worktree and window rows. See PRD section 20.

5. **Basic badges** — Window-level badges (running, idle, error, agent-waiting). Worktree-level aggregation (dirty, ahead/behind, unread count, alert). Project-level aggregation. See PRD section 20.

6. **Command palette** (PRD section 34 lists this under Phase 2 milestones) — Basic fuzzy search over projects, worktrees, windows. Keyboard shortcut (Cmd+K or Cmd+P).

### Suggested implementation order
1. Git worktree discovery (new `MoriGit` package or add to MoriCore)
2. Create worktree flow (UI + git + tmux)
3. Templates (stored as config, applied on session create)
4. Badges and status (git status parsing, tmux output monitoring)
5. Unread output tracking
6. Command palette

### Key PRD references
- Section 12: Worktree discovery (`git worktree list --porcelain`)
- Section 18.4: New worktree interaction flow
- Section 19: Default template mechanism
- Section 20: Status aggregation (window/worktree/project levels)
- Section 33-34: MVP-2 scope and Phase 2 milestones

## Blockers / Gotchas

- **No Xcode** — Only Command Line Tools. Can't use XCTest, swift-testing, or libghostty XCFramework.
- **PTY terminal is basic** — No cursor grid or alternate screen buffer. Works for tmux but not a full VT100.
- **`WindowBadge.none` ambiguity** — `.none` case collides with `Optional.none`. Consider renaming to `.idle`.
- **Session folder** — Phase 1 plan/tasks/handoff at `.agents/sessions/2026-03-18-phase1-foundation/`
- **Plan template** — Use the specs-dev skill (`/specs-dev`) for structured planning if desired.
