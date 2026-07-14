# Ivan's Menu

Turn your Mac desktop into a faithful, interactive Wii-style channel menu.
Each channel launches a real app, website, file, or folder.

> **Disclaimer:** Ivan's Menu is an unofficial, fan-made tribute. Not
> affiliated with, endorsed by, or sponsored by Nintendo. All Nintendo
> trademarks belong to their respective owners. It ships **no** Nintendo
> assets — all art, sounds, and code are original; bundled fonts are OFL.

## Build from source

```bash
swift build            # debug
swift test             # run the Kit test suite
./scripts/bundle.sh    # assemble IvansMenu.app (set DEVELOPER_ID to sign)
open IvansMenu.app
```

## Usage
- First launch runs an onboarding wizard to pick your channels.
- The round **Wii** button (or the 🎮 menu-bar item) opens Settings.
- **⌥Space** peeks the real desktop.
- Quit from the 🎮 menu-bar item (restores your desktop icons).

## Troubleshooting
If the app quits unexpectedly and your desktop icons are missing, either:
- Click the 🎮 menu-bar item → **Restore Desktop Icons**, or
- Run in Terminal: `defaults write com.apple.finder CreateDesktop true; killall Finder`

## Credits
- Fonts: Asap, M PLUS Rounded 1c (SIL Open Font License).
- Inspired by the 2006 Wii Menu; all assets re-created originally.
