import SwiftUI

/// A single line of a household's timeline.
///
/// Its own small view rather than a branch inside the list, so SwiftUI compares
/// one row's stored values instead of re-evaluating the whole section's body
/// when a single timestamp label ticks over.
///
/// Face first, then one sentence with the person in bold, then the module as a
/// glyph in its own tint beside the detail. Colour is the glyph's alone: the
/// words stay in the label colours, and "new" is a dot and a wash inside the
/// row, never something hung off its corner.
///
/// `inRun` is the same row inside an opened stretch (`ActivityRunHeader`): the
/// person is already said above it, so it leads with the thing itself.
struct ActivityRow: View {
    let row: HomeActivity
    let isNew: Bool
    /// Its place in the whole feed, for the wave "Mark all read" sends down it.
    let order: Int
    var inRun = false
    let action: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// "**Murat** finished Dishes". The name is dropped from the title when the
    /// server already wrote it there, so it is never said twice.
    private var sentence: Text {
        guard let name = row.shownActorName else { return Text(row.title).fontWeight(.semibold) }
        let rest = row.title.hasPrefix(name)
            ? String(row.title.dropFirst(name.count)).trimmingCharacters(in: .whitespaces)
            : row.title
        return Text(name).fontWeight(.bold) + Text(verbatim: " ") + Text(rest)
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                if inRun {
                    Color.clear.frame(width: 34, height: 1)
                } else {
                    face
                }

                VStack(alignment: .leading, spacing: 2) {
                    if inRun {
                        Text(row.body.isEmpty ? row.title : row.body)
                            .font(.subheadline)
                            .lineLimit(1)
                    } else {
                        sentence
                            .font(.subheadline)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Image(systemName: row.category.symbol)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(row.category.tint)
                            Text(row.body.isEmpty ? String(localized: row.category.label) : row.body)
                                .font(.footnote)
                                .foregroundStyle(.secondaryText)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 4) {
                    RelativeTimeText(row.created)
                        .font(.caption)
                        .foregroundStyle(.secondaryText)
                    if isNew {
                        Circle()
                            .fill(theme.accent)
                            .frame(width: 8, height: 8)
                            .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                            .accessibilityHidden(true)
                    }
                }

                if row.category.isRoutable {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Palette.accessory)
                }
            }
            .padding(.vertical, inRun ? 7 : 9)
            .padding(.horizontal, Metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isNew ? theme.accent.opacity(0.07) : .clear)
            // Read, one row after another rather than all at once, so marking
            // everything read looks like something swept down the list. The
            // stagger is capped, so a long feed is not still going a second
            // later; under Reduce Motion the rows fade together.
            .animation(
                reduceMotion
                    ? Motion.fade
                    : Motion.exit.delay(Motion.stagger(order, step: 0.03, cap: 0.3)),
                value: isNew
            )
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .disabled(!row.category.isRoutable)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(row.category.isRoutable ? .isButton : [])
    }

    /// Who did it. The module's own glyph stands in when the app did it by
    /// itself (a nightly sweep finding an overdue bill).
    @ViewBuilder
    private var face: some View {
        if let actor = row.actor, let name = row.shownActorName {
            // `viewable: false`: this whole row is a control that goes
            // somewhere else, and a tappable face would swallow that tap.
            Avatar(initials: User.initials(from: name), seed: actor.rawValue, size: 34, viewable: false)
        } else {
            Image(systemName: row.category.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(row.category.tint)
                .frame(width: 34, height: 34)
                .background(row.category.tint.opacity(0.16), in: .circle)
        }
    }
}
