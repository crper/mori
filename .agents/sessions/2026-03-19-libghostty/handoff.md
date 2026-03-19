# Handoff

<!-- Append a new phase section after each phase completes. -->

## Phase 0: API Verification (research spike)

**Status:** complete

**Tasks completed:**

- 0.1: Cloned Ghostty repo (shallow) to /tmp/ghostty-mori-research. Tip commit: `c9e1006213eb9234209924c91285d6863e59ce4c` (1.3.2-dev)
- 0.2: Read full `include/ghostty.h` (1179 lines). Documented all API functions, structs, and callback signatures in plan.md "Verified API" section
- 0.3: Confirmed hot-reload: `ghostty_surface_update_config(surface, config)` and `ghostty_app_update_config(app, config)` both exist and are used by Ghostty's macOS app
- 0.4: Default TERM is `xterm-ghostty` (in Config.zig line 3700). Must override to `xterm-256color` via config file `term = xterm-256color` for tmux compat
- 0.5: Zig 0.15.2 required (from `build.zig.zon`). Confirmed available via `mise ls-remote zig`
- 0.6: Updated plan with all verified API names. Major revision: no programmatic config setter API exists — must use config file approach (`ghostty_config_load_file`)

**Decisions & context for next phase:**

- **Config approach changed**: No `ghostty_config_set(key, value)` API. Ghostty config is loaded from files in `key = value` format. Strategy: write a temp config file from TerminalSettings, load via `ghostty_config_load_file()`. Skip `ghostty_config_load_default_files()` to avoid loading user's personal Ghostty config.
- **XCFramework build command**: `zig build -Demit-xcframework=true -Dapp-runtime=none -Doptimize=ReleaseFast`
- **Module map ships with XCFramework**: `module GhosttyKit { umbrella header "ghostty.h" export * }` — no custom module map needed
- **Surface config**: Host provides NSView pointer via `ghostty_platform_macos_s.nsview`. libghostty renders into it via Metal/Core Animation. PTY is fully internal.
- **Graceful close**: Use `ghostty_surface_request_close(surface)` instead of `ghostty_surface_free()` for graceful shutdown. Free after close callback fires.
- **Color format**: Ghostty uses `rrggbb` hex (no `#` prefix) in config files. Color struct is `{r: u8, g: u8, b: u8}`.

## Phase 1: Build Infrastructure

**Status:** complete

**Tasks completed:**

- 1.1: Added Zig 0.15.2 to `mise.toml` tools
- 1.2: Created `scripts/build-ghostty.sh` — clones Ghostty at pinned commit, applies native-only patch (skips iOS targets), builds XCFramework
- 1.3: Added `build:ghostty` mise task
- 1.4: Built and verified XCFramework at `Frameworks/GhosttyKit.xcframework` — contains `libghostty-fat.a`, `ghostty.h`, `module.modulemap` (GhosttyKit module)
- 1.5: Added `Frameworks/` to `.gitignore`

**Files changed:**

- `mise.toml` — added zig tool + build:ghostty task
- `scripts/build-ghostty.sh` — new build script
- `.gitignore` — added Frameworks/

**Commits:**

- `1432452` — feat: add GhosttyKit XCFramework build infrastructure

**Decisions & context for next phase:**

- **XCFramework structure**: `macos-arm64/libghostty-fat.a` + `macos-arm64/Headers/ghostty.h` + `macos-arm64/Headers/module.modulemap`
- **Native-only patch**: Build script patches `GhosttyXCFramework.zig` to skip iOS/iOS Simulator target init when `xcframework-target=native`. Without this, build fails without full Xcode iOS SDK.
- **Requires Xcode.app**: Metal shader compilation and iOS SDK both need full Xcode, not just Command Line Tools. Also requires `xcodebuild -downloadComponent MetalToolchain`.
- **SPM integration note**: XCFramework uses `Headers/` layout (not `.framework` bundle). SPM `.binaryTarget` should work with this.
