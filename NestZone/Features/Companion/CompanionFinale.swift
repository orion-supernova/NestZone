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
    /// The cascade has been set going: every tile arrives on its own delay,
    /// by one change of this value, so the grid is not rebuilt per tile.
    @State private var cascading = false
    @State private var burst = 0
    /// The grid and the crown are made a frame after the title, so the cover
    /// opens on a first frame that is only its backdrop and its title.
    @State private var builtTiles = 0
    @State private var builtCrown = false

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
            if builtCrown { crown(big: big) } else { Color.clear.frame(height: 64) }
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
            // A row a frame, so no one frame builds twenty-eight tiles.
            ForEach(Array(moment.grown.enumerated()).prefix(builtTiles), id: \.element) { index, species in
                portrait(species, big: big)
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .background(RoundedRectangle(cornerRadius: 8).fill(SheetInk.spotFill))
                    .clipShape(.rect(cornerRadius: 8))
                    .opacity(cascading ? 1 : 0)
                    .scaleEffect(cascading || reduceMotion ? 1 : 0.7)
                    // Reduce Motion: one fade, all together, no travel.
                    .animation(reduceMotion ? Motion.fade : Motion.arrive.delay(Double(index) * 0.04), value: cascading)
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

    /// Draws them into the cache: the pets' shapes first, built off the main
    /// thread (the first still of each costs a frame otherwise), then the
    /// stills one at a time between frames.
    static func warm(_ album: [Species], home: HomeID, big: Bool) async {
        let plans = album.filter(\.isPet).compactMap(CritterPlan.of)
        await Task.detached(priority: .utility) { plans.forEach(CritterGeometry.prepare) }.value
        await StillCache.warm(warmJobs(album, home: home, big: big))
    }

    /// The pictures the finale shows, as the cache keeps them: the grown
    /// species' stills and the crown's. The card draws them while the finale
    /// is on its way (`CompanionCard`), so the cover opens on ready bitmaps.
    static func warmJobs(_ album: [Species], home: HomeID, big: Bool) -> [(StillSpec, AnyView)] {
        var jobs: [(StillSpec, AnyView)] = album.map { species in
            let portrait = portrait(species, home: home)
            return (portrait.still(big: big), AnyView(portrait))
        }
        let crown = DecorPortrait(decor: .item(.tinyCrown))
        jobs.append((crown.still(big: big), AnyView(crown)))
        return jobs
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
        // A frame for the cover to open on, then the grid, then the crown:
        // each is made in a frame of its own.
        await FrameTick.next()
        withAnimation(beatIn) { beat = 1 }
        burst += 1
        let perRow = big ? 3 : 4
        while builtTiles < moment.grown.count {
            await FrameTick.next()
            if Task.isCancelled { return }
            builtTiles += perRow
        }
        await FrameTick.next()
        builtCrown = true
        // The stills were drawn ahead and kept (`warmJobs`); this finds them
        // there and draws nothing, unless a house got here without the card
        // having seen it coming, in which case the cascade waits for them.
        await Self.warm(moment.grown, home: store.homeID, big: big)
        if Task.isCancelled { return }
        cascading = true
        // The last tile lands 40 ms after the one before it.
        let cascade = reduceMotion ? 200 : 450 + 40 * moment.grown.count
        try? await Task.sleep(for: .milliseconds(cascade))
        withAnimation(reduceMotion ? Motion.fade : Motion.pop) { beat = 2 }
        burst += 1
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 600))
        withAnimation(Motion.fade) { beat = 3 }
    }
}
