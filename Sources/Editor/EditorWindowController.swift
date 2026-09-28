import Foundation
import AppKit

final class EditorWindowController: NSWindowController {
    private var canvasView: EditorCanvasView
    private var originalImage: NSImage
    private var scrollView: NSScrollView!
    
    // UI Controls
    private var toolSegmentedControl: NSSegmentedControl!
    private var colorWell: NSColorWell!
    private var strokePopup: NSPopUpButton!
    private var gradientPopup: NSPopUpButton!
    private var paddingSlider: NSSlider!
    private var cornerSlider: NSSlider!
    private var shadowSlider: NSSlider!
    
    init(image: NSImage) {
        self.originalImage = image
        self.canvasView = EditorCanvasView(image: image)
        
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let initialWidth = max(min(image.size.width + 120, screenRect.width - 60), 1020)
        let initialHeight = max(min(image.size.height + 160, screenRect.height - 60), 680)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: initialWidth, height: initialHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Alt. Markup & Beautifier"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 980, height: 600)
        window.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 1.0)
        
        super.init(window: window)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        guard let window = self.window else { return }
        
        let mainContainer = NSView(frame: window.contentView!.bounds)
        mainContainer.autoresizingMask = [.width, .height]
        window.contentView = mainContainer
        
        // 1. Top Modern Floating-Style Toolbar
        let topBar = NSVisualEffectView(frame: NSRect(x: 0, y: mainContainer.bounds.height - 54, width: mainContainer.bounds.width, height: 54))
        topBar.autoresizingMask = [.width, .minYMargin]
        topBar.material = .headerView
        topBar.blendingMode = .withinWindow
        topBar.state = .active
        mainContainer.addSubview(topBar)
        
        // Divider line below top bar
        let divider = NSBox(frame: NSRect(x: 0, y: 0, width: topBar.bounds.width, height: 1))
        divider.autoresizingMask = [.width, .maxYMargin]
        divider.boxType = .separator
        topBar.addSubview(divider)
        
        buildTopToolbarItems(in: topBar)
        
