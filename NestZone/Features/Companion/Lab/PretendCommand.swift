#if DEBUG
import Foundation

/// Everything the Lab can do to the pretend house. Each is a change to the
/// stand-in server's own state, which then pushes it to the card as it would
/// any change another phone made: the screen shows it the way it shows the
/// real thing, and nothing is faked on the client.
public enum PretendCommand: Equatable, Sendable {
    // The one growing.
    case giveCompanion(Species)
    case setSpecies(Species)
    case setColour(Int?)
    case setStage(Int)
    /// How far through its stage it is, 0...1; 1 is all grown.
    case setStageShare(Double)
    /// To the next stage, paying it into the jar as growing would.
    case stageUp
    /// Points added or taken away, clamped to what there is.
    case addPoints(Double)
    case makeReady
    case setDaysGrown(Int)
    case newSeed
    case removeCompanion
    /// Back to a house nobody has welcomed: no companion, the gift still to come.
    case freshHouse

    // How the house has been.
    case setLastCare(hoursAgo: Double?)
    case quiet(days: Int)
    case setCareStreak(Int, today: Bool)
    /// `by` is a person: `u0` is the one holding the phone.
    case chore(by: String)

    // Where and when.
    case setRegion(String)
    case setTzOffset(Int)
    case celebrateAll(Bool)

    // The scene.
    case place(String, Spot)
    /// The tree takes up to four things: one put on or taken off.
    case toggleTree(String)
    case clearSpot(Spot)
    case clearScene
    case fillScene
    case ownAllDecor(Bool)

    // The jar and the shop.
    case setLeaves(Int)
    case setSparkles(Int)
    case ownDecor(String, Bool)
    case ownSpecies(Species, Bool)
    case ownAllSpecies(Bool)
    /// The Sparkles a test-store purchase buys.
    case topUp(Int)

    // The album and the finale.
    case fillAlbum(Int)
    case growAllFree
    case growColours(Int)
    case clearAlbum

    // The house.
    case setMembers(Int)
    case openVote
    case ballot(member: Int, species: String, answer: Bool?)
    case othersAnswerAll
    case closeVote(VoteClosing)
    case memberLeaves

    case preset(PretendPreset)
    case reset

    // How the server behaves (not part of the house, so not kept).
    case setLatency(Int)
    case setOffline(Bool)
    case nextBuy(String?)

    public enum VoteClosing: String, Equatable, Sendable { case deadline, everyone }
}

