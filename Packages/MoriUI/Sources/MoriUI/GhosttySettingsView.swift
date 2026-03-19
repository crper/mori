import SwiftUI

/// Settings model representing user-facing ghostty config options.
/// Read from and written to ~/.config/ghostty/config.
public struct GhosttySettingsModel: Equatable {
    public var fontFamily: String
    public var fontSize: Int
    public var theme: String
    public var cursorStyle: String
    public var cursorBlink: Bool
    public var backgroundOpacity: Double
    public var macosOptionAsAlt: String
    public var mouseHideWhileTyping: Bool
    public var mouseScrollMultiplier: Int
    public var copyOnSelect: String
    public var windowPaddingBalance: Bool
    public var keybinds: [String]

    public init(
        fontFamily: String = "",
        fontSize: Int = 13,
        theme: String = "",
        cursorStyle: String = "block",
        cursorBlink: Bool = true,
        backgroundOpacity: Double = 1.0,
        macosOptionAsAlt: String = "false",
        mouseHideWhileTyping: Bool = false,
        mouseScrollMultiplier: Int = 1,
        copyOnSelect: String = "false",
        windowPaddingBalance: Bool = false,
        keybinds: [String] = []
    ) {
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.theme = theme
        self.cursorStyle = cursorStyle
        self.cursorBlink = cursorBlink
        self.backgroundOpacity = backgroundOpacity
        self.macosOptionAsAlt = macosOptionAsAlt
        self.mouseHideWhileTyping = mouseHideWhileTyping
        self.mouseScrollMultiplier = mouseScrollMultiplier
        self.copyOnSelect = copyOnSelect
        self.windowPaddingBalance = windowPaddingBalance
        self.keybinds = keybinds
    }
}

// MARK: - Settings Category

enum SettingsCategory: String, CaseIterable, Identifiable {
    case theme = "Theme"
    case fonts = "Fonts"
    case cursor = "Cursor"
    case keyboard = "Keyboard"
    case mouse = "Mouse"
    case window = "Window"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .theme: return "paintpalette"
        case .fonts: return "textformat"
        case .cursor: return "character.cursor.ibeam"
        case .keyboard: return "keyboard"
        case .mouse: return "computermouse"
        case .window: return "macwindow"
        }
    }
}

// MARK: - Main Settings View

public struct GhosttySettingsView: View {
    @Binding var model: GhosttySettingsModel
    var availableThemes: [String]
    var onChanged: () -> Void
    var onOpenConfigFile: () -> Void

    @State private var selectedCategory: SettingsCategory = .theme

    public init(
        model: Binding<GhosttySettingsModel>,
        availableThemes: [String],
        onChanged: @escaping () -> Void,
        onOpenConfigFile: @escaping () -> Void
    ) {
        self._model = model
        self.availableThemes = availableThemes
        self.onChanged = onChanged
        self.onOpenConfigFile = onOpenConfigFile
    }

