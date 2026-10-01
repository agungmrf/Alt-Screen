import Foundation
import AppKit

// Draggable image view allowing direct drag to Finder, Slack, WhatsApp, Browser, etc.
final class DraggableThumbnailImageView: NSImageView, NSDraggingSource {
    var fileURL: URL?
    var screenshotImage: NSImage?
    
    override func mouseDown(with event: NSEvent) {
        guard let image = self.image else { return }
        
        var writers: [NSPasteboardWriting] = []
        if let url = self.fileURL as NSURL? {
            writers.append(url)
        }
        writers.append(image)
        
        let dragItems = writers.map { writer -> NSDraggingItem in
            let item = NSDraggingItem(pasteboardWriter: writer)
            item.setDraggingFrame(bounds, contents: image)
            return item
        }
        
        beginDraggingSession(with: dragItems, event: event, source: self)
    }
    
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
}

final class QuickAccessPanel: NSPanel {
    private let screenshotImage: NSImage
    private let tempFileURL: URL
    private var dismissTimer: Timer?
    private var hoverCheckTimer: Timer?
    private(set) var isHovered: Bool = false
    
    // UI components
    private var cardContainer: NSView!
    private var hoverOverlayView: NSView!
    private var imgView: DraggableThumbnailImageView!
    
    init(image: NSImage, fileURL: URL, stackIndex: Int = 0) {
        self.screenshotImage = image
        self.tempFileURL = fileURL
        
        // Professional CleanShot X dimensions: 240 × 155 pt
        let cardWidth: CGFloat = 240
        let cardHeight: CGFloat = 155
        
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        
        // Position at bottom-left corner with vertical stacking
        let x = screenRect.minX + 28
        let y = screenRect.minY + 28 + CGFloat(stackIndex) * (cardHeight + 14)
        
        super.init(
            contentRect: NSRect(x: x, y: y, width: cardWidth, height: cardHeight),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        setupCardUI(width: cardWidth, height: cardHeight)
        startHoverTracking()
    }
    
    private func setupCardUI(width: CGFloat, height: CGFloat) {
        // Main Card Container with Apple-grade corner radius and glass border
        cardContainer = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        cardContainer.wantsLayer = true
        cardContainer.layer?.cornerRadius = 16
        cardContainer.layer?.masksToBounds = true
        cardContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.24).cgColor
        cardContainer.layer?.borderWidth = 1.0
        
        // 1. Base Screenshot Image View (Draggable)
        imgView = DraggableThumbnailImageView(frame: cardContainer.bounds)
        imgView.image = screenshotImage
        imgView.fileURL = tempFileURL
        imgView.screenshotImage = screenshotImage
        imgView.imageScaling = .scaleProportionallyUpOrDown
        imgView.wantsLayer = true
        imgView.layer?.cornerRadius = 16
        imgView.layer?.masksToBounds = true
        imgView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.25).cgColor
        
        // Double-click to open Markup Editor
        let dblClick = NSClickGestureRecognizer(target: self, action: #selector(editAction))
        dblClick.numberOfClicksRequired = 2
        imgView.addGestureRecognizer(dblClick)
        cardContainer.addSubview(imgView)
        
        // 2. Hover Overlay View (1:1 with CleanShot X)
        hoverOverlayView = NSView(frame: cardContainer.bounds)
        hoverOverlayView.wantsLayer = true
        hoverOverlayView.layer?.cornerRadius = 16
        hoverOverlayView.layer?.masksToBounds = true
        hoverOverlayView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.68).cgColor
        hoverOverlayView.alphaValue = 0.0 // Hidden by default, smoothly appears on hover
        cardContainer.addSubview(hoverOverlayView)
        
        setupHoverControls(in: hoverOverlayView, width: width, height: height)
        
