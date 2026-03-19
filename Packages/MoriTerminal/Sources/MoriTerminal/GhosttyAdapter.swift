import AppKit
import MoriCore
import GhosttyKit

/// Terminal adapter backed by libghostty — GPU-accelerated terminal with
/// native mouse, scroll, paste, and IME support.
@MainActor
public final class GhosttyAdapter: TerminalHost {

    public var settings: TerminalSettings {
        didSet {
            if settings != oldValue {
                settings.save()
            }
        }
    }

    public init(settings: TerminalSettings = .load()) {
        self.settings = settings
    }

    public func createSurface(command: String, workingDirectory: String) -> NSView {
        // TODO: Phase 4 — create GhosttySurfaceView + ghostty_surface_new
        fatalError("GhosttyAdapter.createSurface not yet implemented")
    }

    public func destroySurface(_ surface: NSView) {
        // TODO: Phase 4
    }

    public func surfaceDidResize(_ surface: NSView, to size: NSSize) {
        // TODO: Phase 4
    }

    public func focusSurface(_ surface: NSView) {
        // TODO: Phase 4
    }

    public func applySettings(to surface: NSView) {
        // TODO: Phase 4
    }
}
