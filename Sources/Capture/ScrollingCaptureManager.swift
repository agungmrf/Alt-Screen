import Foundation
import AppKit

final class ScrollingCaptureManager: NSObject {
    static let shared = ScrollingCaptureManager()
    
    // State
    private(set) var isRecordingScroll: Bool = false
    private(set) var isPaused: Bool = false
    private var targetRect: CGRect = .zero
    private var capturedSlices: [NSImage] = []
    private var lastCapturedHash: Int = 0
    private var totalHeightAccumulated: CGFloat = 0
    
    // Timers & Monitors
    private var cursorTrackerTimer: Timer?
    private var capturePollTimer: Timer?
    private var localKeyMonitor: Any?
    
    // UI Windows
    private var hudWindow: NSPanel?
    private var guideBorderWindow: NSPanel?
    
    // HUD Subviews
    private var statusDot: NSView?
    private var statusTitleLabel: NSTextField?
    private var statusSubtitleLabel: NSTextField?
    private var guideBorderView: NSView?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Entry Point
    
    func startScrollingCapture() {
        guard !isRecordingScroll else { return }
        
        // Launch crosshair selector to choose scrollable area
        RecordingAreaSelectorController.shared.startSelection(
            hint: "Drag to select scrollable area (or press Escape to cancel)",
            onCancel: { [weak self] in
                self?.cancelScrolling()
            }
        ) { [weak self] selectedRect in
            guard let self = self else { return }
            CaptureManager.shared.setLastCapturedArea(selectedRect)
            self.beginCaptureSession(in: selectedRect)
        }
    }
    
    private func beginCaptureSession(in rect: CGRect) {
        guard rect.width >= 100 && rect.height >= 100 else {
            WindowManager.shared.showToast(message: "Selected area is too small for scrolling capture")
            return
        }
        
        self.targetRect = rect
        self.capturedSlices.removeAll()
        self.lastCapturedHash = 0
        self.isRecordingScroll = true
        self.isPaused = false
        self.totalHeightAccumulated = rect.height
        
        // 1. Show Guide Border around the target scrollable area
        showGuideBorder(around: rect)
        
        // 2. Show Floating HUD
        showScrollingHUD(for: rect)
        
        // 3. Take initial frame immediately
        captureSlice()
        
        // 4. Start Cursor Presence Tracker (every 80ms)
        startCursorTracking()
        
        // 5. Start Capture Poller (every 400ms while active)
        startCapturePolling()
    }
    
    // MARK: - Guide Border Window
    
    private func showGuideBorder(around rect: CGRect) {
        guideBorderWindow?.close()
        
        let borderPanel = NSPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        borderPanel.level = .floating
        borderPanel.isOpaque = false
        borderPanel.backgroundColor = .clear
        borderPanel.hasShadow = false
        borderPanel.ignoresMouseEvents = true // Pass all scrolls & clicks through to underlying app!
        borderPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let borderView = NSView(frame: NSRect(x: 0, y: 0, width: rect.width, height: rect.height))
        borderView.wantsLayer = true
        borderView.layer?.borderWidth = 2.5
        borderView.layer?.cornerRadius = 8
        borderView.layer?.borderColor = NSColor(red: 0.05, green: 0.52, blue: 1.0, alpha: 1.0).cgColor
        borderPanel.contentView = borderView
        self.guideBorderView = borderView
        
        borderPanel.orderFront(nil)
        self.guideBorderWindow = borderPanel
    }
    
    // MARK: - Scrolling HUD Window
    
    private func showScrollingHUD(for rect: CGRect) {
        hudWindow?.close()
        
        let hudW: CGFloat = 460
        let hudH: CGFloat = 64
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        
        // Position HUD gracefully near the top or directly above/below targetRect
        let x = min(max(rect.midX - (hudW / 2.0), screen.minX + 20), screen.maxX - hudW - 20)
        var y = rect.maxY + 16
        if y + hudH > screen.maxY {
            y = max(rect.minY - hudH - 16, screen.minY + 20)
        }
        
        let panel = NSPanel(
            contentRect: NSRect(x: x, y: y, width: hudW, height: hudH),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let effect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: hudW, height: hudH))
        effect.material = .hudWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 18
        effect.layer?.masksToBounds = true
        effect.layer?.borderColor = NSColor.white.withAlphaComponent(0.24).cgColor
        effect.layer?.borderWidth = 1.0
        
