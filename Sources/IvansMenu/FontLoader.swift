import AppKit
import CoreText

enum FontLoader {
    static func registerBundledFonts() {
        guard let dir = Bundle.module.url(forResource: "Fonts", withExtension: nil,
                                          subdirectory: "Resources") else { return }
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil)) ?? []
        for url in urls where ["ttf", "otf"].contains(url.pathExtension.lowercased()) {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
