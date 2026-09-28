import Foundation
import AppKit
import CoreImage

final class EditorCanvasView: NSView {
    var baseImage: NSImage
    private var blurredBaseImage: CGImage?
    
    var currentTool: AnnotationTool = .arrow
    var currentColor: NSColor = NSColor.systemRed
    var currentLineWidth: CGFloat = 4.0
    var isFilled: Bool = false
    var stepCounter: Int = 1
    
    var beautifier = BeautifierSettings() {
        didSet {
            invalidateIntrinsicContentSize()
            needsDisplay = true
        }
    }
    
    private(set) var annotations: [AnnotationItem] = []
    private var undoStack: [[AnnotationItem]] = []
    private var redoStack: [[AnnotationItem]] = []
    
    // Live dragging state
    private var dragStart: CGPoint?
    private var dragCurrent: CGPoint?
    private var liveAnnotation: AnnotationItem?
    
    init(image: NSImage) {
        self.baseImage = image
        super.init(frame: .zero)
        setupTracking()
        updateBlurredBaseImage()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var isFlipped: Bool { true }
    
    private func setupTracking() {
        let options: NSTrackingArea.Options = [.activeAlways, .mouseMoved, .mouseEnteredAndExited]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        setupTracking()
    }
    
    override var intrinsicContentSize: NSSize {
        let p = beautifier.padding
        return NSSize(
            width: baseImage.size.width + (p * 2),
            height: baseImage.size.height + (p * 2)
        )
    }
    
    var imageRect: CGRect {
        let p = beautifier.padding
        return CGRect(
            x: p,
            y: p,
            width: baseImage.size.width,
            height: baseImage.size.height
        )
    }
    
    private func updateBlurredBaseImage() {
        guard let tiff = baseImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let cg = bitmap.cgImage else { return }
        
        let ciImage = CIImage(cgImage: cg)
        let filter = CIFilter(name: "CIPixellate")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(18.0, forKey: kCIInputScaleKey)
        
        if let output = filter?.outputImage {
            let context = CIContext()
            self.blurredBaseImage = context.createCGImage(output, from: output.extent)
        }
    }
    
    func undo() {
        guard !annotations.isEmpty else { return }
        redoStack.append(annotations)
        _ = annotations.popLast()
        needsDisplay = true
    }
    
    func redo() {
        guard let restored = redoStack.popLast() else { return }
        annotations = restored
        needsDisplay = true
    }
    
    func clearAll() {
        saveStateForUndo()
        annotations.removeAll()
        stepCounter = 1
        needsDisplay = true
    }
    
    private func saveStateForUndo() {
        undoStack.append(annotations)
        redoStack.removeAll()
    }
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // 1. Draw Beautifier Background Gradient
        if beautifier.gradient != .none {
            drawGradientBackground(in: context, rect: bounds)
        }
        
        // 2. Draw Screenshot with Shadow & Corner Radius
        let targetRect = imageRect
        context.saveGState()
        
        if beautifier.shadowOpacity > 0 {
            context.setShadow(
                offset: CGSize(width: 0, height: 8),
                blur: beautifier.shadowRadius,
                color: NSColor.black.withAlphaComponent(CGFloat(beautifier.shadowOpacity)).cgColor
            )
        }
        
        let clipPath = CGPath(
            roundedRect: targetRect,
            cornerWidth: beautifier.cornerRadius,
            cornerHeight: beautifier.cornerRadius,
            transform: nil
        )
        context.addPath(clipPath)
        context.clip()
        
        // Draw base image
        if let tiff = baseImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let cg = bitmap.cgImage {
            // AppKit flipped coordinate correction for CGContext drawImage
            context.saveGState()
            context.translateBy(x: 0, y: targetRect.maxY)
            context.scaleBy(x: 1.0, y: -1.0)
            context.draw(cg, in: CGRect(x: targetRect.minX, y: 0, width: targetRect.width, height: targetRect.height))
            context.restoreGState()
        }
        
        // Draw real blur regions
        for item in annotations {
            if let blurItem = item as? BlurAnnotation, let blurred = blurredBaseImage {
                let localRect = blurItem.rect.offsetBy(dx: targetRect.minX, dy: targetRect.minY)
                context.saveGState()
                context.clip(to: localRect)
                context.translateBy(x: 0, y: targetRect.maxY)
                context.scaleBy(x: 1.0, y: -1.0)
                context.draw(blurred, in: CGRect(x: targetRect.minX, y: 0, width: targetRect.width, height: targetRect.height))
                context.restoreGState()
            }
        }
        
        context.restoreGState()
        
        // 3. Draw Annotations
        context.saveGState()
        context.translateBy(x: targetRect.minX, y: targetRect.minY)
        
        for item in annotations {
            // Blur items were already drawn clipped onto the image
            if !(item is BlurAnnotation) {
                item.draw(in: context, scale: 1.0)
            }
        }
        
        // Draw Live in-progress annotation
        if let live = liveAnnotation {
            live.draw(in: context, scale: 1.0)
        }
        
        context.restoreGState()
    }
    
