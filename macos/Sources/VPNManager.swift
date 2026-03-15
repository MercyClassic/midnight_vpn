import Foundation

class VPNManager {
    var process: Process?
    var isRunning = false
    var onLog: ((String) -> Void)?
    
    func startVPN(configPath: String) {
        stopVPN()
        
        process = Process()
        guard let process = process else { return }
        
        let configURL = URL(fileURLWithPath: configPath)
        process.currentDirectoryURL = configURL.deletingLastPathComponent()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["/opt/homebrew/bin/sing-box", "run", "-c", configPath]
        process.environment = [
            "HOME": NSHomeDirectory(),
            "USER": NSUserName(),
            "PATH": "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            if let line = String(data: data, encoding: .utf8), !line.isEmpty {
                DispatchQueue.main.async {
                    self?.onLog?(line)
                }
            }
        }
        
        do {
            try process.run()
            isRunning = true
            NSLog("VPN started, PID: \(process.processIdentifier)")
        } catch {
            NSLog("Failed to start VPN: \(error)")
        }
    }
    
    func stopVPN() {
        guard let process = process else { return }
        process.terminate()
        let deadline = DispatchTime.now() + 5
        while process.isRunning && DispatchTime.now() < deadline {
            usleep(100_000)
        }
        if process.isRunning {
            kill(pid_t(process.processIdentifier), SIGKILL)
        }
        self.process = nil
        isRunning = false
    }
    
    func restartVPN(configPath: String) {
        stopVPN()
        startVPN(configPath: configPath)
    }
}