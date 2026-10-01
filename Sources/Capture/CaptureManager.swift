import Foundation
import AppKit
import AudioToolbox

final class CaptureManager {
    static let shared = CaptureManager()
    
    enum CaptureMode {
        case allInOne
        case area
        case previousArea
        case fullscreen
        case window
        case scrolling
        case selfTimer(seconds: Int)
        case textOCR
        case colorPicker
    }
    
    // Persistent memory of the exact previous area
    private let lastCocoaRectKey = "ALT_LastCapturedCocoaRect"
    private let lastScreenRectStrKey = "ALT_LastCapturedScreenRectString"
    
    private(set) var lastCapturedCocoaRect: CGRect?
    private(set) var lastCapturedScreenRectString: String?
    
    private init() {
        if let rectStr = UserDefaults.standard.string(forKey: lastScreenRectStrKey), !rectStr.isEmpty {
            self.lastCapturedScreenRectString = rectStr
        }
        if let cocoaStr = UserDefaults.standard.string(forKey: lastCocoaRectKey), !cocoaStr.isEmpty {
            let rect = NSRectFromString(cocoaStr)
            if rect.width >= 10 && rect.height >= 10 {
                self.lastCapturedCocoaRect = rect
            }
        }
    }
    
    // Convert screencapture -R string "x,y,w,h" back to Cocoa screen coordinates
    func cocoaRect(from rectStr: String) -> CGRect? {
        let parts = rectStr.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 4 else { return nil }
        let (x, y, w, h) = (parts[0], parts[1], parts[2], parts[3])
        guard w >= 10, h >= 10 else { return nil }
        
        let primaryScreen = NSScreen.screens.first ?? NSScreen.main
        let screenH = primaryScreen?.frame.height ?? 900
        let cocoaY = screenH - y - h
        return CGRect(x: x, y: cocoaY, width: w, height: h)
    }
    
    // Public setter so Recording crop and Scrolling capture can also update the previous area
    func setLastCapturedArea(_ rect: CGRect) {
        guard rect.width >= 10 && rect.height >= 10 else { return }
        self.lastCapturedCocoaRect = rect
        
        let screen = NSScreen.screens.first ?? NSScreen.main
        let screenH = screen?.frame.height ?? 900
        let x = Int(rect.origin.x)
        let y = Int(screenH - rect.maxY)
        let w = Int(rect.width)
        let h = Int(rect.height)
        let rectStr = "\(x),\(y),\(w),\(h)"
        self.lastCapturedScreenRectString = rectStr
        
        UserDefaults.standard.set(NSStringFromRect(rect), forKey: lastCocoaRectKey)
        UserDefaults.standard.set(rectStr, forKey: lastScreenRectStrKey)
    }
    
