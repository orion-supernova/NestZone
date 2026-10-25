import ComposableArchitecture
import SwiftUI

// The house's vote for its next companion: a section of the card on Today
// while the one growing is still a seed, and a sheet to answer in.
//
// Every portrait here is a `ScenePortrait` (one still canvas), never a live
// `CompanionScene`, and each view reads only the part of the store it draws, so
// a push that moves one tally redraws the rows and not the card around them.
// Nothing runs continuously: the only motion is a badge popping in under a
// person's own tap.

// MARK: - On the card

/// What stands where the growth bar is while the house has not chosen: the
/// options as little portraits with this person's own answers on them, who has
/// answered, when it closes, and the way in. When there is no vote to answer
/// (it ended with no yes, or it could not be read) it is the way to pick.
struct CardVote: View {
    let store: StoreOf<CompanionFeature>

    var body: some View {
        if store.isOpeningVote {
            // Graduated a moment ago: the vote is opening, and nothing to pick yet.
            Text(L10n.voteOpening)
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if let vote = store.vote, vote.isOpen {
            VoteSummary(store: store, vote: vote)
        } else if store.vote?.winner == nil {
            // Nobody said yes, or no vote: whoever picks first picks.
            VStack(alignment: .leading, spacing: 10) {
                if store.vote?.status == .closed {
                    Text(L10n.voteNobody)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                PrimaryButton(L10n.companionChoose, symbol: "sparkles") { store.send(.chooseTapped) }
                    .accessibilityIdentifier("CompanionChoose")
            }
        }
        // A vote that has chosen: the push that turns the seed into it is on
        // its way, and there is nothing left to ask.
    }
}

private struct VoteSummary: View {
    let store: StoreOf<CompanionFeature>
    let vote: CompanionVote
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ForEach(vote.options) { option in
                    VoteThumb(option: option, seed: store.look?.seed ?? "", answer: vote.mine[option.id])
                        .equatable()
                }
            }
            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 6))) {
                Text(L10n.voteAnswered(vote.answered, vote.members))
                    .oneLineUnlessAccessibility()
                if !typeSize.isAccessibilitySize { Spacer(minLength: 4) }
                VoteCloses(date: vote.closesAt)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if vote.hasAnsweredAll {
                SecondaryButton(L10n.voteChange, symbol: "hand.raised.fill") { store.send(.voteTapped) }
                    .accessibilityIdentifier("CompanionVote")
            } else {
                PrimaryButton(L10n.voteVote, symbol: "hand.raised.fill") { store.send(.voteTapped) }
                    .accessibilityIdentifier("CompanionVote")
            }
        }
    }
}

/// "Closes Sat, 25 Oct, 14:30" — a plain date, no countdown. The date is
/// formatted by `Text`, in the app's language, not by the body.
struct VoteCloses: View, Equatable {
    let date: Date

    private static let format = Date.FormatStyle().weekday(.abbreviated).day().month(.abbreviated).hour().minute()

    var body: some View {
        // A deadline the server did not give is not one to state.
        if date != .distantFuture {
            HStack(spacing: 4) {
                Text(L10n.voteCloses)
                Text(date, format: Self.format)
            }
            .oneLine()
        }
    }
}

/// One option, small, with this person's answer on its corner.
private struct VoteThumb: View, Equatable {
    let option: CompanionVote.Option
    let seed: String
    let answer: Bool?

    @ScaledMetric(relativeTo: .body) private var scaled = 72.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Three of them share a card's width: at the largest text sizes they
    /// stop growing.
    private var side: CGFloat { min(scaled, 96) }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.option.id == rhs.option.id && lhs.seed == rhs.seed && lhs.answer == rhs.answer
    }

    var body: some View {
        Portrait(species: option.species, seed: seed)
            .frame(width: side, height: side)
            .clipShape(.rect(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                if let answer {
                    AnswerBadge(yes: answer)
                        .offset(x: 5, y: 5)
                        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                }
            }
            .animation(Motion.pop, value: answer)
            .accessibilityElement()
            .accessibilityLabel(Text(label))
    }

    private var label: LocalizedStringResource {
        let name = option.species.map { String(localized: $0.title) } ?? String(localized: L10n.voteUnknownKind)
        return switch answer {
        case true?: L10n.voteYouYes(name)
        case false?: L10n.voteYouNo(name)
        case nil: L10n.voteNotAnswered(name)
        }
    }
}

