import Foundation

/// Downloads a Wii theme pack (art assets) from a third-party host into the
/// user's writable theme folder. The app's public repo never ships or hosts
/// these files — the download URL points somewhere the user configures. Ships
/// an original-drawn fallback, so this is purely an opt-in fidelity upgrade.
///
/// Manifest format (JSON):
/// ```
/// { "files": { "background.png": "https://host/background.png",
///              "wii_button.png": "https://host/wii_button.png", ... } }
/// ```
enum ThemePackInstaller {

    /// The pack source. Point this at wherever the theme pack is hosted.
    /// (Left as a placeholder on purpose — set it to your pack's manifest URL.)
    static let defaultManifestURL = URL(string:
        "https://raw.githubusercontent.com/IvanKuria/ivans-menu-wii-pack/main/manifest.json")!

    struct Manifest: Decodable { let files: [String: String] }

    /// A safe theme filename: no path separators, no `..`, image extension only.
    private static func isSafeName(_ name: String) -> Bool {
        guard !name.contains("/"), !name.contains("\\"),
              !name.contains(".."), !name.contains("\0"), name.count <= 64 else { return false }
        let ext = (name as NSString).pathExtension.lowercased()
        guard ["png", "jpg", "jpeg", "gif"].contains(ext) else { return false }
        return name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" || $0 == "." }
    }

    enum InstallError: Error, CustomStringConvertible {
        case badManifest, noFiles, network(String)
        var description: String {
            switch self {
            case .badManifest: return "The theme pack manifest could not be read."
            case .noFiles: return "The theme pack manifest listed no files."
            case .network(let m): return m
            }
        }
    }

    /// Thread-safe counter for concurrent downloads.
    private final class Counter: @unchecked Sendable {
        private let lock = NSLock(); private var n = 0
        func bump() { lock.lock(); n += 1; lock.unlock() }
        var value: Int { lock.lock(); defer { lock.unlock() }; return n }
    }

    /// Downloads the manifest and every file it lists into the user theme dir.
    /// `progress` is called on a background queue with human-readable status.
    static func install(from manifestURL: URL = defaultManifestURL,
                        progress: @escaping @Sendable (String) -> Void = { _ in },
                        completion: @escaping @Sendable (Result<Int, Error>) -> Void) {
        let session = URLSession(configuration: .ephemeral)
        let dir = AssetLibrary.userThemeDir
        progress("Fetching theme pack…")
        session.dataTask(with: manifestURL) { data, _, error in
            if let error { return completion(.failure(InstallError.network(error.localizedDescription))) }
            guard let data,
                  let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else {
                return completion(.failure(InstallError.badManifest))
            }
            guard !manifest.files.isEmpty else { return completion(.failure(InstallError.noFiles)) }

            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            let dirBase = dir.standardizedFileURL.resolvingSymlinksInPath().path + "/"
            let group = DispatchGroup()
            let installed = Counter()
            for (name, urlString) in manifest.files {
                // Reject unsafe filenames (path traversal) and non-https sources.
                guard isSafeName(name),
                      let url = URL(string: urlString), url.scheme?.lowercased() == "https"
                else { continue }
                let dest = dir.appendingPathComponent(name)
                guard dest.standardizedFileURL.resolvingSymlinksInPath().path
                        .hasPrefix(dirBase) else { continue }
                group.enter()
                progress("Downloading \(name)…")
                session.dataTask(with: url) { fileData, _, _ in
                    defer { group.leave() }
                    guard let fileData else { return }
                    if (try? fileData.write(to: dest, options: .atomic)) != nil { installed.bump() }
                }.resume()
            }
            group.notify(queue: .global()) {
                installed.value > 0 ? completion(.success(installed.value))
                                    : completion(.failure(InstallError.network("No files could be downloaded.")))
            }
        }.resume()
    }

    /// Remove the installed theme (revert to the original-drawn look).
    static func uninstall() {
        try? FileManager.default.removeItem(at: AssetLibrary.userThemeDir)
    }
}