    func startCapture(mode: CaptureMode) {
        switch mode {
        case .allInOne, .area:
            // Interactive area selection with live dimensions and crosshair
            RecordingAreaSelectorController.shared.startSelection(
                hint: "Drag to capture area, or press Escape to cancel",
                onCancel: nil
            ) { [weak self] rect in
                guard let self = self else { return }
                self.setLastCapturedArea(rect)
                self.captureAreaRect(rect, isOCR: false)
            }
            
        case .previousArea:
            guard let rectStr = lastCapturedScreenRectString, !rectStr.isEmpty else {
                WindowManager.shared.showToast(message: "⚠️ Belum ada area sebelumnya")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                    self?.startCapture(mode: .area)
                }
                return
            }
            
            // 1. Capture that exact rectangle FIRST to prevent capturing flash overlays or borders
            self.captureRectByString(rectStr, isOCR: false) { [weak self] success in
                guard let self = self else { return }
                if success {
                    // 2. Visual confirmation: flash electric blue border over the exact previous area AFTER capture
                    if let cocoaRect = self.lastCapturedCocoaRect ?? self.cocoaRect(from: rectStr) {
                        self.flashArea(cocoaRect)
                    }
                    WindowManager.shared.showToast(message: "✓ Berhasil menangkap area sebelumnya")
                } else {
                    WindowManager.shared.showToast(message: "⚠️ Gagal mengambil area sebelumnya")
                }
            }
            
        case .textOCR:
            // Drag to extract text from exact area
            RecordingAreaSelectorController.shared.startSelection(
                hint: "Drag to extract text (OCR), or press Escape to cancel",
                onCancel: nil
            ) { [weak self] rect in
                guard let self = self else { return }
                self.setLastCapturedArea(rect)
                self.captureAreaRect(rect, isOCR: true)
            }
            
        case .fullscreen:
            let tempFile = generateTempFileURL()
            executeCaptureCommand(arguments: ["-x", "-m", tempFile.path]) { [weak self] success in
                if success {
                    self?.handleCapturedFile(at: tempFile)
                }
            }
            
        case .window:
            let tempFile = generateTempFileURL()
            executeCaptureCommand(arguments: ["-x", "-i", "-w", tempFile.path]) { [weak self] success in
                if success {
                    self?.handleCapturedFile(at: tempFile)
                }
            }
            
        case .scrolling:
            ScrollingCaptureManager.shared.startScrollingCapture()
            
        case .selfTimer(let seconds):
            let tempFile = generateTempFileURL()
            executeCaptureCommand(arguments: ["-x", "-T", "\(seconds)", tempFile.path]) { [weak self] success in
                if success {
                    self?.handleCapturedFile(at: tempFile)
                }
            }
            
        case .colorPicker:
            pickColor()
        }
    }
    
    func pickColor() {
        if #available(macOS 10.15, *) {
            NSColorSampler().show { selectedColor in
                guard let color = selectedColor else { return }
                let rgbColor = color.usingColorSpace(.sRGB) ?? color
                let r = Int(round(rgbColor.redComponent * 255.0))
                let g = Int(round(rgbColor.greenComponent * 255.0))
                let b = Int(round(rgbColor.blueComponent * 255.0))
                let hex = String(format: "#%02X%02X%02X", r, g, b)
                
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(hex, forType: .string)
                
                WindowManager.shared.showToast(message: "✓ Copied Color: \(hex)")
            }
        }
    }
    
    // MARK: - Rect Capture Helpers
    
    private func captureAreaRect(_ rect: CGRect, isOCR: Bool) {
        let rectStr: String
        if let saved = lastCapturedScreenRectString {
            rectStr = saved
        } else {
            let primaryScreen = NSScreen.screens.first ?? NSScreen.main
            let screenH = primaryScreen?.frame.height ?? 900
            let x = Int(rect.origin.x)
            let y = Int(screenH - rect.maxY)
            let w = Int(rect.width)
            let h = Int(rect.height)
            rectStr = "\(x),\(y),\(w),\(h)"
        }
        
        captureRectByString(rectStr, isOCR: isOCR, completion: nil)
    }
    
    private func captureRectByString(_ rectStr: String, isOCR: Bool, completion: ((Bool) -> Void)?) {
        let tempFile = generateTempFileURL()
        let arguments = ["-x", "-R\(rectStr)", tempFile.path]
        
        executeCaptureCommand(arguments: arguments) { [weak self] success in
            guard let self = self else {
                completion?(false)
                return
            }
            guard success,
                  FileManager.default.fileExists(atPath: tempFile.path),
                  let image = NSImage(contentsOf: tempFile),
                  image.size.width > 0, image.size.height > 0 else {
                try? FileManager.default.removeItem(at: tempFile)
                completion?(false)
                return
            }
            if isOCR {
                self.handleOCRFile(at: tempFile)
            } else {
                self.handleCapturedFile(at: tempFile)
            }
            completion?(true)
        }
    }
    
    private func generateTempFileURL() -> URL {
        let tempDir = NSTemporaryDirectory()
        return URL(fileURLWithPath: tempDir).appendingPathComponent("alt_\(UUID().uuidString).png")
    }
    
    private func executeCaptureCommand(arguments: [String], completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            task.arguments = arguments
            
            do {
                try task.run()
                task.waitUntilExit()
                DispatchQueue.main.async {
                    completion(task.terminationStatus == 0)
                }
            } catch {
                print("Failed to run screencapture: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    
    private var currentFlashWindow: NSWindow?
    
    // MARK: - Visual Feedback Flash
    
    private func flashArea(_ rect: CGRect) {
        currentFlashWindow?.close()
        currentFlashWindow = nil
        
        let flashWin = NSWindow(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        flashWin.level = .floating
        flashWin.isOpaque = false
        flashWin.backgroundColor = .clear
        flashWin.ignoresMouseEvents = true
        flashWin.hasShadow = false
        flashWin.isReleasedWhenClosed = false
        flashWin.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let borderView = NSView(frame: NSRect(x: 0, y: 0, width: rect.width, height: rect.height))
        borderView.wantsLayer = true
        borderView.layer?.borderWidth = 2.5
        borderView.layer?.borderColor = NSColor(red: 0.05, green: 0.52, blue: 1.0, alpha: 1.0).cgColor
        borderView.layer?.cornerRadius = 6
        borderView.layer?.backgroundColor = NSColor(red: 0.05, green: 0.52, blue: 1.0, alpha: 0.12).cgColor
        flashWin.contentView = borderView
        
        self.currentFlashWindow = flashWin
        flashWin.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.30
            flashWin.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            flashWin.close()
            if self?.currentFlashWindow === flashWin {
                self?.currentFlashWindow = nil
            }
        })
    }
    
    // MARK: - Result Handlers
    
    private func handleOCRFile(at fileURL: URL) {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let image = NSImage(contentsOf: fileURL),
              image.size.width > 0, image.size.height > 0 else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        
        if SettingsManager.shared.playShutterSound {
            AudioServicesPlaySystemSound(1108) // Camera shutter
        }
        
        OCRManager.shared.copyTextToClipboard(from: image) { success, charCount in
            try? FileManager.default.removeItem(at: fileURL)
            if success {
                WindowManager.shared.showToast(message: "✓ Copied \(charCount) characters to clipboard!")
            } else {
                WindowManager.shared.showToast(message: "⚠️ No recognizable text found")
            }
        }
    }
    
    private func handleCapturedFile(at fileURL: URL) {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let image = NSImage(contentsOf: fileURL),
              image.size.width > 0, image.size.height > 0 else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        
        // 1. Shutter sound
        if SettingsManager.shared.playShutterSound {
            AudioServicesPlaySystemSound(1108)
        }
        
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