/// A species drawn still, or — for one this build cannot draw — a quiet blank.
private struct Portrait: View {
    let species: Species?
    let seed: String

    /// One moment for every portrait here, so a push that moves a tally does
    /// not hand the canvases a new `Date()` and redraw them.
    private static let noon = Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: Date()) ?? Date()

    var body: some View {
        if let species {
            SpeciesPortrait(species: species, seed: seed, mood: .content, now: Self.noon)
        } else {
            Image(systemName: "questionmark")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.inset)
        }
    }
}

private struct AnswerBadge: View {
    let yes: Bool

    var body: some View {
        Image(systemName: yes ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.system(size: 20, weight: .bold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, yes ? Palette.success : Palette.danger)
            .accessibilityHidden(true)
    }
}

// MARK: - The sheet

/// Answering, and what comes of it: yes or no to each option, who has
/// answered, when it closes, "settle it" for the one who would rather not
/// wait, and — while nobody else has answered — picking straight away.
struct VoteView: View {
    let store: StoreOf<CompanionFeature>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let vote = store.vote {
                    if vote.isOpen {
                        VoteOpen(store: store, vote: vote)
                    } else {
                        VoteOver(store: store, vote: vote)
                    }
                } else {
                    VoteWaiting(store: store)
                }
            }
            .padding(Metrics.screenPadding)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(Text(L10n.companionNextTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { store.send(.sheetDismissed) } label: { Text(L10n.commonDone) }
            }
        }
        // The person's own tap, felt once; the pressable buttons are quiet.
        .sensoryFeedback(.selection, trigger: store.ballotTick)
        .animation(Motion.fade, value: store.voteNote)
        .accessibilityIdentifier("CompanionVoteSheet")
    }
}

/// The sheet opened ahead of the vote it is waiting for.
private struct VoteWaiting: View {
    let store: StoreOf<CompanionFeature>
    /// A vote that never comes (it cannot be read) must not spin for ever.
    @State private var gaveUp = false

