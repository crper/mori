# Handoff: Phase 2 — Product 化 (MVP-2)

<!-- Append a new phase section after each phase completes. -->

## Phase 2.1: MoriGit Package + WindowBadge Rename — COMPLETE

### Summary

All 12 tasks completed with individual commits. The MoriGit package provides a standalone git CLI integration layer following the MoriTmux pattern (actors, protocols, parsers, error enum).

### What was done

1. **WindowBadge.none -> .idle** — Renamed across `WindowBadge.swift` and `MoriCoreTests/main.swift`. No persistence impact (runtime-only model).
2. **MoriGit Package** — Created `Packages/MoriGit/` with swift-tools-version 6.0, macOS 14+, library + executable test target.
3. **GitError** — Error enum: binaryNotFound, executionFailed, notAGitRepo, worktreeAlreadyExists, parseError.
4. **GitCommandRunner** — Actor resolving git binary (`/opt/homebrew`, `/usr/local`, `/usr/bin` fallbacks + `which`). Runs commands via Process with terminationHandler. Includes `run(in:)` for directory-scoped execution.
5. **GitWorktreeInfo** — Struct with path, head, branch, isDetached, isBare. Computed `branchName` strips `refs/heads/` prefix.
6. **GitWorktreeParser** — Parses `git worktree list --porcelain` by splitting blank-line-separated blocks.
7. **GitStatusInfo** — Struct with untrackedCount, modifiedCount, stagedCount, ahead, behind, branch, upstream. Computed `isDirty`. Static `.clean`.
8. **GitStatusParser** — Parses `git status --porcelain=v2 --branch`. Handles branch headers, ordinary (1), rename (2), unmerged (u), untracked (?), ignored (!).
9. **GitControlling** — Protocol: listWorktrees, addWorktree, removeWorktree, status, isGitRepo.
10. **GitBackend** — Actor implementing GitControlling via GitCommandRunner delegation.
11. **Root Package.swift** — Wired MoriGit as dependency of Mori target.
12. **MoriGitTests** — 99 assertions across worktree parser (11 tests) and status parser (13 tests).

### Build verification

- `swift build` from root: **clean, no warnings**
- `swift run MoriGitTests` from MoriGit package: **99/99 assertions passed**

### Commits (12)

- `7a14feb` — refactor: rename WindowBadge.none to .idle
- `db04985` — feat: create MoriGit package scaffold
- `85e70c9` — feat: add GitError enum
- `2b5c2a5` — feat: add GitCommandRunner actor
- `6a60662` — feat: add GitWorktreeInfo struct
- `249dc23` — feat: add GitWorktreeParser
- `5c3f92d` — feat: add GitStatusInfo struct
- `4154cf5` — feat: add GitStatusParser
- `8086346` — feat: add GitControlling protocol
- `3835b2b` — feat: add GitBackend actor
- `54c2853` — feat: wire MoriGit into root Package.swift
- `4399d51` — feat: add MoriGitTests with 99 assertions

### Ready for Phase 2.2

- MoriGit is fully usable for git worktree listing and status queries
- GitBackend can be injected into WorkspaceManager (Phase 2.3)
- GitControlling protocol enables mock testing at integration level

## Phase 2.2: TmuxBackend Extensions + Templates — COMPLETE

### Summary

All 6 tasks completed. TmuxBackend now supports window creation, key sending, and window renaming. Pane activity timestamps are parsed for unread tracking. Session templates and a template applicator enable automatic window setup after session creation.

### What was done

1. **createWindow + sendKeys** — Implemented in TmuxBackend. `createWindow` uses `tmux new-window -t <session> -P -F <windowFormat>` with optional `-n` and `-c` flags, parses output into TmuxWindow. `sendKeys` sends `tmux send-keys -t <session>:<pane> <keys> Enter` with Enter as separate argument.
2. **renameWindow** — Implemented in TmuxBackend (needed by TemplateApplicator to rename the default window). Uses `tmux rename-window -t <session>:<window> <name>`.
3. **pane_activity** — Added `#{pane_activity}` to `TmuxParser.paneFormat`. Added `lastActivity: TimeInterval?` to `TmuxPane`. Parser handles the field as `Double`, backward-compatible with 5-field format.
4. **SessionTemplate + WindowTemplate** — Sendable, Equatable structs in MoriCore. WindowTemplate has `name` and optional `command`. SessionTemplate has `name` and `[WindowTemplate]`.
5. **TemplateRegistry** — Enum in MoriCore with 3 built-in templates: `basic` (shell/run/logs), `go` (editor/server/tests/logs), `agent` (editor/agent/server/logs). Includes `template(named:)` lookup with basic as default.
6. **TemplateApplicator** — Struct in app target. Takes TmuxBackend reference. First template window renames the existing default window; subsequent windows created via `createWindow`. Sends commands via `sendKeys` when `WindowTemplate.command` is set. Selects first window at the end.

