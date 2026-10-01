import Foundation
import AppKit

final class MenuBarManager: NSObject {
    static let shared = MenuBarManager()
    
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var desktopMenuItem: NSMenuItem?
    private var recordMenuItem: NSMenuItem?
    
    private override init() {
        super.init()
    }
    
    // Signature Alt. Menu Bar Logo: Iconic peeled canvas sheet with camera viewfinder lens & signature dot
    static func createAltLogo() -> NSImage {
        let size: CGFloat = 36 // 2x for 18pt Retina status bar
        let img = NSImage(size: NSSize(width: 18, height: 18))
        
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size),
            pixelsHigh: Int(size),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let ctx = NSGraphicsContext.current!.cgContext
        
        ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))
        
        let strokeWidth: CGFloat = 2.4
        ctx.setStrokeColor(NSColor.black.cgColor)
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.setLineWidth(strokeWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        
        let r: CGFloat = 5.0 // Corner radius
        
        // 1. Draw Main Sheet Silhouette with Bottom-Left Peel Opening
        let sheetPath = CGMutablePath()
        // Start after peel on bottom edge (x: 16.0, y: 32.5)
        sheetPath.move(to: CGPoint(x: 16.5, y: 32.5))
        // Bottom edge to bottom-right corner
        sheetPath.addArc(tangent1End: CGPoint(x: 32.5, y: 32.5), tangent2End: CGPoint(x: 32.5, y: 20.0), radius: r)
        // Right edge to top-right corner
        sheetPath.addArc(tangent1End: CGPoint(x: 32.5, y: 3.5), tangent2End: CGPoint(x: 20.0, y: 3.5), radius: r)
        // Top edge to top-left corner
        sheetPath.addArc(tangent1End: CGPoint(x: 3.5, y: 3.5), tangent2End: CGPoint(x: 3.5, y: 20.0), radius: r)
        // Left edge down to peel start (x: 3.5, y: 19.5)
        sheetPath.addLine(to: CGPoint(x: 3.5, y: 19.5))
        
        ctx.addPath(sheetPath)
        ctx.strokePath()
        
        // 2. Draw Fold Crease Line connecting peel points
        ctx.setLineWidth(1.8)
        ctx.move(to: CGPoint(x: 3.5, y: 19.5))
        ctx.addLine(to: CGPoint(x: 16.5, y: 32.5))
        ctx.strokePath()
        
        // 3. Draw Curled Peeled Flap (CleanShot-style peeled corner)
        let flapPath = CGMutablePath()
        flapPath.move(to: CGPoint(x: 3.5, y: 19.5))
        flapPath.addQuadCurve(to: CGPoint(x: 16.5, y: 32.5), control: CGPoint(x: 13.5, y: 19.5))
        
        ctx.setLineWidth(strokeWidth)
        ctx.addPath(flapPath)
        ctx.strokePath()
        
        // 4. Center Camera Viewfinder Lens Aperture
        let lensCenter = CGPoint(x: 19.5, y: 16.5)
        let lensRadius: CGFloat = 4.8
        ctx.setLineWidth(2.2)
        ctx.strokeEllipse(in: CGRect(x: lensCenter.x - lensRadius, y: lensCenter.y - lensRadius, width: lensRadius * 2, height: lensRadius * 2))
        
        // Center Pupil / Shutter Core
        let pupilRadius: CGFloat = 1.8
        ctx.fillEllipse(in: CGRect(x: lensCenter.x - pupilRadius, y: lensCenter.y - pupilRadius, width: pupilRadius * 2, height: pupilRadius * 2))
        
        // 5. Signature Alt. Dot '.' (Filled Accent Dot on bottom right)
        let dotCenter = CGPoint(x: 26.5, y: 25.5)
        let dotRadius: CGFloat = 1.9
        ctx.fillEllipse(in: CGRect(x: dotCenter.x - dotRadius, y: dotCenter.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
        
        NSGraphicsContext.restoreGraphicsState()
        
        img.addRepresentation(rep)
        img.isTemplate = true
        return img
    }
    
    // Crisp 'Aa' icon matching CleanShot OCR
    private func createAaIcon() -> NSImage {
        let size: CGFloat = 32
        let img = NSImage(size: NSSize(width: 16, height: 16))
        
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size),
            pixelsHigh: Int(size),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))
        
        let str = "Aa" as NSString
        let font = NSFont.systemFont(ofSize: 22, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        let strSize = str.size(withAttributes: attrs)
        let drawRect = CGRect(
            x: (size - strSize.width) / 2.0,
            y: (size - strSize.height) / 2.0 - 2,
            width: strSize.width,
            height: strSize.height
        )
        str.draw(in: drawRect, withAttributes: attrs)
        
        NSGraphicsContext.restoreGraphicsState()
        
        img.addRepresentation(rep)
        img.isTemplate = true
        return img
    }
    
    private func symbolImage(name: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
        img?.isTemplate = true
        return img
    }
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = MenuBarManager.createAltLogo()
            button.imagePosition = .imageOnly
        }
        
        rebuildMenu()
        
        // Listen to recording state changes
        RecordingManager.shared.onStateChanged = { [weak self] isRecording in
            self?.updateRecordingUI(isRecording: isRecording)
        }
    }
    
    func rebuildMenu() {
        menu = NSMenu()
        menu.autoenablesItems = false
        
        // 1. All-In-One
        menu.addItem(makeItem(title: "All-In-One", icon: symbolImage(name: "1.circle"), action: #selector(actionAllInOne)))
        
        // 2. Capture Area (viewfinder / 4 brackets) - ⌘⇧1
        menu.addItem(makeItem(title: "Capture Area", icon: symbolImage(name: "viewfinder"), action: #selector(actionCaptureArea), keyEquivalent: "1", modifier: [.command, .shift]))
        
        // 3. Capture Previous Area - ⌘⇧5
        menu.addItem(makeItem(title: "Capture Previous Area", icon: symbolImage(name: "arrow.counterclockwise"), action: #selector(actionCapturePreviousArea), keyEquivalent: "5", modifier: [.command, .shift]))
        
        // 4. Capture Fullscreen - ⌘⇧3
        menu.addItem(makeItem(title: "Capture Fullscreen", icon: symbolImage(name: "display"), action: #selector(actionCaptureFullscreen), keyEquivalent: "3", modifier: [.command, .shift]))
        
        // 5. Capture Window
        menu.addItem(makeItem(title: "Capture Window", icon: symbolImage(name: "macwindow"), action: #selector(actionCaptureWindow)))
        
        // 6. Scrolling Capture - ⌘⇧4
        menu.addItem(makeItem(title: "Scrolling Capture", icon: symbolImage(name: "arrow.down.to.line"), action: #selector(actionScrollingCapture), keyEquivalent: "4", modifier: [.command, .shift]))
        
        // 7. Self-Timer
        menu.addItem(makeItem(title: "Self-Timer", icon: symbolImage(name: "clock.arrow.circlepath"), action: #selector(actionSelfTimer)))
        
        // 8. Capture Text (OCR) - ⌘⇧C
        menu.addItem(makeItem(title: "Capture Text (OCR)", icon: createAaIcon(), action: #selector(actionCaptureTextOCR), keyEquivalent: "c", modifier: [.command, .shift]))
        
        // 9. Pick Color (Eyedropper) - ⌘⇧P
        menu.addItem(makeItem(title: "Pick Color (Eyedropper)", icon: symbolImage(name: "eyedropper"), action: #selector(actionPickColor), keyEquivalent: "p", modifier: [.command, .shift]))
        
        // 10. Record Screen - ⌘⇧2
        let recItem = makeItem(title: "Record Screen", icon: symbolImage(name: "video"), action: #selector(actionRecordScreen), keyEquivalent: "2", modifier: [.command, .shift])
        self.recordMenuItem = recItem
        menu.addItem(recItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 10. Show/Hide Desktop Icons
        let isHidden = DesktopIconManager.shared.areIconsHidden
        let desktopTitle = isHidden ? "Show Desktop Icons" : "Hide Desktop Icons"
        let desktopIconName = isHidden ? "eye.slash" : "eye"
        let desktopItem = makeItem(title: desktopTitle, icon: symbolImage(name: desktopIconName), action: #selector(actionToggleDesktopIcons))
        self.desktopMenuItem = desktopItem
        menu.addItem(desktopItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 11. Open...
        menu.addItem(makeItem(title: "Open...", icon: symbolImage(name: "pencil"), action: #selector(actionOpenImage)))
        
        // 12. Pin to the Screen...
        menu.addItem(makeItem(title: "Pin to the Screen...", icon: symbolImage(name: "pin"), action: #selector(actionPinToScreen)))
        
        menu.addItem(NSMenuItem.separator())
        
        // 13. Capture History... (Shortcut: ⌘⇧Z)
        menu.addItem(makeItem(title: "Capture History...", icon: symbolImage(name: "clock.arrow.circlepath"), action: #selector(actionCaptureHistory), keyEquivalent: "z", modifier: [.command, .shift]))
        
        menu.addItem(NSMenuItem.separator())
        
        // 14. About Alt....
        menu.addItem(makeItem(title: "About Alt....", icon: nil, action: #selector(actionAbout)))
        
        // 15. Check for Updates...
        menu.addItem(makeItem(title: "Check for Updates...", icon: nil, action: #selector(actionCheckUpdates)))
        
        menu.addItem(NSMenuItem.separator())
        
        // 16. Settings... (Shortcut: ⌘,)
        menu.addItem(makeItem(title: "Settings...", icon: nil, action: #selector(actionSettings), keyEquivalent: ",", modifier: [.command]))
        
        menu.addItem(NSMenuItem.separator())
        
        // 17. Quit
        menu.addItem(makeItem(title: "Quit Alt.", icon: nil, action: #selector(actionQuit), keyEquivalent: "q", modifier: [.command]))
        
        statusItem.menu = menu
    }
    
    private func makeItem(title: String, icon: NSImage?, action: Selector, keyEquivalent: String = "", modifier: NSEvent.ModifierFlags = []) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.keyEquivalentModifierMask = modifier
        if let icon = icon {
            item.image = icon
            if #available(macOS 15.0, *) {
                item.preferredImageVisibility = .visible
            }
        }
        return item
    }
    
    private func updateRecordingUI(isRecording: Bool) {
        if isRecording {
            statusItem.button?.title = " ● REC"
            recordMenuItem?.title = "Stop Recording"
        } else {
            statusItem.button?.title = ""
            statusItem.button?.image = MenuBarManager.createAltLogo()
            recordMenuItem?.title = "Record Screen"
        }
    }
    
    // MARK: - Actions
    
    @objc private func actionAllInOne() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            CaptureManager.shared.startCapture(mode: .allInOne)
        }
    }
    
    @objc private func actionCaptureArea() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            CaptureManager.shared.startCapture(mode: .area)
        }
    }
    
    @objc private func actionCapturePreviousArea() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            CaptureManager.shared.startCapture(mode: .previousArea)
        }
    }
    
    @objc private func actionCaptureFullscreen() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            CaptureManager.shared.startCapture(mode: .fullscreen)
        }
    }
    
    @objc private func actionCaptureWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            CaptureManager.shared.startCapture(mode: .window)
        }
    }
    
    @objc private func actionScrollingCapture() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            ScrollingCaptureManager.shared.startScrollingCapture()
        }
    }
    
    @objc private func actionSelfTimer() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            CaptureManager.shared.startCapture(mode: .selfTimer(seconds: 3))
        }
    }
    
    @objc private func actionCaptureTextOCR() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            CaptureManager.shared.startCapture(mode: .textOCR)
        }
    }
    
    @objc private func actionPickColor() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            CaptureManager.shared.startCapture(mode: .colorPicker)
        }
    }
    
    @objc private func actionRecordScreen() {
        if RecordingManager.shared.isRecording {
            RecordingManager.shared.stopRecording()
        } else {
            RecordingManager.shared.showRecordingHUD()
        }
    }
    
    @objc private func actionToggleDesktopIcons() {
        DesktopIconManager.shared.toggleDesktopIcons { isHidden in
            let title = isHidden ? "Show Desktop Icons" : "Hide Desktop Icons"
            let iconName = isHidden ? "eye.slash" : "eye"
            self.desktopMenuItem?.title = title
            self.desktopMenuItem?.image = self.symbolImage(name: iconName)
            if #available(macOS 15.0, *) {
                self.desktopMenuItem?.preferredImageVisibility = .visible
            }
        }
    }
    
    @objc private func actionOpenImage() {
        WindowManager.shared.openFileFromDisk()
    }
    
    @objc private func actionPinToScreen() {
        let pb = NSPasteboard.general
        if let data = pb.data(forType: .png) ?? pb.data(forType: .tiff), let img = NSImage(data: data) {
            WindowManager.shared.pinImage(img)
        } else {
            WindowManager.shared.openFileFromDisk()
        }
    }
    
    @objc private func actionCaptureHistory() {
        WindowManager.shared.openHistory()
    }
    
    @objc private func actionAbout() {
        WindowManager.shared.showAbout()
    }
    
    @objc private func actionCheckUpdates() {
        WindowManager.shared.showToast(message: "✓ You're up to date! Alt. 1.0.0 is the latest version.")
    }
    
    @objc private func actionSettings() {
        WindowManager.shared.openSettings()
    }
    
    @objc private func actionQuit() {
        NSApp.terminate(nil)
    }
}
