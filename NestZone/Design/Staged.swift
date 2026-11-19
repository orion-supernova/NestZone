import SwiftUI

/// A segment's first build, in beats rather than in one frame.
///
/// Building a screen is one block of main-thread work, and the first time a
/// segment is chosen that block is 150–300 ms on the simulator: the underline
/// stops half way and the fade starts late. The screen is not slow to *show*,
/// it is slow to *make*, so what nobody can see yet is made a frame later,
/// and the next piece a frame after that. A page is built at no opacity and
/// fades in over a quarter of a second, and each piece fades up as it lands,
/// so it arrives into the fade instead of popping into a finished picture.
///
/// A screen opts in at its root with `stagedBuild(_:)` and marks the pieces
/// that may wait with `Staged`. What holds the screen up (its bar, its search,
/// the container the pieces sit in) is not staged, and neither is a `List`'s
/// content: staged, a list is nothing at first, and a screen that is nothing
/// has no toolbar either. Tried on Tasks, Shopping and Recipes, where the rows
/// or the whole list waiting moved nothing measurable.
///
/// Only a first build is staged. The beat lives with the screen, so a segment
/// that is kept alive and returned to is already at its last one and nothing
/// waits on the way back. A segment left before it has finished simply stops
/// where it is and carries on when it returns: nothing is built for nobody.
extension View {
    /// Builds the screen's staged pieces one beat after another, `beats` of
    /// them, once the screen is on stage. Beat 0 is the screen without any;
    /// `Staged(n)` appears with beat `n`.
    func stagedBuild(_ beats: Int) -> some View {
        modifier(StagedBuild(beats: beats))
    }
}

extension EnvironmentValues {
    /// The last beat reached. Everything is built outside a staged screen.
    @Entry var buildBeat: Int = .max
}

private struct StagedBuild: ViewModifier {
    let beats: Int
    @State private var beat = 0
    @LivePhase private var phase

    func body(content: Content) -> some View {
        let onStage = phase == .onScreen
        content
            .environment(\.buildBeat, beat)
            // Not before the screen is on stage: the stage is where its bar
            // items and search arrive, and a piece built in the same frame
            // would be one more thing in it.
            .task(id: onStage) {
                guard onStage else { return }
                await build()
            }
    }

    /// A beat waits for a frame, not for a time. A sleep that ran out while
    /// the beat before it was still being built resumed the moment the main
    /// thread was free, ahead of the frame that would have drawn that beat,
    /// and two or three beats were made in one block.
    private func build() async {
        while beat < beats {
            await FrameTick.next()
            guard !Task.isCancelled else { return }
            beat += 1
        }
    }
}

/// A piece of a screen that is made at beat `beat` of `stagedBuild(_:)`, and
/// fades in with it.
///
/// Type-erased on purpose, and only here. A generic `Staged<Content>` puts the
/// piece's whole type into the screen's own, and SwiftUI looks every part of
/// that type up (its conformances, its metadata) when the screen is made,
/// whether or not the piece is built yet; behind `AnyView` the type is only
/// looked up when the closure runs, which is the beat.
struct Staged: View {
    let beat: Int
    let fades: Bool
    let content: () -> AnyView

    @Environment(\.buildBeat) private var reached
    /// Whether this piece was made before its beat. Only a piece that had to
    /// wait arrives with a fade: one made when a face is switched to, long
    /// after the first build, has a transition of its own.
    @State private var waited = false

    /// `fades: false` for a piece whose content stages its own entrances
    /// (`appear`, `drawIn`): they already arrive in turn, and a parent fading
    /// as well makes them later and softer. `beat` must not exceed the
    /// screen's `stagedBuild(_:)`, or the piece is never built; the two are
    /// written in different places and nothing checks them against each other.
    init(_ beat: Int, fades: Bool = true, @ViewBuilder content: @escaping () -> some View) {
        self.beat = beat
        self.fades = fades
        self.content = { AnyView(content()) }
    }

    var body: some View {
        Group {
            if reached >= beat {
                content().modifier(StagedArrival(fades: fades && waited))
            }
        }
        .onChange(of: reached >= beat, initial: true) { _, built in
            if !built { waited = true }
        }
    }
}

/// How a staged piece that waited arrives: it is made at no opacity and fades
/// up. A fade is not travel, so Reduce Motion keeps it.
private struct StagedArrival: ViewModifier {
    let fades: Bool
    @State private var arrived: Bool

    init(fades: Bool) {
        self.fades = fades
        _arrived = State(initialValue: !fades)
    }

    func body(content: Content) -> some View {
        content
            .opacity(arrived ? 1 : 0)
            .onAppear { if !arrived { withAnimation(Motion.fade) { arrived = true } } }
    }
}

/// Suspends until the display's next frame, so work that follows begins after
/// the frame in between has been drawn.
@MainActor
final class FrameTick: NSObject {
    private var link: CADisplayLink?
    private var continuation: CheckedContinuation<Void, Never>?

    static func next() async {
        let tick = FrameTick()
        // A cancelled build does not wait out the frame: the tick fires at
        // once, the display link goes with it, and the caller sees the
        // cancellation on its next line.
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                tick.continuation = continuation
                let link = CADisplayLink(target: tick, selector: #selector(fire))
                tick.link = link
                link.add(to: .main, forMode: .common)
            }
        } onCancel: {
            Task { @MainActor in tick.fire() }
        }
    }

    @objc private func fire() {
        link?.invalidate()
        link = nil
        continuation?.resume()
        continuation = nil
    }
}