extension PretendState {
    /// Applies one command to the house. The server behaviours (latency, a
    /// dropped connection, the next purchase's answer) are the actor's.
    mutating func apply(_ command: PretendCommand, now: Date) {
        switch command {
        case let .giveCompanion(species):
            if current == nil {
                current = Current(
                    id: "companion-\(albumCount + 1)-lab", species: species, seed: "pretend-\(albumCount)",
                    startedAt: now, points: 0
                )
                welcomed = true
            } else {
                apply(.setSpecies(species), now: now)
            }
        case let .setSpecies(species):
            guard var c = current else { return apply(.giveCompanion(species), now: now) }
            c.species = species
            c.undecided = false
            current = c
            markStagePaid()
        case let .setColour(colour):
            current?.colour = Colourway.read(colour)
        case let .setStage(stage):
            guard var c = current else { return }
            let t = thresholds(isPet: c.species.isPet)
            c.points = t[min(max(stage, 0), t.count - 1)] * PretendRules.graduateAt + 0.001
            c.undecided = false
            current = c
            markStagePaid()
        case let .setStageShare(share):
            guard var c = current else { return }
            let t = thresholds(isPet: c.species.isPet)
            let k = stage(of: c)
            let low = t[k], high = k + 1 < t.count ? t[k + 1] : 1
            c.points = min((low + min(max(share, 0), 1) * (high - low)) * PretendRules.graduateAt + 0.001, PretendRules.graduateAt)
            current = c
            markStagePaid()
        case .stageUp:
            guard var c = current, !c.undecided else { return }
            let t = thresholds(isPet: c.species.isPet)
            let next = stage(of: c) + 1
            c.points = next < t.count ? t[next] * PretendRules.graduateAt + 0.001 : PretendRules.graduateAt
            current = c
            settleStages(now: now)
        case let .addPoints(points):
            guard var c = current else { return }
            c.points = min(max(c.points + points, 0), PretendRules.graduateAt)
            current = c
            markStagePaid()
        case .makeReady:
            guard var c = current else { return }
            c.points = PretendRules.graduateAt
            c.undecided = false
            c.startedAt = min(c.startedAt, now.addingTimeInterval(-(PretendRules.floorDays + 1) * PretendRules.day))
            current = c
            markStagePaid()
        case let .setDaysGrown(days):
            current?.startedAt = now.addingTimeInterval(-Double(max(days, 0)) * PretendRules.day)
        case .newSeed:
            current?.seed = "pretend-\(UUID().uuidString.prefix(6))"
        case .removeCompanion:
            current = nil
            vote = nil
        case .freshHouse:
            current = nil
            vote = nil
            welcomed = false
            hasHouse = true

        case let .setLastCare(hours):
            current?.lastCare = hours.map { now.addingTimeInterval(-$0 * 3_600) }
        case let .quiet(days):
            quiet(days: days, now: now)
        case let .setCareStreak(length, today):
            guard var c = current else { return }
            let calendar = Calendar.current
            let first = today ? 0 : 1
            c.careDays = (0..<max(length, 0)).compactMap { offset in
                calendar.date(byAdding: .day, value: -(first + offset), to: now).map(dayKey)
            }
            if length > 0 { c.lastCare = now.addingTimeInterval(-Double(first) * PretendRules.day) }
            current = c
        case let .chore(user):
            recent.insert(Recent(kind: "chore", at: now, user: user), at: 0)
            if recent.count > 120 { recent.removeLast() }
            if var c = current {
                c.points = min(c.points + PretendRules.chorePoints, PretendRules.graduateAt)
                current = c
                settleStages(now: now)
            }

        case let .setRegion(code):
            region = code
        case let .setTzOffset(minutes):
            tzOffset = minutes
        case let .celebrateAll(on):
            holidays = on ? Holiday.all.map(\.id.rawValue) : nil

        case let .place(raw, spot):
            place(raw, in: spot)
        case let .toggleTree(raw):
            if let index = layout.tree.firstIndex(of: raw) { layout.tree.remove(at: index) } else { place(raw, in: .tree) }
        case let .clearSpot(spot):
            if spot == .tree { layout.tree = [] } else { layout[spot] = nil }
        case .clearScene:
            layout = SceneLayout()
        case .fillScene:
            owned.formUnion(DecorItem.allCases.map(\.rawValue))
            layout = Self.stressLayout
        case let .ownAllDecor(on):
            owned = on ? Set(DecorItem.allCases.map(\.rawValue)) : []

        case let .setLeaves(amount):
            leaves = max(amount, 0)
        case let .setSparkles(amount):
            sparkles = max(amount, 0)
        case let .ownDecor(raw, on):
            if on { owned.insert(raw) } else { owned.remove(raw) }
        case let .ownSpecies(species, on):
            if on { ownedSpecies.insert(species.rawValue) } else { ownedSpecies.remove(species.rawValue) }
        case let .ownAllSpecies(on):
            ownedSpecies = on ? Set(Species.allCases.map(\.rawValue)) : []
        case let .topUp(sparkleCount):
            sparkles += sparkleCount
            addJar("topUp", leaves: 0, sparkles: sparkleCount, at: now)

        case let .fillAlbum(count):
            fillAlbum(count, now: now)
        case .growAllFree:
            growAllFree(now: now)
        case let .growColours(count):
            growColours(count, now: now)
        case .clearAlbum:
            album = []
            albumCount = 0
            grownColours = []
            finaleAt = nil

        case let .setMembers(count):
            members = min(max(count, 1), 3)
            resizeVote()
            settleVote(now: now)
        case .openVote:
            if current == nil { apply(.giveCompanion(.magnolia), now: now) }
            openVote(now: now)
            settleVote(now: now)
        case let .ballot(member, species, answer):
            guard var v = vote, v.isOpen else { return }
            if member == 0 {
                v.mine[species] = answer
            } else if member - 1 < v.others.count {
                v.others[member - 1][species] = answer
            }
            vote = v
            settleVote(now: now)
        case .othersAnswerAll:
            guard var v = vote, v.isOpen else { return }
            for index in v.others.indices {
                for (position, option) in v.options.enumerated() {
                    v.others[index][option] = (position + index) % 2 == 0
                }
            }
            vote = v
            settleVote(now: now)
        case let .closeVote(how):
            guard var v = vote, v.isOpen else { return }
            if how == .everyone {
                for option in v.options where v.mine[option] == nil { v.mine[option] = true }
                for index in v.others.indices {
                    for (position, option) in v.options.enumerated() where v.others[index][option] == nil {
                        v.others[index][option] = (position + index) % 2 == 0
                    }
                }
                vote = v
                closeVote(how: "everyone", winner: v.leader)
            } else {
                closeVote(how: "deadline", winner: v.leader)
            }
        case .memberLeaves:
            guard members > 1 else { return }
            members -= 1
            let wasOpen = vote?.isOpen == true
            if vote?.others.isEmpty == false { vote?.others.removeLast() }
            if wasOpen, let v = vote, v.members == 1 || v.answered == v.members {
                closeVote(how: "moved", winner: v.leader)
            }

        case let .preset(preset):
            self = preset.state(now: now)
        case .reset:
            self = PretendState.scenario("growing", now: now)

        case .setLatency, .setOffline, .nextBuy:
            break
        }
    }

