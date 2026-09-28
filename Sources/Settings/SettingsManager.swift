import Foundation
import AppKit

final class SettingsManager {
    static let shared = SettingsManager()
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let saveDirectory = "ALT_SaveDirectory"
        static let autoCopyToClipboard = "ALT_AutoCopyToClipboard"
        static let showQuickAccess = "ALT_ShowQuickAccess"
        static let quickAccessDuration = "ALT_QuickAccessDuration"
        static let playShutterSound = "ALT_PlayShutterSound"
        static let openEditorDirectly = "ALT_OpenEditorDirectly"
        static let licenseKey = "ALT_LicenseKey"
        static let isLicensed = "ALT_IsLicensed"
        static let exportFormat = "ALT_ExportFormat"
        static let filenamePrefix = "ALT_FilenamePrefix"
    }
    
    private init() {
        registerDefaults()
        ensureSaveDirectoryExists()
    }
    
    private func registerDefaults() {
        let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
        let defaultFolder = picturesURL?.appendingPathComponent("Screenshots").path ?? (NSHomeDirectory() + "/Pictures/Screenshots")
        
        defaults.register(defaults: [
            Keys.saveDirectory: defaultFolder,
            Keys.autoCopyToClipboard: true,
            Keys.showQuickAccess: true,
            Keys.quickAccessDuration: 8.0,
            Keys.playShutterSound: true,
            Keys.openEditorDirectly: false,
            Keys.licenseKey: "ALT-PRO-LIFETIME-COMMERCIAL",
            Keys.isLicensed: true,
            Keys.exportFormat: ExportImageFormat.png.rawValue,
            Keys.filenamePrefix: "Alt."
        ])
    }
    
    var exportFormat: ExportImageFormat {
        get {
            let str = defaults.string(forKey: Keys.exportFormat) ?? ""
            return ExportImageFormat(rawValue: str) ?? .png
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.exportFormat) }
    }
    
    var filenamePrefix: String {
        get { defaults.string(forKey: Keys.filenamePrefix) ?? "Alt." }
        set { defaults.set(newValue, forKey: Keys.filenamePrefix) }
    }
    
    var saveDirectory: String {
        get { defaults.string(forKey: Keys.saveDirectory) ?? (NSHomeDirectory() + "/Pictures/Screenshots") }
        set {
            defaults.set(newValue, forKey: Keys.saveDirectory)
            ensureSaveDirectoryExists()
        }
    }
    
    var autoCopyToClipboard: Bool {
        get { defaults.bool(forKey: Keys.autoCopyToClipboard) }
        set { defaults.set(newValue, forKey: Keys.autoCopyToClipboard) }
    }
    
    var showQuickAccess: Bool {
        get { defaults.bool(forKey: Keys.showQuickAccess) }
        set { defaults.set(newValue, forKey: Keys.showQuickAccess) }
    }
    
    var quickAccessDuration: Double {
        get {
            let val = defaults.double(forKey: Keys.quickAccessDuration)
            return val > 0 ? val : 8.0
        }
        set { defaults.set(newValue, forKey: Keys.quickAccessDuration) }
    }
    
    var playShutterSound: Bool {
        get { defaults.bool(forKey: Keys.playShutterSound) }
        set { defaults.set(newValue, forKey: Keys.playShutterSound) }
    }
    
    var openEditorDirectly: Bool {
        get { defaults.bool(forKey: Keys.openEditorDirectly) }
        set { defaults.set(newValue, forKey: Keys.openEditorDirectly) }
    }
    
    func ensureSaveDirectoryExists() {
        let path = saveDirectory
        if !FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    func generateTimestampedFilename(prefix: String? = nil) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let timestamp = formatter.string(from: Date())
        let pref = prefix ?? filenamePrefix
        let ext = exportFormat.fileExtension
        return "\(pref) \(timestamp).\(ext)"
    }
    
    func generateSaveURL(prefix: String? = nil) -> URL {
        ensureSaveDirectoryExists()
        let filename = generateTimestampedFilename(prefix: prefix)
        return URL(fileURLWithPath: saveDirectory).appendingPathComponent(filename)
    }
}

enum ExportImageFormat: String, CaseIterable {
    case png = "PNG (Lossless)"
    case jpg = "JPEG (Compressed)"
    case webp = "WebP (Modern Web)"
    
    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpg: return "jpg"
        case .webp: return "webp"
        }
    }
}
