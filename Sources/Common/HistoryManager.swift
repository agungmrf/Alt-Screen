import Foundation
import AppKit

enum HistoryItemType: String, CaseIterable {
    case all = "All"
    case screenshot = "Screenshots"
    case video = "Videos"
    case gif = "GIFs"
}

struct HistoryItem: Identifiable {
    let id: UUID
    let image: NSImage
    let fileURL: URL
    let timestamp: Date
    let dimensions: CGSize
    
    var itemType: HistoryItemType {
        let ext = fileURL.pathExtension.lowercased()
        if ext == "gif" { return .gif }
        if ext == "mov" || ext == "mp4" { return .video }
        return .screenshot
    }
}

final class HistoryManager {
    static let shared = HistoryManager()
    
    private(set) var items: [HistoryItem] = []
    
    private init() {}
    
    func addItem(image: NSImage, fileURL: URL) {
        let item = HistoryItem(
            id: UUID(),
            image: image,
            fileURL: fileURL,
            timestamp: Date(),
            dimensions: image.size
        )
        items.insert(item, at: 0) // Most recent first
        if items.count > 30 {
            _ = items.popLast()
        }
    }
    
    func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
    }
    
    func clearHistory() {
        items.removeAll()
    }
}
