import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem!
    let vpnManager = VPNManager()
    let configManager = ConfigManager()
    lazy var logWindowController = LogWindowController()

    private var logBuffer: [String] = []
    private var logFlushScheduled = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let image = NSImage(contentsOfFile: Bundle.main.path(forResource: "gear", ofType: "png") ?? "") {
            image.size = NSSize(width: 18, height: 18)
            statusItem.button?.image = image
        }

        // Батчим логи порциями раз в 100ms — не заваливаем main thread
        vpnManager.onLog = { [weak self] line in
            guard let self else { return }
            NSLog("[DIAG] onLog received: \(line.prefix(60))")
            self.logBuffer.append(line)
            if !self.logFlushScheduled {
                self.logFlushScheduled = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let lines = self.logBuffer.joined()
                    self.logBuffer.removeAll()
                    self.logFlushScheduled = false
                    NSLog("[DIAG] flushing \(lines.count) chars to appendLog")
                    self.logWindowController.appendLog(lines)
                }
            }
        }

        if let config = configManager.getCurrentConfig() {
            NSLog("Starting VPN with config: \(config.path)")
            vpnManager.startVPN(configPath: config.path)
        } else {
            NSLog("No config found")
        }

        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()

        let toggleTitle = vpnManager.isRunning ? "Stop VPN 🟢" : "Start VPN 🔴"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleVPN), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        let configMenuItem = NSMenuItem(title: "Config", action: nil, keyEquivalent: "")
        let configMenu = NSMenu()
        let configs = configManager.loadConfigs()

        for config in configs {
            let title = config.deletingPathExtension().lastPathComponent
            let item = NSMenuItem(title: title, action: #selector(selectConfig(_:)), keyEquivalent: "")
            item.representedObject = config
            item.target = self
            item.state = configManager.getCurrentConfig() == config ? .on : .off
            configMenu.addItem(item)
        }
        configMenuItem.submenu = configMenu
        menu.addItem(configMenuItem)

        let editItem = NSMenuItem(title: "Edit Config", action: #selector(editConfig), keyEquivalent: "")
        editItem.target = self
        menu.addItem(editItem)

        let logItem = NSMenuItem(title: "View Logs", action: #selector(viewLogs), keyEquivalent: "")
        logItem.target = self
        menu.addItem(logItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc func toggleVPN() {
        if vpnManager.isRunning {
            vpnManager.stopVPN()
        } else {
            guard let config = configManager.getCurrentConfig() else { return }
            vpnManager.startVPN(configPath: config.path)
        }
        rebuildMenu()
    }

    @objc func selectConfig(_ sender: NSMenuItem) {
        guard let config = sender.representedObject as? URL else { return }
        configManager.setCurrentConfig(config)
        logWindowController.clearLogs()
        if vpnManager.isRunning {
            vpnManager.restartVPN(configPath: config.path)
        } else {
            vpnManager.startVPN(configPath: config.path)
        }
        rebuildMenu()
    }

    @objc func editConfig() {
        guard let config = configManager.getCurrentConfig() else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "CotEditor", config.path]
        try? task.run()
    }

    @objc func viewLogs() {
        logWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quit() {
        vpnManager.stopVPN()
        NSApplication.shared.terminate(self)
    }
}