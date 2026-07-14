import Foundation

enum DesktopIcons {
    static func setHidden(_ hidden: Bool) {
        run("/usr/bin/defaults",
            ["write", "com.apple.finder", "CreateDesktop", "-bool", hidden ? "false" : "true"])
        run("/usr/bin/killall", ["Finder"])
    }

    private static func run(_ path: String, _ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        try? p.run(); p.waitUntilExit()
    }
}
