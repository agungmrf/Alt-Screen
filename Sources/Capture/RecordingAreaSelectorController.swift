import Foundation
import AppKit

final class RecordingAreaSelectorController: NSWindowController {
    static let shared = RecordingAreaSelectorController()
    
    private var selectionCallback: ((CGRect) -> Void)?
    private var cancelCallback: (() -> Void)?
    private var overlayView: AreaSelectorOverlayView!
    
    init() {
        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let window = NSWindow(
            contentRect: screen,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        super.init(window: window)
        
        overlayView = AreaSelectorOverlayView(frame: screen)
        overlayView.onSelectionComplete = { [weak self] rect in
            self?.completeSelection(rect: rect)
        }
        overlayView.onCancelled = { [weak self] in
            self?.cancelSelection()
        }
        window.contentView = overlayView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func startSelection(
        hint: String = "Drag to select recording area, or press Escape to cancel",
        onCancel: (() -> Void)? = nil,
        completion: @escaping (CGRect) -> Void
    ) {
        self.selectionCallback = completion
        self.cancelCallback = onCancel
        
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        let screenFrame = targetScreen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        
        if let win = self.window {
            win.setFrame(screenFrame, display: true)
            overlayView.frame = NSRect(origin: .zero, size: screenFrame.size)
            overlayView.hintText = hint
            overlayView.reset()
        }
        self.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
    
    private func completeSelection(rect: CGRect) {
        let screenRect = self.window?.convertToScreen(rect) ?? rect
        self.window?.orderOut(nil)
        self.close()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self = self else { return }
            let cb = self.selectionCallback
            self.selectionCallback = nil
            self.cancelCallback = nil
            cb?(screenRect)
        }
    }
    
    private func cancelSelection() {
        self.close()
        let cb = cancelCallback
        selectionCallback = nil
        cancelCallback = nil
        cb?()
    }
}

final class AreaSelectorOverlayView: NSView {
    var onSelectionComplete: ((CGRect) -> Void)?
    var onCancelled: (() -> Void)?
    var hintText: String = "Drag to select recording area, or press Escape to cancel"
    
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var isDragging: Bool = false
    
    override var acceptsFirstResponder: Bool { true }
    
    func reset() {
        startPoint = nil
        currentPoint = nil
        isDragging = false
        needsDisplay = true
    }
    
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onCancelled?()
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        isDragging = true
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        guard let start = startPoint, let current = currentPoint else { return }
        isDragging = false
        
        let rect = CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        
        if rect.width > 20 && rect.height > 20 {
            onSelectionComplete?(rect)
        } else {
            onCancelled?()
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // 1. Semi-translucent dark shroud over screen
        context.setFillColor(NSColor.black.withAlphaComponent(0.35).cgColor)
        context.fill(bounds)
        
        guard let start = startPoint, let current = currentPoint, isDragging else {
            // Draw initial hint
            let hint = hintText as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: NSColor.white
            ]
            let size = hint.size(withAttributes: attrs)
            let hintRect = CGRect(x: (bounds.width - size.width) / 2.0, y: bounds.height - 100, width: size.width, height: size.height)
            
            context.setFillColor(NSColor.black.withAlphaComponent(0.70).cgColor)
            let pill = CGPath(roundedRect: hintRect.insetBy(dx: -16, dy: -8), cornerWidth: 16, cornerHeight: 16, transform: nil)
            context.addPath(pill)
            context.fillPath()
            hint.draw(in: hintRect, withAttributes: attrs)
            return
        }
        
        let selectionRect = CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        
        // 2. Clear out selection rectangle
        context.clear(selectionRect)
        
        // 3. Electric blue border around selection
        context.setStrokeColor(NSColor(red: 0.05, green: 0.52, blue: 1.0, alpha: 1.0).cgColor)
        context.setLineWidth(2.5)
        context.stroke(selectionRect)
        
        // 4. Dimensions badge (e.g. "1280 × 720")
        let dimStr = "\(Int(selectionRect.width)) × \(Int(selectionRect.height))" as NSString
        let badgeAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let badgeSize = dimStr.size(withAttributes: badgeAttrs)
        let badgeRect = CGRect(
            x: selectionRect.midX - badgeSize.width / 2.0,
            y: max(selectionRect.minY - 28, 10),
            width: badgeSize.width,
            height: badgeSize.height
        )
        
        context.setFillColor(NSColor.black.withAlphaComponent(0.75).cgColor)
        let badgePath = CGPath(roundedRect: badgeRect.insetBy(dx: -10, dy: -4), cornerWidth: 6, cornerHeight: 6, transform: nil)
        context.addPath(badgePath)
        context.fillPath()
        dimStr.draw(in: badgeRect, withAttributes: badgeAttrs)
    }
}