    private func drawGradientBackground(in context: CGContext, rect: CGRect) {
        let colors = beautifier.gradient.colors.map { $0.cgColor } as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0]) else { return }
        
        let startPoint = CGPoint(x: rect.minX, y: rect.minY)
        let endPoint = CGPoint(x: rect.maxX, y: rect.maxY)
        context.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
    }
    
    // MARK: - Mouse Events
    
    private func localPoint(from event: NSEvent) -> CGPoint {
        let windowPoint = convert(event.locationInWindow, from: nil)
        let p = beautifier.padding
        return CGPoint(x: windowPoint.x - p, y: windowPoint.y - p)
    }
    
    override func mouseDown(with event: NSEvent) {
        let pt = localPoint(from: event)
        dragStart = pt
        dragCurrent = pt
        saveStateForUndo()
        
        if currentTool != .text {
            commitInlineText()
        }
        
        switch currentTool {
        case .step:
            let stepItem = StepCounterAnnotation(
                center: pt,
                number: stepCounter,
                color: currentColor
            )
            stepCounter += 1
            annotations.append(stepItem)
            needsDisplay = true
            
        case .text:
            startInlineTextEditing(at: pt)
            
        case .pen, .highlighter:
            liveAnnotation = FreehandAnnotation(
                points: [pt],
                color: currentColor,
                lineWidth: currentLineWidth,
                isHighlighter: currentTool == .highlighter
            )
            needsDisplay = true
            
        default:
            break
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        let current = localPoint(from: event)
        dragCurrent = current
        
        let rect = CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        
        switch currentTool {
        case .arrow:
            liveAnnotation = ArrowAnnotation(start: start, end: current, color: currentColor, lineWidth: currentLineWidth)
        case .rectangle:
            liveAnnotation = RectAnnotation(rect: rect, color: currentColor, lineWidth: currentLineWidth, isFilled: isFilled, cornerRadius: 4.0)
        case .circle:
            liveAnnotation = CircleAnnotation(rect: rect, color: currentColor, lineWidth: currentLineWidth, isFilled: isFilled)
        case .blur:
            liveAnnotation = BlurAnnotation(rect: rect)
        case .pen, .highlighter:
            if var freehand = liveAnnotation as? FreehandAnnotation {
                freehand.points.append(current)
                liveAnnotation = freehand
            }
        default:
            break
        }
        
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        if let live = liveAnnotation {
            annotations.append(live)
            liveAnnotation = nil
        }
        dragStart = nil
        dragCurrent = nil
        needsDisplay = true
    }
    
    private var inlineTextField: NSTextField?
    
    private func startInlineTextEditing(at point: CGPoint) {
        commitInlineText()
        
        let p = beautifier.padding
        let fieldX = point.x + p
        let fieldY = point.y + p
        
        let field = NSTextField(frame: NSRect(x: fieldX, y: fieldY, width: 240, height: 34))
        field.isBordered = false
        field.wantsLayer = true
        field.layer?.cornerRadius = 6
        field.layer?.masksToBounds = true
        field.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.78).cgColor
        field.textColor = currentColor
        field.font = NSFont.boldSystemFont(ofSize: 18)
        field.placeholderString = "Type text here (Return)..."
        field.focusRingType = .none
        field.target = self
        field.action = #selector(inlineTextSubmitted(_:))
        
        addSubview(field)
        window?.makeFirstResponder(field)
        self.inlineTextField = field
    }
    
    @objc private func inlineTextSubmitted(_ sender: NSTextField) {
        commitInlineText()
    }
    
    func commitInlineText() {
        guard let field = inlineTextField else { return }
        let str = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !str.isEmpty {
            let p = beautifier.padding
            let origin = CGPoint(x: field.frame.minX - p, y: field.frame.minY - p + 4)
            let textItem = TextAnnotation(
                origin: origin,
                text: str,
                font: field.font ?? NSFont.boldSystemFont(ofSize: 18),
                color: currentColor,
                hasBackgroundPill: true
            )
            annotations.append(textItem)
        }
        field.removeFromSuperview()
        inlineTextField = nil
        needsDisplay = true
    }
    
    // MARK: - Export Full Resolution Image
    
    func renderExportImage() -> NSImage {
        commitInlineText()
        let exportSize = intrinsicContentSize
        let image = NSImage(size: exportSize)
        
        image.lockFocusFlipped(true)
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return baseImage
        }
        
        let exportBounds = CGRect(origin: .zero, size: exportSize)
        
        if beautifier.gradient != .none {
            drawGradientBackground(in: context, rect: exportBounds)
        }
        
        let targetRect = imageRect
        context.saveGState()
        
        if beautifier.shadowOpacity > 0 {
            context.setShadow(
                offset: CGSize(width: 0, height: 8),
                blur: beautifier.shadowRadius,
                color: NSColor.black.withAlphaComponent(CGFloat(beautifier.shadowOpacity)).cgColor
            )
        }
        
        let clipPath = CGPath(
            roundedRect: targetRect,
            cornerWidth: beautifier.cornerRadius,
            cornerHeight: beautifier.cornerRadius,
            transform: nil
        )
        context.addPath(clipPath)
        context.clip()
        
        // Draw base image in export
        baseImage.draw(in: targetRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        
        // Draw blurred regions
        for item in annotations {
            if let blurItem = item as? BlurAnnotation, let blurred = blurredBaseImage {
                let localRect = blurItem.rect.offsetBy(dx: targetRect.minX, dy: targetRect.minY)
                context.saveGState()
                context.clip(to: localRect)
                let blurredImg = NSImage(cgImage: blurred, size: targetRect.size)
                blurredImg.draw(in: targetRect, from: .zero, operation: .sourceOver, fraction: 1.0)
                context.restoreGState()
            }
        }
        
        context.restoreGState()
        
        // Draw Annotations
        context.saveGState()
        context.translateBy(x: targetRect.minX, y: targetRect.minY)
        for item in annotations {
            if !(item is BlurAnnotation) {
                item.draw(in: context, scale: 1.0)
            }
        }
        context.restoreGState()
        
        image.unlockFocus()
        return image
    }
}
