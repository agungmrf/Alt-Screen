import Foundation
import AppKit
import AVFoundation

final class RecordingHUDWindowController: NSWindowController {
    static let shared = RecordingHUDWindowController()
    
    // Toggles state
    var isMicEnabled: Bool = false
    var isSystemAudioEnabled: Bool = false
    var isWebcamEnabled: Bool = false
    var isClicksEnabled: Bool = true
    var isKeystrokesEnabled: Bool = false
    
    var captureWidth: Int = 1920
    var captureHeight: Int = 1080
    var selectedRecordingRect: CGRect? = nil
    
    // UI elements
    private var dimPill: NSView!
    private var dimLabel: NSTextField!
    private var micButton: NSButton!
    private var audioButton: NSButton!
    private var webcamButton: NSButton!
    private var clicksButton: NSButton!
    private var keystrokesButton: NSButton!
    
    init() {
        let panelWidth: CGFloat = 340
        let panelHeight: CGFloat = 260
        
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let x = (screenRect.width - panelWidth) / 2.0
        let y = (screenRect.height - panelHeight) / 2.0
        
        let window = NSWindow(
            contentRect: NSRect(x: x, y: y, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        super.init(window: window)
        setupUI(width: panelWidth, height: panelHeight)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI(width: CGFloat, height: CGFloat) {
        guard let window = self.window else { return }
        
        let mainView = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        
        // 1. Top Card: Dimensions & Toggles (Matches CleanShot X top card)
        let topCard = createGlassCard(frame: NSRect(x: 0, y: 135, width: width, height: 120), cornerRadius: 20)
        mainView.addSubview(topCard)
        
        // Top Row: Settings, Dimensions, Preset, Crop
        let settingsIcon = createIconButton(name: "slider.horizontal.3", frame: NSRect(x: 16, y: 72, width: 34, height: 34), action: #selector(showSettingsMenu))
        topCard.addSubview(settingsIcon)
        
        // Dimensions Pill: e.g. "1920 × 1080" (Clickable with dropdown menu)
        dimPill = NSView(frame: NSRect(x: 62, y: 72, width: 156, height: 34))
        dimPill.wantsLayer = true
        dimPill.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        dimPill.layer?.cornerRadius = 10
        dimPill.layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
        dimPill.layer?.borderWidth = 1
        
        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        captureWidth = Int(screen.width)
        captureHeight = Int(screen.height)
        
        dimLabel = NSTextField(labelWithString: "\(captureWidth)  ×  \(captureHeight)")
        dimLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .bold)
        dimLabel.textColor = .white
        dimLabel.alignment = .center
        dimLabel.frame = NSRect(x: 4, y: 8, width: 120, height: 18)
        dimPill.addSubview(dimLabel)
        
        let fitIcon = NSImageView(frame: NSRect(x: 128, y: 9, width: 16, height: 16))
        fitIcon.image = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: nil)
        fitIcon.contentTintColor = NSColor.white.withAlphaComponent(0.7)
        dimPill.addSubview(fitIcon)
        
        let pillClick = NSClickGestureRecognizer(target: self, action: #selector(dimPillClicked(_:)))
        dimPill.addGestureRecognizer(pillClick)
        topCard.addSubview(dimPill)
        
        // Crop Area selection button (Allows dragging screen recording area)
        let cropIcon = createIconButton(name: "crop", frame: NSRect(x: 232, y: 72, width: 34, height: 34), action: #selector(selectCustomArea))
        cropIcon.toolTip = "Crop / Select Recording Area"
        topCard.addSubview(cropIcon)
        
        // Close 'x' button on top-right
        let closeBtn = NSButton(frame: NSRect(x: width - 42, y: 76, width: 26, height: 26))
        closeBtn.bezelStyle = .circular
        closeBtn.title = "×"
        closeBtn.font = NSFont.boldSystemFont(ofSize: 14)
        closeBtn.target = self
        closeBtn.action = #selector(dismissHUD)
        topCard.addSubview(closeBtn)
        
        // Middle Row: 5 Feature Toggles (Mic, Speaker, Webcam, Clicks, Keystrokes)
        var toggleX: CGFloat = 20
        let spacing: CGFloat = 60
        
        micButton = createToggleItem(icon: "mic.fill", x: toggleX, action: #selector(toggleMic))
        micButton.toolTip = "Record Microphone Audio"
        topCard.addSubview(micButton)
        toggleX += spacing
        
        audioButton = createToggleItem(icon: "display.and.sound", x: toggleX, action: #selector(toggleAudio))
        audioButton.toolTip = "Record System Audio"
        topCard.addSubview(audioButton)
        toggleX += spacing
        
        webcamButton = createToggleItem(icon: "video.fill", x: toggleX, action: #selector(toggleWebcam))
        webcamButton.toolTip = "Webcam Overlay (Studio Mode)"
        topCard.addSubview(webcamButton)
        toggleX += spacing
        
        clicksButton = createToggleItem(icon: "cursorarrow.rays", x: toggleX, action: #selector(toggleClicks))
        clicksButton.state = .on // Default highlight clicks
        clicksButton.toolTip = "Highlight Mouse Clicks"
        updateToggleAppearance(clicksButton)
        topCard.addSubview(clicksButton)
        toggleX += spacing
        
        keystrokesButton = createToggleItem(icon: "command", x: toggleX, action: #selector(toggleKeystrokes))
        keystrokesButton.toolTip = "Show Keystrokes Overlay"
        topCard.addSubview(keystrokesButton)
        
        // 2. Middle Card: Record GIF & Record Video
        let middleCard = createGlassCard(frame: NSRect(x: 0, y: 46, width: width, height: 82), cornerRadius: 20)
        mainView.addSubview(middleCard)
        
        let gifRow = createActionRow(
            icon: "gif",
            title: "Record GIF",
            shortcut: "⌥ ↩",
            frame: NSRect(x: 0, y: 41, width: width, height: 40),
            action: #selector(startRecordGIF)
        )
        middleCard.addSubview(gifRow)
        
        let divider = NSBox(frame: NSRect(x: 16, y: 40, width: width - 32, height: 1))
        divider.boxType = .separator
        middleCard.addSubview(divider)
        
        let videoRow = createActionRow(
            icon: "video.fill",
            title: "Record Video",
            shortcut: "↩",
            frame: NSRect(x: 0, y: 0, width: width, height: 40),
            action: #selector(startRecordVideo)
        )
        middleCard.addSubview(videoRow)
        
        // 3. Bottom Card: Record in Studio Mode
        let bottomCard = createGlassCard(frame: NSRect(x: 0, y: 0, width: width, height: 40), cornerRadius: 18)
        mainView.addSubview(bottomCard)
        
        let studioRow = createActionRow(
            icon: "film.stack",
            title: "Record in Studio Mode",
            shortcut: "?",
            frame: NSRect(x: 0, y: 0, width: width, height: 40),
            action: #selector(startRecordStudio)
        )
        bottomCard.addSubview(studioRow)
        
        window.contentView = mainView
    }
    
    private func createGlassCard(frame: NSRect, cornerRadius: CGFloat) -> NSVisualEffectView {
        let effect = NSVisualEffectView(frame: frame)
        effect.material = .hudWindow
        effect.blendingMode = .withinWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = cornerRadius
        effect.layer?.masksToBounds = true
        effect.layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
        effect.layer?.borderWidth = 1.0
        return effect
    }
    
    private func createIconButton(name: String, frame: NSRect, action: Selector?) -> NSButton {
        let btn = NSButton(frame: frame)
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        btn.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
        btn.contentTintColor = NSColor.white.withAlphaComponent(0.85)
        if let action = action {
            btn.target = self
            btn.action = action
        }
        return btn
    }
    
    private func createToggleItem(icon: String, x: CGFloat, action: Selector) -> NSButton {
        let btn = NSButton(frame: NSRect(x: x, y: 16, width: 44, height: 38))
        btn.setButtonType(.pushOnPushOff)
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        let config = NSImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        btn.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)?.withSymbolConfiguration(config)
        btn.target = self
        btn.action = action
        updateToggleAppearance(btn)
        return btn
    }
    
    private func updateToggleAppearance(_ btn: NSButton) {
        if btn.state == .on {
            btn.contentTintColor = NSColor(red: 0.05, green: 0.52, blue: 1.0, alpha: 1.0) // Vibrant electric blue
        } else {
            btn.contentTintColor = NSColor.white.withAlphaComponent(0.4) // Subtle inactive
        }
    }
    
    private func createActionRow(icon: String, title: String, shortcut: String, frame: NSRect, action: Selector) -> NSButton {
        let btn = NSButton(frame: frame)
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        btn.target = self
        btn.action = action
        
        let container = NSView(frame: NSRect(x: 0, y: 0, width: frame.width, height: frame.height))
        container.wantsLayer = true
        
        // Icon
        let iconView = NSImageView(frame: NSRect(x: 20, y: 11, width: 20, height: 18))
        if icon == "gif" {
            let badge = NSTextField(labelWithString: "GIF")
            badge.font = NSFont.boldSystemFont(ofSize: 10)
            badge.textColor = .white
            badge.backgroundColor = NSColor.white.withAlphaComponent(0.2)
            badge.drawsBackground = true
            badge.alignment = .center
            badge.frame = NSRect(x: 18, y: 12, width: 28, height: 16)
            badge.wantsLayer = true
            badge.layer?.cornerRadius = 4
            badge.layer?.masksToBounds = true
            container.addSubview(badge)
        } else {
            iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
            iconView.contentTintColor = .white
            container.addSubview(iconView)
        }
        
        // Title
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.frame = NSRect(x: 54, y: 10, width: 180, height: 20)
        container.addSubview(titleLabel)
        
        // Shortcut hint
        let scLabel = NSTextField(labelWithString: shortcut)
        scLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        scLabel.textColor = NSColor.white.withAlphaComponent(0.5)
        scLabel.alignment = .right
        scLabel.frame = NSRect(x: frame.width - 70, y: 10, width: 50, height: 20)
        container.addSubview(scLabel)
        
        btn.addSubview(container)
        return btn
    }
    
    // MARK: - Actions
    
    private var localKeyMonitor: Any?
    
    @objc func showHUD() {
        self.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        if localKeyMonitor == nil {
            localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self, self.window?.isVisible == true else { return event }
                if event.keyCode == 53 { // Escape
                    self.dismissHUD()
                    return nil
                }
                if event.keyCode == 36 { // Return
                    if event.modifierFlags.contains(.option) {
                        self.startRecordGIF()
                    } else {
                        self.startRecordVideo()
                    }
                    return nil
                }
                return event
            }
        }
    }
    
    @objc private func dismissHUD() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        self.close()
    }
    
    @objc private func toggleMic(_ sender: NSButton) {
        isMicEnabled = (sender.state == .on)
        updateToggleAppearance(sender)
    }
    
    @objc private func toggleAudio(_ sender: NSButton) {
        isSystemAudioEnabled = (sender.state == .on)
        updateToggleAppearance(sender)
    }
    
    @objc private func toggleWebcam(_ sender: NSButton) {
        isWebcamEnabled = (sender.state == .on)
        updateToggleAppearance(sender)
    }
    
    @objc private func toggleClicks(_ sender: NSButton) {
        isClicksEnabled = (sender.state == .on)
        updateToggleAppearance(sender)
    }
    
    @objc private func toggleKeystrokes(_ sender: NSButton) {
        isKeystrokesEnabled = (sender.state == .on)
        updateToggleAppearance(sender)
    }
    
    @objc private func showSettingsMenu() {
        WindowManager.shared.openSettings()
    }
    
    @objc private func dimPillClicked(_ sender: Any) {
        showResolutionMenu(dimPill)
    }
    
    @objc private func showResolutionMenu(_ sender: NSView) {
        let menu = NSMenu()
        
        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let fullItem = NSMenuItem(title: "Fullscreen (\(Int(screen.width)) × \(Int(screen.height)))", action: #selector(presetSelected(_:)), keyEquivalent: "")
        fullItem.target = self
        fullItem.representedObject = "fullscreen"
        menu.addItem(fullItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let presets: [(String, Int, Int)] = [
            ("4K UHD (3840 × 2160)", 3840, 2160),
            ("2K QHD (2560 × 1440)", 2560, 1440),
            ("1080p FHD (1920 × 1080)", 1920, 1080),
            ("720p HD (1280 × 720)", 1280, 720),
            ("Square 1:1 (1080 × 1080)", 1080, 1080)
        ]
        
        for (title, w, h) in presets {
            let item = NSMenuItem(title: title, action: #selector(presetSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = CGSize(width: w, height: h)
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let cropItem = NSMenuItem(title: "Custom Crop Area...", action: #selector(selectCustomArea), keyEquivalent: "")
        cropItem.target = self
        menu.addItem(cropItem)
        
        let location = NSPoint(x: 0, y: 0)
        menu.popUp(positioning: nil, at: location, in: sender)
    }
    
    @objc private func presetSelected(_ sender: NSMenuItem) {
        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        if let str = sender.representedObject as? String, str == "fullscreen" {
            selectedRecordingRect = nil
            captureWidth = Int(screen.width)
            captureHeight = Int(screen.height)
        } else if let size = sender.representedObject as? CGSize {
            let w = min(size.width, screen.width)
            let h = min(size.height, screen.height)
            let x = (screen.width - w) / 2.0
            let y = (screen.height - h) / 2.0
            selectedRecordingRect = CGRect(x: x, y: y, width: w, height: h)
            captureWidth = Int(w)
            captureHeight = Int(h)
        }
        updateDimensionsLabel()
    }
    
    func updateDimensionsLabel() {
        dimLabel?.stringValue = "\(captureWidth)  ×  \(captureHeight)"
    }
    
    @objc private func selectCustomArea() {
        self.window?.orderOut(nil)
        RecordingAreaSelectorController.shared.startSelection(
            hint: "Drag to select recording area, or press Escape to cancel",
            onCancel: { [weak self] in
                self?.showHUD()
            }
        ) { [weak self] rect in
            guard let self = self else { return }
            self.selectedRecordingRect = rect
            self.captureWidth = Int(rect.width)
            self.captureHeight = Int(rect.height)
            CaptureManager.shared.setLastCapturedArea(rect)
            self.updateDimensionsLabel()
            self.showHUD()
        }
    }
    
    @objc private func startRecordVideo() {
        dismissHUD()
        RecordingManager.shared.startRecordingVideo()
    }
    
    @objc private func startRecordGIF() {
        dismissHUD()
        RecordingManager.shared.startRecordingGIF()
    }
    
    @objc private func startRecordStudio() {
        dismissHUD()
        RecordingManager.shared.startRecordingVideo()
    }
}
