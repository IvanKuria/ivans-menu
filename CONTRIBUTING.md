# Contributing to Ivan's Menu

Thanks for your interest in improving Ivan's Menu. This guide covers how to set up, how the code is organized, and what a good contribution looks like.

## Development Setup

You need macOS 14.0 or later, the Xcode Command Line Tools, and Swift 6.2. Full Xcode is not required.

```bash
xcode-select --install     # if you do not already have the tools
git clone https://github.com/IvanKuria/ivans-menu.git
cd ivans-menu
swift build                # compile (debug)
swift test                 # run the IvansMenuKit test suite
./scripts/bundle.sh        # assemble IvansMenu.app
```

To preview the interface without touching your real desktop, render it to a PNG:

```bash
swift build && .build/debug/IvansMenu --render out.png 1710 1112
```

## Codebase Organization

The project is a Swift Package with two targets:

- **IvansMenuKit** holds the pure logic with no AppKit dependency: the config model, channel codec, banner planning, and clock formatting. Everything here is unit-tested.
- **IvansMenu** is the AppKit and SwiftUI executable. It draws the desktop window, wires up the launcher, and owns everything visual.

Inside the app target, the pieces that get touched most often are the desktop window and menu-bar wiring (`AppDelegate`), the channel grid and animation (`WiiMenuView`), the pillow tiles (`ChannelTileView`), the clock and buttons (`BottomBarView`), procedural drawing helpers (`WiiControls`), the asset lookup and caching (`AssetLibrary`), and the runtime theme download (`ThemePackInstaller`).

## Key Architectural Patterns

- **Kit stays AppKit-free.** Anything that can be expressed without AppKit belongs in IvansMenuKit so it can be tested in isolation. Keep that boundary clean.
- **Swift 6 concurrency throughout.** The app target is annotated with `@MainActor`, and background work returns to the main actor before touching UI. Prefer the compiler-checked path over silencing warnings.
- **Desktop-level window.** The menu is an `NSWindow` placed just above the desktop icon layer, non-key and joining all Spaces, so it reads as a wallpaper rather than an app window.
- **Layered asset lookup.** `AssetLibrary` resolves each asset in order: the user theme directory first, then the bundled copy, then a procedural fallback drawn in code. New art should slot into this chain, not bypass it.
- **No assets in the repo or the DMG.** The real Wii art is never committed and never shipped inside a build. The app fetches a theme pack at runtime, so keep any asset work behind that mechanism.
- **Verify visuals by rendering, not eyeballing.** Use `--render` at `1710x1112` and measure the region you changed. This project treats "looks about right" as unverified.

## Code Quality Standards

- Match the style of the surrounding code: naming, comment density, and idiom.
- Prefer modern AppKit and SwiftUI idioms over deprecated ones.
- Do not add third-party dependencies without discussing it in an issue first.
- Follow Swift concurrency rules rather than working around them with unchecked escapes, unless there is a clearly documented reason.
- Keep prose in the repo free of em dashes, matching the existing docs.
- When you change the interface, include a before-and-after render in your pull request.

## Contribution Process

1. Open an issue describing the change before large work, so we can agree on the approach.
2. Keep each pull request focused on a single issue.
3. Make sure `swift build` and `swift test` both pass.
4. For visual changes, attach a render at `1710x1112` showing the result.
5. Describe what you changed and how you verified it.

### AI-assisted contributions

AI-assisted contributions are welcome. If a change came out of a prompt, share the prompt alongside the code so others can reproduce and build on your approach. Treat the generated output the same as any other code: read it, test it, and verify it against the standards above before opening a pull request.
