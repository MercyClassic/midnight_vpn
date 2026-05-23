import Foundation

class VPNManager {
    // Всё состояние читается/пишется только на этой serial queue.
    private let queue = DispatchQueue(label: "com.personal.midnight.vpn")

    private var process: Process?
    private var outputPipe: Pipe?
    private var running = false

    var onLog: ((String) -> Void)?

    /// Потокобезопасное чтение состояния для UI (main thread).
    var isRunning: Bool {
        queue.sync { running }
    }

    func startVPN(configPath: String) {
        queue.async { [weak self] in
            self?.startLocked(configPath: configPath)
        }
    }

    func stopVPN() {
        queue.async { [weak self] in
            self?.stopLocked()
        }
    }

    func restartVPN(configPath: String) {
        queue.async { [weak self] in
            self?.stopLocked()
            self?.startLocked(configPath: configPath)
        }
    }

    // MARK: - Private (всегда на queue)

    private func startLocked(configPath: String) {
        // На случай если поверх уже запущенного — гасим старый.
        if process != nil {
            stopLocked()
        }

        let process = Process()
        let pipe = Pipe()
        self.process = process
        self.outputPipe = pipe

        let configURL = URL(fileURLWithPath: configPath)
        process.currentDirectoryURL = configURL.deletingLastPathComponent()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["/opt/homebrew/bin/sing-box", "run", "-c", configPath]
        process.environment = [
            "HOME": NSHomeDirectory(),
            "USER": NSUserName(),
            "PATH": "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
        ]

        process.standardOutput = pipe
        process.standardError = pipe

        // ВАЖНО: waitForDataInBackgroundAndNotify постит нотификацию в RunLoop
        // того потока, где он вызван. У GCD serial queue нет RunLoop, поэтому
        // регистрацию обсервера и старт ожидания делаем на main thread.
        let handle = pipe.fileHandleForReading
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            NSLog("[DIAG] registering observer + waitForData on main")
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.dataAvailable(_:)),
                name: .NSFileHandleDataAvailable,
                object: handle
            )
            handle.waitForDataInBackgroundAndNotify()
        }

        process.terminationHandler = { [weak self] p in
            guard let self else { return }
            self.queue.async {
                // Игнорируем, если это уже не текущий процесс (перезапуск).
                guard self.process === p else { return }
                NSLog("sing-box terminated, exit code: \(p.terminationStatus)")
                self.cleanupLocked()
            }
        }

        do {
            try process.run()
            running = true
            NSLog("VPN started, PID: \(process.processIdentifier)")
        } catch {
            NSLog("Failed to start VPN: \(error)")
            cleanupLocked()
        }
    }

    private func stopLocked() {
        guard let process = process else { return }

        // Снимаем handler заранее, чтобы он не сработал во время остановки.
        process.terminationHandler = nil
        detachPipeObserver()

        if process.isRunning {
            process.terminate()
            let deadline = Date().addingTimeInterval(5)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.1)
            }
            if process.isRunning {
                kill(pid_t(process.processIdentifier), SIGKILL)
            }
        }

        self.process = nil
        self.outputPipe = nil
        running = false
    }

    /// Вызывается когда процесс умер сам (terminationHandler).
    private func cleanupLocked() {
        detachPipeObserver()
        process = nil
        outputPipe = nil
        running = false
    }

    private func detachPipeObserver() {
        if let handle = outputPipe?.fileHandleForReading {
            NotificationCenter.default.removeObserver(
                self,
                name: .NSFileHandleDataAvailable,
                object: handle
            )
        }
    }

    @objc private func dataAvailable(_ notification: Notification) {
        guard let handle = notification.object as? FileHandle else { return }
        let data = handle.availableData
        NSLog("[DIAG] dataAvailable fired, \(data.count) bytes")

        if let line = String(data: data, encoding: .utf8), !line.isEmpty {
            onLog?(line)
        }

        // Продолжаем слушать только если это актуальный pipe и процесс жив.
        // Состояние читаем безопасно с serial queue, сам wait — на main RunLoop.
        let stillValid: Bool = queue.sync {
            outputPipe?.fileHandleForReading === handle && process?.isRunning == true
        }

        if stillValid && !data.isEmpty {
            handle.waitForDataInBackgroundAndNotify()
        }
    }

    deinit {
        detachPipeObserver()
    }
}