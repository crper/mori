# Tasks: Phase 2 — Product 化 (MVP-2)

## Phase 2.1: MoriGit Package + WindowBadge Rename

- [x] 2.1.1 — Rename `WindowBadge.none` to `.idle` across codebase (`WindowBadge.swift`, any references)
- [x] 2.1.2 — Create `Packages/MoriGit/Package.swift` (swift-tools-version 6.0, macOS 14+)
- [x] 2.1.3 — `GitError.swift` — error enum
- [x] 2.1.4 — `GitCommandRunner.swift` — actor, resolve git binary, run commands
- [x] 2.1.5 — `GitWorktreeInfo.swift` — struct (path, branch, head, isDetached, isBare)
- [x] 2.1.6 — `GitWorktreeParser.swift` — parse `git worktree list --porcelain`
- [x] 2.1.7 — `GitStatusInfo.swift` — struct (isDirty, counts, ahead, behind, branch, upstream)
- [x] 2.1.8 — `GitStatusParser.swift` — parse `git status --porcelain=v2 --branch`
- [x] 2.1.9 — `GitControlling.swift` — protocol
- [x] 2.1.10 — `GitBackend.swift` — actor implementing GitControlling
- [x] 2.1.11 — Wire MoriGit into root `Package.swift`
- [x] 2.1.12 — Test target: `MoriGitTests` — parser tests (executable target)

## Phase 2.2: TmuxBackend Extensions + Templates

- [x] 2.2.1 — Implement `createWindow(sessionId:name:cwd:)` in TmuxBackend
- [x] 2.2.2 — Implement `sendKeys(sessionId:paneId:keys:)` in TmuxBackend
- [x] 2.2.3 — Add `pane_activity` to `TmuxParser.paneFormat` and `TmuxPane` struct
- [x] 2.2.4 — `SessionTemplate` + `WindowTemplate` structs in MoriCore
- [x] 2.2.5 — `TemplateRegistry` enum in MoriCore with built-in templates
- [x] 2.2.6 — `TemplateApplicator` in app target — applies template via createWindow + sendKeys

## Phase 2.3: Create Worktree Flow

- [x] 2.3.1 — Add `GitBackend` as dependency of `WorkspaceManager`
- [x] 2.3.2 — Validate git repo on `addProject()`, set `gitCommonDir` properly
- [x] 2.3.3 — `WorkspaceManager.createWorktree(projectId:branchName:)` — full orchestration
- [x] 2.3.4 — Default path logic: `~/.mori/{project-slug}/{branch-slug}`
- [x] 2.3.5 — Partial failure handling (git ok + tmux fail → still save to DB)
- [x] 2.3.6 — Sidebar "+" button → sheet/popover with branch name input
- [x] 2.3.7 — Wire UI action → WorkspaceManager → refresh → select new worktree
- [x] 2.3.8 — Error handling (branch exists, invalid name, git failure) with alerts
- [x] 2.3.9 — `WorkspaceManager.removeWorktree(worktreeId:)` with confirmation dialog

## Phase 2.4: Git Status Polling + Badges

- [ ] 2.4.1 — `GitStatusCoordinator` in app target — encapsulates git polling with TaskGroup
- [ ] 2.4.2 — Single coordinated polling timer in WorkspaceManager (replaces TmuxBackend self-polling)
- [ ] 2.4.3 — Update Worktree fields (hasUncommittedChanges, aheadCount, behindCount) + persist
- [ ] 2.4.4 — Window badge derivation from tmux pane state
- [ ] 2.4.5 — `StatusAggregator` in MoriCore — pure aggregation logic (worktree + project levels)
- [ ] 2.4.6 — Update AppState with aggregated badges
- [ ] 2.4.7 — Badge rendering in WorktreeSidebarView
- [ ] 2.4.8 — Tests: StatusAggregator assertions (add to MoriCore test target)

## Phase 2.5: Unread Output Tracking

- [ ] 2.5.1 — `UnreadTracker` in app target — in-memory last-seen map
- [ ] 2.5.2 — Process pane_activity on each poll tick → detect new activity
- [ ] 2.5.3 — Mark hasUnreadOutput on RuntimeWindow, roll up to Worktree + Project
- [ ] 2.5.4 — Clear unread in `selectWindow()` — reset hasUnreadOutput, update tracker
- [ ] 2.5.5 — Unread indicators in WorktreeSidebarView (dot/count on window + worktree rows)
- [ ] 2.5.6 — Tests: UnreadTracker assertions

## Phase 2.6: Command Palette

- [ ] 2.6.1 — `CommandPaletteItem` model (project/worktree/window/action variants)
- [ ] 2.6.2 — `FuzzyMatcher` utility — scoring: prefix > word boundary > substring
- [ ] 2.6.3 — `CommandPaletteDataSource` — collect items from AppState, score against query
- [ ] 2.6.4 — `CommandPaletteController` — NSPanel + NSTextField + NSTableView
- [ ] 2.6.5 — Register Cmd+K shortcut in AppDelegate
- [ ] 2.6.6 — Wire selection → navigation (selectProject/selectWorktree/selectWindow) or action
- [ ] 2.6.7 — Actions: Create Worktree, Refresh, Open Project
- [ ] 2.6.8 — Tests: FuzzyMatcher assertions
