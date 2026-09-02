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

    struct ConfigGroup {
        let folderName: String?
        let displayName: String?
        let configs: [URL]
    }

    private func sortedByName(_ urls: [URL]) -> [URL] {
        urls.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    private func parseFolderName(_ name: String) -> (displayName: String, order: Int?) {
        if let dotRange = name.range(of: ".", options: .backwards) {
            let suffix = name[dotRange.upperBound...]
            if !suffix.isEmpty, let number = Int(suffix) {
                return (String(name[..<dotRange.lowerBound]), number)
            }
        }
        return (name, nil)
    }

    func loadConfigGroups() -> [ConfigGroup] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: configDir,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return []
        }

        var rootConfigs: [URL] = []
        var folders: [(name: String, displayName: String, order: Int?, configs: [URL])] = []

        for entry in entries {
            var isDir: ObjCBool = false
            fm.fileExists(atPath: entry.path, isDirectory: &isDir)

            if isDir.boolValue {
                guard let subEntries = try? fm.contentsOfDirectory(at: entry, includingPropertiesForKeys: nil) else {
                    continue
                }
                let jsonFiles = sortedByName(subEntries.filter { $0.pathExtension == "json" })
                if !jsonFiles.isEmpty {
                    let parsed = parseFolderName(entry.lastPathComponent)
                    folders.append((name: entry.lastPathComponent, displayName: parsed.displayName, order: parsed.order, configs: jsonFiles))
                }
            } else if entry.pathExtension == "json" {
                rootConfigs.append(entry)
            }
        }

        folders.sort { a, b in
            switch (a.order, b.order) {
            case let (oa?, ob?):
                if oa != ob { return oa < ob }
                return a.displayName.localizedStandardCompare(b.displayName) == .orderedAscending
            case (nil, nil):
                return a.displayName.localizedStandardCompare(b.displayName) == .orderedAscending
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            }
        }

        var groups: [ConfigGroup] = []
        if !rootConfigs.isEmpty {
            groups.append(ConfigGroup(folderName: nil, displayName: nil, configs: sortedByName(rootConfigs)))
        }
        for folder in folders {
            groups.append(ConfigGroup(folderName: folder.name, displayName: folder.displayName, configs: folder.configs))
        }
        return groups
    }

    func loadConfigs() -> [URL] {
        loadConfigGroups().flatMap { $0.configs }
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