    public var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            contentArea
        }
        .frame(minWidth: 740, idealWidth: 780, minHeight: 540, idealHeight: 600)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 2) {
                ForEach(SettingsCategory.allCases) { category in
                    sidebarRow(category)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 12)

            Spacer()

            Divider()
                .padding(.horizontal, 12)

            Button(action: onOpenConfigFile) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 13))
                    Text("Open Config File")
                        .font(.system(size: 12))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 8)
        }
        .frame(width: 180)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
    }

    private func sidebarRow(_ category: SettingsCategory) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            selectedCategory = category
        } label: {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 13))
                    .frame(width: 20)
                    .foregroundStyle(isSelected ? .white : .secondary)
                Text(category.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : .primary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content Area

    private var contentArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text(selectedCategory.rawValue)
                .font(.title2.weight(.semibold))
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedCategory {
                    case .theme: ThemeSettingsContent(model: $model, availableThemes: availableThemes, onChanged: onChanged)
                    case .fonts: FontSettingsContent(model: $model, onChanged: onChanged)
                    case .cursor: CursorSettingsContent(model: $model, onChanged: onChanged)
                    case .keyboard: KeyboardSettingsContent(model: $model, onChanged: onChanged)
                    case .mouse: MouseSettingsContent(model: $model, onChanged: onChanged)
                    case .window: WindowSettingsContent(model: $model, onChanged: onChanged)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Setting Row Components

/// A single setting row with title, optional description, and a control on the right.
private struct SettingRow<Control: View>: View {
    let title: String
    var description: String? = nil
    @ViewBuilder var control: () -> Control

    var body: some View {
        HStack(alignment: description != nil ? .top : .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                if let description {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 16)
            control()
        }
    }
}

/// A card container for grouping related settings.
private struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct CardDivider: View {
    var body: some View {
        Divider().padding(.vertical, 12)
    }
}

// MARK: - Terminal Preview

/// Simulated terminal preview showing font, theme colors, and cursor.
private struct TerminalPreview: View {
    let fontFamily: String
    let fontSize: Int
    let cursorStyle: String
    let opacity: Double

    private var previewFont: Font {
        let name = fontFamily.isEmpty ? "SF Mono" : fontFamily
        return .custom(name, size: CGFloat(fontSize))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title bar
            HStack(spacing: 6) {
                Circle().fill(.red.opacity(0.8)).frame(width: 10, height: 10)
                Circle().fill(.yellow.opacity(0.8)).frame(width: 10, height: 10)
                Circle().fill(.green.opacity(0.8)).frame(width: 10, height: 10)
                Spacer()
                Text("Terminal Preview")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.05))

            // Terminal content
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 0) {
                    Text("user").foregroundStyle(.green) +
                    Text("@").foregroundStyle(.secondary) +
                    Text("mori").foregroundStyle(.cyan)
                    Text(" ~ $ ").foregroundStyle(.secondary)
                    Text("ls -la").foregroundStyle(.primary)
                }

                HStack(spacing: 0) {
                    Text("drwxr-xr-x  ").foregroundStyle(.secondary)
                    Text("src/").foregroundStyle(.blue)
                }

                HStack(spacing: 0) {
                    Text("-rw-r--r--  ").foregroundStyle(.secondary)
                    Text("README.md").foregroundStyle(.primary)
                }

                HStack(spacing: 0) {
                    Text("-rw-r--r--  ").foregroundStyle(.secondary)
                    Text("Package.swift").foregroundStyle(.yellow)
                }

                HStack(spacing: 0) {
                    Text("user").foregroundStyle(.green) +
                    Text("@").foregroundStyle(.secondary) +
                    Text("mori").foregroundStyle(.cyan)
                    Text(" ~ $ ").foregroundStyle(.secondary)
                    cursorView
                }
            }
            .font(previewFont)
            .padding(10)
        }
        .background(Color.black.opacity(opacity))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var cursorView: some View {
        switch cursorStyle {
        case "bar":
            Rectangle()
                .fill(Color.white.opacity(0.8))
                .frame(width: 2, height: CGFloat(fontSize))
        case "underline":
            VStack(spacing: 0) {
                Color.clear.frame(height: CGFloat(fontSize) - 2)
                Rectangle().fill(Color.white.opacity(0.8)).frame(width: CGFloat(fontSize) * 0.6, height: 2)
            }
            .frame(height: CGFloat(fontSize))
        default: // block
            Rectangle()
                .fill(Color.white.opacity(0.5))
                .frame(width: CGFloat(fontSize) * 0.6, height: CGFloat(fontSize))
        }
    }
}

// MARK: - Theme Settings

private struct ThemeSettingsContent: View {
    @Binding var model: GhosttySettingsModel
    let availableThemes: [String]
    let onChanged: () -> Void

    @State private var themeSearch = ""