    private mutating func place(_ raw: String, in spot: Spot) {
        guard let decor = Decor(rawValue: raw) else { return }
        if case let .item(item) = decor { owned.insert(item.rawValue) }
        if spot == .tree {
            if !layout.tree.contains(raw), layout.tree.count < SceneLayout.treeLimit { layout.tree.append(raw) }
            return
        }
        if spot == .left, layout.right == raw { layout.right = nil }
        if spot == .right, layout.left == raw { layout.left = nil }
        layout[spot] = raw
    }

    /// One of everything that is drawn each frame or lit at night, in every
    /// spot there is: what a house with the lot looks like, to stress it.
    static let stressLayout: SceneLayout = {
        var layout = SceneLayout()
        layout.above = DecorItem.windChime.rawValue
        layout.sky = DecorItem.starryRooftop.rawValue
        layout.weather = DecorItem.petals.rawValue
        layout.tree = [DecorItem.fairyLights, .ornaments, .treeStar, .wishNotes].map(\.rawValue)
        layout.wearing = DecorItem.tinyCrown.rawValue
        layout.pot = DecorItem.glazedPot.rawValue
        layout.left = DecorItem.paperLantern.rawValue
        layout.right = DecorItem.watermelon.rawValue
        layout.ground = DecorItem.kilim.rawValue
        return layout
    }()

    // MARK: The album

    /// A house with `count` graduates, oldest first, each a different species
    /// in turn, over a year.
    private mutating func fillAlbum(_ count: Int, now: Date) {
        let species = Species.allCases
        album = (0..<max(count, 0)).map { index in
            let ago = Double(count - index) * 9 * PretendRules.day
            return Card(
                uuid: UUID().uuidString, species: species[index % species.count], seed: "pretend-\(index)",
                started: now.addingTimeInterval(-ago - 7 * PretendRules.day), graduated: now.addingTimeInterval(-ago), colour: nil
            )
        }
        albumCount = album.count
        grownColours = []
        finaleAt = Species.freeToHave.isSubset(of: grown) ? now : nil
    }

    /// Every free species grown but one, which is the one growing and is
    /// ready: graduating it plays the finale. The jar and the scene stay.
    private mutating func growAllFree(now: Date) {
        let last = Species.sunflower
        album = Species.allCases.filter { Species.freeToHave.contains($0) && $0 != last }.enumerated().map { index, species in
            Card(
                uuid: UUID().uuidString, species: species, seed: "pretend-\(index)",
                started: now.addingTimeInterval(-60 * PretendRules.day), graduated: now.addingTimeInterval(-30 * PretendRules.day),
                colour: nil
            )
        }
        albumCount = album.count
        grownColours = []
        finaleAt = nil
        vote = nil
        if var c = current, !c.undecided {
            c.species = last
            current = c
        } else {
            current = Current(species: last, seed: "pretend-last", startedAt: now, points: 0)
        }
        apply(.makeReady, now: now)
    }

    /// Colours 1 to `count` grown for every species in the album, as their
    /// own graduates (the finale has been held: the colour picker is open).
    private mutating func growColours(_ count: Int, now: Date) {
        if album.isEmpty { growAllFree(now: now) }
        let originals = Array(Set(album.filter { $0.colour == nil }.map(\.species))).sorted { $0.rawValue < $1.rawValue }
        album.removeAll { $0.colour != nil }
        grownColours = []
        for colour in Colourway.range where colour <= count {
            for (index, species) in originals.enumerated() {
                album.append(Card(
                    uuid: UUID().uuidString, species: species, seed: "pretend-c\(colour)-\(index)",
                    started: now.addingTimeInterval(-20 * PretendRules.day), graduated: now.addingTimeInterval(-10 * PretendRules.day),
                    colour: colour
                ))
                grownColours.insert(Colourway.key(species, colour))
            }
        }
        albumCount = album.count
        finaleAt = finaleAt ?? now
    }

    // MARK: The vote

    private mutating func resizeVote() {
        guard var v = vote else { return }
        let others = members - 1
        while v.others.count < others { v.others.append([:]) }
        while v.others.count > others { v.others.removeLast() }
        vote = v
    }

    /// The vote closes by itself once everybody has answered every option and
    /// there is a yes to follow.
    mutating func settleVote(now: Date) {
        guard let v = vote, v.isOpen, v.answered >= v.members, let winner = v.leader else { return }
        closeVote(how: "everyone", winner: winner)
    }
}
#endif
