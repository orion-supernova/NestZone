import SwiftUI

/// What the tour's pages draw: small compositions of symbols and glass, built
/// from the app's own parts so they follow the theme and need no image assets.
/// Each piece pops in once its page is the one on show (`PopIn`), staggered.

/// Pops a view in when its page becomes the current one, and puts it back a
/// moment after the page has been left, so swiping back plays it again.
/// Reduce Motion: a fade, no scale.
private struct PopIn: ViewModifier {
    let index: Int
    let isCurrent: Bool

    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(shown || reduceMotion ? 1 : 0.55)
            .opacity(shown ? 1 : 0)
            .task(id: isCurrent) {
                if isCurrent {
                    withAnimation(reduceMotion ? Motion.fade : Motion.pop.delay(0.08 * Double(index) + 0.1)) {
                        shown = true
                    }
                } else {
                    // Not at once: the page is still sliding away.
                    try? await Task.sleep(for: .milliseconds(450))
                    guard !Task.isCancelled else { return }
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { shown = false }
                }
            }
    }
}

extension View {
    func popIn(_ index: Int, isCurrent: Bool) -> some View {
        modifier(PopIn(index: index, isCurrent: isCurrent))
    }
}

/// A round glass tile with one symbol in it.
private struct ArtDisc: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 56

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .glassEffect(.regular.tint(tint.opacity(0.16)), in: .circle)
    }
}

/// One home, and the people in it.
struct WelcomeArt: View {
    let isCurrent: Bool

    @Environment(\.theme) private var theme

    private static let people: [(x: CGFloat, y: CGFloat, tint: Color)] = [
        (-96, -34, Palette.hotPink), (92, -52, Palette.amber),
        (-70, 62, Palette.cyan), (84, 56, Palette.violet),
    ]

    var body: some View {
        GlassGroup(spacing: 40) {
            ZStack {
                ArtDisc(symbol: "house.fill", tint: theme.ink, size: 112)
                    .popIn(0, isCurrent: isCurrent)
                ForEach(Self.people.indices, id: \.self) { index in
                    let person = Self.people[index]
                    ArtDisc(symbol: "person.fill", tint: person.tint, size: 52)
                        .offset(x: person.x, y: person.y)
                        .popIn(index + 1, isCurrent: isCurrent)
                }
            }
        }
        .frame(height: 200)
        .accessibilityHidden(true)
    }
}

/// A chore list and a shopping cart: rows drawn as bars, so there is no
/// sample text to translate.
struct ListsArt: View {
    let isCurrent: Bool

    @Environment(\.theme) private var theme

    private static let rows: [(done: Bool, width: CGFloat)] = [(true, 120), (false, 150), (false, 96)]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Self.rows.indices, id: \.self) { index in
                        let row = Self.rows[index]
                        HStack(spacing: 12) {
                            Image(systemName: row.done ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(row.done ? theme.ink : Palette.textTertiary)
                            Capsule().fill(Palette.inset).frame(width: row.width, height: 10)
                            Spacer(minLength: 0)
                        }
                        .popIn(index + 1, isCurrent: isCurrent)
                    }
                }
            }
            .frame(width: 252)
            .popIn(0, isCurrent: isCurrent)

            ArtDisc(symbol: "cart.fill", tint: Palette.success, size: 56)
                .offset(x: 18, y: -24)
                .popIn(4, isCurrent: isCurrent)
        }
        .frame(height: 200)
        .accessibilityHidden(true)
    }
}

/// Calendar, meals and movies, as three tiles with their names.
struct PlansArt: View {
    let isCurrent: Bool

    private static let tiles: [(symbol: String, tint: Color, title: LocalizedStringResource)] = [
        ("calendar", Palette.hotPink, L10n.tabBarCalendar),
        ("fork.knife", Palette.amber, L10n.tabBarRecipes),
        ("popcorn.fill", Palette.violet, L10n.tabBarMovies),
    ]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(Self.tiles.indices, id: \.self) { index in
                let tile = Self.tiles[index]
                VStack(spacing: 10) {
                    Image(systemName: tile.symbol)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(tile.tint)
                        .frame(width: 84, height: 84)
                        .glassEffect(.regular.tint(tile.tint.opacity(0.14)), in: .rect(cornerRadius: 24, style: .continuous))
                    Text(tile.title).font(.footnote.weight(.semibold))
                }
                .popIn(index, isCurrent: isCurrent)
            }
        }
        .frame(height: 200)
        .accessibilityHidden(true)
    }
}

/// Notes, money and problems; the two that are Plus wear its tag.
struct HouseArt: View {
    let isCurrent: Bool

    private static let rows: [(symbol: String, tint: Color, title: LocalizedStringResource, isPlus: Bool)] = [
        ("note.text", Palette.amber, L10n.tabBarNotes, false),
        ("dollarsign.circle.fill", Palette.indigo, L10n.tabBarFinance, true),
        ("wrench.adjustable.fill", Palette.eventOutdoor, L10n.tabBarProblems, true),
    ]

    var body: some View {
        GlassGroup(spacing: 24) {
            VStack(spacing: 10) {
                ForEach(Self.rows.indices, id: \.self) { index in
                    let row = Self.rows[index]
                    HStack(spacing: 14) {
                        Image(systemName: row.symbol)
                            .font(.title3)
                            .foregroundStyle(row.tint)
                            .frame(width: 40)
                        Text(row.title).font(.headline)
                        if row.isPlus { PlusTag() }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, Metrics.cardPadding)
                    .frame(height: 56)
                    .glassCard()
                    .popIn(index, isCurrent: isCurrent)
                }
            }
            .frame(maxWidth: 300)
        }
        .frame(minHeight: 200)
        .accessibilityHidden(true)
    }
}

/// Nestie: a plant that grows, with a pet at its side.
struct NestieArt: View {
    let isCurrent: Bool

    var body: some View {
        GlassGroup(spacing: 40) {
            ZStack {
                ArtDisc(symbol: "leaf.fill", tint: Palette.success, size: 120)
                    .bounces(when: isCurrent)
                    .popIn(0, isCurrent: isCurrent)
                ArtDisc(symbol: "pawprint.fill", tint: Palette.amber, size: 52)
                    .offset(x: 88, y: 50)
                    .popIn(1, isCurrent: isCurrent)
                ArtDisc(symbol: "sparkles", tint: Palette.sparkle, size: 44)
                    .offset(x: -84, y: -48)
                    .popIn(2, isCurrent: isCurrent)
            }
        }
        .frame(height: 200)
        .accessibilityHidden(true)
    }
}

/// The replay's last page.
struct DoneArt: View {
    let isCurrent: Bool

    var body: some View {
        ArtDisc(symbol: "checkmark.seal.fill", tint: Palette.success, size: 120)
            .bounces(when: isCurrent)
            .popIn(0, isCurrent: isCurrent)
            .frame(height: 200)
            .accessibilityHidden(true)
    }
}
