# Plan: Phase 2 — Product 化 (MVP-2)

## Overview

Transform Mori from a foundation into a usable product by adding git worktree management, session templates, status awareness, and a command palette. Phase 1 delivered the shell (data models, tmux backend, sidebar, PTY terminal, state restoration). Phase 2 makes it worktree-aware and status-rich.

### Goals

- Users can create and manage git worktrees from within Mori
- New worktrees get pre-configured tmux sessions via templates
- Sidebar shows live git status (dirty, ahead/behind) and unread indicators
- Command palette provides fast keyboard-driven navigation and actions

### Success Criteria

- [ ] User can create a worktree (branch name → git worktree add → tmux session → template windows)
- [ ] Worktree metadata (branch, HEAD, detached) populated from git
- [ ] Git status (dirty, ahead/behind) updates on 5s poll cycle
- [ ] Window-level unread badges appear when non-active windows have new output
- [ ] Unread clears on window select; counts roll up to worktree and project
- [ ] Command palette (Cmd+K) fuzzy-searches projects, worktrees, windows, and actions
- [ ] All new code passes Swift 6 strict concurrency
- [ ] New executable test targets with assertions for MoriGit package
- [ ] Zero build warnings

### Out of Scope

- Auto-discovery of existing git worktrees (user adds manually)
- Template selection UI (always "basic" template for now)
- File-based template configuration (hardcoded built-ins only)
- Agent state detection (Phase 3)
- Notifications / CLI socket (MVP-3)
- libghostty integration

## Technical Approach

### New Package: MoriGit

Follows MoriTmux pattern — standalone package, no deps on other Mori packages.

```
Packages/MoriGit/
  Sources/MoriGit/
    GitCommandRunner.swift    — actor, runs git CLI (like TmuxCommandRunner)
    GitWorktreeParser.swift   — parse `git worktree list --porcelain`
    GitStatusParser.swift     — parse `git status --porcelain=v2 --branch`
    GitWorktreeInfo.swift     — struct: path, branch, head, isDetached, isBare
    GitStatusInfo.swift       — struct: dirty, ahead, behind, branch, upstream
    GitControlling.swift      — protocol (like TmuxControlling)
    GitBackend.swift          — actor implementing GitControlling
    GitError.swift            — error enum
  Tests/MoriGitTests/
    main.swift
    Assert.swift
    GitWorktreeParserTests.swift
    GitStatusParserTests.swift
```

**GitControlling protocol:**
```swift
protocol GitControlling: Sendable {
    func listWorktrees(repoPath: String) async throws -> [GitWorktreeInfo]
    func addWorktree(repoPath: String, path: String, branch: String, createBranch: Bool) async throws
    func removeWorktree(repoPath: String, path: String, force: Bool) async throws
    func status(worktreePath: String) async throws -> GitStatusInfo
    func isGitRepo(path: String) async throws -> Bool
}
```

### TmuxBackend Extensions

Implement the deferred `TmuxControlling` methods:
- `createWindow(sessionId:name:cwd:)` — `tmux new-window -t <session> -n <name> -c <cwd>`
- `sendKeys(sessionId:paneId:keys:)` — `tmux send-keys -t <session>:<pane> <keys> Enter` (note: `Enter` is a separate argument to tmux, not concatenated to keys string)

### Template System

```swift
struct SessionTemplate: Sendable {
    let name: String
    let windows: [WindowTemplate]
}
struct WindowTemplate: Sendable {
    let name: String
    let command: String?  // nil = just open shell
}
```

Built-in templates defined as static constants in a `TemplateRegistry` enum. Applied by WorkspaceManager after tmux session creation.

### Git Status Polling

Single coordinated polling timer in WorkspaceManager (not two independent timers). On each 5s tick, WorkspaceManager triggers both `tmuxBackend.pollOnce()` and git status calls concurrently via `TaskGroup`. Git status calls run in parallel across worktrees using `TaskGroup`. Only active worktrees are polled (skip `.unavailable`). Update AppState fields, persist dirty/ahead/behind to DB.

### Unread Output Tracking

Extend TmuxBackend's existing poll to capture `#{pane_activity}` (Unix timestamp) in the pane format string. `UnreadTracker` (app target helper) maintains an in-memory "last seen" map (`[String: TimeInterval]`, keyed by `worktreeId:windowId`). In-memory only — on restart, all windows treated as "seen." On each poll: compare `pane_activity` vs last seen → mark `hasUnreadOutput = true` on RuntimeWindow. Clear on `selectWindow()`.