        // 2. Bottom Action & Beautifier Bar
        let bottomBar = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: mainContainer.bounds.width, height: 48))
        bottomBar.autoresizingMask = [.width, .maxYMargin]
        bottomBar.material = .headerView
        bottomBar.blendingMode = .withinWindow
        bottomBar.state = .active
        mainContainer.addSubview(bottomBar)
        
        // Divider line above bottom bar
        let bottomDivider = NSBox(frame: NSRect(x: 0, y: 47, width: bottomBar.bounds.width, height: 1))
        bottomDivider.autoresizingMask = [.width, .minYMargin]
        bottomDivider.boxType = .separator
        bottomBar.addSubview(bottomDivider)
        
        buildBottomBarItems(in: bottomBar)
        
        // 3. Middle Scroll View for Canvas
        let scrollY: CGFloat = 48
        let scrollHeight = mainContainer.bounds.height - 54 - scrollY
        scrollView = NSScrollView(frame: NSRect(x: 0, y: scrollY, width: mainContainer.bounds.width, height: scrollHeight))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = NSColor(calibratedWhite: 0.15, alpha: 1.0)
        scrollView.drawsBackground = true
        
        // Wrap canvas inside a clip container to center it
        canvasView.frame = NSRect(origin: .zero, size: canvasView.intrinsicContentSize)
        scrollView.documentView = canvasView
        mainContainer.addSubview(scrollView)
    }
    
    private func buildTopToolbarItems(in bar: NSView) {
        // Leading Stack (Tools, Color, Stroke, Undo, Clear)
        let leftStack = NSStackView()
        leftStack.orientation = .horizontal
        leftStack.alignment = .centerY
        leftStack.spacing = 10
        leftStack.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(leftStack)
        
        // Tool Picker
        let tools: [AnnotationTool] = [.arrow, .rectangle, .circle, .step, .text, .pen, .highlighter, .blur]
        toolSegmentedControl = NSSegmentedControl()
        toolSegmentedControl.segmentCount = tools.count
        for (i, t) in tools.enumerated() {
            toolSegmentedControl.setLabel(t.rawValue, forSegment: i)
            toolSegmentedControl.setWidth(0, forSegment: i)
        }
        toolSegmentedControl.selectedSegment = 0
        toolSegmentedControl.target = self
        toolSegmentedControl.action = #selector(toolChanged(_:))
        leftStack.addArrangedSubview(toolSegmentedControl)
        
        // Color Well
        colorWell = NSColorWell(frame: NSRect(x: 0, y: 0, width: 32, height: 28))
        colorWell.color = NSColor.systemRed
        colorWell.target = self
        colorWell.action = #selector(colorChanged(_:))
        leftStack.addArrangedSubview(colorWell)
        
        // Stroke Width
        strokePopup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 75, height: 28), pullsDown: false)
        strokePopup.addItems(withTitles: ["2 px", "4 px", "8 px", "12 px"])
        strokePopup.selectItem(at: 1)
        strokePopup.target = self
        strokePopup.action = #selector(strokeChanged(_:))
        leftStack.addArrangedSubview(strokePopup)
        
        // Undo & Clear
        let undoBtn = NSButton(title: "↩ Undo", target: self, action: #selector(undoClicked))
        undoBtn.bezelStyle = .rounded
        leftStack.addArrangedSubview(undoBtn)
        
        let clearBtn = NSButton(title: "Clear", target: self, action: #selector(clearClicked))
        clearBtn.bezelStyle = .rounded
        leftStack.addArrangedSubview(clearBtn)
        
        // Trailing Stack (OCR, Pin, Save, Copy Image)
        let rightStack = NSStackView()
        rightStack.orientation = .horizontal
        rightStack.alignment = .centerY
        rightStack.spacing = 10
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(rightStack)
        
        let ocrBtn = NSButton(title: "🔍 OCR", target: self, action: #selector(ocrClicked))
        ocrBtn.bezelStyle = .rounded
        rightStack.addArrangedSubview(ocrBtn)
        
        let pinBtn = NSButton(title: "📌 Pin", target: self, action: #selector(pinClicked))
        pinBtn.bezelStyle = .rounded
        rightStack.addArrangedSubview(pinBtn)
        
        let saveBtn = NSButton(title: "💾 Save", target: self, action: #selector(saveClicked))
        saveBtn.bezelStyle = .rounded
        rightStack.addArrangedSubview(saveBtn)
        
        let copyBtn = NSButton(title: "📋 Copy Image", target: self, action: #selector(copyClicked))
        copyBtn.bezelStyle = .rounded
        copyBtn.keyEquivalent = "\r"
        rightStack.addArrangedSubview(copyBtn)
        
        NSLayoutConstraint.activate([
            leftStack.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 16),
            leftStack.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            
            rightStack.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -16),
            rightStack.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            rightStack.leadingAnchor.constraint(greaterThanOrEqualTo: leftStack.trailingAnchor, constant: 16)
        ])
    }
    
    private func buildBottomBarItems(in bar: NSView) {
        let bottomStack = NSStackView()
        bottomStack.orientation = .horizontal
        bottomStack.alignment = .centerY
        bottomStack.spacing = 12
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(bottomStack)
        
        // Label: Beautifier
        let label = NSTextField(labelWithString: "✨ Beautifier Background:")
        label.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        bottomStack.addArrangedSubview(label)
        
        // Gradient selector
        gradientPopup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 140, height: 26), pullsDown: false)
        for g in BeautifierGradient.allCases {
            gradientPopup.addItem(withTitle: g.rawValue)
        }
        gradientPopup.target = self
        gradientPopup.action = #selector(gradientChanged(_:))
        bottomStack.addArrangedSubview(gradientPopup)
        
        // Padding
        let padLabel = NSTextField(labelWithString: "Padding:")
        bottomStack.addArrangedSubview(padLabel)
        
        paddingSlider = NSSlider(value: 0.0, minValue: 0.0, maxValue: 80.0, target: self, action: #selector(paddingChanged(_:)))
        paddingSlider.widthAnchor.constraint(equalToConstant: 80).isActive = true
        bottomStack.addArrangedSubview(paddingSlider)
        
        // Corners
        let cornerLabel = NSTextField(labelWithString: "Corners:")
        bottomStack.addArrangedSubview(cornerLabel)
        
        cornerSlider = NSSlider(value: 0.0, minValue: 0.0, maxValue: 24.0, target: self, action: #selector(cornerChanged(_:)))
        cornerSlider.widthAnchor.constraint(equalToConstant: 75).isActive = true
        bottomStack.addArrangedSubview(cornerSlider)
        
        // Shadow
        let shadowLabel = NSTextField(labelWithString: "Shadow:")
        bottomStack.addArrangedSubview(shadowLabel)
        
        shadowSlider = NSSlider(value: 0.0, minValue: 0.0, maxValue: 30.0, target: self, action: #selector(shadowChanged(_:)))
        shadowSlider.widthAnchor.constraint(equalToConstant: 75).isActive = true
        bottomStack.addArrangedSubview(shadowSlider)
        
        NSLayoutConstraint.activate([
            bottomStack.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 16),
            bottomStack.centerYAnchor.constraint(equalTo: bar.centerYAnchor)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func toolChanged(_ sender: NSSegmentedControl) {
        let tools: [AnnotationTool] = [.arrow, .rectangle, .circle, .step, .text, .pen, .highlighter, .blur]
        guard sender.selectedSegment >= 0 && sender.selectedSegment < tools.count else { return }
        canvasView.currentTool = tools[sender.selectedSegment]
    }
    
    @objc private func colorChanged(_ sender: NSColorWell) {
        canvasView.currentColor = sender.color
    }
    
    @objc private func strokeChanged(_ sender: NSPopUpButton) {
        let widths: [CGFloat] = [2.0, 4.0, 8.0, 12.0]
        if sender.indexOfSelectedItem >= 0 && sender.indexOfSelectedItem < widths.count {
            canvasView.currentLineWidth = widths[sender.indexOfSelectedItem]
        }
    }
    
    @objc private func undoClicked() {
        canvasView.undo()
    }
    
    @objc private func clearClicked() {
        canvasView.clearAll()
    }
    
    @objc private func gradientChanged(_ sender: NSPopUpButton) {
        let grads = BeautifierGradient.allCases
        guard sender.indexOfSelectedItem >= 0 && sender.indexOfSelectedItem < grads.count else { return }
        canvasView.beautifier.gradient = grads[sender.indexOfSelectedItem]
        
        // If enabling gradient for first time, add comfortable default padding & shadow
        if canvasView.beautifier.gradient != .none && canvasView.beautifier.padding == 0 {
            paddingSlider.doubleValue = 40.0
            cornerSlider.doubleValue = 12.0
            shadowSlider.doubleValue = 20.0
            canvasView.beautifier.padding = 40.0
            canvasView.beautifier.cornerRadius = 12.0
            canvasView.beautifier.shadowRadius = 20.0
            canvasView.beautifier.shadowOpacity = 0.35
        }
        updateCanvasLayout()
    }
    
    @objc private func paddingChanged(_ sender: NSSlider) {
        canvasView.beautifier.padding = CGFloat(sender.doubleValue)
        updateCanvasLayout()
    }
    
    @objc private func cornerChanged(_ sender: NSSlider) {
        canvasView.beautifier.cornerRadius = CGFloat(sender.doubleValue)
        canvasView.needsDisplay = true
    }
    
    @objc private func shadowChanged(_ sender: NSSlider) {
        let val = CGFloat(sender.doubleValue)
        canvasView.beautifier.shadowRadius = val
        canvasView.beautifier.shadowOpacity = val > 0 ? 0.35 : 0.0
        canvasView.needsDisplay = true
    }
    
    private func updateCanvasLayout() {
        let newSize = canvasView.intrinsicContentSize
        canvasView.frame = NSRect(origin: .zero, size: newSize)
        canvasView.needsDisplay = true
    }
    
    @objc private func copyClicked() {
        let finalImage = canvasView.renderExportImage()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([finalImage])
        showTransientToast(message: "✓ Copied to clipboard!")
    }
    
    @objc private func saveClicked() {
        let finalImage = canvasView.renderExportImage()
        let saveURL = SettingsManager.shared.generateSaveURL()
        
        guard let tiff = finalImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let pngData = rep.representation(using: .png, properties: [:]) else {
            return
        }
        
        do {
            try pngData.write(to: saveURL)
            showTransientToast(message: "✓ Saved to: \(saveURL.lastPathComponent)")
            NSWorkspace.shared.activateFileViewerSelecting([saveURL])
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }
    
    @objc private func pinClicked() {
        let finalImage = canvasView.renderExportImage()
        WindowManager.shared.pinImage(finalImage)
    }
    
    @objc private func ocrClicked() {
        let finalImage = canvasView.renderExportImage()
        OCRManager.shared.copyTextToClipboard(from: finalImage) { success, count in
            if success {
                self.showTransientToast(message: "✓ Extracted \(count) characters to clipboard!")
            } else {
                self.showTransientToast(message: "⚠️ No text recognized")
            }
        }
    }
    
    private func showTransientToast(message: String) {
        guard let window = self.window else { return }
        let toast = NSTextField(labelWithString: message)
        toast.font = NSFont.boldSystemFont(ofSize: 13)
        toast.textColor = .white
        toast.backgroundColor = NSColor.black.withAlphaComponent(0.8)
        toast.isBezeled = false
        toast.drawsBackground = true
        toast.alignment = .center
        toast.wantsLayer = true
        toast.layer?.cornerRadius = 8
        toast.layer?.masksToBounds = true
        
        let width: CGFloat = 300
        let height: CGFloat = 36
        toast.frame = NSRect(
            x: (window.contentView!.bounds.width - width) / 2.0,
            y: 60,
            width: width,
            height: height
        )
        window.contentView?.addSubview(toast)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                toast.animator().alphaValue = 0.0
            }, completionHandler: {
                toast.removeFromSuperview()
            })
        }
    }
}