        // Live Pulsing Status Dot (Green = Active, Orange = Paused)
        let dot = NSView(frame: NSRect(x: 18, y: 26, width: 12, height: 12))
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 6
        dot.layer?.backgroundColor = NSColor.systemGreen.cgColor
        effect.addSubview(dot)
        self.statusDot = dot
        
        // Status Title
        let titleLabel = NSTextField(labelWithString: "Active: Scroll content down...")
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.frame = NSRect(x: 38, y: 32, width: 230, height: 18)
        effect.addSubview(titleLabel)
        self.statusTitleLabel = titleLabel
        
        // Status Subtitle (Frames & Dimension height counter)
        let subLabel = NSTextField(labelWithString: "Captured: 1 frame  •  \(Int(rect.height)) px")
        subLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        subLabel.textColor = NSColor.white.withAlphaComponent(0.65)
        subLabel.frame = NSRect(x: 38, y: 14, width: 230, height: 16)
        effect.addSubview(subLabel)
        self.statusSubtitleLabel = subLabel
        
        // Cancel Button [ ✕ Cancel ]
        let cancelBtn = NSButton(title: "✕ Cancel", target: self, action: #selector(cancelScrolling))
        cancelBtn.bezelStyle = .regularSquare
        cancelBtn.isBordered = false
        cancelBtn.wantsLayer = true
        cancelBtn.layer?.cornerRadius = 14
        cancelBtn.layer?.masksToBounds = true
        cancelBtn.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.18).cgColor
        cancelBtn.contentTintColor = .white
        cancelBtn.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        cancelBtn.frame = NSRect(x: hudW - 182, y: 16, width: 78, height: 32)
        effect.addSubview(cancelBtn)
        
