import Foundation
import AppKit

final class WindowManager {
    static let shared = WindowManager()
    
    private var quickAccessPanels: [QuickAccessPanel] = []
    private var editorControllers: [EditorWindowController] = []
    private var pinControllers: [PinWindowController] = []
    private var historyWindowController: HistoryWindowController?
    private var settingsWindowController: NSWindowController?
    private var aboutWindowController: NSWindowController?
    
    private init() {}
    
    func showQuickAccess(image: NSImage, fileURL: URL) {
        let panel = QuickAccessPanel(image: image, fileURL: fileURL, stackIndex: quickAccessPanels.count)
        quickAccessPanels.append(panel)
        panel.orderFront(nil)
    }
    
    func removeQuickAccess(_ panel: QuickAccessPanel) {
        quickAccessPanels.removeAll { $0 === panel }
    }
    
    func openEditor(with image: NSImage) {
        let editor = EditorWindowController(image: image)
        editorControllers.append(editor)
        editor.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func pinImage(_ image: NSImage) {
        let pin = PinWindowController(image: image)
        pinControllers.append(pin)
        pin.showWindow(nil)
    }
    
    func removePin(_ pin: PinWindowController) {
        pinControllers.removeAll { $0 === pin }
    }
    
    func openFileFromDisk() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.png, .jpeg, .tiff, .heic, .pdf]
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Open"
        openPanel.message = "Select an image to annotate in Alt. Markup"
        