### Build verification

- `swift build` from root: **clean, no warnings**
- `swift run MoriTmuxTests` from MoriTmux package: **105/105 assertions passed** (up from 95)

### Commits (5)

- `28d731b` — feat: implement createWindow and sendKeys in TmuxBackend
- `a4718a8` — feat: add pane_activity to TmuxParser and TmuxPane
- `4ef3228` — feat: add SessionTemplate and WindowTemplate structs
- `1a39110` — feat: add TemplateRegistry with built-in templates
- `8750aae` — feat: add TemplateApplicator with renameWindow support
- `829eb80` — test: add pane_activity parsing tests (105 assertions)

### Ready for Phase 2.3

- TmuxBackend has all methods needed for worktree creation flow (createSession, createWindow, renameWindow, sendKeys)
- TemplateApplicator can be called from WorkspaceManager after session creation
- pane_activity field ready for UnreadTracker in Phase 2.5

## Phase 2.3: Create Worktree Flow — COMPLETE

### Summary

All 9 tasks completed. End-to-end worktree creation from sidebar UI through git + tmux + DB, with error handling and removal support.

### What was done

1. **GitBackend as WorkspaceManager dependency** — Added `gitBackend: GitBackend` as init param (defaults to fresh instance). AppDelegate wires it in.
2. **Git repo validation on addProject** — Added `gitCommonDir()` to GitControlling/GitBackend using `git rev-parse --git-common-dir`. `addProject()` is now async, validates git repo and resolves common dir. Handles relative paths from git output.
3. **createWorktree orchestration** — Full flow: validate branch name, compute path `~/.mori/{project-slug}/{branch-slug}`, git worktree add, DB save, tmux session create, basic template apply, update AppState, select new worktree.
4. **Default path logic** — Worktrees created at `~/.mori/{project-slug}/{branch-slug}` with `FileManager.createDirectory(withIntermediateDirectories:)`.
5. **Partial failure handling** — If git fails, no DB write. If tmux fails after git success, worktree is still saved to DB (tmux session created on next select via `ensureTmuxSession`).
6. **Sidebar "+" button** — WorktreeSidebarView header with "Worktrees" label and "+" button. Inline text field for branch name with submit/cancel. Context menu on worktree rows for removal.
7. **UI wiring** — HostingControllers pass `onCreateWorktree` and `onRemoveWorktree` callbacks. AppDelegate bridges to `WorkspaceManager.handleCreateWorktree` and `removeWorktree` via async Tasks.
8. **Error handling** — `WorkspaceError` enum with `.projectNotFound`, `.branchNameEmpty`, `.branchNameInvalid`. Branch names validated for git-invalid characters (spaces, tildes, colons, etc.). NSAlert shown for all error cases.
9. **removeWorktree** — NSAlert confirmation with three options: "Remove from Mori" (soft delete, mark unavailable), "Remove from Mori and Delete Files" (soft delete + `git worktree remove` + kill tmux session), "Cancel". Main worktree removal prevented.

### Build verification

- `swift build` from root: **clean, no warnings**

### Commits (6)

- `6044730` — feat: add GitBackend as dependency of WorkspaceManager
- `4e2c7d2` — feat: validate git repo on addProject and set gitCommonDir
- `b5c1cbe` — feat: add createWorktree with default path logic and partial failure handling
- `9b4b57e` — feat: add sidebar "+" button with branch name input for worktree creation
- `d6d6c99` — feat: wire sidebar create/remove worktree actions to WorkspaceManager
- `6d64988` — feat: add branch name validation and user-facing error alerts

### Key files modified

- `Sources/Mori/App/WorkspaceManager.swift` — createWorktree, removeWorktree, handleCreateWorktree, WorkspaceError
- `Sources/Mori/App/AppDelegate.swift` — GitBackend wiring, async addProject call, sidebar callbacks
- `Sources/Mori/App/HostingControllers.swift` — onCreateWorktree/onRemoveWorktree callback passthrough
- `Packages/MoriUI/Sources/MoriUI/WorktreeSidebarView.swift` — header, "+" button, branch input, context menu
- `Packages/MoriGit/Sources/MoriGit/GitControlling.swift` — gitCommonDir protocol method
- `Packages/MoriGit/Sources/MoriGit/GitBackend.swift` — gitCommonDir implementation

### Ready for Phase 2.4

- WorkspaceManager has gitBackend for status polling
- createWorktree flow tested via build; ready for git status integration
- TemplateApplicator already applies basic template on worktree creation
- Sidebar UI ready for badge rendering additions
