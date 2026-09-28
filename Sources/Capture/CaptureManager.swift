import Foundation
import AppKit
import AudioToolbox

final class CaptureManager {
    static let shared = CaptureManager()
    private init() {}
    
    enum CaptureMode {
        case allInOne
        case area
        case previousArea
        case fullscreen
        case window
        case scrolling
        case selfTimer(seconds: Int)
        case textOCR
    }
    
    private var lastCapturedRect: String?
    
    func startCapture(mode: CaptureMode) {
        let tempDir = NSTemporaryDirectory()
        let tempFile = URL(fileURLWithPath: tempDir).appendingPathComponent("alt_\(UUID().uuidString).png")
        
        var arguments: [String] = []
        
        switch mode {
        case .allInOne:
            // macOS interactive capture: click to window, drag to area, space to toggle
            arguments = ["-i", tempFile.path]
            
        case .area:
            arguments = ["-i", "-s", tempFile.path]
            
        case .previousArea:
            if let rect = lastCapturedRect {
                arguments = ["-R\(rect)", tempFile.path]
            } else {
                arguments = ["-i", "-s", tempFile.path]
            }
            
        case .fullscreen:
            arguments = ["-m", tempFile.path]
            
        case .window:
            arguments = ["-i", "-w", tempFile.path]
            
        case .scrolling:
            // Area selection which immediately opens in editor
            arguments = ["-i", "-s", tempFile.path]
            
        case .selfTimer(let seconds):
            arguments = ["-T", "\(seconds)", tempFile.path]
            
        case .textOCR:
            // Directly capture area and OCR text to clipboard
            arguments = ["-i", "-s", tempFile.path]
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            task.arguments = arguments
            
            do {
                try task.run()
                task.waitUntilExit()
                
                DispatchQueue.main.async {
                    switch mode {
                    case .textOCR:
                        self.handleOCRFile(at: tempFile)
                    case .scrolling:
                        self.handleScrollingFile(at: tempFile)
                    default:
                        self.handleCapturedFile(at: tempFile)
                    }
                }
            } catch {
                print("Failed to run screencapture: \(error)")
            }
        }
    }
    
    private func handleOCRFile(at fileURL: URL) {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let image = NSImage(contentsOf: fileURL),
              image.size.width > 0, image.size.height > 0 else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        
        AudioServicesPlaySystemSound(1108) // Camera shutter
        
        OCRManager.shared.copyTextToClipboard(from: image) { success, charCount in
            try? FileManager.default.removeItem(at: fileURL)
            if success {
                WindowManager.shared.showToast(message: "✓ Copied \(charCount) characters to clipboard!")
            } else {
                WindowManager.shared.showToast(message: "⚠️ No recognizable text found")
            }
        }
    }
    
    private func handleScrollingFile(at fileURL: URL) {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let image = NSImage(contentsOf: fileURL),
              image.size.width > 0, image.size.height > 0 else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        
        AudioServicesPlaySystemSound(1108)
        HistoryManager.shared.addItem(image: image, fileURL: fileURL)
        WindowManager.shared.openEditor(with: image)
    }
    
    private func handleCapturedFile(at fileURL: URL) {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let image = NSImage(contentsOf: fileURL),
              image.size.width > 0, image.size.height > 0 else {
            // User cancelled (Esc)
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        
        // 1. Shutter sound
        if SettingsManager.shared.playShutterSound {
            AudioServicesPlaySystemSound(1108)
        }
        
        // Save previous area rect
        let w = Int(image.size.width)
        let h = Int(image.size.height)
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let x = min(max(Int(mouse.x) - w / 2, 0), max(Int(screen.width) - w, 0))
        let y = min(max(Int(mouse.y) - h / 2, 0), max(Int(screen.height) - h, 0))
        self.lastCapturedRect = "\(x),\(y),\(w),\(h)"
        
        // 2. Add to History
        HistoryManager.shared.addItem(image: image, fileURL: fileURL)
        
        // 3. Auto Copy to Clipboard
        if SettingsManager.shared.autoCopyToClipboard {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.writeObjects([image])
        }
        
        // 4. Open editor or quick access
        if SettingsManager.shared.openEditorDirectly {
            WindowManager.shared.openEditor(with: image)
        } else if SettingsManager.shared.showQuickAccess {
            WindowManager.shared.showQuickAccess(image: image, fileURL: fileURL)
        }
    }
}