### Status Aggregation

Per PRD section 20, priority: `error > waiting > unread > dirty > normal`

- **Window level**: badge from pane state (running/idle/error) + unread
- **Worktree level**: aggregate window badges + git dirty/ahead/behind + unread count
- **Project level**: aggregate worktree states + total unread

### Command Palette

AppKit NSPanel (floating, non-activating):
- NSTextField for search input
- NSTableView (or SwiftUI List via NSHostingView) for results
- Fuzzy matching via simple substring + scoring algorithm
- Result types: project, worktree, window, action
- Actions: "Create Worktree", "Refresh", "Open Project"
- Cmd+K to toggle, Escape to dismiss (PRD section 28 assigns Cmd+K to "clear pane display" — we override this for command palette as it's more standard in modern apps; clear-pane can use Cmd+Shift+K or Ctrl+L instead)
- Arrow keys + Enter to select

### Components

- **MoriGit** (new package): Git CLI integration — worktree management + status parsing
- **MoriTmux** (extend): Implement `createWindow`, `sendKeys`; add `pane_last_activity` to pane format
- **MoriCore** (modify): Rename `WindowBadge.none` → `.idle`; add `SessionTemplate`/`WindowTemplate` models; add `TemplateRegistry`
- **MoriPersistence** (no changes expected): Existing schema already has all needed columns
- **MoriUI** (extend): Unread badges in sidebar, create-worktree button
- **App target** (extend): WorkspaceManager coordinates git+tmux; extracted helpers: `GitStatusCoordinator` (git polling + status updates), `UnreadTracker` (pane activity comparison + unread state), `TemplateApplicator` (template application after session create). New `CommandPaletteController`.

## Implementation Phases

### Phase 2.1: MoriGit Package + WindowBadge Rename

Foundation for all git operations.

1. Rename `WindowBadge.none` → `.idle` across codebase (MoriCore, MoriPersistence, any references)
2. Create `Packages/MoriGit/Package.swift` — swift-tools-version 6.0, macOS 14+
3. `GitError.swift` — error enum (binaryNotFound, executionFailed, notAGitRepo, worktreeAlreadyExists)
4. `GitCommandRunner.swift` — actor, resolve git binary, run commands (mirror TmuxCommandRunner)
5. `GitWorktreeInfo.swift` — struct (path, branch, head, isDetached, isBare)
6. `GitWorktreeParser.swift` — parse `git worktree list --porcelain` output
7. `GitStatusInfo.swift` — struct (isDirty, untrackedCount, modifiedCount, stagedCount, ahead, behind, branch, upstream)
8. `GitStatusParser.swift` — parse `git status --porcelain=v2 --branch` output
9. `GitControlling.swift` — protocol
10. `GitBackend.swift` — actor implementing GitControlling
11. Wire MoriGit into root `Package.swift` (add to Mori target dependencies)
12. Test target: `MoriGitTests` — parser tests for worktree list + status output (executable target)

### Phase 2.2: TmuxBackend Extensions + Templates

Enable window creation and template application.

1. Implement `createWindow(sessionId:name:cwd:)` in TmuxBackend
2. Implement `sendKeys(sessionId:paneId:keys:)` in TmuxBackend
3. Add `pane_last_activity` to `TmuxParser.paneFormat` and `TmuxPane` struct
4. `SessionTemplate` + `WindowTemplate` structs in MoriCore
5. `TemplateRegistry` enum in MoriCore with built-in templates (basic, go, agent)
6. Template application logic in WorkspaceManager: after session create, iterate template windows → `createWindow` + `sendKeys`

### Phase 2.3: Create Worktree Flow

End-to-end worktree creation from UI to git+tmux.

1. Add `GitBackend` as dependency of `WorkspaceManager` (init param, stored property)
2. Validate project is a git repo via `gitBackend.isGitRepo()` on `addProject()` (set `gitCommonDir` properly)
3. `WorkspaceManager.createWorktree(projectId:branchName:)` — orchestrates: git worktree add → DB save → tmux session → template apply. Sets `tmuxSessionName` via `SessionNaming.sessionName(project:worktree:)` before saving.
4. Default path logic: `~/.mori/{project-slug}/{branch-slug}` (create `~/.mori/` directory tree if needed)
5. Partial failure handling: if git succeeds but tmux fails, still save worktree to DB (tmux session will be created on next select). If git fails, no DB write.
6. Sidebar "+" button in WorktreeSidebarView → sheet/popover with branch name input
7. Wire UI action → WorkspaceManager → refresh state → select new worktree
8. Handle errors (branch exists, invalid name, git failure) with user-facing alerts
9. `WorkspaceManager.removeWorktree(worktreeId:)` — confirmation dialog: "Remove from Mori" (soft delete, mark unavailable) vs "Remove from Mori and delete files" (soft delete + `git worktree remove`)

### Phase 2.4: Git Status Polling + Badges

Live git status and badge aggregation.

1. `GitStatusCoordinator` (app target) — encapsulates git polling logic. On each 5s tick, runs `gitBackend.status()` concurrently for all active worktrees via `TaskGroup`.
2. Single coordinated polling timer in WorkspaceManager replacing TmuxBackend's self-managed polling. Triggers both tmux scan and git status on each tick.
3. Update Worktree model fields (hasUncommittedChanges, aheadCount, behindCount) → persist to DB
4. Window badge logic: derive from tmux pane state (running command vs idle shell vs exited)
5. `StatusAggregator` (MoriCore, pure logic) — worktree-level aggregation (window badges + git status), project-level aggregation. Priority: error > waiting > unread > dirty > normal.
6. Update AppState with aggregated badges → SwiftUI re-renders sidebar with indicators
7. Badge rendering in WorktreeSidebarView (colored dots/icons for dirty, ahead/behind counts, unread)

### Phase 2.5: Unread Output Tracking

Detect and surface new terminal output.

1. `UnreadTracker` (app target) — in-memory `[String: TimeInterval]` map keyed by `worktreeId:windowId`. Not persisted (on restart all windows treated as "seen").
2. On each coordinated poll tick: `UnreadTracker.processActivity()` compares `pane_activity` timestamps vs last-seen → returns list of windows with new activity
3. Mark `hasUnreadOutput = true` on RuntimeWindow for windows with new activity
4. Roll up unread count to Worktree.unreadCount and Project.aggregateUnreadCount via `StatusAggregator`
5. Clear unread in `selectWindow()`: reset hasUnreadOutput, update last-seen map in `UnreadTracker`, recompute aggregates
6. Unread indicator in WorktreeSidebarView (dot or count badge on window rows and worktree rows)

### Phase 2.6: Command Palette

Keyboard-driven navigation and actions.

1. `CommandPaletteItem` model — enum cases: project, worktree, window, action; with title, subtitle, icon
2. `FuzzyMatcher` utility — simple scoring: exact prefix > word boundary > substring > no match
3. `CommandPaletteDataSource` — collects all items from AppState, scores against query
4. `CommandPaletteController` — NSPanel subclass (or NSWindowController managing NSPanel), NSTextField + NSTableView
5. Register Cmd+K global shortcut in AppDelegate (NSEvent.addLocalMonitorForEvents)
6. Wire selection → WorkspaceManager navigation (selectProject/selectWorktree/selectWindow) or action execution
7. Actions: "Create Worktree" (opens create flow), "Refresh" (triggers poll), "Open Project" (opens NSOpenPanel)

## Testing Strategy

### MoriGit Tests (executable target)
- Parse well-formed `git worktree list --porcelain` output (main worktree, linked worktrees, detached HEAD, bare repo)
- Parse `git status --porcelain=v2 --branch` output (clean, dirty, staged, ahead/behind, no upstream)
- Parse edge cases: empty output, malformed lines, missing fields

### TmuxBackend Tests (extend existing)
- `createWindow` produces correct tmux command
- `sendKeys` produces correct tmux command
- `pane_last_activity` parsed from pane format

### Template Tests
- TemplateRegistry returns correct built-in templates
- Template application creates expected windows (mock TmuxControlling)

### Status Aggregation Tests (MoriCore executable target)
- Window badge derivation from pane state
- Worktree-level aggregation (priority: error > waiting > unread > dirty > normal)
- Project-level aggregation from worktree states
- Edge cases: no windows, all idle, mixed states

### FuzzyMatcher Tests (app target or MoriCore)
- Exact prefix match scores highest
- Word boundary match scores higher than substring
- No match returns zero score
- Empty query returns all items
- Case-insensitive matching

### UnreadTracker Tests
- New activity detected when pane_activity > last_seen
- No false positive when pane_activity == last_seen
- Clear resets last_seen to current activity timestamp
- Fresh tracker treats all windows as "seen" (no unread on first poll)

### Integration-level (manual)
- Create worktree end-to-end: branch input → git worktree add → tmux session with template windows
- Git status updates after modifying files in worktree
- Unread badge appears on background window activity, clears on select
- Command palette search finds projects/worktrees/windows/actions

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Git CLI not available on PATH | High | GitCommandRunner resolves binary with fallbacks (like TmuxCommandRunner). Show alert if missing. |
| Git status polling performance with many worktrees | Medium | Run git status concurrently via `TaskGroup`. Skip `.unavailable` worktrees. Only poll active worktrees. |
| `pane_activity` resolution insufficient for unread detection | Medium | Use Unix timestamp comparison with 1s tolerance. Fall back to tmux `monitor-activity` flag if needed. |
| Process spawning overhead (git + tmux combined) | Medium | With 5 projects x 3 worktrees x 4 windows = ~75 tmux + 15 git processes per 5s tick. Mitigate with concurrent TaskGroup execution and skip inactive worktrees. |
| Command palette focus stealing | Low | Use NSPanel with `.nonactivatingPanel` style mask, proper key handling. |
| Swift 6 concurrency with git+tmux dual polling | Medium | Keep GitBackend as separate actor. Single coordinated timer in WorkspaceManager on @MainActor. |
| Partial failure in create worktree flow | Medium | If git succeeds but tmux fails, save worktree to DB anyway — tmux session created on next select. If git fails, no DB write. |

## Open Questions

All resolved — converted to decisions:

- **Worktree discovery**: Manual only (user adds). No auto-sync from `git worktree list`.
- **Template selection**: Always "basic" for now. No UI picker.
- **Git status polling**: Same 5s interval as tmux, coordinated in WorkspaceManager.
- **Command palette scope**: Navigation + actions (Create Worktree, Refresh, Open Project).
- **Unread clearing**: Window-level only.
- **Worktree path**: `~/.mori/{project-slug}/{branch-slug}`.

## Review Feedback

### Round 1 (reviewer subagent)

**Verdict: CHANGES NEEDED** — All issues addressed:

1. **Fixed**: Moved GitBackend wiring from Phase 2.4 to Phase 2.3 (create worktree needs git access)
2. **Fixed**: Removed incorrect "WindowBadge.none breaks persistence" risk — RuntimeWindow is runtime-only, not persisted
3. **Fixed**: Documented Cmd+K conflict with PRD section 28; command palette takes priority, clear-pane reassigned
4. **Fixed**: Added WorkspaceManager decomposition — `GitStatusCoordinator`, `UnreadTracker`, `TemplateApplicator` as extracted helpers
5. **Fixed**: Specified single coordinated polling timer (not two independent timers)
6. **Fixed**: Added tests for StatusAggregator, FuzzyMatcher, and UnreadTracker
7. **Fixed**: Added partial failure handling for create worktree flow
8. **Fixed**: Specified concurrent `TaskGroup` execution for git status polling
9. **Fixed**: Clarified worktree removal UX (confirmation dialog with two options)
10. **Noted**: `AlertState.none` has same ambiguity but is persisted — deferring rename to avoid migration complexity; can address in future if it causes real issues
11. **Fixed**: Specified `sendKeys` sends `Enter` as separate tmux argument
12. **Fixed**: Specified UnreadTracker is in-memory only (not persisted)

## Final Status

**COMPLETE** — All 6 phases implemented, reviewed, and approved.

### Test Summary
- MoriCore: 134 assertions (models, StatusAggregator, FuzzyMatcher, unread logic)
- MoriPersistence: 42 assertions (GRDB round-trip)
- MoriTmux: 105 assertions (parser, pane_activity)
- MoriGit: 99 assertions (worktree parser, status parser)
- **Total: 380 assertions passing** (up from 204 in Phase 1)

### Build Status
- Zero warnings under Swift 6 strict concurrency
- Clean build via `swift build`

### Deviations from Plan
- AlertState extended with `.dirty`, `.unread`, `.waiting` cases + `Comparable` (not originally planned, needed for proper aggregation priority)
- WorktreeRowView and WindowRowView extracted as separate files (cleaner than inline in WorktreeSidebarView)
- `renameWindow` added to TmuxBackend (needed by TemplateApplicator for first-window handling)
- `gitCommonDir` added to GitControlling protocol (needed for proper git repo validation)

### Known Limitations
- Template selection is always "basic" (no UI picker yet)
- Window badge derivation is simple (unread/idle only — no running/error detection from pane commands)
- `AlertState.none` still has Optional.none ambiguity (deferred to avoid migration)
- Git status polls all active worktrees every 5s (could optimize with reduced frequency for non-selected)
