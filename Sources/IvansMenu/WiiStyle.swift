import SwiftUI
import IvansMenuKit

/// Shared Wii-flavored SwiftUI styling used by the Onboarding and Settings
/// windows so they read as part of the same "channel" world as `WiiMenuView`.
/// Visual-only helpers — no app logic lives here.
enum WiiFont {
    /// Large friendly title, e.g. window headers ("Pick your channels").
    static func title(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    /// Regular body copy.
    static func body(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }
    /// Small labels / captions, e.g. app names under an icon.
    static func label(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
}

/// Radial light-gray background echoing the main menu's `wiiBGCenter` →
/// `wiiBGEdge` gradient, topped with a thin accent "wave" divider.
struct WiiBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                ZStack(alignment: .top) {
                    RadialGradient(
                        colors: [.wiiBGCenter, .wiiBGEdge],
                        center: .center, startRadius: 0, endRadius: 520)
                    Capsule()
                        .fill(Color.wiiAccent.opacity(0.8))
                        .frame(width: 120, height: 3)
                        .offset(y: 6)
                }
                .ignoresSafeArea()
            )
    }
}

extension View {
    func wiiBackground() -> some View { modifier(WiiBackground()) }
}

/// Rounded-rect card container for app cells / channel rows, echoing the
/// channel tile look (rounded corners, soft shadow, accent glow when selected).
struct WiiCard: ViewModifier {
    var selected: Bool = false
    var cornerRadius: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(selected ? Color.wiiAccent : Color.black.opacity(0.08),
                                  lineWidth: selected ? 2.5 : 1)
            )
            .shadow(color: selected ? Color.wiiAccent.opacity(0.45) : Color.black.opacity(0.12),
                    radius: selected ? 8 : 4, x: 0, y: 2)
    }
}

extension View {
    func wiiCard(selected: Bool = false, cornerRadius: CGFloat = 14) -> some View {
        modifier(WiiCard(selected: selected, cornerRadius: cornerRadius))
    }
}

/// Soft light-gray capsule button with an accent border — the standard Wii
/// "channel menu" button look.
struct WiiButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WiiFont.body(13))
            .foregroundColor(.black.opacity(0.75))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(
                    LinearGradient(colors: [.white, Color.wiiBGEdge.opacity(0.6)],
                                   startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                Capsule().strokeBorder(Color.wiiAccent.opacity(configuration.isPressed ? 0.9 : 0.6),
                                       lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Filled accent variant for primary actions (e.g. "Finish").
struct WiiProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WiiFont.body(14).weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(
                    LinearGradient(colors: [Color.wiiAccent, Color.wiiAccent.opacity(0.85)],
                                   startPoint: .top, endPoint: .bottom))
            )
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.5), lineWidth: 1))
            .shadow(color: Color.wiiAccent.opacity(configuration.isPressed ? 0.2 : 0.45),
                    radius: configuration.isPressed ? 3 : 6, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == WiiButtonStyle {
    static var wii: WiiButtonStyle { WiiButtonStyle() }
}

extension ButtonStyle where Self == WiiProminentButtonStyle {
    static var wiiProminent: WiiProminentButtonStyle { WiiProminentButtonStyle() }
}

/// Rounded, lightly bordered text field background matching the card style.
struct WiiFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(WiiFont.body(13))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
            )
    }
}

extension View {
    func wiiField() -> some View { modifier(WiiFieldStyle()) }
}
