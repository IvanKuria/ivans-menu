import Foundation

public final class ConfigStore {
    private let fileURL: URL
    private let fm = FileManager.default

    public init(fileURL: URL = ConfigStore.defaultFileURL) { self.fileURL = fileURL }

    public static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        return base.appendingPathComponent("Ivan's Menu", isDirectory: true)
                   .appendingPathComponent("config.json")
    }

    public func load() -> AppConfig {
        guard let data = try? Data(contentsOf: fileURL) else { return .makeDefault() }
        if let cfg = try? JSONDecoder().decode(AppConfig.self, from: data) { return cfg }
        backupCorrupt(data)
        return .makeDefault()
    }

    public func save(_ config: AppConfig) throws {
        try fm.createDirectory(at: fileURL.deletingLastPathComponent(),
                               withIntermediateDirectories: true)
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(config).write(to: fileURL, options: .atomic)
    }

    private func backupCorrupt(_ data: Data) {
        var n = 0
        var dst: URL
        repeat {
            dst = fileURL.deletingPathExtension()
                .appendingPathExtension("corrupt-\(n).json"); n += 1
        } while fm.fileExists(atPath: dst.path)
        try? data.write(to: dst)
    }
}
