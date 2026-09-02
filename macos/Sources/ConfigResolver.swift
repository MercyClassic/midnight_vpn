import Foundation

enum ConfigResolverError: LocalizedError {
    case sourceFileMissing(String)
    case invalidJSON(String)
    case invalidRoot(String)
    case keyNotFound(String, String)
    case refTooDeep(String)

    var errorDescription: String? {
        switch self {
        case .sourceFileMissing(let name):
            return "Source file not found: \(name)"
        case .invalidJSON(let name):
            return "Invalid JSON: \(name)"
        case .invalidRoot(let name):
            return "\(name): root must be a JSON object"
        case .keyNotFound(let key, let file):
            return "Key \"\(key)\" not found in \(file)"
        case .refTooDeep(let ref):
            return "$ref chain too deep (possible circular reference): \(ref)"
        }
    }
}

final class ConfigResolver {

    let sourcesDir: URL
    let buildDir: URL

    init(baseDir: URL) {
        sourcesDir = baseDir.appendingPathComponent("sources")
        buildDir = baseDir.appendingPathComponent("build")
        try? FileManager.default.createDirectory(at: sourcesDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)
    }

    func resolve(configURL: URL) throws -> URL {
        let raw = try Data(contentsOf: configURL)
        guard let rawJson = try JSONSerialization.jsonObject(with: raw) as? [String: Any] else {
            throw ConfigResolverError.invalidRoot(configURL.lastPathComponent)
        }
        let json = try resolveRefs(rawJson) as! [String: Any]

        guard let extendsList = json["$extends"] as? [String], !extendsList.isEmpty else {
            return configURL
        }

        var merged: [String: Any] = [:]
        for entry in extendsList {
            let fragment = try loadFragment(entry: entry)
            merged = ConfigResolver.merge(base: merged, overlay: fragment)
        }

        var own = json
        own.removeValue(forKey: "$extends")
        merged = ConfigResolver.merge(base: merged, overlay: own)

        let outURL = buildDir.appendingPathComponent(
            configURL.deletingPathExtension().lastPathComponent + ".json"
        )
        let data = try JSONSerialization.data(withJSONObject: merged, options: [.prettyPrinted, .sortedKeys])
        guard var text = String(data: data, encoding: .utf8) else {
            throw ConfigResolverError.invalidRoot(configURL.lastPathComponent)
        }
        text = text.replacingOccurrences(of: "\\/", with: "/")
        let cleanedData = Data(text.utf8)
        try cleanedData.write(to: outURL, options: .atomic)
        return outURL
    }

    private func loadFragment(entry: String) throws -> [String: Any] {
        let parts = entry.split(separator: "#", maxSplits: 1).map(String.init)
        let fileName = parts[0]
        let full = try loadJSONObject(fileName: fileName)

        guard parts.count == 2 else {
            return full
        }

        let keyParts = parts[1].split(separator: ":", maxSplits: 1).map(String.init)
        let sourceKey = keyParts[0]
        let targetKey = keyParts.count == 2 ? keyParts[1] : sourceKey

        guard let value = full[sourceKey] else {
            throw ConfigResolverError.keyNotFound(sourceKey, fileName)
        }

        return [targetKey: value]
    }

    private func loadJSONObject(fileName: String, depth: Int = 0) throws -> [String: Any] {
        let url = sourcesDir.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else {
            throw ConfigResolverError.sourceFileMissing(fileName)
        }
        guard let raw = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw ConfigResolverError.invalidJSON(fileName)
        }
        return (try resolveRefs(raw, depth: depth) as? [String: Any]) ?? raw
    }

    private static let maxRefDepth = 20

    private func resolveRefs(_ value: Any, depth: Int = 0) throws -> Any {
        if let str = value as? String, str.hasPrefix("$ref:") {
            guard depth < Self.maxRefDepth else {
                throw ConfigResolverError.refTooDeep(str)
            }
            let ref = String(str.dropFirst(5))
            let parts = ref.split(separator: "#", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return value }
            let full = try loadJSONObject(fileName: parts[0], depth: depth + 1)
            guard let resolved = full[parts[1]] else {
                throw ConfigResolverError.keyNotFound(parts[1], parts[0])
            }
            return resolved
        }
        if let dict = value as? [String: Any] {
            var result: [String: Any] = [:]
            for (k, v) in dict { result[k] = try resolveRefs(v, depth: depth) }
            return result
        }
        if let arr = value as? [Any] {
            return try arr.map { try resolveRefs($0, depth: depth) }
        }
        return value
    }

    private static let taggedArrayKeys: Set<String> = ["inbounds", "outbounds", "endpoints"]
    private static let shallowObjectKeys: Set<String> = ["dns", "route", "experimental", "log"]

    static func merge(base: [String: Any], overlay: [String: Any]) -> [String: Any] {
        var result = base

        for (key, overlayValue) in overlay {
            guard let baseValue = result[key] else {
                result[key] = overlayValue
                continue
            }

            if taggedArrayKeys.contains(key),
               let baseArr = baseValue as? [[String: Any]],
               let overlayArr = overlayValue as? [[String: Any]] {
                result[key] = mergeTaggedArrays(base: baseArr, overlay: overlayArr)

            } else if shallowObjectKeys.contains(key),
                      let baseObj = baseValue as? [String: Any],
                      let overlayObj = overlayValue as? [String: Any] {
                result[key] = mergeShallowObject(base: baseObj, overlay: overlayObj)

            } else {
                result[key] = overlayValue
            }
        }

        return result
    }

    private static func mergeShallowObject(base: [String: Any], overlay: [String: Any]) -> [String: Any] {
        var result = base
        for (key, value) in overlay {
            if (key == "rule_set" || key == "servers"),
               let baseArr = base[key] as? [[String: Any]],
               let overlayArr = value as? [[String: Any]] {
                result[key] = mergeTaggedArrays(base: baseArr, overlay: overlayArr)

            } else if key == "rules", let overlayArr = value as? [[String: Any]] {
                let baseArr = (base[key] as? [[String: Any]]) ?? []
                result[key] = baseArr + overlayArr

            } else {
                result[key] = value
            }
        }
        return result
    }

    private static func mergeTaggedArrays(base: [[String: Any]], overlay: [[String: Any]]) -> [[String: Any]] {
        var order: [String] = []
        var byTag: [String: [String: Any]] = [:]
        var untagged: [[String: Any]] = []

        func ingest(_ arr: [[String: Any]]) {
            for item in arr {
                if let tag = item["tag"] as? String {
                    if byTag[tag] == nil { order.append(tag) }
                    byTag[tag] = item
                } else {
                    untagged.append(item)
                }
            }
        }

        ingest(base)
        ingest(overlay)

        return order.compactMap { byTag[$0] } + untagged
    }
}
