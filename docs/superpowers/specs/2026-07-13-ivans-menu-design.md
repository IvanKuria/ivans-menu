# Ivan's Menu — Design Specification

**Date:** 2026-07-13
**Status:** Approved design, pre-implementation
**Author:** Ivan Kuria (with Claude)

---

## 1. Overview

**Ivan's Menu** is a native macOS app that replaces the desktop with a faithful,
interactive recreation of the original 2006 Nintendo **Wii Menu**. Each channel
tile is bound to a real macOS action — launch an app, open a URL, reveal a file,
or open a folder — so the Wii menu becomes a fully functional, nostalgic app
launcher that *is* your desktop.

It runs as an invisible **agent app** (`LSUIElement`, no Dock icon) and draws an
immersive fullscreen window at the desktop window level on every display. Finder's
desktop icons are hidden while it's active for full immersion, and restored on
quit. A tiny menu-bar status icon exists purely as a reliable escape hatch.

The project is open-source (MIT), ships only original assets, and carries a clear
"unofficial fan tribute, not affiliated with Nintendo" disclaimer.

### Non-goals
- Not a Wii U menu recreation (that's a distinct, flatter aesthetic).
- Not an emulator or ROM launcher — it launches ordinary Mac apps/URLs/files.
- No Nintendo trademarks, logos, fonts, sounds, or ripped textures shipped.

---

## 2. Aesthetic target — Faithful Wii Menu (2006)

Backed by research against faithful open-source recreations (values are close
estimates unless marked documented; verify against high-res screenshots during
implementation).

| Element | Spec |
|---|---|
| **Grid** | 4 columns × 3 rows = 12 tiles/page; **4 pages = 48 slots** |
| **Tile shape** | Rounded rectangle, aspect ~**1.82:1** (wider than tall), thin light bezel + soft drop shadow |
| **Tile corner radius** | ~8–12 px @1× (~1–1.5% of tile width) |
| **Background** | Near-white cool gray, subtle radial gradient (~`#F4F4F4` center → `#D0D2D9` edge) |
| **Bottom bar** | ~20% of screen height, base `#D2D6DB` |
| **Accent blue** (wave, glow, clock) | `#3CB9E6` (acceptable range `#009AC7`–`#4EBCFF`) |
| **Clock / date text** | Gray `#84868A`; colon blinks 1 Hz; date format "Fri 19/6" (weekday + D/M) |
| **Wii button** | Round silver disc, blue "Wii"-style wordmark, bottom-left, soft blue glow |
| **SD indicator** | Small SD glyph near the Wii button |
| **Envelope button** | Round button, bottom-right |
| **Fonts** | OFL substitutes for Rodin NTLG: **Asap** (UI/clock) + **M PLUS Rounded 1c** (accents) |
| **Hover** | Tile scales `0.94 → 1.0` + white rounded glow fades in, ~400 ms ease |
| **Select (click)** | Tile zooms from its center to fill screen, then launches; soft "whoosh" |
| **Wave** | Continuous slow horizontal sine ripple, self-drawn (Core Animation) |

**Wii-menu-native controls (on-theme):**
- **Wii button → opens Ivan's Menu Settings** (mirrors the real console opening system settings).
- **Envelope button → reserved** (v1: opens an "About / tips" panel; future: notifications).

---

## 3. Architecture

Small, single-purpose units communicating through well-defined interfaces.

### 3.1 `AppDelegate` (agent lifecycle)
- `LSUIElement = true` — no Dock icon, no ⌘-Tab entry.
- Owns app lifecycle; creates the menu-bar `NSStatusItem` (escape hatch: Settings, Quit, Reopen).
- On activate: hides Finder desktop icons; on quit/disable: restores them.
- Registers global hotkey **⌥Space** = "peek desktop" (temporarily reveal real desktop while held/toggled).
- Observes `NSApplication.didChangeScreenParametersNotification` to rebuild windows on display changes.

**Desktop-icon hiding:** toggle `com.apple.finder CreateDesktop` (write `false`, `killall Finder`) on enable; restore (`true`, `killall Finder`) on disable/quit. Store prior value so we never clobber a user who already hides icons.

### 3.2 `WallpaperWindowController`
- Creates **one immersive window per `NSScreen`**, keyed by display ID.
- Each window: borderless, `backing: .buffered`, fills `screen.frame`.
- **Window level:** at/above the Finder desktop-icon layer so tiles are clickable and cover icons. Baseline `NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)`; tuned during implementation.
- `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]` — spans all Spaces, stays out of Mission Control shuffle and ⌘-Tab.
- **Interactive:** `ignoresMouseEvents = false`; overrides `canBecomeKey`/`canBecomeMain` to allow focus for clicks/keyboard when active.
- Never steals focus on show (`orderFront` without forcing key unless interacting).
- Hosts the SwiftUI `WiiMenuView` via `NSHostingView`.
- Menu on the **primary display**; secondary displays show the same background/wave fill (full multi-display menus can come later, but v1 renders cleanly on all).

*(Foundation: Lively's MIT `WallpaperWindow.swift` pattern, adapted from non-interactive to interactive.)*

### 3.3 `WiiMenuView` (SwiftUI)
- Renders the paged 4×3 grid + bottom bar.
- Owns navigation state (current page), horizontal slide paging (on-screen left/right arrows + trackpad swipe + arrow keys).
- Owns hover and select animations.
- Composes `ChannelTileView` per slot and `BottomBarView`.

### 3.4 `ChannelTileView` (SwiftUI)
- Renders one tile from a `Channel`: banner art + hover glow + select zoom.
- Empty slot = recessed light-gray placeholder.
- Click → `Launcher.open(channel.action)` with zoom transition + sound.

### 3.5 `BottomBarView` + `WaveView`
- `BottomBarView`: Wii button (→ Settings), SD indicator, live clock + date (center), envelope button.
- `WaveView`: self-drawn animated wave via Core Animation (owns its own animation loop; independent of user input).
- Clock: updates on the minute; colon blinks at 1 Hz.

### 3.6 `ChannelStore`
- Loads/saves config as **JSON in `~/Library/Application Support/Ivan's Menu/config.json`**.
- Holds the 48 `Channel` bindings + ordering; supports drag-reorder.
- Publishes changes (ObservableObject) so views update live.

### 3.7 `Channel` (model)
```
Channel {
  id: UUID
  slot: Int              // 0..47 (page = slot / 12)
  action: Action         // .app(bundleID/path) | .url(String) | .file(path) | .folder(path) | .empty
  banner: BannerSource   // .pack(id) | .generated | .custom(imagePath)
  title: String?         // optional label override
}
```

### 3.8 `BannerRenderer`
Resolves a `Channel` to a rendered banner image, in priority order:
1. **`.pack(id)`** — hand-made, Wii-styled banner from the bundled **Channel Pack** (~30–50 popular apps/sites; all original art).
2. **`.generated`** — fallback for anything not in the pack (e.g. **Helium browser**): pull the app's `NSWorkspace` icon (or the site's favicon for URLs), sample the icon's **dominant color**, and composite the icon centered on a Wii-style card in that hue (rounded rect, bezel, subtle gradient). Guarantees every app gets a cohesive tile.
3. **`.custom(path)`** — user-supplied image, fit to tile with the Wii bezel applied.
- Caches rendered banners to disk keyed by source + size.

### 3.9 `Launcher`
- Executes a `Channel.action` via `NSWorkspace`:
  - `.app` → `openApplication`
  - `.url` → `open(URL)`
  - `.file` / `.folder` → `open`/`activateFileViewerSelecting`
- Reports failures gracefully (tile shake + no crash).

### 3.10 `OnboardingWizard` (SwiftUI, first run)
- Scans `/Applications` (+ common subfolders), lists installed apps with icons.
- Tap-to-add apps as channels; auto-matches Channel Pack banners, else `.generated`.
- "Add a website" field (URL → favicon-generated banner).
- Arranges added channels into slots; writes to `ChannelStore`.
- Goal: install → populated Wii menu in ~60 seconds.

### 3.11 `SettingsWindow` (SwiftUI)
- Opened by the **Wii button** and by the menu-bar status item.
- Rebind/reorder tiles (drag), swap banner source per tile, edit titles.
- Toggles: sound cues on/off, ambient music on/off, hide-desktop-icons on/off, hotkey config, which display shows the menu.
- Manage pages.

---

## 4. Data flow

```
config.json ──load──▶ ChannelStore ──publishes──▶ WiiMenuView
                                          │
                          per tile ──▶ BannerRenderer ──▶ banner image
                                          │
   user clicks tile ──▶ Launcher.open(action) ──▶ NSWorkspace

OnboardingWizard / SettingsWindow ──edit──▶ ChannelStore ──save──▶ config.json
                                                     └─publishes─▶ views refresh
```

---

## 5. Audio (original assets only)
- **Sound cues:** self-made/royalty-free "tick" (hover), "whoosh" (select), "back". Toggleable; off = silent.
- **Ambient music:** optional original/royalty-free ambient loop (NOT Nintendo's theme). Off by default; toggleable.

---

## 6. Error handling
- Launch failure → tile "shake" feedback, log, no crash.
- Missing app/file (moved/uninstalled) → tile shows a subtle "broken" state; still editable.
- Banner render failure → fall back to `.generated`, then to a neutral placeholder card.
- Display disconnect/reconnect → `WallpaperWindowController` rebuilds windows.
- Desktop-icon toggle failure (permissions) → warn once, continue without hiding icons.
- Corrupt `config.json` → back up the bad file, start from defaults, notify.

---

## 7. Testing strategy
- **Unit:** `ChannelStore` (load/save/migrate/corrupt-recovery), `Channel` codec, `BannerRenderer` priority + dominant-color sampling, `Launcher` action routing (mock `NSWorkspace`).
- **Snapshot:** `ChannelTileView`, `BottomBarView`, empty vs filled tiles, hover/select states.
- **Manual/integration checklist:** window sits above icons and is clickable; icons hide/restore correctly; multi-display rebuild; ⌥Space peek; Wii button → Settings; onboarding end-to-end; menu-bar escape hatch quits reliably.

---

## 8. Distribution & legal
- Public repo, **MIT license**.
- README: build-from-source (Xcode) + code-signed/notarized release (Ivan's Apple Developer account).
- Disclaimer: *"Ivan's Menu is an unofficial, fan-made tribute. Not affiliated with, endorsed by, or sponsored by Nintendo. All Nintendo trademarks belong to their respective owners."*
- Ship **no** Nintendo names in the product/app name, logos, fonts, sounds, or ripped textures. All banner art, wave, and audio are original; fonts are OFL.

---

## 9. Scope — v1 ("everything at once")
Included: all 4 pages + paging, drag-reorder, onboarding wizard, settings window,
Channel Pack + auto-generate + custom banners, animated wave, live clock,
hover/select animations, sound cues + optional ambient music, hide-desktop-icons
immersion, Wii-button→Settings, menu-bar escape hatch, ⌥Space peek, multi-display
render, code-signed build.

Deferred (post-v1): full independent menus on every display, envelope/notifications
feature, theme variants, iCloud sync of config, community banner-pack sharing.

---

## 10. Key references (from research)
- Interactive desktop window: **Lively** `WallpaperWindow.swift` (MIT).
- Layout/CSS reference: **danintosh/Wii-Menu-HTML** (MIT), **Wii.JS**, **tobieche110/wii-portfolio** (MIT).
- Concrete values (hex/timing/sizes): faithful recreations above + The Spriters Resource (reference only, do not ship).
- Fonts: Asap + M PLUS Rounded 1c (OFL), substitutes for Rodin NTLG.
