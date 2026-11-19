#if DEBUG
import ComposableArchitecture
import Foundation

/// The Lab's settings, kept on this phone (`SharedKey.companionLab`).
///
/// The Lab has two modes, and the master switch between them decides what it
/// may do:
///
/// - **The real house** (the default, `pretend` off): the card is served live
///   and untouched. The Lab offers only what is drawn differently and never
///   written (`look`): a mood, an hour and a day, a birthday, a hemisphere, a
///   colourway.
/// - **A pretend house**: the card runs against a stand-in server on this
///   phone (`FakeNestieServer`), through the same `CompanionClient`
///   dependency, so every flow works for real and nothing leaves the phone.
///   The Lab then controls the house itself, not only how it looks.
///
/// Everything else the pretend house is — the jar, the album, the vote — is
/// in `PretendState`, which the stand-in server keeps. Only what the reducer
/// has to know on its own is here.
struct CompanionLab: Codable, Equatable, Sendable {
    /// The card runs against the pretend house. Off until it is turned on.
    var pretend = false
    /// What is pretended about how the house looks (both modes).
    var look = LabLook()
    /// People in the pretend house: the mood needs two of them to be bright,
    /// and a vote needs the others. The server's copy is told whenever this
    /// changes (`LabAction.members`).
    var members = 1
    /// How long the pretend server takes to answer, and whether it answers at
    /// all.
    var latency = 150
    var offline = false
    /// The answer the next purchase will get, whatever it would honestly be:
    /// `owned`, `short`, `unavailable` or `priceChanged`. It is cleared when
    /// the purchase is answered.
    var nextBuy: String?

    init() {}

    enum CodingKeys: String, CodingKey { case pretend, look, members, latency, offline, nextBuy }

    /// Lenient, like every file this app keeps: a Lab file from before the
    /// pretend house (points, coins) is read as a fresh one.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pretend = (try? c.decodeIfPresent(Bool.self, forKey: .pretend)) ?? false
        look = (try? c.decodeIfPresent(LabLook.self, forKey: .look)) ?? LabLook()
        members = min(max((try? c.decodeIfPresent(Int.self, forKey: .members)) ?? 1, 1), 3)
        latency = (try? c.decodeIfPresent(Int.self, forKey: .latency)) ?? 150
        offline = (try? c.decodeIfPresent(Bool.self, forKey: .offline)) ?? false
        nextBuy = (try? c.decodeIfPresent(String.self, forKey: .nextBuy)) ?? nil
    }
}

extension SharedKey where Self == FileStorageKey<CompanionLab>.Default {
    /// One home's Lab on this phone, for Debug builds. The overrides it holds
    /// are never sent anywhere, and the pretend house it switches on never
    /// reaches the server.
    ///
    /// The house's companion itself is the server's (`CompanionClient`). The
    /// MVP's own file, `companion-<home>.json`, is only read once, to be
    /// offered to the house (`LocalCompanion`), and is never written.
    static func companionLab(_ homeID: HomeID) -> Self {
        Self[
            .fileStorage(.documentsDirectory.appending(component: "companionLab-\(homeID.rawValue).json")),
            default: CompanionLab()
        ]
    }
}
#endif