    var body: some View {
        // Preview
        TerminalPreview(
            fontFamily: model.fontFamily,
            fontSize: model.fontSize,
            cursorStyle: model.cursorStyle,
            opacity: model.backgroundOpacity
        )

        // Theme settings card
        SettingsCard {
            SettingRow(
                title: "Color theme",
                description: "Select a color scheme for the terminal."
            ) {
                Text(model.theme.isEmpty ? "Default" : model.theme)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 160, alignment: .trailing)
            }

            CardDivider()

            // Theme search and list
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 12))
                TextField("Search themes…", text: $themeSearch)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !themeSearch.isEmpty {
                    Button { themeSearch = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.04))
            )

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredThemes, id: \.self) { name in
                        themeListRow(name)
                    }
                }
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )

            CardDivider()

            SettingRow(
                title: "Background opacity",
                description: "Translucent background behind the terminal content."
            ) {
                HStack(spacing: 8) {
                    Text(String(format: "%.2f", model.backgroundOpacity))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 36)
                    Slider(value: $model.backgroundOpacity, in: 0.1...1.0, step: 0.05)
                        .frame(width: 140)
                        .onChange(of: model.backgroundOpacity) { _, _ in onChanged() }
                }
            }
        }
    }

    private var filteredThemes: [String] {
        guard !themeSearch.isEmpty else { return availableThemes }
        let query = themeSearch.lowercased()
        return availableThemes.filter { $0.lowercased().contains(query) }
    }

    @ViewBuilder
    private func themeListRow(_ name: String) -> some View {
        let isSelected = model.theme.lowercased() == name.lowercased()
        HStack {
            Text(name)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isSelected ? Color.accentColor.opacity(0.1) : .clear)
        .contentShape(Rectangle())
        .onTapGesture {
            model.theme = name
            onChanged()
        }
    }
}

// MARK: - Font Settings

private struct FontSettingsContent: View {
    @Binding var model: GhosttySettingsModel
    let onChanged: () -> Void

    @State private var fontSearch = ""

    var body: some View {
        TerminalPreview(
            fontFamily: model.fontFamily,
            fontSize: model.fontSize,
            cursorStyle: model.cursorStyle,
            opacity: model.backgroundOpacity
        )

        SettingsCard {
            SettingRow(
                title: "Font family",
                description: "The font to use for terminal text. Leave empty for the default."
            ) {
                TextField("SF Mono", text: $model.fontFamily)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                    .font(.system(size: 12))
                    .onChange(of: model.fontFamily) { _, _ in onChanged() }
            }

            CardDivider()

            SettingRow(
                title: "Font size",
                description: "Size in points for terminal text."
            ) {
                HStack(spacing: 8) {
                    Text("\(model.fontSize) pt")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 40)
                    Stepper("", value: $model.fontSize, in: 6...48)
                        .labelsHidden()
                        .onChange(of: model.fontSize) { _, _ in onChanged() }
                }
            }
        }

        // Monospace font browser
        SettingsCard {
            Text("Available Monospace Fonts")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 12))
                TextField("Filter fonts…", text: $fontSearch)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.04))
            )

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredFonts, id: \.self) { family in
                        fontRow(family)
                    }
                }
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func fontRow(_ family: String) -> some View {
        let isSelected = model.fontFamily.lowercased() == family.lowercased()
        HStack {
            Text(family)
                .font(.custom(family, size: 13))
                .lineLimit(1)
            Spacer()
            Text("Aa 0O Il 1l")
                .font(.custom(family, size: 11))
                .foregroundStyle(.secondary)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isSelected ? Color.accentColor.opacity(0.1) : .clear)
        .contentShape(Rectangle())
        .onTapGesture {
            model.fontFamily = family
            onChanged()
        }
    }

    private var monospacedFonts: [String] {
        let manager = NSFontManager.shared
        return manager.availableFontFamilies.filter { family in
            guard let members = manager.availableMembers(ofFontFamily: family),
                  let first = members.first,
                  let fontName = first[0] as? String,
                  let font = NSFont(name: fontName, size: 13)
            else { return false }
            return font.isFixedPitch
        }.sorted()
    }

    private var filteredFonts: [String] {
        let all = monospacedFonts
        guard !fontSearch.isEmpty else { return all }
        let query = fontSearch.lowercased()
        return all.filter { $0.lowercased().contains(query) }
    }
}

// MARK: - Cursor Settings

private struct CursorSettingsContent: View {
    @Binding var model: GhosttySettingsModel
    let onChanged: () -> Void

