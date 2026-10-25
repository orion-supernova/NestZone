import Foundation

/// A favourite species grown again in a new colour. 0 is the original, the
/// way the species has always looked; 1, 2 and 3 are three curated palettes
/// for it (the names are `Species.colourName`, and the rules are
/// `Docs/Companion/art/RULES.md`, section 17).
///
/// The type itself (`range`, `key`, `read`) is the finale's, in `CompanionModels`; this is what the painters ask of it.
///
/// The drawing never asks whether a colourway "exists": a number is clamped
/// to 0...3, and every painter has a row for all four, so a build that is
/// handed a colour it has not heard of (a newer server) draws the original.
///
/// A colourway is a palette and a pattern, never new geometry: it is carried
/// as a number to every layer that is cached or compared (`TreeState`,
/// `Canopy`, `StillSpec`), so a new one redraws what was kept and what was
/// kept for another colour is never shown for this one.
extension Colourway {
    /// How many colours a species has besides the original.
    static var count: Int { range.count }

    /// The colourway a stored number means: nothing, or one this build does not
    /// know, is the original.
    static func clamp(_ colour: Int?) -> Int {
        guard let colour, range.contains(colour) else { return 0 }
        return colour
    }

    /// What is drawn for a companion that holds `colour`. On a Debug build
    /// `-nestieColour <n>` draws a companion that has none in that colour
    /// (the bench, a scene on the simulator), so every species can be seen
    /// in every colour without a flow to get there; a colour a companion holds
    /// wins over it. Release builds have no override.
    static func drawn(_ colour: Int?) -> Int {
#if DEBUG
        if colour == nil, let launch = launchOverride { return launch }
#endif
        return clamp(colour)
    }

#if DEBUG
    static let launchOverride: Int? = {
        guard UserDefaults.standard.object(forKey: "nestieColour") != nil else { return nil }
        return clamp(UserDefaults.standard.integer(forKey: "nestieColour"))
    }()
#endif
}
