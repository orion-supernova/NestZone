import SwiftUI
import UIKit

/// The app's visual identities.
///
/// These used to carry a full palette each — background, card, text, secondary
/// text, plus two gradient stops — and every screen rebuilt all of them on every
/// redraw via `AppTheme.colors(for:)`. Under Liquid Glass that palette is the
/// system's job: surfaces are glass, text is `.primary`/`.secondary`, and the
/// background is the real content behind the glass. A theme is now only an
/// *accent identity*, which is the part that actually carried the personality.
///
/// Every colour here is a stored constant, so switching themes allocates nothing
/// and a `body` never parses a hex string.
public enum AppTheme: String, CaseIterable, Sendable, Codable, Identifiable {
    case basic, cyberpunk, retroWave, neonNight, deepOcean

    public var id: String { rawValue }

    /// The primary tint: buttons, selected states, symbols, glass tinting.
    public var accent: Color {
        switch self {
        case .basic: Palette.violet
        case .cyberpunk: Palette.magenta
        case .retroWave: Palette.hotPink
        case .neonNight: Palette.emerald
        case .deepOcean: Palette.oceanBlue
        }
    }

    /// The second hue, for two-stop gradients on hero elements only.
    public var support: Color {
        switch self {
        case .basic: Palette.indigo
        case .cyberpunk: Palette.neonGreen
        case .retroWave: Palette.ultraviolet
        case .neonNight: Palette.cyan
        case .deepOcean: Palette.cyan
        }
    }

    /// Reserved for the rare element that must out-shout the accent — a streak
    /// badge, a "new" pip. Never for body text.
    public var highlight: Color {
        switch self {
        case .basic, .retroWave, .neonNight: Palette.amber
        case .cyberpunk: Palette.lemon
        case .deepOcean: Palette.mint
        }
    }

    public var displayName: LocalizedStringResource {
        switch self {
        case .basic: L10n.themeBasic
        case .cyberpunk: L10n.themeCyberpunk
        case .retroWave: L10n.themeRetrowave
        case .neonNight: L10n.themeNeonNight
        case .deepOcean: L10n.themeDeepOcean
        }
    }

    /// Two-stop gradient for hero surfaces. Built once per theme, not per frame.
    public var gradient: LinearGradient {
        switch self {
        case .basic: Palette.basicGradient
        case .cyberpunk: Palette.cyberpunkGradient
        case .retroWave: Palette.retroWaveGradient
        case .neonNight: Palette.neonNightGradient
        case .deepOcean: Palette.deepOceanGradient
        }
    }
}

/// Every literal colour in the app, allocated exactly once.
public enum Palette {
    public static let violet = Color(hex: "7C3AED")
    public static let indigo = Color(hex: "4F46E5")
    public static let magenta = Color(hex: "FF1F8A")
    public static let neonGreen = Color(hex: "46FF8B")
    public static let hotPink = Color(hex: "FF4D8D")
    public static let ultraviolet = Color(hex: "7A5AF8")
    public static let emerald = Color(hex: "10B981")
    public static let cyan = Color(hex: "06B6D4")
    public static let oceanBlue = Color(hex: "1D4ED8")
    public static let amber = Color(hex: "F59E0B")
    public static let lemon = Color(hex: "FDE047")
    public static let mint = Color(hex: "34D399")
    /// Second and third place on the contributions leaderboard, and nothing
    /// else. Both are dark enough to carry white text at 11pt.
    public static let silver = Color(hex: "9AA0A6")
    public static let bronze = Color(hex: "B87333")

