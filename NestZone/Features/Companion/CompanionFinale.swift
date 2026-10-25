import ComposableArchitecture
import SwiftUI

/// "You've grown them all": the last beats of a graduation that finished every
/// species that costs no Sparkles. It lives inside the ceremony's own cover
/// (`CeremonyView`), after "All grown up!" when a start brought the graduation
/// with it, or alone when the ceremony on Today has been played already, so
/// the house never sees two covers compete.
///
/// The whole album arrives as small stills in a cascade, then the tiny crown,
/// then the line about the next door. Confetti twice: it is the biggest thing a
/// house achieves. Under Reduce Motion the cascade is a fade and nothing
/// travels, scales or spins; the haptics stay.
struct FinaleView: View {
    let store: StoreOf<CompanionFeature>
    let moment: CompanionFeature.State.Moment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    /// 1 the title, 2 the crown, 3 the door and the way out.
    @State private var beat = 0
    /// How many of the album's tiles have arrived.
    @State private var revealed = 0
    @State private var burst = 0

    private enum Ink {
        /// The finale's confetti: the crown's gold, the jar's Sparkles and Leaves, and violet.
        static let tints: [Color] = [Palette.lemon, Palette.sparkle, Palette.leaf, Palette.violet]
    }

    var body: some View {
        let big = typeSize.isAccessibilitySize
        VStack(spacing: 14) {
            Text(L10n.finaleTitle)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .oneLine()
                .scaleEffect(beat >= 1 || reduceMotion ? 1 : 0.85)
                .opacity(beat >= 1 ? 1 : 0)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 24)
            ScrollView {
                grid(big: big)
                    .padding(.horizontal, 4)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            crown(big: big)
            Text(L10n.finaleDoor)
                .font(.body.weight(.semibold))
                .foregroundStyle(SheetInk.caption)
                .multilineTextAlignment(.center)
                .opacity(beat >= 3 ? 1 : 0)
            PrimaryButton(L10n.finaleDone, symbol: "sparkles") {
                store.send(.momentDismissed, animation: Motion.arrive)
            }
            .opacity(beat >= 3 ? 1 : 0)
            .allowsHitTesting(beat >= 3)
            .accessibilityHidden(beat < 3)
            .padding(.bottom, 24)
            .accessibilityIdentifier("FinaleDone")
        }
        .padding(.horizontal, Metrics.screenPadding)
        .overlay { ConfettiBurst(trigger: burst, tints: Ink.tints) }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: beat) { _, now in now == 1 }
        .sensoryFeedback(.success, trigger: beat) { _, now in now == 2 }
        .task { await play(big: big) }
    }

    // MARK: The album

    private func grid(big: Bool) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: big ? 3 : 4)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(moment.grown.enumerated()), id: \.element) { index, species in
                portrait(species, big: big)
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .background(RoundedRectangle(cornerRadius: 8).fill(SheetInk.spotFill))
                    .clipShape(.rect(cornerRadius: 8))
                    .opacity(index < revealed ? 1 : 0)
                    .scaleEffect(index < revealed || reduceMotion ? 1 : 0.7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L10n.finaleCount(moment.grown.count)))
    }

    private func portrait(_ species: Species, big: Bool) -> some View {
        Self.portrait(species, home: store.homeID).tile(big: big)
    }

    private static func portrait(_ species: Species, home: HomeID) -> SpeciesPortrait {
        SpeciesPortrait(species: species, seed: "\(home.rawValue)-\(species.rawValue)")
    }

    // MARK: The crown

    private func crown(big: Bool) -> some View {
        HStack(spacing: 12) {
            DecorPortrait(decor: .item(.tinyCrown)).tile(big: big)
                .frame(width: 64, height: 64)
                .background(RoundedRectangle(cornerRadius: 12).fill(SheetInk.spotOn))
                .clipShape(.rect(cornerRadius: 12))
            Text(L10n.finaleCrown)
                .font(.headline)
                .foregroundStyle(Palette.lemon)
                .multilineTextAlignment(.leading)
        }
        .scaleEffect(beat >= 2 || reduceMotion ? 1 : 0.6)
        .opacity(beat >= 2 ? 1 : 0)
    }

    // MARK: The beats

    private func play(big: Bool) async {
        let beatIn: Animation = reduceMotion ? Motion.fade : Motion.celebrate
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 300))
        withAnimation(beatIn) { beat = 1 }
        burst += 1
        // The stills are drawn once, off the scroll, and kept; the cascade
        // starts when they are there to arrive.
        var jobs: [(StillSpec, AnyView)] = moment.grown.map { species in
            let portrait = Self.portrait(species, home: store.homeID)
            return (portrait.still(big: big), AnyView(portrait))
        }
        let crown = DecorPortrait(decor: .item(.tinyCrown))
        jobs.append((crown.still(big: big), AnyView(crown)))
        await StillCache.warm(jobs)
        if Task.isCancelled { return }
        if reduceMotion {
            withAnimation(Motion.fade) { revealed = moment.grown.count }
        } else {
            for index in 1...max(moment.grown.count, 1) {
                try? await Task.sleep(for: .milliseconds(40))
                withAnimation(Motion.arrive) { revealed = index }
            }
        }
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 450))
        withAnimation(reduceMotion ? Motion.fade : Motion.pop) { beat = 2 }
        burst += 1
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 600))
        withAnimation(Motion.fade) { beat = 3 }
    }
}