        // Finish Button [ ✓ Finish ]
        let finishBtn = NSButton(title: "✓ Finish", target: self, action: #selector(finishScrolling))
        finishBtn.bezelStyle = .regularSquare
        finishBtn.isBordered = false
        finishBtn.wantsLayer = true
        finishBtn.layer?.cornerRadius = 14
        finishBtn.layer?.masksToBounds = true
        finishBtn.layer?.backgroundColor = NSColor(red: 0.05, green: 0.52, blue: 1.0, alpha: 1.0).cgColor
        finishBtn.contentTintColor = .white
        finishBtn.font = NSFont.systemFont(ofSize: 12.5, weight: .bold)
        finishBtn.keyEquivalent = "\r"
        finishBtn.frame = NSRect(x: hudW - 96, y: 16, width: 80, height: 32)
        effect.addSubview(finishBtn)
        
        panel.contentView = effect
        panel.orderFront(nil)
        self.hudWindow = panel
        
        // Keyboard monitors
        if localKeyMonitor == nil {
            localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self, self.isRecordingScroll else { return event }
                if event.keyCode == 53 { // Escape
                    self.cancelScrolling()
                    return nil
                }
                if event.keyCode == 36 { // Return
                    self.finishScrolling()
                    return nil
                }
                return event
            }
        }
    }
    
    // MARK: - Cursor Presence Detection (Auto-Pause / Auto-Resume)
    
    private func startCursorTracking() {
        cursorTrackerTimer?.invalidate()
        cursorTrackerTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecordingScroll else { return }
            
            let mouseLoc = NSEvent.mouseLocation
            // Tolerance margin: generous 8px around targetRect
            let isInside = self.targetRect.insetBy(dx: -8, dy: -8).contains(mouseLoc)
            
            if isInside {
                if self.isPaused {
                    self.resumeCapture()
                }
            } else {
                if !self.isPaused {
                    self.pauseCapture()
                }
            }
        }
    }
    
    private func pauseCapture() {
        isPaused = true
        
        // 1. Update Guide Border to amber/orange
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            self.guideBorderView?.layer?.borderColor = NSColor.systemOrange.cgColor
            self.statusDot?.layer?.backgroundColor = NSColor.systemOrange.cgColor
        }
        
        // 2. Update HUD status
        statusTitleLabel?.stringValue = "❚❚ Paused: Cursor outside area"
        statusTitleLabel?.textColor = NSColor(red: 1.0, green: 0.72, blue: 0.2, alpha: 1.0)
    }
    
    private func resumeCapture() {
        isPaused = false
        
        // 1. Update Guide Border to electric blue
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            self.guideBorderView?.layer?.borderColor = NSColor(red: 0.05, green: 0.52, blue: 1.0, alpha: 1.0).cgColor
            self.statusDot?.layer?.backgroundColor = NSColor.systemGreen.cgColor
        }
        
        // 2. Update HUD status
        statusTitleLabel?.stringValue = "● Active: Scroll content down..."
        statusTitleLabel?.textColor = .white
    }
    
    // MARK: - Frame Capture & Polling
    
    private func startCapturePolling() {
        capturePollTimer?.invalidate()
        capturePollTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecordingScroll, !self.isPaused else { return }
            self.captureSlice()
        }
    }
    
    private func captureSlice() {
        guard let screen = NSScreen.main else { return }
        
        let screenH = screen.frame.height
        let x = max(0, Int(targetRect.origin.x))
        let y = max(0, Int(screenH - targetRect.maxY))
        let w = max(20, Int(targetRect.width))
        let h = max(20, Int(targetRect.height))
        
        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("alt_scroll_\(UUID().uuidString).png")
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-x", "-R\(x),\(y),\(w),\(h)", tempFile.path]
        
        try? task.run()
        task.waitUntilExit()
        
        guard let image = NSImage(contentsOf: tempFile) else { return }
        try? FileManager.default.removeItem(at: tempFile)
        
        // Fast hash verification to avoid redundant duplicate captures
        let dataCount = image.tiffRepresentation?.count ?? 0
        if dataCount == lastCapturedHash && !capturedSlices.isEmpty {
            return // No scroll movement occurred
        }
        
        lastCapturedHash = dataCount
        capturedSlices.append(image)
        
        // Update Height & Frame counter
        let overlapRatio: CGFloat = 0.45
        if capturedSlices.count > 1 {
            totalHeightAccumulated += targetRect.height * (1.0 - overlapRatio)
        }
        
        DispatchQueue.main.async {
            self.statusSubtitleLabel?.stringValue = "Captured: \(self.capturedSlices.count) frames  •  \(Int(self.totalHeightAccumulated)) px"
        }
    }
    
    // MARK: - Completion & Cancel
    
    @objc func cancelScrolling() {
        cleanup()
        WindowManager.shared.showToast(message: "Scrolling capture cancelled")
    }
    
    @objc func finishScrolling() {
        cleanup()
        
        guard !capturedSlices.isEmpty else {
            WindowManager.shared.showToast(message: "No frames captured")
            return
        }
        
        WindowManager.shared.showToast(message: "⚡ Stitching \(capturedSlices.count) frames...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let stitchedImage = self.stitchFrames(self.capturedSlices)
            
            DispatchQueue.main.async {
                let saveURL = SettingsManager.shared.generateSaveURL(prefix: "Alt. Scrolling Capture")
                if let tiff = stitchedImage.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff),
                   let png = rep.representation(using: .png, properties: [:]) {
                    try? png.write(to: saveURL)
                    HistoryManager.shared.addItem(image: stitchedImage, fileURL: saveURL)
                    
                    if SettingsManager.shared.autoCopyToClipboard {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.writeObjects([stitchedImage])
                    }
                }
                
                WindowManager.shared.showToast(message: "✓ Scrolling capture complete!")
                WindowManager.shared.openEditor(with: stitchedImage)
            }
        }
    }
    
    private func cleanup() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        cursorTrackerTimer?.invalidate()
        cursorTrackerTimer = nil
        capturePollTimer?.invalidate()
        capturePollTimer = nil
        
        isRecordingScroll = false
        isPaused = false
        
        guideBorderWindow?.close()
        guideBorderWindow = nil
        guideBorderView = nil
        
        hudWindow?.close()
        hudWindow = nil
    }
    
    // MARK: - Seamless Vertical Stitcher
    
    private func stitchFrames(_ slices: [NSImage]) -> NSImage {
        guard slices.count > 1 else { return slices.first ?? NSImage() }
        
        let first = slices[0]
        let width = first.size.width
        let frameH = first.size.height
        
        // Calculate progressive scroll advancement
        let overlapRatio: CGFloat = 0.45
        let advanceStep = frameH * (1.0 - overlapRatio)
        let totalH = frameH + CGFloat(slices.count - 1) * advanceStep
        
        let stitched = NSImage(size: NSSize(width: width, height: totalH))
        stitched.lockFocus()
        
        // Draw bottom-to-top in Cocoa coordinate space
        for (i, slice) in slices.enumerated() {
            let y = totalH - frameH - (CGFloat(i) * advanceStep)
            slice.draw(
                in: CGRect(x: 0, y: y, width: width, height: frameH),
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0
            )
        }
        
        stitched.unlockFocus()
        return stitched
    }
}