    /// Chevrons, disclosure arrows, overflow dots — the small glyphs that say
    /// "there is more here" and carry no other information.
    ///
    /// Not `.tertiary`: over glass that is legible on a light ground and very
    /// nearly invisible on a dark one, because the hierarchy styles are tuned
    /// against opaque system backgrounds rather than a blurred one. These two
    /// are fixed alpha over white and black respectively, which holds up in
    /// both appearances and under every theme. Built from a dynamic `UIColor`
    /// and stored, so a `body` never allocates one.
    public static let accessory = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.55)
            : UIColor(white: 0, alpha: 0.35)
    })

    /// The same idea for a glyph that is also a control — an overflow menu —
    /// where "there is more here" has to read as tappable.
    public static let accessoryStrong = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.78)
            : UIColor(white: 0, alpha: 0.55)
    })

    /// The ground under an inset block of monospaced detail inside a row — a
    /// device token, an id — so it reads as a quoted block rather than a line
    /// of text that wandered to the left margin.
    ///
    /// Fixed alpha for the same reason as `accessory`: `.quaternary` is tuned
    /// against an opaque system background and all but disappears over the
    /// blurred one this app puts behind every screen.
    public static let inset = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.10)
            : UIColor(white: 0, alpha: 0.06)
    })

    /// One colour per spending category, allocated once.
    ///
    /// A category's colour is the only thing tying its donut segment to its
    /// budget ring to its row in the ledger, so these are fixed rather than
    /// derived: a hue hashed from the name — the way `MemberTint` does it —
    /// would change the moment a category was renamed, and the chart a
    /// household had learned to read would rearrange itself under them. Ten
    /// hues, spaced far enough apart to stay apart both on a ring at 26pt and
    /// in an 8pt legend dot.
    public static let spendGroceries = Color(hex: "34D399")
    public static let spendUtilities = Color(hex: "38BDF8")
    public static let spendRent = Color(hex: "6366F1")
    public static let spendHousehold = Color(hex: "A78BFA")
    public static let spendDining = Color(hex: "FB7185")
    public static let spendTransport = Color(hex: "F59E0B")
    public static let spendHealth = Color(hex: "F87171")
    public static let spendEntertainment = Color(hex: "E879F9")
    public static let spendSubscriptions = Color(hex: "22D3EE")
    public static let spendOther = Color(hex: "94A3B8")

    /// One colour per kind of event, allocated once.
    ///
    /// Fixed rather than derived for the same reason the spending categories
    /// are: the colour is the only thing tying a dot on the month grid to the
    /// block on the week timeline to the row in the agenda, and a household
    /// learns to read it. Twelve hues, far enough apart to survive being a 5pt
    /// dot on a crowded Tuesday. Several kinds deliberately share one — a cinema
    /// trip and a movie night are the same colour because they are the same
    /// evening seen from two sides, and a household reads the grid faster with
    /// twelve hues than with nineteen.
    public static let eventGeneral = Color(hex: "6366F1")
    public static let eventParty = Color(hex: "F472B6")
    public static let eventFood = Color(hex: "FB923C")
    public static let eventScreen = Color(hex: "A855F7")
    public static let eventPlay = Color(hex: "14B8A6")
    public static let eventPeople = Color(hex: "0EA5E9")
    public static let eventChore = Color(hex: "94A3B8")
    public static let eventStage = Color(hex: "E11D48")
    public static let eventOutdoor = Color(hex: "65A30D")
    public static let eventTravel = Color(hex: "06B6D4")
    public static let eventCelebrate = Color(hex: "EC4899")
    public static let eventHoliday = Color(hex: "F59E0B")
    public static let eventAdmin = Color(hex: "60A5FA")
    public static let eventDeadline = Color(hex: "EF4444")

    /// One colour per tile on the Home tab.
    ///
    /// Fixed rather than drawn from the theme, which is what they used to be —
    /// shopping took `theme.accent` and notes took `theme.support`. That made
    /// every collision theme-dependent and therefore invisible until somebody
    /// switched: under the default theme `support` is indigo and the events
    /// tile was indigo too, so two of the five tiles were the same colour in
    /// dark mode and nearly the same in light.
    ///
    /// Five hues, spread far enough around the wheel to stay apart at 15pt in
    /// both appearances, and stable across all five themes — the tile's colour
    /// is how you find it without reading it, so it must not move when the
    /// accent does.
    public static let statTasks = Color(hex: "F59E0B")      // amber
    public static let statShopping = Color(hex: "22C55E")   // green
    public static let statNotes = Color(hex: "A855F7")      // purple
    public static let statMessages = Color(hex: "38BDF8")   // sky
    public static let statEvents = Color(hex: "FB7185")     // rose
    // The sixth tile. Indigo because it is what is left: the five above sit at
    // roughly 38°, 142°, 199°, 271° and 350° round the wheel, and the widest
    // usable gap between two of them that is not simply "another green" is the
    // one between sky and purple. It does not go red when something is urgent —
    // a tile's colour is how you find it without reading it, and one that moves
    // is one you have to hunt for on exactly the day you most need it.
    public static let statIssues = Color(hex: "6366F1")     // indigo

    /// How badly a house problem matters, as a four-step ramp.
    ///
    /// Read as a ramp rather than as four labels — grey, blue, amber, red is a
    /// sequence anybody can order at a glance without learning it, which is the
    /// whole reason severity is worth a colour at all. It is the tint a problem
    /// row carries, because urgency is what a person scans a list of faults for.
    public static let issueCosmetic = Color(hex: "94A3B8")
    public static let issueMinor = Color(hex: "38BDF8")
    public static let issueMajor = Color(hex: "F59E0B")
    public static let issueUrgent = Color(hex: "EF4444")

    /// How far along a problem is.
    ///
    /// Also a sequence, and deliberately a different one: nothing yet, seen,
    /// booked, being done, then either done or dropped. `blocked` is amber
    /// rather than another cool hue because being stuck is the one state on the
    /// track that is asking somebody for something.
    public static let issueReported = Color(hex: "94A3B8")
    public static let issueAcknowledged = Color(hex: "60A5FA")
    public static let issueScheduled = Color(hex: "A78BFA")
    public static let issueInProgress = Color(hex: "06B6D4")
    public static let issueBlocked = Color(hex: "F59E0B")
    public static let issueFixed = Color(hex: "22C55E")
    public static let issueWontFix = Color(hex: "78716C")

    /// Semantic colours. These resolve per-appearance on their own, which is why
    /// the app no longer needs a light and a dark value for everything.
    public static let danger = Color.red
    public static let success = Color.green
    public static let warning = Color.orange

    /// Sits behind a title laid over artwork — a swipe-deck poster, a hero
    /// image. Fades to nothing at the top rather than cutting a hard black edge
    /// across the picture the way a flat bar does. A stored constant, so the
    /// card's `body` never allocates a gradient per frame.
    public static let posterScrim = LinearGradient(
        colors: [.clear, .black.opacity(0.35), .black.opacity(0.75)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Behind a photo opened full screen. Black rather than a material: the
    /// picture is the only thing on the screen, and anything that lets the app
    /// show through competes with it.
    public static let viewerBackdrop = Color.black

    /// A control floating over a photograph, which may be any brightness.
    public static let viewerControl = Color.black.opacity(0.45)

    /// The ring drawn around the crop circle, so its edge is visible against a
    /// photo of any brightness.
    public static let cropRing = Color.white.opacity(0.9)

    /// Laid over a control whose change is still in flight, to say the tap
    /// landed and the result is not in yet.
    public static let busyScrim = Color.black.opacity(0.35)

    /// Everything the crop circle is not.
    ///
    /// Dark enough that the discarded edges read as excluded rather than merely
    /// shaded, and light enough to still show what is being given up — the
    /// whole job of the editor is letting someone see what falls outside the
    /// circle before they commit to it.
    public static let cropScrim = Color.black.opacity(0.55)

    static let basicGradient = gradient(violet, indigo)
    static let cyberpunkGradient = gradient(magenta, neonGreen)
    static let retroWaveGradient = gradient(hotPink, ultraviolet)
    static let neonNightGradient = gradient(emerald, cyan)
    static let deepOceanGradient = gradient(oceanBlue, cyan)

    private static func gradient(_ from: Color, _ to: Color) -> LinearGradient {
        LinearGradient(colors: [from, to], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Environment

extension EnvironmentValues {
    /// The active theme. Read this instead of reaching for `@AppStorage` in a
    /// view — it keeps views previewable and makes the dependency explicit.
    @Entry public var theme: AppTheme = .basic
}

extension View {
    /// Applies `theme` to this subtree, including SwiftUI's own `tint`, so
    /// system controls (switches, pickers, the tab bar) pick it up for free.
    public func appTheme(_ theme: AppTheme) -> some View {
        environment(\.theme, theme).tint(theme.accent)
    }
}
