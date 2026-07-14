import AppKit

// Design/screenshot mode: render to PNG and exit, without the desktop window.
if RenderHarness.runIfRequested() { /* exits inside */ }

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
