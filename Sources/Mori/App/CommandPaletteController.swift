import AppKit
import MoriCore

/// NSWindowController managing a floating command palette panel.
/// Contains an NSTextField for search and an NSTableView for results.
@MainActor
final class CommandPaletteController: NSWindowController {

    // MARK: - Callbacks

    /// Called when the user selects an item. The caller routes to WorkspaceManager.
    var onSelectItem: ((CommandPaletteItem) -> Void)?

    // MARK: - State

    private var dataSource: CommandPaletteDataSource?
    private var results: [CommandPaletteItem] = []
    private var selectedIndex: Int = 0

    // MARK: - Views

    private let searchField = NSTextField()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let containerView = NSView()

    // MARK: - Constants

    private let panelWidth: CGFloat = 500
    private let searchFieldHeight: CGFloat = 36
    private let rowHeight: CGFloat = 32
    private let maxVisibleRows: Int = 10

    // MARK: - Init

    init(appState: AppState) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.hasShadow = true
        panel.backgroundColor = .windowBackgroundColor
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = true
        panel.becomesKeyOnlyIfNeeded = true

        super.init(window: panel)

        self.dataSource = CommandPaletteDataSource(appState: appState)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public

    /// Toggle palette visibility.
    func toggle() {
        if let panel = window, panel.isVisible {
            dismiss()
        } else {
            show()
        }
    }

    func show() {
        guard let panel = window else { return }

        // Reset state
        searchField.stringValue = ""
        selectedIndex = 0
        updateResults()

        // Center above the main window
        positionPanel()

        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(searchField)
    }

    func dismiss() {
        window?.orderOut(nil)
    }

    // MARK: - Setup

    private func setupUI() {
        guard let panel = window else { return }

        containerView.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = containerView

        setupSearchField()
        setupTableView()
        layoutViews()
    }

    private func setupSearchField() {
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Search projects, worktrees, windows, actions..."
        searchField.font = .systemFont(ofSize: 16)
        searchField.isBordered = false
        searchField.focusRingType = .none
        searchField.bezelStyle = .roundedBezel
        searchField.isBezeled = true
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(searchFieldAction(_:))
        containerView.addSubview(searchField)
    }

    private func setupTableView() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("results"))
        column.title = ""
        column.width = panelWidth - 20
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = rowHeight
        tableView.selectionHighlightStyle = .regular
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.target = self
        tableView.doubleAction = #selector(tableDoubleClicked)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        containerView.addSubview(scrollView)
    }

    private func layoutViews() {
        let separator = NSBox()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.boxType = .separator
        containerView.addSubview(separator)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            searchField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            searchField.heightAnchor.constraint(equalToConstant: searchFieldHeight),

            separator.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            separator.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: separator.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
    }

    // MARK: - Positioning

    private func positionPanel() {
        guard let panel = window else { return }

        if let mainWindow = NSApp.mainWindow ?? NSApp.keyWindow {
            let mainFrame = mainWindow.frame
            let panelHeight = computePanelHeight()
            let x = mainFrame.midX - panelWidth / 2
            let y = mainFrame.maxY - panelHeight - 80
            panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        } else {
            let panelHeight = computePanelHeight()
            panel.setFrame(NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight), display: true)
            panel.center()
        }
    }

    private func computePanelHeight() -> CGFloat {
        let visibleRows = min(results.count, maxVisibleRows)
        let tableHeight = CGFloat(max(visibleRows, 1)) * rowHeight
        let topPadding: CGFloat = 8 + searchFieldHeight + 8 + 1 // padding + field + padding + separator
        return topPadding + tableHeight + 8
    }

    // MARK: - Results

    private func updateResults() {
        let query = searchField.stringValue
        results = dataSource?.search(query: query) ?? []
        selectedIndex = results.isEmpty ? -1 : 0
        tableView.reloadData()

        if selectedIndex >= 0 {
            tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        }

        // Resize panel to fit results
        resizePanel()
    }

    private func resizePanel() {
        guard let panel = window else { return }
        let panelHeight = computePanelHeight()
        var frame = panel.frame
        let heightDiff = panelHeight - frame.height
        frame.origin.y -= heightDiff
        frame.size.height = panelHeight
        panel.setFrame(frame, display: true, animate: false)
    }

    // MARK: - Selection

    private func confirmSelection() {
        guard selectedIndex >= 0, selectedIndex < results.count else { return }
        let item = results[selectedIndex]
        dismiss()
        onSelectItem?(item)
    }

    private func moveSelectionUp() {
        guard !results.isEmpty else { return }
        selectedIndex = max(0, selectedIndex - 1)
        tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        tableView.scrollRowToVisible(selectedIndex)
    }

    private func moveSelectionDown() {
        guard !results.isEmpty else { return }
        selectedIndex = min(results.count - 1, selectedIndex + 1)
        tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        tableView.scrollRowToVisible(selectedIndex)
    }

    // MARK: - Actions

    @objc private func searchFieldAction(_ sender: NSTextField) {
        confirmSelection()
    }

    @objc private func tableDoubleClicked() {
        let row = tableView.clickedRow
        guard row >= 0, row < results.count else { return }
        selectedIndex = row
        confirmSelection()
    }
}

// MARK: - NSTextFieldDelegate

extension CommandPaletteController: NSTextFieldDelegate {

    func controlTextDidChange(_ notification: Notification) {
        updateResults()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.moveUp(_:)) {
            moveSelectionUp()
            return true
        }
        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            moveSelectionDown()
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            dismiss()
            return true
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            confirmSelection()
            return true
        }
        return false
    }
}

// MARK: - NSTableViewDataSource

extension CommandPaletteController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        results.count
    }
}

// MARK: - NSTableViewDelegate

extension CommandPaletteController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < results.count else { return nil }
        let item = results[row]

        let cellID = NSUserInterfaceItemIdentifier("CommandPaletteCell")
        let cell: NSTableCellView

        if let existing = tableView.makeView(withIdentifier: cellID, owner: nil) as? NSTableCellView {
            cell = existing
        } else {
            cell = makeCell(identifier: cellID)
        }

        // Configure icon
        if let iconName = item.iconName {
            cell.imageView?.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        } else {
            cell.imageView?.image = nil
        }

        // Configure text
        cell.textField?.stringValue = item.title

        // Configure subtitle (second text field, tag 100)
        if let subtitleField = cell.viewWithTag(100) as? NSTextField {
            subtitleField.stringValue = item.subtitle ?? ""
            subtitleField.isHidden = item.subtitle == nil
        }

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        if row >= 0 {
            selectedIndex = row
        }
    }

    private func makeCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier

        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyDown
        cell.addSubview(imageView)
        cell.imageView = imageView

        let titleField = NSTextField(labelWithString: "")
        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.font = .systemFont(ofSize: 13)
        titleField.lineBreakMode = .byTruncatingTail
        cell.addSubview(titleField)
        cell.textField = titleField

        let subtitleField = NSTextField(labelWithString: "")
        subtitleField.translatesAutoresizingMaskIntoConstraints = false
        subtitleField.font = .systemFont(ofSize: 11)
        subtitleField.textColor = .secondaryLabelColor
        subtitleField.lineBreakMode = .byTruncatingTail
        subtitleField.tag = 100
        cell.addSubview(subtitleField)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 18),
            imageView.heightAnchor.constraint(equalToConstant: 18),

            titleField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 8),
            titleField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),

            subtitleField.leadingAnchor.constraint(equalTo: titleField.trailingAnchor, constant: 8),
            subtitleField.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -8),
            subtitleField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])

        // Let title compress but not subtitle
        titleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        subtitleField.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        return cell
    }
}
