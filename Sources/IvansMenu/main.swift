import AppKit

// Design/screenshot mode: render to PNG and exit, without the desktop window.
if RenderHarness.runIfRequested() { /* exits inside */ }

// Headless theme-pack install: `IvansMenu --install-theme [manifestURL]`.
// Downloads the pack into the user theme dir and exits. Used to verify the
// pack end to end and to let users install without opening Settings.
if let idx = CommandLine.arguments.firstIndex(of: "--install-theme") {
    let sema = DispatchSemaphore(value: 0)
    // Write-then-read is serialized by the semaphore, so this box is race-free.
    final class ExitCode: @unchecked Sendable { var value: Int32 = 0 }
    let code = ExitCode()
    let done: @Sendable (Result<Int, Error>) -> Void = { result in
        switch result {
        case .success(let n):
            FileHandle.standardError.write(Data("installed \(n) files to \(AssetLibrary.userThemeDir.path)\n".utf8))
        case .failure(let e):
            FileHandle.standardError.write(Data("install failed: \(e)\n".utf8)); code.value = 2
        }
        sema.signal()
    }
    let progress: @Sendable (String) -> Void = { msg in
        FileHandle.standardError.write(Data("\(msg)\n".utf8))
    }
    if idx + 1 < CommandLine.arguments.count,
       let url = URL(string: CommandLine.arguments[idx + 1]) {
        ThemePackInstaller.install(from: url, progress: progress, completion: done)
    } else {
        ThemePackInstaller.install(progress: progress, completion: done)
    }
    sema.wait()
    exit(code.value)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
