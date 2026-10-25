import ComposableArchitecture
import SwiftUI

/// After the finale, a species the house has grown asks which colour first:
/// three swatches, each the species' small still in that colourway with the
/// colourway's name. A colour already grown is marked and cannot be picked.
/// Floats over Choose like the purchase card: glass, snapped to the bottom.
struct ColourPickerLayer: View {
    let store: StoreOf<CompanionFeature>

    var body: some View {
        ZStack(alignment: .bottom) {
            if let species = store.colourChoice {
                Palette.dim
                    .ignoresSafeArea()
                    .onTapGesture { store.send(.colourDismissed, animation: Motion.exit) }
                    .transition(.opacity)
                    .accessibilityHidden(true)
                ColourPickerCard(store: store, species: species)
                    .transition(.move(edge: .bottom))
            }
        }
    }
}

private struct ColourPickerCard: View {
    let store: StoreOf<CompanionFeature>
    let species: Species

    @Environment(\.shopStage) private var stage
    @Environment(\.dynamicTypeSize) private var typeSize

    private static let cardShape = UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous)

    var body: some View {
        let big = typeSize.isAccessibilitySize
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.colourPickTitle(String(localized: species.title)))
                        .font(.title3.weight(.bold))
                        .oneLine()
                        .accessibilityAddTraits(.isHeader)
                    Text(L10n.colourPickHint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .oneLineUnlessAccessibility()
                }
                Spacer()
                IconButton(symbol: "xmark", label: L10n.commonClose) { store.send(.colourDismissed, animation: Motion.exit) }
                    .foregroundStyle(.primary)
            }
            let layout = big ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
            layout {
                ForEach(Array(Colourway.range), id: \.self) { colour in
                    swatch(colour, big: big)
                }
            }
            SecondaryButton(L10n.colourPickOriginal) {
                store.send(.colourPicked(species, nil), animation: Motion.exit)
            }
            .accessibilityIdentifier("Colour.original")
        }
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background {
            Self.cardShape.fill(Palette.cardWash)
                .glassEffect(.regular, in: Self.cardShape)
                .ignoresSafeArea(edges: .bottom)
        }
        .tint(.primary)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .task {
            // The three stills, drawn once and kept, so the swatches are not
            // three canvases recorded in the frame the card comes up.
            await StillCache.warm(Colourway.range.map { colour in
                let portrait = portrait(colour)
                return (portrait.still(big: big), AnyView(portrait))
            })
        }
    }

    private func portrait(_ colour: Int) -> SpeciesPortrait {
        SpeciesPortrait(
            species: species, seed: "\(store.homeID.rawValue)-\(store.house.albumCount)", hour: stage.portraitHour,
            colourway: colour
        )
    }

    private func swatch(_ colour: Int, big: Bool) -> some View {
        let grown = store.house.hasGrown(species, colour: colour)
        let name = String(localized: species.colourName(colour))
        return Button {
            store.send(.colourPicked(species, colour), animation: Motion.exit)
        } label: {
            VStack(spacing: 6) {
                portrait(colour).tile(big: big)
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .background(RoundedRectangle(cornerRadius: 10).fill(SheetInk.spotFill))
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay(alignment: .topTrailing) {
                        if grown {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Palette.success)
                                .padding(6)
                        }
                    }
                Text(verbatim: name)
                    .font(.subheadline.weight(.semibold))
                    .oneLine()
                if grown {
                    Text(L10n.colourGrown)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .oneLine()
                }
            }
            .frame(maxWidth: .infinity)
            .opacity(grown ? 0.5 : 1)
        }
        .buttonStyle(.pressable)
        .disabled(grown)
        .accessibilityLabel(Text(verbatim: grown ? "\(name), \(String(localized: L10n.colourGrown))" : name))
        .accessibilityIdentifier("Colour.\(colour)")
    }
}
