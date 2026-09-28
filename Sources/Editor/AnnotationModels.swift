import Foundation
import AppKit

enum AnnotationTool: String, CaseIterable {
    case select = "Select"
    case arrow = "Arrow"
    case rectangle = "Rectangle"
    case circle = "Circle"
    case step = "Step (1, 2..)"
    case text = "Text"
    case pen = "Pen"
    case highlighter = "Highlighter"
    case blur = "Blur / Sensor"
    case beautify = "Beautifier"
    
    var iconName: String {
        switch self {
        case .select: return "arrow.up.left"
        case .arrow: return "arrow.up.right"
        case .rectangle: return "square"
        case .circle: return "circle"
        case .step: return "number.circle.fill"
        case .text: return "textformat"
        case .pen: return "pencil.tip"
        case .highlighter: return "highlighter"
        case .blur: return "eye.slash"
        case .beautify: return "sparkles"
        }
    }
}

enum BeautifierGradient: String, CaseIterable {
    case none = "None (Transparent)"
    case sunset = "Sunset"
    case ocean = "Ocean Breeze"
    case midnight = "Midnight Obsidian"
    case aurora = "Aurora Green"
    case lavender = "Lavender Velvet"
    case slate = "Clean Slate"
    
    var colors: [NSColor] {
        switch self {
        case .none:
            return [.clear, .clear]
        case .sunset:
            return [NSColor(red: 1.0, green: 0.32, blue: 0.18, alpha: 1.0),
                    NSColor(red: 0.87, green: 0.14, blue: 0.46, alpha: 1.0)]
        case .ocean:
            return [NSColor(red: 0.13, green: 0.58, blue: 0.69, alpha: 1.0),
                    NSColor(red: 0.43, green: 0.84, blue: 0.93, alpha: 1.0)]
        case .midnight:
            return [NSColor(red: 0.08, green: 0.11, blue: 0.15, alpha: 1.0),
                    NSColor(red: 0.16, green: 0.22, blue: 0.28, alpha: 1.0)]
        case .aurora:
            return [NSColor(red: 0.0, green: 0.69, blue: 0.61, alpha: 1.0),
                    NSColor(red: 0.59, green: 0.79, blue: 0.24, alpha: 1.0)]
        case .lavender:
            return [NSColor(red: 0.48, green: 0.38, blue: 0.95, alpha: 1.0),
                    NSColor(red: 0.86, green: 0.44, blue: 0.84, alpha: 1.0)]
        case .slate:
            return [NSColor(red: 0.88, green: 0.92, blue: 0.98, alpha: 1.0),
                    NSColor(red: 0.81, green: 0.87, blue: 0.95, alpha: 1.0)]
        }
    }
}

struct BeautifierSettings {
    var gradient: BeautifierGradient = .none
    var padding: CGFloat = 0.0          // Inset padding (0 - 80)
    var cornerRadius: CGFloat = 0.0     // Screenshot corner radius (0 - 24)
    var shadowRadius: CGFloat = 0.0     // Shadow blur radius (0 - 40)
    var shadowOpacity: Float = 0.0      // Shadow opacity (0.0 - 0.5)
}

protocol AnnotationItem {
    var id: UUID { get }
    func draw(in context: CGContext, scale: CGFloat)
}

struct ArrowAnnotation: AnnotationItem {
    let id = UUID()
    var start: CGPoint
    var end: CGPoint
    var color: NSColor
    var lineWidth: CGFloat
    
    func draw(in context: CGContext, scale: CGFloat) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setFillColor(color.cgColor)
        context.setLineWidth(lineWidth * scale)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        guard length > 4 else {
            context.restoreGState()
            return
        }
        
        let arrowLength = min(max(lineWidth * 4 * scale, 14 * scale), length * 0.6)
        let angle = atan2(dy, dx)
        let arrowAngle: CGFloat = .pi / 6.0
        
        // Main line
        context.move(to: start)
        let shaftEnd = CGPoint(
            x: end.x - arrowLength * 0.7 * cos(angle),
            y: end.y - arrowLength * 0.7 * sin(angle)
        )
        context.addLine(to: shaftEnd)
        context.strokePath()
        
        // Arrowhead triangle
        let p1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let p2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )
        
        context.move(to: end)
        context.addLine(to: p1)
        context.addLine(to: p2)
        context.closePath()
        context.fillPath()
        
        context.restoreGState()
    }
}

struct RectAnnotation: AnnotationItem {
    let id = UUID()
    var rect: CGRect
    var color: NSColor
    var lineWidth: CGFloat
    var isFilled: Bool
    var cornerRadius: CGFloat
    
    func draw(in context: CGContext, scale: CGFloat) {
        context.saveGState()
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius * scale, cornerHeight: cornerRadius * scale, transform: nil)
        context.addPath(path)
        
        if isFilled {
            context.setFillColor(color.cgColor)
            context.fillPath()
        } else {
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(lineWidth * scale)
            context.strokePath()
        }
        context.restoreGState()
    }
}

