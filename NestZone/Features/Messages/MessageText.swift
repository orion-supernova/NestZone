import SwiftUI

/// A bubble's words, with the people it names set apart and whatever the chat
/// search is looking for marked.
///
/// Plain `Text` for the common case. The attributed version is built only for
/// a message that names somebody or matches the search, so a thread of
/// ordinary bubbles does no extra work.
struct MessageText: View {
    let content: String
    /// Display names of the people this message mentions.
    let mentionNames: [String]
    /// What the chat search is looking for; empty when it is closed.
    let highlight: String
    /// Mentions are accent-coloured in somebody else's bubble. In your own the
    /// bubble is the accent, so they are set apart by weight and an underline.
    let isMine: Bool

    @Environment(\.theme) private var theme

    var body: some View {
        if mentionNames.isEmpty && highlight.isEmpty {
            Text(content)
        } else {
            Text(attributed)
        }
    }

    private var attributed: AttributedString {
        var text = AttributedString(content)
        for name in mentionNames {
            mark(&text, "@\(name)", localized: false) { run in
                run.font = .subheadline.weight(.semibold)
                if isMine {
                    run.underlineStyle = .single
                } else {
                    run.foregroundColor = theme.ink
                }
            }
        }
        if !highlight.isEmpty {
            // The same matching the thread's filter uses, so every message the
            // search keeps has its match marked (Turkish dotted and dotless i
            // included).
            mark(&text, highlight, localized: true) { $0.backgroundColor = Palette.searchHighlight }
        }
        return text
    }

    /// Applies `style` to every occurrence of `needle`.
    private func mark(
        _ text: inout AttributedString,
        _ needle: String,
        localized: Bool,
        _ style: (inout AttributeContainer) -> Void
    ) {
        var container = AttributeContainer()
        style(&container)
        var from = content.startIndex
        while from < content.endIndex {
            let found = localized
                ? content[from...].localizedStandardRange(of: needle)
                : content[from...].range(of: needle, options: .caseInsensitive)
            guard let found, let range = Range(found, in: text) else { break }
            text[range].mergeAttributes(container)
            from = found.upperBound
        }
    }
}
