import Foundation
import AppKit
import AVFoundation
import UniformTypeIdentifiers

final class RecordingManager {
    static let shared = RecordingManager()
    
    enum RecordType {
        case video
        case gif
    }
    
    private var recordingProcess: Process?
    private var currentOutputURL: URL?
    private var currentType: RecordType = .video
    private(set) var isRecording: Bool = false
    
    var onStateChanged: ((Bool) -> Void)?
    
    private init() {}
    
    func showRecordingHUD() {
        RecordingHUDWindowController.shared.showHUD()
    }
    
    func startRecordingVideo() {
        startRecording(type: .video)
    }
    
    func startRecordingGIF() {
        startRecording(type: .gif)
    }
    
    private func startRecording(type: RecordType) {
        guard !isRecording else { return }
        self.currentType = type
        
        let prefix = type == .gif ? "Alt. Recording (GIF)" : "Alt. Recording"
        let saveURL = SettingsManager.shared.generateSaveURL(prefix: prefix).deletingPathExtension().appendingPathExtension("mov")
        currentOutputURL = saveURL
        
        var arguments = ["-v"]
        
        // Custom area rect option
        if let rect = RecordingHUDWindowController.shared.selectedRecordingRect,
           let screen = NSScreen.main {
            let screenH = screen.frame.height
            let x = max(0, Int(rect.origin.x))
            let y = max(0, Int(screenH - rect.maxY))
            let w = max(10, Int(rect.width))
            let h = max(10, Int(rect.height))
            arguments.append("-R\(x),\(y),\(w),\(h)")
        }
        
        // Clicks option
        if RecordingHUDWindowController.shared.isClicksEnabled {
            arguments.append("-k")
        }
        
        // Microphone audio option
        if RecordingHUDWindowController.shared.isMicEnabled {
            arguments.append("-g")
        }
        
        // System audio option
        if RecordingHUDWindowController.shared.isSystemAudioEnabled {
            arguments.append("-A")
        }
        
        arguments.append(saveURL.path)
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = arguments
        
        do {
            try task.run()
            self.recordingProcess = task
            self.isRecording = true
            self.onStateChanged?(true)
            self.showRecordingControlBar()
            
            DispatchQueue.global(qos: .userInitiated).async {
                task.waitUntilExit()
                DispatchQueue.main.async {
                    self.finishRecording()
                }
            }
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    func stopRecording() {
        guard isRecording, let process = recordingProcess else { return }
        process.interrupt()
    }
    
    private func finishRecording() {
        isRecording = false
        recordingProcess = nil
        hideRecordingControlBar()
        onStateChanged?(false)
        
        guard let url = currentOutputURL, FileManager.default.fileExists(atPath: url.path) else { return }
        
        if currentType == .gif {
            WindowManager.shared.showToast(message: "⚡ Converting to GIF...")
            convertMovToGIF(movURL: url) { gifURL in
                if let gif = gifURL {
                    WindowManager.shared.showToast(message: "✓ GIF Saved: \(gif.lastPathComponent)")
                    if let img = NSImage(contentsOf: gif) {
                        HistoryManager.shared.addItem(image: img, fileURL: gif)
                        if SettingsManager.shared.showQuickAccess {
                            WindowManager.shared.showQuickAccess(image: img, fileURL: gif)
                        }
                    }
                    NSWorkspace.shared.activateFileViewerSelecting([gif])
                }
            }
        } else {
            if let img = self.generateVideoThumbnail(from: url) {
                HistoryManager.shared.addItem(image: img, fileURL: url)
                if SettingsManager.shared.showQuickAccess {
                    WindowManager.shared.showQuickAccess(image: img, fileURL: url)
                }
            }
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
    
    private func generateVideoThumbnail(from url: URL) -> NSImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0.5, preferredTimescale: 600)
        if let cgImg = try? generator.copyCGImage(at: time, actualTime: nil) {
            return NSImage(cgImage: cgImg, size: NSSize(width: cgImg.width, height: cgImg.height))
        }
        return nil
    }
    
    // MARK: - Floating Recording Control Bar
    
    private var controlPanel: NSPanel?
    private var recordingTimer: Timer?
    private var elapsedSeconds: Int = 0
    private var timerLabel: NSTextField?
    
    private func showRecordingControlBar() {
        elapsedSeconds = 0
        let panelW: CGFloat = 210
        let panelH: CGFloat = 46
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let x = (screen.width - panelW) / 2.0
        let y = screen.minY + 36
        
        let panel = NSPanel(
            contentRect: NSRect(x: x, y: y, width: panelW, height: panelH),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let effect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: panelW, height: panelH))
        effect.material = .hudWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 23
        effect.layer?.masksToBounds = true
        effect.layer?.borderColor = NSColor.white.withAlphaComponent(0.28).cgColor
        effect.layer?.borderWidth = 1.0
        
        let dot = NSView(frame: NSRect(x: 16, y: 17, width: 12, height: 12))
        dot.wantsLayer = true
        dot.layer?.backgroundColor = NSColor.systemRed.cgColor
        dot.layer?.cornerRadius = 6
        effect.addSubview(dot)
        
        let tLabel = NSTextField(labelWithString: "00:00")
        tLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .bold)
        tLabel.textColor = .white
        tLabel.frame = NSRect(x: 36, y: 14, width: 60, height: 18)
        effect.addSubview(tLabel)
        self.timerLabel = tLabel
        
        let stopBtn = NSButton(title: "■ Stop", target: self, action: #selector(stopButtonClicked))
        stopBtn.frame = NSRect(x: 108, y: 8, width: 86, height: 30)
        stopBtn.bezelStyle = .rounded
        effect.addSubview(stopBtn)
        
        panel.contentView = effect
        panel.orderFront(nil)
        self.controlPanel = panel
        
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.elapsedSeconds += 1
            let mins = self.elapsedSeconds / 60
            let secs = self.elapsedSeconds % 60
            self.timerLabel?.stringValue = String(format: "%02d:%02d", mins, secs)
        }
    }
    
