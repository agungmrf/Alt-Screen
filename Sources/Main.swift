import Foundation
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as menu bar accessory app
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize settings
        SettingsManager.shared.ensureSaveDirectoryExists()
        
        // Setup menu bar item
        MenuBarManager.shared.setupMenuBar()
        
        // Setup global hotkeys (⌘⇧1, ⌘⇧2, ⌘⇧3, ⌘⇧4, ⌘⇧C, ⌘⇧Z)
        HotKeyManager.shared.setupHotKeys()
        
        print("Alt. started successfully!")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Stay running in menu bar even when windows are closed
    }
}

@main
struct AltApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
