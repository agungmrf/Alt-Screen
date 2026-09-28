import Foundation
import AppKit
import Vision

final class OCRManager {
    static let shared = OCRManager()
    private init() {}
    
    func recognizeText(from image: NSImage, completion: @escaping (String?) -> Void) {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let cgImage = bitmap.cgImage else {
            completion(nil)
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            let fullText = recognizedStrings.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            
            DispatchQueue.main.async {
                completion(fullText.isEmpty ? nil : fullText)
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
    
    func copyTextToClipboard(from image: NSImage, onFinished: ((Bool, Int) -> Void)? = nil) {
        recognizeText(from: image) { text in
            guard let text = text, !text.isEmpty else {
                onFinished?(false, 0)
                return
            }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            onFinished?(true, text.count)
        }
    }
}