    @objc private func stopButtonClicked() {
        stopRecording()
    }
    
    private func hideRecordingControlBar() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        controlPanel?.close()
        controlPanel = nil
    }
    
    // Native AVAssetReader to GIF conversion using ImageIO
    private func convertMovToGIF(movURL: URL, completion: @escaping (URL?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVAsset(url: movURL)
            let gifURL = movURL.deletingPathExtension().appendingPathExtension("gif")
            
            guard let track = asset.tracks(withMediaType: .video).first else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            let outputSettings: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB
            ]
            guard let reader = try? AVAssetReader(asset: asset) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let trackOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
            reader.add(trackOutput)
            reader.startReading()
            
            guard let destination = CGImageDestinationCreateWithURL(gifURL as CFURL, UTType.gif.identifier as CFString, 0, nil) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            let gifProperties: [String: Any] = [
                kCGImagePropertyGIFDictionary as String: [
                    kCGImagePropertyGIFLoopCount as String: 0
                ]
            ]
            CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)
            
            let frameProperties: [String: Any] = [
                kCGImagePropertyGIFDictionary as String: [
                    kCGImagePropertyGIFDelayTime as String: 0.08
                ]
            ]
            
            var frameCount = 0
            while reader.status == .reading {
                if let sampleBuffer = trackOutput.copyNextSampleBuffer(),
                   let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                    
                    CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
                    let ciImage = CIImage(cvPixelBuffer: imageBuffer)
                    let context = CIContext()
                    if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                        CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
                        frameCount += 1
                    }
                    CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
                    
                    if frameCount > 240 { break } // Max 20-30 seconds of GIF
                } else {
                    break
                }
            }
            
            CGImageDestinationFinalize(destination)
            
            DispatchQueue.main.async {
                completion(gifURL)
            }
        }
    }
}
