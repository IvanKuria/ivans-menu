import SwiftUI
import AppKit
import IvansMenuKit

struct SettingsView: View {
    @ObservedObject var vm: ChannelStoreVM

    var body: some View {
        TabView {
            channelsTab.tabItem { Text("Channels") }
            settingsTab.tabItem { Text("Settings") }
            aboutTab.tabItem { Text("About") }
        }
        .frame(width: 620, height: 520)
        .onDisappear { vm.save() }
    }

    private var channelsTab: some View {
        List(0..<Theme.totalSlots, id: \.self) { slot in
            if let idx = vm.binding(forSlot: slot) {
                ChannelRow(channel: $vm.config.channels[idx])
            }
        }
    }

    private var settingsTab: some View {
        Form {
            Toggle("Sound effects", isOn: $vm.config.settings.soundEnabled)
            Toggle("Ambient music", isOn: $vm.config.settings.musicEnabled)
            Toggle("Hide desktop icons", isOn: $vm.config.settings.hideDesktopIcons)
        }.padding()
    }

    private var aboutTab: some View {
        VStack(spacing: 12) {
            Text("Ivan's Menu").font(.title.bold())
            Text("An unofficial, fan-made tribute. Not affiliated with, endorsed by, or sponsored by Nintendo. All Nintendo trademarks belong to their respective owners.")
                .font(.footnote).multilineTextAlignment(.center).padding()
        }.padding()
    }
}

struct ChannelRow: View {
    @Binding var channel: Channel
    @State private var urlText: String = ""

    var body: some View {
        HStack {
            Text("Slot \(channel.slot)").frame(width: 60, alignment: .leading)
            Button("Choose App…") { pickApp() }
            TextField("https://…", text: $urlText, onCommit: {
                channel.action = .url(urlText)
            }).frame(width: 220)
            TextField("Title", text: Binding(
                get: { channel.title ?? "" },
                set: { channel.title = $0.isEmpty ? nil : $0 }))
        }
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
}