    var body: some View {
        TerminalPreview(
            fontFamily: model.fontFamily,
            fontSize: model.fontSize,
            cursorStyle: model.cursorStyle,
            opacity: model.backgroundOpacity
        )

        SettingsCard {
            SettingRow(
                title: "Cursor style",
                description: "The shape of the cursor in the terminal."
            ) {
                Picker("", selection: $model.cursorStyle) {
                    Text("Block").tag("block")
                    Text("Bar").tag("bar")
                    Text("Underline").tag("underline")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 200)
                .onChange(of: model.cursorStyle) { _, _ in onChanged() }
            }

            CardDivider()

            SettingRow(
                title: "Cursor blink",
                description: "Whether the cursor blinks when idle."
            ) {
                Toggle("", isOn: $model.cursorBlink)
                    .labelsHidden()
                    .onChange(of: model.cursorBlink) { _, _ in onChanged() }
            }
        }
    }
}

// MARK: - Keyboard Settings

private struct KeyboardSettingsContent: View {
    @Binding var model: GhosttySettingsModel
    let onChanged: () -> Void

    var body: some View {
        SettingsCard {
            SettingRow(
                title: "Option as Alt",
                description: "Treat the macOS Option key as Alt for terminal escape sequences. Disables special character input when enabled."
            ) {
                Picker("", selection: $model.macosOptionAsAlt) {
                    Text("Off").tag("false")
                    Text("On").tag("true")
                    Text("Left").tag("left")
                    Text("Right").tag("right")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)
                .onChange(of: model.macosOptionAsAlt) { _, _ in onChanged() }
            }
        }

        SettingsCard {
            HStack {
                Text("Custom Keybinds")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(model.keybinds.count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            if model.keybinds.isEmpty {
                Text("No custom keybinds configured.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(model.keybinds.enumerated()), id: \.offset) { index, bind in
                    if index > 0 { CardDivider() }
                    HStack {
                        Text(bind)
                            .font(.system(size: 12, design: .monospaced))
                            .lineLimit(1)
                        Spacer()
                        Button {
                            model.keybinds.remove(at: index)
                            onChanged()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            CardDivider()

            Text("Edit the config file to add new keybinds.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Mouse Settings

private struct MouseSettingsContent: View {
    @Binding var model: GhosttySettingsModel
    let onChanged: () -> Void

    var body: some View {
        SettingsCard {
            SettingRow(
                title: "Hide while typing",
                description: "Automatically hide the mouse cursor when typing in the terminal."
            ) {
                Toggle("", isOn: $model.mouseHideWhileTyping)
                    .labelsHidden()
                    .onChange(of: model.mouseHideWhileTyping) { _, _ in onChanged() }
            }

            CardDivider()

            SettingRow(
                title: "Scroll multiplier",
                description: "Multiplier for mouse scroll speed."
            ) {
                HStack(spacing: 8) {
                    Text("\(model.mouseScrollMultiplier)x")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 28)
                    Stepper("", value: $model.mouseScrollMultiplier, in: 1...10)
                        .labelsHidden()
                        .onChange(of: model.mouseScrollMultiplier) { _, _ in onChanged() }
                }
            }

            CardDivider()

            SettingRow(
                title: "Copy on select",
                description: "Automatically copy selected text to the clipboard."
            ) {
                Picker("", selection: $model.copyOnSelect) {
                    Text("Off").tag("false")
                    Text("On").tag("true")
                    Text("Clipboard").tag("clipboard")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 180)
                .onChange(of: model.copyOnSelect) { _, _ in onChanged() }
            }
        }
    }
}

// MARK: - Window Settings

private struct WindowSettingsContent: View {
    @Binding var model: GhosttySettingsModel
    let onChanged: () -> Void

    var body: some View {
        SettingsCard {
            SettingRow(
                title: "Balance window padding",
                description: "Distribute extra padding evenly around the terminal content to center it within the window."
            ) {
                Toggle("", isOn: $model.windowPaddingBalance)
                    .labelsHidden()
                    .onChange(of: model.windowPaddingBalance) { _, _ in onChanged() }
            }
        }
    }
}
