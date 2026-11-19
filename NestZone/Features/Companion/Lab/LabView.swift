#if DEBUG
import ComposableArchitecture
import SwiftUI

extension EnvironmentValues {
    /// The Lab's sheet is pulled all the way up: the card behind it is hidden,
    /// so the Lab shows a scene of its own.
    @Entry var labSheetIsFull = false
}

/// The Lab: Debug builds only, and the owner's way to see everything Nestie
/// can be. One master switch decides what it is for.
///
/// - **Off**, the card shows the real house and the Lab only changes how it
///   looks: a mood, the hour, the day, a hemisphere, a colour. Nothing here
///   is ever written.
/// - **On**, the card runs against a pretend house on this phone and every
///   control sets the house itself — the species, the jar, the album, the
///   vote — so every flow, ceremony and purchase card can be walked for real.
///
/// A medium sheet by design: the card above it is live while it changes (the
/// sheet lets Today scroll up to half height), and pulled all the way up it
/// brings a scene of its own.
struct LabView: View {
    let store: StoreOf<CompanionFeature>

    @Dependency(\.pretendHouse) private var pretendHouse
    @Environment(\.labSheetIsFull) private var isFull
    /// The pretend server's own house, which the card's read does not carry:
    /// a housemate's ballots, what is owned and not out.
    @State private var house = PretendState()

    var body: some View {
        VStack(spacing: 0) {
            if isFull, store.hasCompanion {
                LabPreview(store: store)
            }
            ScrollViewReader { proxy in
                Form {
                    LabModeSection(store: store)
                    if store.isPretend {
                        LabPresetsSection(store: store).id("presets")
                        LabCompanionSection(store: store, house: house).id("companion")
                        LabMoodSection(store: store, house: house).id("mood")
                        LabTimeSection(store: store, house: house).id("time")
                        LabSceneSection(store: store, house: house).id("scene")
                        LabJarSection(store: store, house: house).id("jar")
                        LabAlbumSection(store: store, house: house).id("album")
                        LabMomentsSection(store: store).id("moments")
                        LabHouseSection(store: store, house: house).id("house")
                        LabServerSection(store: store).id("server")
                    } else {
                        LabMoodSection(store: store, house: nil).id("mood")
                        LabTimeSection(store: store, house: nil).id("time")
                        LabColourSection(store: store).id("colour")
                    }
                    LabResetSection(store: store)
                }
                // `-labSection jar` opens the Lab scrolled to that section, to
                // photograph it on a simulator nobody can touch.
                .task {
                    guard let id = UserDefaults.standard.string(forKey: "labSection") else { return }
                    try? await Task.sleep(for: .seconds(1))
                    proxy.scrollTo(id, anchor: .top)
                }
            }
        }
        .navigationTitle(Text(verbatim: "Lab"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { store.send(.sheetDismissed) } label: { Text(verbatim: "Done") }
            }
        }
        .task(id: store.isPretend) {
            guard store.isPretend else { return }
            for await next in pretendHouse.houses() { house = next }
        }
    }
}

/// The scene, small, at the top of the Lab when the card behind it is hidden.
private struct LabPreview: View {
    let store: StoreOf<CompanionFeature>

    var body: some View {
        CardScene(store: store, compact: false, covered: false)
            .frame(height: 170)
            .clipShape(.rect(cornerRadius: Metrics.cardRadius, style: .continuous))
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }
}

// MARK: - The switch

private struct LabModeSection: View {
    let store: StoreOf<CompanionFeature>

    var body: some View {
        Section {
            Toggle(isOn: store.labBinding(\.isPretend) { .pretend($0) }) {
                Label { Text(verbatim: "Pretend house") } icon: { Image(systemName: "theatermasks.fill") }
            }
            .tint(Palette.warning)
        } footer: {
            Text(verbatim: store.isPretend
                 ? "The card runs on a stand-in server on this phone, with no network. Care, buying, decorating, the vote and the ceremonies all work for real, and none of it reaches your house. It is kept between launches."
                 : "You are looking at your real house. The Lab can only change how it looks (a mood, the hour, the day, a hemisphere, a colour) and writes nothing. Turn this on to change the house itself.")
        }
    }
}

// MARK: - Presets

private struct LabPresetsSection: View {
    let store: StoreOf<CompanionFeature>

    var body: some View {
        Section {
            ForEach(PretendPreset.allCases) { preset in
                Button { store.lab(.preset(preset)) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Label { Text(verbatim: preset.title) } icon: { Image(systemName: preset.symbol) }
                        Text(verbatim: preset.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(verbatim: "Presets")
        } footer: {
            Text(verbatim: "One tap sets the whole pretend house, the day and the people in it.")
        }
    }
}

// MARK: - Reset

private struct LabResetSection: View {
    let store: StoreOf<CompanionFeature>
    @State private var confirming = false

    var body: some View {
        Section {
            LabButton(title: "Reset all Lab overrides", symbol: "arrow.counterclockwise") {
                store.lab(.resetOverrides)
            }
            if store.isPretend {
                LabButton(title: "Reset the pretend house", symbol: "trash", role: .destructive) { confirming = true }
            }
        } footer: {
            Text(verbatim: store.isPretend
                 ? "Overrides are the mood, the day, the birthday and the switches below. Resetting the pretend house starts it over as a magnolia a few days old."
                 : "Overrides are the mood, the day, the hemisphere, the birthday and the colour.")
        }
        .confirmationDialog(Text(verbatim: "Reset the pretend house?"), isPresented: $confirming, titleVisibility: .visible) {
            Button(role: .destructive) { store.lab(.resetPretend) } label: { Text(verbatim: "Reset") }
        } message: {
            Text(verbatim: "The album, the jar and the scene of the pretend house are gone. Your real house is not touched.")
        }
    }
}
#endif