    var body: some View {
        VStack(spacing: 14) {
            if gaveUp {
                Text(L10n.voteNobody)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                SecondaryButton(L10n.votePickInstead, symbol: "sparkles") { store.send(.pickInsteadTapped) }
            } else {
                ProgressView()
                Text(L10n.voteLoading)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .task {
            try? await Task.sleep(for: .seconds(5))
            gaveUp = true
        }
    }
}

private struct VoteOpen: View {
    let store: StoreOf<CompanionFeature>
    let vote: CompanionVote

    var body: some View {
        Text(L10n.voteHint)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        ForEach(vote.options) { option in
            VoteOptionRow(store: store, option: option, answer: vote.mine[option.id], seed: store.look?.seed ?? "")
                .equatable()
        }
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(L10n.voteAnswered(vote.answered, vote.members))
                .oneLine()
            Spacer(minLength: 4)
            VoteCloses(date: vote.closesAt)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        VoteSettle(store: store, vote: vote)
    }
}

private struct VoteOptionRow: View, Equatable {
    let store: StoreOf<CompanionFeature>
    let option: CompanionVote.Option
    let answer: Bool?
    let seed: String

    @ScaledMetric(relativeTo: .body) private var scaled = 92.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var side: CGFloat { min(scaled, 132) }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.option == rhs.option && lhs.answer == rhs.answer && lhs.seed == rhs.seed
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Portrait(species: option.species, seed: seed)
                .frame(width: side, height: side)
                .clipShape(.rect(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(.headline)
                    .oneLine()
                Text(kind)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .oneLine()
                Text(L10n.voteCounts(option.yes, option.no))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    // The digits roll; with Reduce Motion they just change.
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .animation(reduceMotion ? nil : Motion.dataDraw, value: option.yes)
                    .animation(reduceMotion ? nil : Motion.dataDraw, value: option.no)
                    .oneLine()
                HStack(spacing: 8) {
                    AnswerButton(yes: true, selected: answer == true, name: name) {
                        store.send(.ballotTapped(option.id, yes: true))
                    }
                    AnswerButton(yes: false, selected: answer == false, name: name) {
                        store.send(.ballotTapped(option.id, yes: false))
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.inset, in: .rect(cornerRadius: Metrics.tightRadius, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Vote.\(option.id)")
    }

    private var name: String {
        option.species.map { String(localized: $0.title) } ?? String(localized: L10n.voteUnknownKind)
    }

    private var kind: String {
        let base = String(localized: option.isPet ? L10n.voteKindPet : L10n.voteKindPlant)
        return option.grown ? "\(base) · \(String(localized: L10n.voteInAlbum))" : base
    }
}

/// Yes or no. The one that is this person's answer is filled; tapping it again
/// takes the answer back.
private struct AnswerButton: View {
    let yes: Bool
    let selected: Bool
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(yes ? L10n.voteYes : L10n.voteNo)
                    .oneLine()
            } icon: {
                Image(systemName: symbol)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(selected ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .frame(minHeight: Metrics.minTapTarget)
            .background {
                Capsule().fill(selected ? (yes ? Palette.success : Palette.danger) : Palette.inset)
            }
            .overlay { Capsule().strokeBorder(Color.secondary.opacity(selected ? 0 : 0.35), lineWidth: 1) }
            .contentShape(.capsule)
            .animation(Motion.fade, value: selected)
        }
        .buttonStyle(.pressableQuiet)
        .accessibilityLabel(Text(yes ? L10n.voteYesFor(name) : L10n.voteNoFor(name)))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var symbol: String {
        if yes { selected ? "hand.thumbsup.fill" : "hand.thumbsup" } else { selected ? "hand.thumbsdown.fill" : "hand.thumbsdown" }
    }
}

/// "Settle it": count what is in, now. And, while nobody else has answered,
/// the straight pick.
private struct VoteSettle: View {
    let store: StoreOf<CompanionFeature>
    let vote: CompanionVote

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if vote.othersVoted {
                PrimaryButton(L10n.voteSettle, symbol: "checkmark.seal.fill", isLoading: store.isDeciding) {
                    store.send(.settleTapped)
                }
                .accessibilityIdentifier("CompanionSettle")
            } else {
                SecondaryButton(L10n.voteSettle, symbol: "checkmark.seal.fill") { store.send(.settleTapped) }
                    .accessibilityIdentifier("CompanionSettle")
            }
            Text(L10n.voteSettleHint)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            // Only while it still holds: somebody answering since makes it stale.
            if let note = store.voteNote, note == .alone ? !vote.othersVoted : !vote.hasYes {
                Text(note == .alone ? L10n.voteNoteAlone : L10n.voteNoteNoYes)
                    .font(.footnote.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
            // Nobody else has answered, so this is a pick and nobody is
            // waited on; once somebody has, the ballots decide.
            if !vote.othersVoted {
                SecondaryButton(L10n.votePickInstead, symbol: "sparkles") { store.send(.pickInsteadTapped) }
                    .accessibilityIdentifier("CompanionPickInstead")
            }
        }
    }
}

/// A vote that is over, while its sheet is still up: who won, or that nobody
/// said yes and anyone may pick.
private struct VoteOver: View {
    let store: StoreOf<CompanionFeature>
    let vote: CompanionVote

    var body: some View {
        if let winner = vote.winner {
            VStack(spacing: 12) {
                Portrait(species: Species(rawValue: winner), seed: store.look?.seed ?? "")
                    .frame(height: 180)
                    .clipShape(.rect(cornerRadius: Metrics.tightRadius, style: .continuous))
                    .accessibilityHidden(true)
                Text(L10n.voteResultTitle(Species(rawValue: winner).map { String(localized: $0.title) } ?? String(localized: L10n.voteUnknownKind)))
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.voteNobody)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                PrimaryButton(L10n.companionChoose, symbol: "sparkles") { store.send(.pickInsteadTapped) }
            }
        }
    }
}
