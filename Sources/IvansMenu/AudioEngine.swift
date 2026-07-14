import AppKit
import AVFoundation

@MainActor
final class AudioEngine {
    static let shared = AudioEngine()
    var soundEnabled = true
    var musicEnabled = false
    private var music: AVAudioPlayer?

    enum Cue: String { case hover, select, back }

    func play(_ cue: Cue) {
        guard soundEnabled,
              let url = Bundle.module.url(forResource: cue.rawValue,
                                          withExtension: "caf", subdirectory: "Resources/Sounds")
        else { return }
        let sound = NSSound(contentsOf: url, byReference: true)
        // The hover blip fires constantly, so keep it soft and unobtrusive.
        sound?.volume = (cue == .hover) ? 0.22 : 0.5
        sound?.play()
    }

    func startMusic() {
        guard musicEnabled, music == nil,
              let url = Bundle.module.url(forResource: "ambient", withExtension: "m4a",
                                          subdirectory: "Resources/Sounds")
        else { return }
        music = try? AVAudioPlayer(contentsOf: url)
        music?.numberOfLoops = -1; music?.volume = 0.4; music?.play()
    }

    func stopMusic() { music?.stop(); music = nil }
}