struct CircleAnnotation: AnnotationItem {
    let id = UUID()
    var rect: CGRect
    var color: NSColor
    var lineWidth: CGFloat
    var isFilled: Bool
    
    func draw(in context: CGContext, scale: CGFloat) {
        context.saveGState()
        context.addEllipse(in: rect)
        if isFilled {
            context.setFillColor(color.cgColor)
            context.fillPath()
        } else {
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(lineWidth * scale)
            context.strokePath()
        }
        context.restoreGState()
    }
}

struct StepCounterAnnotation: AnnotationItem {
    let id = UUID()
    var center: CGPoint
    var number: Int
    var color: NSColor
    var radius: CGFloat = 16.0
    
    func draw(in context: CGContext, scale: CGFloat) {
        context.saveGState()
        let r = radius * scale
        let circleRect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        
        // Shadow
        context.setShadow(offset: CGSize(width: 0, height: -2 * scale), blur: 4 * scale, color: NSColor.black.withAlphaComponent(0.3).cgColor)
        
        // Outer Circle
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: circleRect)
        
        // Inner white ring stroke
        context.setShadow(offset: .zero, blur: 0, color: nil)
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(2 * scale)
        context.strokeEllipse(in: circleRect.insetBy(dx: 1.5 * scale, dy: 1.5 * scale))
        
        // Number Text
        let text = "\(number)" as NSString
        let font = NSFont.boldSystemFont(ofSize: 15 * scale)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let textSize = text.size(withAttributes: attrs)
        let textRect = CGRect(
            x: center.x - textSize.width / 2.0,
            y: center.y - textSize.height / 2.0,
            width: textSize.width,
            height: textSize.height
        )
        
        NSGraphicsContext.saveGraphicsState()
        let nsc = NSGraphicsContext(cgContext: context, flipped: true)
        NSGraphicsContext.current = nsc
        text.draw(in: textRect, withAttributes: attrs)
        NSGraphicsContext.restoreGraphicsState()
        
        context.restoreGState()
    }
}

struct TextAnnotation: AnnotationItem {
    let id = UUID()
    var origin: CGPoint
    var text: String
    var font: NSFont
    var color: NSColor
    var hasBackgroundPill: Bool
    
    func draw(in context: CGContext, scale: CGFloat) {
        guard !text.isEmpty else { return }
        context.saveGState()
        
        let scaledFont = NSFont(descriptor: font.fontDescriptor, size: font.pointSize * scale) ?? font
        let attrs: [NSAttributedString.Key: Any] = [
            .font: scaledFont,
            .foregroundColor: color
        ]
        let nsText = text as NSString
        let size = nsText.size(withAttributes: attrs)
        let padding: CGFloat = 8.0 * scale
        
        let textRect = CGRect(x: origin.x, y: origin.y, width: size.width, height: size.height)
        let pillRect = textRect.insetBy(dx: -padding, dy: -padding * 0.4)
        
        if hasBackgroundPill {
            context.setFillColor(NSColor.black.withAlphaComponent(0.75).cgColor)
            let path = CGPath(roundedRect: pillRect, cornerWidth: 6 * scale, cornerHeight: 6 * scale, transform: nil)
            context.addPath(path)
            context.fillPath()
        }
        
        NSGraphicsContext.saveGraphicsState()
        let nsc = NSGraphicsContext(cgContext: context, flipped: true)
        NSGraphicsContext.current = nsc
        nsText.draw(in: textRect, withAttributes: attrs)
        NSGraphicsContext.restoreGraphicsState()
        
        context.restoreGState()
    }
}

struct FreehandAnnotation: AnnotationItem {
    let id = UUID()
    var points: [CGPoint]
    var color: NSColor
    var lineWidth: CGFloat
    var isHighlighter: Bool
    
    func draw(in context: CGContext, scale: CGFloat) {
        guard points.count > 1 else { return }
        context.saveGState()
        
        let strokeColor = isHighlighter ? color.withAlphaComponent(0.35) : color
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(lineWidth * scale)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        if isHighlighter {
            context.setBlendMode(.multiply)
        }
        
        context.move(to: points[0])
        for i in 1..<points.count {
            context.addLine(to: points[i])
        }
        context.strokePath()
        context.restoreGState()
    }
}

struct BlurAnnotation: AnnotationItem {
    let id = UUID()
    var rect: CGRect
    
    func draw(in context: CGContext, scale: CGFloat) {
        // Blur is handled dynamically over the base image bitmap,
        // but if rendered in preview, can draw a pixelated/frosted overlay.
        context.saveGState()
        context.setFillColor(NSColor.gray.withAlphaComponent(0.4).cgColor)
        context.fill(rect)
        
        // Draw subtle grid/pixelate hint
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.2).cgColor)
        context.setLineWidth(1)
        let step: CGFloat = 8 * scale
        var x = rect.minX
        while x < rect.maxX {
            context.move(to: CGPoint(x: x, y: rect.minY))
            context.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += step
        }
        var y = rect.minY
        while y < rect.maxY {
            context.move(to: CGPoint(x: rect.minX, y: y))
            context.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += step
        }
        context.strokePath()
        context.restoreGState()
    }
}
