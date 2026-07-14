# Sounds

This directory holds the audio assets consumed by `AudioEngine` (see
`Sources/IvansMenu/AudioEngine.swift`). It ships empty — `AudioEngine` guards
every lookup with `Bundle.module.url(forResource:withExtension:subdirectory:)`,
so a missing file is a silent no-op and the app builds/runs fine without any
assets in place.

No Nintendo/Wii audio may be added here — original or royalty-free assets
only.

## Expected files

| File           | Format | Used by                     |
|----------------|--------|------------------------------|
| `hover.caf`    | CAF    | `AudioEngine.Cue.hover`       |
| `select.caf`   | CAF    | `AudioEngine.Cue.select`      |
| `back.caf`     | CAF    | `AudioEngine.Cue.back`        |
| `ambient.m4a`  | M4A    | `AudioEngine.startMusic()`   |

## Adding a cue

1. Record or source an original/royalty-free short sound effect.
2. Convert to CAF (short UI cues) with `afconvert`, e.g.:
   ```sh
   afconvert -f caff -d ima4 input.wav hover.caf
   ```
3. For the ambient loop, export/convert to AAC in an `.m4a` container:
   ```sh
   afconvert -f m4af -d aac input.wav ambient.m4a
   ```
4. Drop the resulting file into this directory using the exact name from the
   table above. `swift build` picks it up automatically via
   `resources: [.copy("Resources")]` in `Package.swift` — no code changes
   needed.
