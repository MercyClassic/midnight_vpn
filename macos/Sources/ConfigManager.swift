import Foundation

class ConfigManager {

    let configDir: URL
    let defaultsKey = "currentConfig"

    init() {

        let home = FileManager.default.homeDirectoryForCurrentUser

        configDir = home
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent("Midnight")
            .appendingPathComponent("configs")

        createConfigDir()
    }

    func createConfigDir() {

        if !FileManager.default.fileExists(atPath: configDir.path) {

            try? FileManager.default.createDirectory(
                at: configDir,
                withIntermediateDirectories: true
            )

            print("Created config directory:", configDir.path)
        }
    }

    func loadConfigs() -> [URL] {

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: configDir,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return files
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    func setCurrentConfig(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: defaultsKey)
    }

    func getCurrentConfig() -> URL? {
        if let path = UserDefaults.standard.string(forKey: defaultsKey) {
            return URL(fileURLWithPath: path)
        }

        let configs = loadConfigs()
        if let first = configs.first {
            setCurrentConfig(first)
            return first
        }
        return nil
    }
}
