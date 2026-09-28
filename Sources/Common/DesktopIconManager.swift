import Foundation

final class DesktopIconManager {
    static let shared = DesktopIconManager()
    
    private(set) var areIconsHidden: Bool = false
    
    private init() {
        checkCurrentState()
    }
    
    func checkCurrentState() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["read", "com.apple.finder", "CreateDesktop"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        try? task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
            areIconsHidden = (output == "0" || output.lowercased() == "false")
        } else {
            areIconsHidden = false
        }
    }
    
    func toggleDesktopIcons(completion: @escaping (Bool) -> Void) {
        let shouldHide = !areIconsHidden
        let valString = shouldHide ? "false" : "true"
        
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            task.arguments = ["write", "com.apple.finder", "CreateDesktop", "-bool", valString]
            
            try? task.run()
            task.waitUntilExit()
            
            // Restart Finder quietly
            let killTask = Process()
            killTask.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            killTask.arguments = ["Finder"]
            try? killTask.run()
            killTask.waitUntilExit()
            
            DispatchQueue.main.async {
                self.areIconsHidden = shouldHide
                completion(self.areIconsHidden)
            }
        }
    }
}
