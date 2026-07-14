import SwiftUI
import AppKit
import IvansMenuKit

struct OnboardingView: View {
    @ObservedObject var vm: ChannelStoreVM
    var onFinish: () -> Void
    @State private var selected: Set<String> = []
    @State private var website: String = ""

    private var apps: [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Applications"),
            includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "app" }.sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []
    }

    var body: some View {
        VStack {
            Text("Pick your channels").font(.title2.bold())
            ScrollView {
                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 4)) {
                    ForEach(apps, id: \.path) { url in
                        appCell(url)
                    }
                }.padding()
            }
            HStack {
                TextField("Add a website (https://…)", text: $website)
                Button("Finish") { finish() }
            }.padding()
        }.frame(width: 640, height: 560)
    }

    private func appCell(_ url: URL) -> some View {
        let on = selected.contains(url.path)
        return VStack {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable().frame(width: 48, height: 48)
            Text(url.deletingPathExtension().lastPathComponent).font(.caption).lineLimit(1)
        }
        .padding(6)
        .background(on ? Color.accentColor.opacity(0.3) : Color.clear)
        .cornerRadius(8)
        .onTapGesture { if on { selected.remove(url.path) } else { selected.insert(url.path) } }
    }

    private func finish() {
        var slot = 0
        func nextSlot() -> Int? {
            while slot < Theme.totalSlots {
                let s = slot; slot += 1
                if let i = vm.binding(forSlot: s), vm.config.channels[i].isEmpty { return i }
            }
            return nil
        }
        for path in selected.sorted() {
            guard let i = nextSlot() else { break }
            vm.config.channels[i].action = .app(path: path)
            vm.config.channels[i].title = URL(fileURLWithPath: path)
                .deletingPathExtension().lastPathComponent
        }
        if let url = URL(string: website), url.scheme != nil, let i = nextSlot() {
            vm.config.channels[i].action = .url(website)
        }
        vm.save()
        UserDefaults.standard.set(true, forKey: "didOnboard")
        onFinish()
    }
}