        self.contentView = cardContainer
    }
    
    private func setupHoverControls(in overlay: NSView, width: CGFloat, height: CGFloat) {
        let btnSize: CGFloat = 28
        let margin: CGFloat = 10
        
        // Top-Left: Close Button (xmark)
        let closeBtn = createCircleButton(
            icon: "xmark",
            frame: NSRect(x: margin, y: height - btnSize - margin, width: btnSize, height: btnSize),
            action: #selector(deleteAction),
            tooltip: "Close & Discard"
        )
        overlay.addSubview(closeBtn)
        
        // Top-Right: Pin Button (pin.fill)
        let pinBtn = createCircleButton(
            icon: "pin.fill",
            frame: NSRect(x: width - btnSize - margin, y: height - btnSize - margin, width: btnSize, height: btnSize),
            action: #selector(pinAction),
            tooltip: "Pin to Screen"
        )
        overlay.addSubview(pinBtn)
        
        // Bottom-Left: Edit Button (pencil)
        let editBtn = createCircleButton(
            icon: "pencil",
            frame: NSRect(x: margin, y: margin, width: btnSize, height: btnSize),
            action: #selector(editAction),
            tooltip: "Markup & Annotate"
        )
        overlay.addSubview(editBtn)
        
        // Bottom-Right: OCR Button (text.viewfinder)
        let ocrBtn = createCircleButton(
            icon: "text.viewfinder",
            frame: NSRect(x: width - btnSize - margin, y: margin, width: btnSize, height: btnSize),
            action: #selector(ocrAction),
            tooltip: "Extract Text (OCR)"
        )
        overlay.addSubview(ocrBtn)
        
        // Center: [Copy] Pill Button
        let pillW: CGFloat = 82
        let pillH: CGFloat = 28
        let copyBtn = createPillButton(
            title: "Copy",
            frame: NSRect(x: (width - pillW) / 2.0, y: height / 2.0 + 5, width: pillW, height: pillH),
            action: #selector(copyAction)
        )
        overlay.addSubview(copyBtn)
        
        // Center: [Save] Pill Button
        let saveBtn = createPillButton(
            title: "Save",
            frame: NSRect(x: (width - pillW) / 2.0, y: height / 2.0 - 33, width: pillW, height: pillH),
            action: #selector(saveAction)
        )
        overlay.addSubview(saveBtn)
    }
    
    private func createCircleButton(icon: String, frame: NSRect, action: Selector, tooltip: String) -> NSButton {
        let btn = NSButton(frame: frame)
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.cornerRadius = frame.width / 2.0
        btn.layer?.masksToBounds = true
        btn.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.24).cgColor
        
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        btn.image = NSImage(systemSymbolName: icon, accessibilityDescription: tooltip)?.withSymbolConfiguration(config)
        btn.contentTintColor = .white
        btn.toolTip = tooltip
        btn.target = self
        btn.action = action
        return btn
    }
    
    private func createPillButton(title: String, frame: NSRect, action: Selector) -> NSButton {
        let btn = NSButton(frame: frame)
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.cornerRadius = frame.height / 2.0
        btn.layer?.masksToBounds = true
        btn.layer?.backgroundColor = NSColor.white.cgColor
        
        btn.title = title
        btn.font = NSFont.systemFont(ofSize: 12.5, weight: .bold)
        btn.contentTintColor = NSColor(calibratedWhite: 0.12, alpha: 1.0)
        btn.target = self
        btn.action = action
        return btn
    }
    
    // MARK: - Bulletproof Proactive Hover Tracking
    
    private func startHoverTracking() {
        hoverCheckTimer?.invalidate()
        // High-precision tracking loop (0.08s interval) for smooth overlay display
        hoverCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self = self, self.isVisible else { return }
            let mouseLoc = NSEvent.mouseLocation
            let isNearOrInside = self.frame.insetBy(dx: -20, dy: -20).contains(mouseLoc)
            
            if isNearOrInside {
                if !self.isHovered {
                    self.setHoverState(true)
                }
            } else {
                if self.isHovered {
                    self.setHoverState(false)
                }
            }
        }
    }
    
    private func setHoverState(_ hovered: Bool) {
        self.isHovered = hovered
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            if hovered {
                self.hoverOverlayView.animator().alphaValue = 1.0
                self.cardContainer.layer?.borderColor = NSColor(red: 0.05, green: 0.52, blue: 1.0, alpha: 1.0).cgColor
                self.cardContainer.layer?.borderWidth = 2.5
            } else {
                self.hoverOverlayView.animator().alphaValue = 0.0
                self.cardContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.24).cgColor
                self.cardContainer.layer?.borderWidth = 1.0
            }
        }
    }
    
    @objc func dismissPanel() {
        hoverCheckTimer?.invalidate()
        hoverCheckTimer = nil
        dismissTimer?.invalidate()
        dismissTimer = nil
        
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.24
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            self.close()
            WindowManager.shared.removeQuickAccess(self)
        })
    }
    
    // MARK: - Actions
    
    @objc private func copyAction() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([screenshotImage])
        WindowManager.shared.showToast(message: "✓ Copied to clipboard!")
        dismissPanel()
    }
    
    @objc private func saveAction() {
        let targetURL = SettingsManager.shared.generateSaveURL()
        do {
            try FileManager.default.copyItem(at: tempFileURL, to: targetURL)
            WindowManager.shared.showToast(message: "✓ Saved to: \(targetURL.lastPathComponent)")
            NSWorkspace.shared.activateFileViewerSelecting([targetURL])
        } catch {
            if let tiff = screenshotImage.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let data = rep.representation(using: .png, properties: [:]) {
                try? data.write(to: targetURL)
                WindowManager.shared.showToast(message: "✓ Saved to: \(targetURL.lastPathComponent)")
                NSWorkspace.shared.activateFileViewerSelecting([targetURL])
            }
        }
        dismissPanel()
    }
    
    @objc private func editAction() {
        WindowManager.shared.openEditor(with: screenshotImage)
        dismissPanel()
    }
    
    @objc private func pinAction() {
        WindowManager.shared.pinImage(screenshotImage)
        dismissPanel()
    }
    
    @objc private func ocrAction() {
        OCRManager.shared.copyTextToClipboard(from: screenshotImage) { success, count in
            if success {
                WindowManager.shared.showToast(message: "✓ Extracted \(count) characters to clipboard!")
            }
            self.dismissPanel()
        }
    }
    
    @objc private func deleteAction() {
        try? FileManager.default.removeItem(at: tempFileURL)
        dismissPanel()
    }
}
