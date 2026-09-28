import Foundation
import AppKit

final class PinWindowController: NSWindowController, NSWindowDelegate {
    private let pinnedImage: NSImage
    private var imageView: NSImageView!
    
    init(image: NSImage) {
        self.pinnedImage = image
        
        let safeWidth = max(image.size.width, 1)
        let initialWidth = min(safeWidth, 600)
        let initialHeight = (max(image.size.height, 1) / safeWidth) * initialWidth
        
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let x = screenRect.maxX - initialWidth - 60
        let y = screenRect.maxY - initialHeight - 60
        
        let window = NSWindow(
            contentRect: NSRect(x: x, y: y, width: initialWidth, height: initialHeight),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        super.init(window: window)
        window.delegate = self
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        guard let window = self.window else { return }
        
        let container = NSView(frame: window.contentView!.bounds)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        container.layer?.masksToBounds = true
        container.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        container.layer?.borderWidth = 1.0
        
        imageView = NSImageView(frame: container.bounds)
        imageView.autoresizingMask = [.width, .height]
        imageView.image = pinnedImage
        imageView.imageScaling = .scaleAxesIndependently
        container.addSubview(imageView)
        
        // Add Close Button (CleanShot style top-right 'x' on hover or persistent)
        let closeBtn = NSButton(frame: NSRect(x: container.bounds.width - 28, y: container.bounds.height - 28, width: 20, height: 20))
        closeBtn.autoresizingMask = [.minXMargin, .minYMargin]
        closeBtn.bezelStyle = .circular
        closeBtn.title = "×"
        closeBtn.target = self
        closeBtn.action = #selector(closePinned)
        container.addSubview(closeBtn)
        
        // Right-click context menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "📋 Copy Image", action: #selector(copyImage), keyEquivalent: "c"))
        menu.addItem(NSMenuItem(title: "✏️ Open in Markup Editor", action: #selector(openInEditor), keyEquivalent: "e"))
        menu.addItem(NSMenuItem(title: "💾 Save Image...", action: #selector(saveImage), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "🔍 OCR Copy Text", action: #selector(copyOCRText), keyEquivalent: "t"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "❌ Close Pin", action: #selector(closePinned), keyEquivalent: "w"))
        
        for item in menu.items {
            item.target = self
        }
        
        container.menu = menu
        window.contentView = container
    }
    
    @objc private func closePinned() {
        window?.close()
        WindowManager.shared.removePin(self)
    }
    
    @objc private func copyImage() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([pinnedImage])
    }
    
    @objc private func openInEditor() {
        WindowManager.shared.openEditor(with: pinnedImage)
        closePinned()
    }
    
    @objc private func saveImage() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = SettingsManager.shared.generateTimestampedFilename()
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                if let tiff = self.pinnedImage.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff),
                   let data = rep.representation(using: .png, properties: [:]) {
                    try? data.write(to: url)
                }
            }
        }
    }
    
    @objc private func copyOCRText() {
        OCRManager.shared.copyTextToClipboard(from: pinnedImage)
    }
}
