import SwiftUI
import AppKit
import UniformTypeIdentifiers
import IvansMenuKit

struct SettingsView: View {
    @ObservedObject var vm: ChannelStoreVM

    var body: some View {
        TabView {
            settingsTab.tabItem { Text("Settings") }
            aboutTab.tabItem { Text("About") }
        }
        .frame(width: 520, height: 420)
        .wiiBackground()
        .onDisappear { vm.save() }
    }

    private var settingsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Set up channels by right-clicking any tile on the menu.")
                .font(WiiFont.body(13))
                .foregroundColor(.black.opacity(0.55))
                .padding(.bottom, 4)
            wiiToggle("Sound effects", isOn: $vm.config.settings.soundEnabled)
            wiiToggle("Ambient music", isOn: $vm.config.settings.musicEnabled)
            wiiToggle("Hide desktop icons", isOn: $vm.config.settings.hideDesktopIcons)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func wiiToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(WiiFont.body(14))
                .foregroundColor(.black.opacity(0.8))
        }
        .toggleStyle(.switch)
        .tint(.wiiAccent)
        .padding(12)
        .wiiCard()
    }

    private var aboutTab: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("Ivan's Menu")
                .font(WiiFont.title(26))
                .foregroundColor(.black.opacity(0.8))
            Text("An unofficial, fan-made tribute. Not affiliated with, endorsed by, or sponsored by Nintendo. All Nintendo trademarks belong to their respective owners.")
                .font(WiiFont.body(12))
                .foregroundColor(.black.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ChannelRow: View {
    @Binding var channel: Channel
    @State private var urlText: String = ""

    var body: some View {
        HStack(spacing: 10) {
            Text("Slot \(channel.slot)")
                .font(WiiFont.label())
                .foregroundColor(.black.opacity(0.6))
                .frame(width: 56, alignment: .leading)
            Button("Choose App…") { pickApp() }
                .buttonStyle(.wii)
            TextField("https://…", text: $urlText, onCommit: {
                channel.action = .url(urlText)
            })
            .wiiField()
            .frame(width: 160)
            Button(thumbnailLabel) { pickThumbnail() }
                .buttonStyle(.wii)
            if case .custom = channel.banner {
                Button("✕") { channel.banner = .generated }
                    .buttonStyle(.wii)
                    .help("Remove custom thumbnail")
            }
            TextField("Title", text: Binding(
                get: { channel.title ?? "" },
                set: { channel.title = $0.isEmpty ? nil : $0 }))
            .wiiField()
        }
        .padding(10)
        .wiiCard()
    }

    private var thumbnailLabel: String {
        if case .custom = channel.banner { return "Thumbnail ✓" }
        return "Thumbnail…"
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        if panel.runModal() == .OK, let url = panel.url {
            channel.action = .app(path: url.path)
            if channel.title == nil {
                channel.title = url.deletingPathExtension().lastPathComponent
            }
        }
    }

    /// Pick a custom channel thumbnail — any image, including animated GIFs.
    private func pickThumbnail() {
        let panel = NSOpenPanel()
        panel.message = "Choose a channel thumbnail (PNG, JPEG, or animated GIF)"
        panel.allowedContentTypes = [.image, .gif, .png, .jpeg]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            channel.banner = .custom(path: url.path)
        }
    }
}
