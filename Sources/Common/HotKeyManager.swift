import Foundation
import AppKit
import Carbon

final class HotKeyManager {
    static let shared = HotKeyManager()
    
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var isHandlerInstalled: Bool = false
    
    private init() {}
    
    func setupHotKeys() {
        guard !isHandlerInstalled else { return }
        
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        let eventHandler: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let result = GetEventParameter(
                theEvent,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            if result == noErr {
                HotKeyManager.shared.handleHotKey(id: hotKeyID.id)
                return noErr
            }
            return OSStatus(eventNotHandledErr)
        }
        
        // 1. Install event handler on Event Dispatcher Target (system-wide)
        let statusDispatcher = InstallEventHandler(
            GetEventDispatcherTarget(),
            eventHandler,
            1,
            &eventSpec,
            nil,
            nil
        )
        
        // 2. Also install on Application Event Target as reliable backup
        let statusApp = InstallEventHandler(
            GetApplicationEventTarget(),
            eventHandler,
            1,
            &eventSpec,
            nil,
            nil
        )
        
        if statusDispatcher == noErr || statusApp == noErr {
            isHandlerInstalled = true
        } else {
            print("Failed to install Carbon event handlers: \(statusDispatcher), \(statusApp)")
        }
        
        let signature = OSType(1096041844) // 'ALTS'
        let mod = UInt32(cmdKey | shiftKey)
        
        // 1. ⌘ + ⇧ + 1 : Capture Area (kVK_ANSI_1 = 18)
        registerHotKey(id: 1, signature: signature, keyCode: 18, modifiers: mod, name: "⌘⇧1 Area Capture")
        
        // 2. ⌘ + ⇧ + 2 : Record Screen Options HUD (kVK_ANSI_2 = 19)
        registerHotKey(id: 2, signature: signature, keyCode: 19, modifiers: mod, name: "⌘⇧2 Record HUD")
        
        // 3. ⌘ + ⇧ + 3 : Capture Fullscreen (kVK_ANSI_3 = 20)
        registerHotKey(id: 3, signature: signature, keyCode: 20, modifiers: mod, name: "⌘⇧3 Fullscreen")
        
        // 4. ⌘ + ⇧ + 4 : Scrolling Capture (kVK_ANSI_4 = 21)
        registerHotKey(id: 4, signature: signature, keyCode: 21, modifiers: mod, name: "⌘⇧4 Scrolling Capture")
        
        // 5. ⌘ + ⇧ + C : OCR Text (kVK_ANSI_C = 8)
        registerHotKey(id: 5, signature: signature, keyCode: 8, modifiers: mod, name: "⌘⇧C OCR Text")
        
        // 6. ⌘ + ⇧ + Z : Capture History Carousel (kVK_ANSI_Z = 6)
        registerHotKey(id: 6, signature: signature, keyCode: 6, modifiers: mod, name: "⌘⇧Z History Carousel")
    }
    
    private func registerHotKey(id: UInt32, signature: OSType, keyCode: UInt32, modifiers: UInt32, name: String) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr, let ref = hotKeyRef {
            hotKeyRefs.append(ref)
            print("✓ Hotkey registered: \(name)")
        } else {
            // Try application target fallback
            let fallbackStatus = RegisterEventHotKey(
                keyCode,
                modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )
            if fallbackStatus == noErr, let ref = hotKeyRef {
                hotKeyRefs.append(ref)
                print("✓ Hotkey registered (app target): \(name)")
            } else {
                print("⚠️ Failed to register hotkey \(name): error \(status)/\(fallbackStatus)")
            }
        }
    }
    
    fileprivate func handleHotKey(id: UInt32) {
        DispatchQueue.main.async {
            switch id {
            case 1:
                CaptureManager.shared.startCapture(mode: .area)
            case 2:
                RecordingManager.shared.showRecordingHUD()
            case 3:
                CaptureManager.shared.startCapture(mode: .fullscreen)
            case 4:
                ScrollingCaptureManager.shared.startScrollingCapture()
            case 5:
                CaptureManager.shared.startCapture(mode: .textOCR)
            case 6:
                HistoryWindowController.shared.showHistory()
            default:
                break
            }
        }
    }
}