        if openPanel.runModal() == .OK, let url = openPanel.url, let image = NSImage(contentsOf: url) {
            openEditor(with: image)
        }
    }
    
    func openHistory() {
        HistoryWindowController.shared.showHistory()
    }
    
    func showAbout() {
        if let controller = aboutWindowController {
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About Alt."
        window.center()
        window.isReleasedWhenClosed = false
        
        let view = NSView(frame: window.contentView!.bounds)
        window.contentView = view
        
        // App Icon
        let iconView = NSImageView(frame: NSRect(x: 140, y: 160, width: 80, height: 80))
        iconView.image = NSApp.applicationIconImage ?? MenuBarManager.createAltLogo()
        view.addSubview(iconView)
        
        // Title
        let titleLabel = NSTextField(labelWithString: "Alt.")
        titleLabel.font = NSFont.systemFont(ofSize: 26, weight: .heavy)
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 20, y: 120, width: 320, height: 30)
        view.addSubview(titleLabel)
        
        // Version
        let versionLabel = NSTextField(labelWithString: "Version 1.0.0 • Pro Commercial Edition")
        versionLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        versionLabel.textColor = NSColor(red: 0.25, green: 0.65, blue: 1.0, alpha: 1.0)
        versionLabel.alignment = .center
        versionLabel.frame = NSRect(x: 20, y: 95, width: 320, height: 20)
        view.addSubview(versionLabel)
        
        // Description
        let descLabel = NSTextField(labelWithString: "The next-generation native screen utility & recording studio for macOS.\nEngineered with pure Swift & AppKit.")
        descLabel.font = NSFont.systemFont(ofSize: 11)
        descLabel.textColor = .secondaryLabelColor
        descLabel.alignment = .center
        descLabel.frame = NSRect(x: 20, y: 46, width: 320, height: 38)
        view.addSubview(descLabel)
        
        // Copyright
        let copyLabel = NSTextField(labelWithString: "© 2026 Alt. All rights reserved.")
        copyLabel.font = NSFont.systemFont(ofSize: 10)
        copyLabel.textColor = .tertiaryLabelColor
        copyLabel.alignment = .center
        copyLabel.frame = NSRect(x: 20, y: 16, width: 320, height: 16)
        view.addSubview(copyLabel)
        
        let controller = NSWindowController(window: window)
        self.aboutWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func showToast(message: String) {
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let width: CGFloat = 340
        let height: CGFloat = 44
        let x = (screenRect.width - width) / 2.0
        let y = screenRect.minY + 80
        
        let panel = NSPanel(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        
        let effect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        effect.material = .hudWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 10
        effect.layer?.masksToBounds = true
        
        let label = NSTextField(labelWithString: message)
        label.font = NSFont.boldSystemFont(ofSize: 13)
        label.textColor = .white
        label.alignment = .center
        label.frame = NSRect(x: 10, y: 12, width: width - 20, height: 20)
        effect.addSubview(label)
        
        panel.contentView = effect
        panel.orderFront(nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                panel.animator().alphaValue = 0.0
            }, completionHandler: {
                panel.close()
            })
        }
    }
    
    func openSettings() {
        if let existing = settingsWindowController {
            existing.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Alt. Preferences & Settings"
        window.center()
        window.isReleasedWhenClosed = false
        
        let view = NSView(frame: window.contentView!.bounds)
        window.contentView = view
        
        var y: CGFloat = 430
        
        // 1. General Toggles
        let autoCopyBtn = NSButton(checkboxWithTitle: "Automatically copy screenshot to Clipboard", target: self, action: #selector(toggleAutoCopy(_:)))
        autoCopyBtn.frame = NSRect(x: 24, y: y, width: 460, height: 24)
        autoCopyBtn.state = SettingsManager.shared.autoCopyToClipboard ? .on : .off
        view.addSubview(autoCopyBtn)
        y -= 32
        
        let quickAccessBtn = NSButton(checkboxWithTitle: "Show Quick Access Floating Overlay", target: self, action: #selector(toggleQuickAccess(_:)))
        quickAccessBtn.frame = NSRect(x: 24, y: y, width: 460, height: 24)
        quickAccessBtn.state = SettingsManager.shared.showQuickAccess ? .on : .off
        view.addSubview(quickAccessBtn)
        y -= 32
        
        let soundBtn = NSButton(checkboxWithTitle: "Play camera shutter sound", target: self, action: #selector(toggleSound(_:)))
        soundBtn.frame = NSRect(x: 24, y: y, width: 460, height: 24)
        soundBtn.state = SettingsManager.shared.playShutterSound ? .on : .off
        view.addSubview(soundBtn)
        y -= 32
        
        let editorBtn = NSButton(checkboxWithTitle: "Always open Markup Editor directly after capture", target: self, action: #selector(toggleEditor(_:)))
        editorBtn.frame = NSRect(x: 24, y: y, width: 460, height: 24)
        editorBtn.state = SettingsManager.shared.openEditorDirectly ? .on : .off
        view.addSubview(editorBtn)
        y -= 38
        
        // 2. Format & Naming Section
        let formatLabel = NSTextField(labelWithString: "Default Image Format:")
        formatLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        formatLabel.frame = NSRect(x: 24, y: y, width: 170, height: 22)
        view.addSubview(formatLabel)
        
        let formatPopup = NSPopUpButton(frame: NSRect(x: 200, y: y - 2, width: 200, height: 26), pullsDown: false)
        for fmt in ExportImageFormat.allCases {
            formatPopup.addItem(withTitle: fmt.rawValue)
        }
        formatPopup.selectItem(withTitle: SettingsManager.shared.exportFormat.rawValue)
        formatPopup.target = self
        formatPopup.action = #selector(formatChanged(_:))
        view.addSubview(formatPopup)
        y -= 36
        
        let prefixLabel = NSTextField(labelWithString: "Filename Prefix:")
        prefixLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        prefixLabel.frame = NSRect(x: 24, y: y, width: 170, height: 22)
        view.addSubview(prefixLabel)
        
        let prefixField = NSTextField(frame: NSRect(x: 200, y: y - 2, width: 195, height: 24))
        prefixField.stringValue = SettingsManager.shared.filenamePrefix
        prefixField.target = self
        prefixField.action = #selector(prefixChanged(_:))
        view.addSubview(prefixField)
        y -= 42
        
        // 3. Save Location
        let folderLabel = NSTextField(labelWithString: "Save Directory: \(SettingsManager.shared.saveDirectory)")
        folderLabel.frame = NSRect(x: 24, y: y, width: 350, height: 28)
        folderLabel.lineBreakMode = .byTruncatingMiddle
        view.addSubview(folderLabel)
        
        let changeFolderBtn = NSButton(title: "Change...", target: self, action: #selector(chooseSaveDirectory))
        changeFolderBtn.frame = NSRect(x: 390, y: y, width: 95, height: 28)
        view.addSubview(changeFolderBtn)
        y -= 54
        
        // 4. Global Shortcuts Box (Cheat Sheet)
        let box = NSBox(frame: NSRect(x: 20, y: 16, width: 480, height: y))
        box.title = "Global Keyboard Shortcuts"
        box.titleFont = NSFont.boldSystemFont(ofSize: 12)
        
        let shortcuts = [
            ("⌘ + ⇧ + 1", "Capture Area"),
            ("⌘ + ⇧ + 2", "Record Screen (GIF / Video) HUD"),
            ("⌘ + ⇧ + 3", "Capture Fullscreen"),
            ("⌘ + ⇧ + 4", "Scrolling Capture"),
            ("⌘ + ⇧ + C", "Capture Text (OCR) to Clipboard"),
            ("⌘ + ⇧ + Z", "Capture History Carousel")
        ]
        
        var sy: CGFloat = box.contentView!.bounds.height - 30
        for sc in shortcuts {
            let keyLabel = NSTextField(labelWithString: sc.0)
            keyLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
            keyLabel.frame = NSRect(x: 16, y: sy, width: 120, height: 18)
            box.contentView?.addSubview(keyLabel)
            
            let desc = NSTextField(labelWithString: sc.1)
            desc.font = NSFont.systemFont(ofSize: 12)
            desc.textColor = .secondaryLabelColor
            desc.frame = NSRect(x: 140, y: sy, width: 300, height: 18)
            box.contentView?.addSubview(desc)
            sy -= 22
        }
        
        view.addSubview(box)
        
        let controller = NSWindowController(window: window)
        self.settingsWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func formatChanged(_ sender: NSPopUpButton) {
        let formats = ExportImageFormat.allCases
        if sender.indexOfSelectedItem >= 0 && sender.indexOfSelectedItem < formats.count {
            SettingsManager.shared.exportFormat = formats[sender.indexOfSelectedItem]
        }
    }
    
    @objc private func prefixChanged(_ sender: NSTextField) {
        let val = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !val.isEmpty {
            SettingsManager.shared.filenamePrefix = val
        }
    }
    
    @objc private func toggleAutoCopy(_ sender: NSButton) {
        SettingsManager.shared.autoCopyToClipboard = (sender.state == .on)
    }
    
    @objc private func toggleQuickAccess(_ sender: NSButton) {
        SettingsManager.shared.showQuickAccess = (sender.state == .on)
    }
    
    @objc private func toggleSound(_ sender: NSButton) {
        SettingsManager.shared.playShutterSound = (sender.state == .on)
    }
    
    @objc private func toggleEditor(_ sender: NSButton) {
        SettingsManager.shared.openEditorDirectly = (sender.state == .on)
    }
    
    @objc private func chooseSaveDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Choose"
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            SettingsManager.shared.saveDirectory = url.path
            openSettings()
        }
    }
}
