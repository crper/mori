import AppKit

final class MainWindowController: NSWindowController {

    // MARK: - Init

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 800, height: 500)
        window.title = "Mori"
        window.titlebarAppearsTransparent = true
        window.setFrameAutosaveName("MoriMainWindow")
        if !window.setFrameUsingName("MoriMainWindow") {
            window.center()
        }

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public

    func updateTitle(projectName: String?) {
        window?.title = projectName.map { "\($0) — Mori" } ?? "Mori"
    }
}
