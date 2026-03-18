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
