import SwiftUI

/// The companion's little world: sky, decorations, the plant or the pet, and
/// the moments that make it feel alive.
///
/// The feature hands this view facts — how grown, what mood, what is out —
/// and the view turns changes in them into motion: a chore sends a drop
/// flying to the soil, a quiet plant that is cared for lifts its leaves and
/// opens its buds, a dozing one has its glass dome lifted off, a new stage
/// pops with a ring of light. None of that is state the reducer has to keep;
/// it is how a change looks, so it lives here.
struct CompanionScene: View {
    let companion: Companion
    /// 0…1 of the way to graduation.
    let progress: Double
    let mood: Mood
    let stage: Int
    let layout: SceneLayout
    let southern: Bool
    /// The clock the scene follows — the lab's pretend day on a development
    /// build, the real one otherwise.
    let now: Date
    /// Changes whenever somebody finishes a chore.
    let choreTick: Int
    /// Changes whenever somebody cares for it from this phone.
    let careTick: Int
    /// The small version for a busy day: just the companion, no decorations.
    var compact = false
    /// Holds still while a sheet covers the card: nobody is watching it, and
    /// its frames are the sheet's.
    var paused = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isScrolling) private var isScrolling

    @State private var canopy: Canopy?
    @State private var epoch = Date()
    @State private var moodFrom = Mood.content.level
    @State private var moodTo = Mood.content.level
    @State private var moodAt = Date.distantPast
    @State private var progressFrom = 0.0
    @State private var progressTo = 0.0
    @State private var progressAt = Date.distantPast
    @State private var revivedAt: Date?
    @State private var revivedFromDozing = false
    /// Whether the mood change under way is a waking-up, which is slower and
    /// overshoots.
    @State private var isWaking = false
    @State private var stageUpAt: Date?
    @State private var dropAt: Date?
    /// The water poured by recent taps on Water (hearts, for a pet), each
    /// with its own start: a tap never restarts one already falling.
    @State private var pours: [Pour] = []
    @State private var landedAt: Date?
    @State private var pettedAt: Date?
    @State private var petSide = 1.0
    @State private var bursts: [Burst] = []
    @State private var isVisible = true
    @State private var didSettle = false
    @State private var viewSize = CGSize(width: 360, height: 360)
    @State private var crowns = CrownCache()

    /// One tap's water: when it was poured, and a little to one side of the
    /// last, so two pours in a row don't fall as one.
    struct Pour: Equatable {
        var at: Date
        var shift: Double
    }

    /// A one-off spray: sparkles from a landing, hearts from a pet.
    struct Burst: Equatable {
        enum Kind { case sparkles, hearts, ring }
        var kind: Kind
        var x: Double, y: Double
        var at: Date
        var seed: UInt32
    }

    var body: some View {
        let snapshot = self.snapshot
        TimelineView(.animation(minimumInterval: frameInterval, paused: isPaused)) { timeline in
            let date = timeline.date
            ZStack {
                Canvas { context, size in snapshot.drawBack(context, size: size, at: date) }
                if let canopy, companion.species.art == .tree {
                    let wind = snapshot.wind(viewSize, at: date)
                    let state = snapshot.treeState(at: date)
                    ZStack {
                        TreeLayer(canopy: canopy, state: state)
                            .equatable()
                        if !state.decor.isEmpty {
                            DecorLayer(state: state, anchors: snapshot.anchors(at: date), twinkle: snapshot.twinkle(state, at: date))
                                .equatable()
                        }
                    }
                    .transformEffect(wind.bend)
                    .scaleEffect(x: 1 - wind.bounce * 0.35, y: 1 + wind.bounce, anchor: SceneSpace.root)
                } else if companion.species.art == .plant, let plan = PlantPlan.of(companion.species) {
                    // The same wind and bounce as the tree, over a plant.
                    let wind = snapshot.wind(viewSize, at: date)
                    let state = snapshot.treeState(at: date)
                    ZStack {
                        PlantLayer(plan: plan, state: state)
                            .equatable()
                        if !state.decor.isEmpty {
                            DecorLayer(state: state, anchors: snapshot.anchors(at: date), twinkle: snapshot.twinkle(state, at: date))
                                .equatable()
                        }
                    }
                    .transformEffect(wind.bend)
                    .scaleEffect(x: 1 - wind.bounce * 0.35, y: 1 + wind.bounce, anchor: SceneSpace.root)
                } else if companion.species.art == .sketch, !companion.species.isPet {
                    // A sketched plant has no crown yet; its lights and
                    // baubles go round the emoji instead.
                    let state = snapshot.treeState(at: date)
                    if !state.decor.isEmpty {
                        DecorLayer(state: state, anchors: snapshot.sketchAnchors(at: date), twinkle: snapshot.twinkle(state, at: date))
                            .equatable()
                    }
                }
                Canvas { context, size in snapshot.drawFront(context, size: size, at: date) }
            }
        }
        .contentShape(.rect)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { viewSize = $0 }
        .onTapGesture(coordinateSpace: .local) { location in pet(at: location) }
        .onScrollVisibilityChange(threshold: 0.05) { isVisible = $0 }
        .onAppear(perform: settle)
        // A new companion can keep the old one's seed (choosing again before
        // anything graduated), so the tree is grown again for a new species
        // too — keyed on the seed alone, a pomegranate kept the lemon's tree.
        .onChange(of: companion.species) { _, _ in canopy = nil; settle() }
        .onChange(of: companion.seed) { _, _ in canopy = nil; settle() }
        .onChange(of: mood) { old, new in moodChanged(from: old, to: new) }
        .onChange(of: progress) { _, new in
            progressFrom = shownProgress(at: Date())
            progressTo = new
            progressAt = Date()
        }
        .onChange(of: stage) { old, new in if new > old { stageUpAt = Date() } }
        // The landing is scheduled when the flight starts: under Reduce
        // Motion there is no flight, only the result.
        .onChange(of: choreTick) { _, _ in
            dropAt = Date()
            land(after: reduceMotion ? 0 : 0.95)
        }
        // Every tap pours its own water and gets its own landing — water and
        // sparkle together. Tapped faster than the water can fall, the plant
        // gives a happy wiggle instead of a fourth pour: one tap restarting
        // the drops while every tap queued a sparkle showed one splash of
        // water and a dozen sparkles.
        .onChange(of: careTick) { _, _ in
            let now = Date()
            pours.removeAll { now.timeIntervalSince($0.at) > 1 }
            if pours.count < 3 {
                pours.append(Pour(at: now, shift: pours.isEmpty ? 0 : Double.random(in: -14...14)))
                land(after: reduceMotion ? 0 : 0.7)
            } else {
                pettedAt = now
                petSide = -petSide
            }
        }
    }

    /// Thirty frames a second is plenty for swaying leaves; the small one on
    /// a busy day gets fifteen.
    private var frameInterval: Double { compact ? 1.0 / 15 : 1.0 / 30 }

    /// Nothing is drawn while the card is scrolled away or the app is not in
    /// front, so the scene costs nothing when nobody is looking at it. It
    /// holds still while the screen scrolls, too: a frame of the scene is
    /// time the scroll needs, and a tree caught mid-sway for a moment is not
    /// something anybody sees.
    private var isPaused: Bool { paused || isScrolling || !isVisible || scenePhase != .active }

    // MARK: - Changes into motion

    private func settle() {
        if canopy == nil, companion.species.art == .tree {
            canopy = Canopy(seed: companion.seed, species: companion.species)
        }
        guard !didSettle else { return }
        didSettle = true
        moodFrom = mood.level; moodTo = mood.level
        progressFrom = progress; progressTo = progress
    }

    private func moodChanged(from old: Mood, to new: Mood) {
        let now = Date()
        moodFrom = shownMood(at: now)
        moodTo = new.level
        moodAt = now
        // Somebody came back to a quiet companion: it wakes up.
        isWaking = old.isQuiet && !new.isQuiet
        if isWaking {
            revivedAt = now
            revivedFromDozing = old == .dozing
        }
    }

    private func shownMood(at date: Date) -> Double { snapshot.shownMood(at: date) }
    private func shownProgress(at date: Date) -> Double { snapshot.shownProgress(at: date) }

    /// Everything the canvas draws from, read here, in the view — so SwiftUI
    /// knows a change to any of it means drawing again. Read only inside the
    /// canvas's closure, a change made on appear (the tree being grown from
    /// its seed) could be missed until something else redrew the card.
    private var snapshot: SceneSnapshot {
        SceneSnapshot(
            companion: companion, progress: progress, stage: stage, layout: layout, southern: southern, now: now,
            compact: compact, reduceMotion: reduceMotion, canopy: canopy, epoch: epoch,
            moodFrom: moodFrom, moodTo: moodTo, moodAt: moodAt, isWaking: isWaking,
            progressFrom: progressFrom, progressTo: progressTo, progressAt: progressAt,
            revivedAt: revivedAt, revivedFromDozing: revivedFromDozing, stageUpAt: stageUpAt,
            dropAt: dropAt, landedAt: landedAt, pettedAt: pettedAt, pours: pours, petSide: petSide, bursts: bursts,
            crowns: crowns
        )
    }

    private func land(after delay: Double) {
        Task { @MainActor in
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            landedAt = Date()
            let soil = companion.species.isPet ? SceneSpace.floor - 60 : SceneSpace.soil
            bursts.append(Burst(kind: .sparkles, x: 0, y: soil, at: Date(), seed: UInt32.random(in: 0...UInt32.max)))
            trim()
        }
    }

    /// A tap: hearts where the finger was, and a sway away from it. Kept in
    /// scene units, which is what the canvas draws in.
    private func pet(at location: CGPoint) {
        let scale = max(viewSize.height / SceneSpace.height, 0.001)
        pettedAt = Date()
        petSide = location.x < viewSize.width / 2 ? -1 : 1
        bursts.append(Burst(kind: .hearts, x: location.x / scale, y: location.y / scale, at: Date(), seed: 0))
        trim()
    }

    private func trim() {
        let now = Date()
        bursts.removeAll { now.timeIntervalSince($0.at) > 2 }
    }

}

/// One moment of the scene: what it is and how it is moving, and the drawing
/// made from it.
struct SceneSnapshot {
    let companion: Companion
    let progress: Double
    let stage: Int
    let layout: SceneLayout
    let southern: Bool
    let now: Date
    let compact: Bool
    let reduceMotion: Bool
    let canopy: Canopy?
    let epoch: Date
    let moodFrom: Double, moodTo: Double, moodAt: Date, isWaking: Bool
    let progressFrom: Double, progressTo: Double, progressAt: Date
    let revivedAt: Date?, revivedFromDozing: Bool
    let stageUpAt: Date?, dropAt: Date?, landedAt: Date?, pettedAt: Date?
    let pours: [CompanionScene.Pour]
    let petSide: Double
    let bursts: [CompanionScene.Burst]
    let crowns: CrownCache

    /// How long the mood takes to change on screen. Waking up is slower and
    /// overshoots — leaves lifting past where they rest, then settling.
    var moodDuration: Double { reduceMotion ? 0.35 : isWaking ? 1.8 : 1.4 }

    func shownMood(at date: Date) -> Double {
        let t = date.timeIntervalSince(moodAt) / moodDuration
        guard t < 1 else { return moodTo }
        let curve = isWaking && !reduceMotion ? Ink.back(t) : Ink.smooth(t)
        return Ink.clamp(Ink.lerp(moodFrom, moodTo, curve))
    }

    func shownProgress(at date: Date) -> Double {
        let t = date.timeIntervalSince(progressAt) / (reduceMotion ? 0.3 : 1.2)
        guard t < 1 else { return progressTo }
        return Ink.lerp(progressFrom, progressTo, Ink.ease(t))
    }


    /// What every layer of one frame agrees on.
    struct Moment {
        var frame: SceneFrame
        var scale: Double, width: Double, seconds: Double
        var revive: Double?
        var center: Double { width / 2 }
    }

    func moment(_ size: CGSize, at date: Date) -> Moment {
        let scale = size.height / SceneSpace.height
        let seconds = date.timeIntervalSince(epoch)
        let hour = Double(Calendar.current.component(.hour, from: now)) + Double(Calendar.current.component(.minute, from: now)) / 60
        let revive = revivedAt.map { date.timeIntervalSince($0) }
        let domeLift: Double = {
            guard let revive, revivedFromDozing else { return 0 }
            return revive < 1.2 ? Ink.ease(revive / 0.9) : 0
        }()
        let motion = treeMotion(at: date)
        let frame = SceneFrame(
            time: seconds, day: SceneFrame.dayness(hour), hour: hour,
            mood: shownMood(at: date), progress: shownProgress(at: date),
            reduceMotion: reduceMotion, bounce: motion.bounce, wobble: motion.wobble,
            layout: compact ? SceneLayout() : layout, southern: southern, domeLift: domeLift
        )
        return Moment(frame: frame, scale: scale, width: size.width / scale, seconds: seconds, revive: revive)
    }

    /// The squash and stretch after something lands, a new stage or a
    /// waking-up, and the sway after a pet.
    func treeMotion(at date: Date) -> (bounce: Double, wobble: Double) {
        guard !reduceMotion else { return (0, 0) }
        var bounce = landedAt.map { Ink.settle(date.timeIntervalSince($0), amplitude: 0.18, frequency: 12.6, damping: 5.5) } ?? 0
        if let stageUpAt { bounce += Ink.settle(date.timeIntervalSince(stageUpAt) - 0.2, amplitude: 0.12, frequency: 10, damping: 4) }
        if let revivedAt { bounce += Ink.settle(date.timeIntervalSince(revivedAt) - 0.6, amplitude: 0.12, frequency: 11, damping: 5) }
        let wobble = pettedAt.map { petSide * Ink.settle(date.timeIntervalSince($0), amplitude: 0.22, frequency: 7.3, damping: 2.5) } ?? 0
        return (bounce, wobble)
    }

    /// What the tree shows at this instant. It changes only while a mood or
    /// a stage is easing in and when the light moves — the rest of the time it
    /// is equal to the last frame's, and the tree is not drawn again.
    func treeState(at date: Date) -> TreeState {
        let hour = Double(Calendar.current.component(.hour, from: now)) + Double(Calendar.current.component(.minute, from: now)) / 60
        return TreeState(
            seed: companion.seed, species: companion.species, mood: shownMood(at: date), progress: shownProgress(at: date),
            day: (SceneFrame.dayness(hour) * 50).rounded() / 50, light: (SceneFrame.skySide(hour) * 10).rounded() / 10,
            decor: compact ? [] : layout.tree, reduceMotion: reduceMotion
        )
    }

    /// Steps a few times a second while lights or a star are out after dark,
    /// so they twinkle; otherwise 0, and they are drawn once.
    func twinkle(_ state: TreeState, at date: Date) -> Int {
        let glows = state.decor.contains { $0 == DecorItem.fairyLights.rawValue || $0 == DecorItem.treeStar.rawValue }
        return !reduceMotion && state.day < 0.85 && glows ? Int(date.timeIntervalSince(epoch) * 4) : 0
    }

    /// The wind for this frame, in the tree layer's own points.
    ///
    /// It is a shear of the cached picture, not a shader. Two GPU passes over
    /// the tree — a wind distortion and a painted finish — held Today to about
    /// 25 frames a second on the simulator, waiting on the GPU every frame,
    /// and scrolling past it stuttered; a transform is free, and Today stays
    /// at 60. The shaders are kept in Docs/Companion/art/shaders.
    struct Wind {
        var root: CGPoint
        /// How far the crown leans, as points sideways per point of height.
        var lean: Double
        /// The squash and stretch after something lands.
        var bounce: Double

        /// The wind as a shear about the root: the top moves, the base stays.
        var bend: CGAffineTransform {
            CGAffineTransform(translationX: -root.x, y: -root.y)
                .concatenating(CGAffineTransform(a: 1, b: 0, c: -lean, d: 1, tx: 0, ty: 0))
                .concatenating(CGAffineTransform(translationX: root.x, y: root.y))
        }
    }

    /// A slow sway and gusts that only push one way, limper when the tree is
    /// tired, plus the swing after a pet.
    func wind(_ size: CGSize, at date: Date) -> Wind {
        let moment = moment(size, at: date)
        let motion = treeMotion(at: date)
        let strength = reduceMotion ? 0 : moment.frame.wind
        let t = moment.seconds, droop = Ink.smooth((0.66 - moment.frame.mood) / 0.56)
        let gust = max(0, (sin(t * 0.7) + 0.5 * sin(t * 1.9 + 1) + 0.8 * sin(t * 0.23 + 2)) / 2.3)
        let lean = strength * (sin(t * 1.25) * 0.025 + gust * 0.045) * (1 - 0.5 * droop) + motion.wobble * 0.4
        return Wind(root: CGPoint(x: size.width / 2, y: SceneSpace.soil * moment.scale), lean: lean, bounce: motion.bounce)
    }

    /// Where decorations hang on the crown as it stands.
    func anchors(at date: Date) -> CanopyAnchors {
        if let plan = PlantPlan.of(companion.species) {
            return crowns.anchors(plan, species: companion.species, seed: companion.seed, progress: shownProgress(at: date), mood: shownMood(at: date))
        }
        guard let canopy else { return CrownCache.none }
        return crowns.anchors(canopy, progress: shownProgress(at: date), mood: shownMood(at: date))
    }

    /// The crown as it stands, for whatever plays around it. The pose is
    /// worked out once per mood and stage, not once a frame.
    func crown(_ moment: Moment) -> CGRect {
        let center = moment.center
        if companion.species.art == .sketch {
            return sketchBox(progress: moment.frame.progress, center: center).insetBy(dx: -10, dy: -10)
        }
        if let plan = PlantPlan.of(companion.species) {
            let crown = crowns.anchors(plan, species: companion.species, seed: companion.seed, progress: moment.frame.progress, mood: moment.frame.mood)
            return CGRect(x: center + crown.left - 10, y: SceneSpace.soil + crown.top - 10,
                          width: crown.right - crown.left + 20, height: max(crown.bottom - crown.top + 20, 40))
        }
        guard !companion.species.isPet, let canopy else {
            return companion.species.isPet
                ? CGRect(x: center - 90, y: SceneSpace.floor - 190, width: 180, height: 150)
                : CGRect(x: center - 80, y: SceneSpace.soil - 200, width: 160, height: 160)
        }
        let crown = crowns.anchors(canopy, progress: moment.frame.progress, mood: moment.frame.mood)
        return CGRect(x: center + crown.left - 10, y: SceneSpace.soil + crown.top - 10,
                      width: crown.right - crown.left + 20, height: max(crown.bottom - crown.top + 20, 40))
    }

    /// Behind the tree: the sky, what hangs above, the rug, the pot — or the
    /// pet, which is drawn whole every frame.
    func drawBack(_ context: GraphicsContext, size: CGSize, at date: Date) {
        let moment = moment(size, at: date)
        let frame = moment.frame, center = moment.center
        let painter = ScenePainter(frame: frame, width: moment.width, seed: companion.seed)
        var c = context
        c.scaleBy(x: moment.scale, y: moment.scale)
        painter.sky(c)
        painter.above(c)
        painter.rug(c)
        switch companion.species.art {
        case .duckling:
            let pet = PetPainter(
                frame: frame, stage: stage,
                hop: [landedAt, stageUpAt].compactMap { $0 }.map { date.timeIntervalSince($0) }.min(),
                wiggle: pettedAt.map { date.timeIntervalSince($0) },
                waking: moment.revive.flatMap { $0 < 1.8 ? $0 : nil }
            )
            pet.draw(c, x: center, floor: SceneSpace.floor - 4, size: 190)
        case .critter:
            if let plan = CritterPlan.of(companion.species) {
                CritterPainter(
                    plan: plan, frame: frame, stage: stage,
                    hop: [landedAt, stageUpAt].compactMap { $0 }.map { date.timeIntervalSince($0) }.min(),
                    wiggle: pettedAt.map { date.timeIntervalSince($0) },
                    waking: moment.revive.flatMap { $0 < 1.8 ? $0 : nil }
                ).draw(c, x: center, floor: SceneSpace.floor - 4, size: 190)
            }
        case .tree, .plant:
            painter.pot(c, style: PotStyle(seed: companion.seed))
        case .sketch:
            if !companion.species.isPet { painter.pot(c, style: PotStyle(seed: companion.seed)) }
            sketch(c, moment)
        }
    }

    /// Where a hat sits and where a bow or scarf is tied, each the point its
    /// foot stands on: the crown's top and the pot's front for a plant; the
    /// head and the chin for a pet — the duckling's from its drawing, grown.
    func wearingPoints(_ moment: Moment, crown: CGRect) -> (top: CGPoint, neck: CGPoint) {
        let center = moment.center
        let pot = CGPoint(x: center, y: SceneSpace.soil + 32)
        switch (companion.species.art, companion.species.isPet) {
        case (.duckling, _):
            return (CGPoint(x: center - 22, y: SceneSpace.floor - 120), CGPoint(x: center - 18, y: SceneSpace.floor - 62))
        case (.critter, _):
            guard let plan = CritterPlan.of(companion.species) else { return (CGPoint(x: center, y: SceneSpace.floor - 140), CGPoint(x: center, y: SceneSpace.floor - 80)) }
            let w = CritterPainter.wearing(plan, stage: stage), k = 190.0 / 120
            let floor = SceneSpace.floor - 4
            func scene(_ p: CGPoint) -> CGPoint { CGPoint(x: center + (p.x - 60) * k, y: floor + (p.y - 108) * k) }
            return (scene(w.top), scene(w.neck))
        case (.sketch, true):
            let box = sketchBox(progress: moment.frame.progress, center: center)
            return (CGPoint(x: box.midX, y: box.minY + 8), CGPoint(x: box.midX, y: box.maxY - box.height * 0.04))
        case (.sketch, false):
            let box = sketchBox(progress: moment.frame.progress, center: center)
            return (CGPoint(x: box.midX, y: box.minY + 8), pot)
        case (.tree, _), (.plant, _):
            return (CGPoint(x: crown.midX, y: crown.minY + 12), pot)
        }
    }

    // MARK: Sketches

    /// The point a sketched species is hatched or sprouted at: before it, an
    /// egg or a seedling stands in for it.
    private var sketchOpens: Double {
        companion.species.isPet ? CompanionMath.petStages[2] : CompanionMath.plantStages[1]
    }

    /// Where a sketched species stands, in scene units: on the soil in its pot,
    /// or on the floor, as tall as it has grown.
    func sketchBox(progress: Double, center: Double) -> CGRect {
        let isPet = companion.species.isPet
        let size = progress < sketchOpens
            ? (isPet ? 54.0 : 34)
            : Ink.lerp(isPet ? 72 : 52, 150, Ink.ease((progress - sketchOpens) / (1 - sketchOpens)))
        let base = isPet ? SceneSpace.floor - 4 : SceneSpace.soil + 4
        return CGRect(x: center - size / 2, y: base - size, width: size, height: size)
    }

    /// A species not drawn yet, as its emoji: a seedling or an egg to begin
    /// with, then itself, growing with every stage, swaying, bouncing when
    /// something lands, and drooping and fading as the house goes quiet. It
    /// stands in until the art pass.
    func sketch(_ c: GraphicsContext, _ moment: Moment) {
        let frame = moment.frame
        let box = sketchBox(progress: frame.progress, center: moment.center)
        let opened = frame.progress >= sketchOpens
        let symbol = opened ? companion.species.symbol : companion.species.isPet ? "🥚" : "🌱"
        let droop = Ink.smooth((0.66 - frame.mood) / 0.56)
        let sway = frame.reduceMotion ? 0 : sin(moment.seconds * 1.25) * 0.035 * frame.wind
        // The wobbly egg wobbles.
        let wobble = !opened && stage >= 1 && !frame.reduceMotion ? sin(moment.seconds * 7) * 0.12 : 0
        c.sketch(symbol, box.midX, box.maxY, size: box.height, angle: sway + wobble + frame.wobble * 0.4 + droop * 0.16,
                 stretch: frame.bounce, opacity: 1 - 0.35 * droop)
    }

    /// Where things hang on a sketched plant, round its emoji, in the tree's
    /// own space: across from the trunk, up from the soil.
    func sketchAnchors(at date: Date) -> CanopyAnchors {
        let box = sketchBox(progress: shownProgress(at: date), center: 0)
        let top = box.minY - SceneSpace.soil, bottom = box.maxY - SceneSpace.soil
        let middle = (top + bottom) / 2, radius = box.width * 0.36
        let hangs = (0..<7).map { i in
            let angle = Double.pi * (0.12 + 0.76 * Double(i) / 6)
            return CGPoint(x: -cos(angle) * radius, y: middle + sin(angle) * radius * 0.7)
        }
        return CanopyAnchors(
            left: box.minX, right: box.maxX, top: top, bottom: middle + radius * 0.5, crownTop: CGPoint(x: 0, y: top),
            hangs: hangs, notes: [CGPoint(x: -radius * 0.55, y: middle - radius * 0.2), CGPoint(x: radius * 0.5, y: middle - radius * 0.35)]
        )
    }

    /// In front of the tree: what stands on the floor, what flies, the
    /// weather, and every moment — drops, sparkles, rings and hearts.
    func drawFront(_ context: GraphicsContext, size: CGSize, at date: Date) {
        let moment = moment(size, at: date)
        let frame = moment.frame, center = moment.center, seconds = moment.seconds
        let painter = ScenePainter(frame: frame, width: moment.width, seed: companion.seed)
        let crown = crown(moment)
        var c = context
        c.scaleBy(x: moment.scale, y: moment.scale)
        painter.floor(c)
        painter.fireflies(c)
        if !compact {
            // Butterflies keep clear of a pet's head: they circle a point up and
            // to the right of it (the head is left of centre, and a butterfly
            // on the face reads as a glitch).
            let around = companion.species.isPet ? CGPoint(x: center + 96, y: SceneSpace.floor - 168) : CGPoint(x: crown.midX, y: crown.midY)
            painter.butterflies(c, around: around, swing: companion.species.isPet ? 44 : 70)
            painter.weather(c)
        }
        painter.glints(c, in: crown)
        if !compact {
            let (top, neck) = wearingPoints(moment, crown: crown)
            painter.wearing(c, top: top, neck: neck)
        }

        // Ready to graduate: a slow golden breath around it.
        if progress >= 1 {
            let pulse = reduceMotion ? 0.7 : 0.5 + 0.5 * sin(seconds * 2)
            c.glow(crown.midX, crown.midY, 170, Ink.color(0xFFD27A, 0.18 + 0.12 * pulse))
        }
        if companion.species.isPet {
            if frame.mood < 0.2, moment.revive == nil, stage > 1 { painter.zees(c, x: center + 46, y: SceneSpace.floor - 150) }
        } else {
            painter.fallingLeaf(c, from: anchors(at: date).hangs)
            painter.thirstBubble(c, near: crown)
            let domeAlpha = frame.mood < 0.15 ? 1 : frame.domeLift > 0 ? 1 - frame.domeLift : 0
            painter.dome(c, top: crown.minY - 14, alpha: domeAlpha)
        }

        flights(c, at: date, center: center, width: moment.width)
        waking(c, at: date, revive: moment.revive, center: center)
        stageUp(c, at: date, crown: crown)
        drawBursts(c, at: date, center: center)
    }

    /// A chore's drop arcing in from the corner; a care's water from the can.
    func flights(_ c: GraphicsContext, at date: Date, center: Double, width: Double) {
        guard !reduceMotion else { return }
        let target = companion.species.isPet ? SceneSpace.floor - 70 : SceneSpace.soil - 4
        if let dropAt {
            let t = date.timeIntervalSince(dropAt) / 0.95
            if t >= 0, t < 1 {
                let u = Ink.smooth(t), v = 1 - u
                let x0 = width - 28, y0 = 34.0, cx = Ink.lerp(x0, center, 0.5), cy = -30.0
                let x = v * v * x0 + 2 * v * u * cx + u * u * center
                let y = v * v * y0 + 2 * v * u * cy + u * u * target
                c.glow(x, y, 16, SceneInk.water.opacity(0.5))
                drop(c, x: x, y: y, size: 1)
            }
        }
        for pour in pours {
            let t = date.timeIntervalSince(pour.at)
            for i in 0..<3 {
                let start = Double(i) * 0.12
                let k = (t - start) / 0.55
                guard k >= 0, k < 1 else { continue }
                if companion.species.isPet {
                    // A pet is petted, not watered: hearts rise off it.
                    let x = center - 20 + Double(i) * 20 + pour.shift, y = target - 20 - 70 * k
                    c.heart(x, y, 8, SceneInk.heart.opacity(1 - Ink.smooth((k - 0.6) / 0.4)))
                } else {
                    let x = center - 18 + Double(i) * 18 + pour.shift, y = Ink.lerp(SceneSpace.soil - 190, target, k * k)
                    drop(c, x: x, y: y, size: 0.7)
                }
            }
        }
    }

    func drop(_ c: GraphicsContext, x: Double, y: Double, size: Double) {
        var d = c
        d.translateBy(x: x, y: y)
        d.scaleBy(x: size, y: size)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: -11))
        path.addCurve(to: CGPoint(x: 7, y: 3), control1: CGPoint(x: 4, y: -4), control2: CGPoint(x: 7, y: 0))
        path.addArc(center: CGPoint(x: 0, y: 3), radius: 7, startAngle: .zero, endAngle: .radians(.pi), clockwise: false)
        path.addCurve(to: CGPoint(x: 0, y: -11), control1: CGPoint(x: -7, y: 0), control2: CGPoint(x: -4, y: -4))
        d.fill(path, with: .color(SceneInk.water))
        d.ellipse(-2.5, 2, 1.6, 2.6, .color(Color.white.opacity(0.85)))
    }

    /// Waking up: a splash ring in the soil, then a burst of light as it
    /// stands up straight.
    func waking(_ c: GraphicsContext, at date: Date, revive: Double?, center: Double) {
        guard let revive, revive < 2, !reduceMotion else { return }
        let ground = companion.species.isPet ? SceneSpace.floor - 2 : SceneSpace.soil
        let ring = revive / 0.9
        if ring < 1 {
            let rx = 20 + 70 * Ink.ease(ring), ry = 4 + 10 * Ink.ease(ring)
            c.stroke(Path(ellipseIn: CGRect(x: center - rx, y: ground - ry, width: rx * 2, height: ry * 2)),
                     with: .color(SceneInk.water.opacity(0.6 * (1 - ring))), lineWidth: 2.5)
        }
        let burst = (revive - 0.9) / 0.9
        if burst > 0, burst < 1 {
            var r = Ink.Random(seed: 7)
            for _ in 0..<14 {
                let angle = -Double.pi / 2 + (r.next() - 0.5) * 2.6
                let speed = r.between(80, 160)
                let x = center + cos(angle) * speed * burst
                let y = ground - 90 + sin(angle) * speed * burst + 120 * burst * burst
                c.glint(x, y, 2.6 * (1 - burst), SceneInk.sparkle.opacity(1 - burst))
            }
        }
    }

    /// A new stage: a ring of light opening around it.
    func stageUp(_ c: GraphicsContext, at date: Date, crown: CGRect) {
        guard let stageUpAt else { return }
        let t = date.timeIntervalSince(stageUpAt) / 1.2
        guard t >= 0, t < 1 else { return }
        let radius = 30 + 140 * Ink.ease(t)
        c.stroke(Path(ellipseIn: CGRect(x: crown.midX - radius, y: crown.midY - radius, width: radius * 2, height: radius * 2)),
                 with: .color(Ink.color(0xFFE296, 0.7 * (1 - t))), lineWidth: 3 * (1 - t) + 0.5)
        c.glow(crown.midX, crown.midY, radius, Ink.color(0xFFE296, 0.2 * (1 - t)))
    }

    func drawBursts(_ c: GraphicsContext, at date: Date, center: Double) {
        for burst in bursts {
            let t = date.timeIntervalSince(burst.at)
            switch burst.kind {
            case .sparkles:
                guard t < 1.4 else { continue }
                var r = Ink.Random(seed: burst.seed)
                for _ in 0..<16 {
                    let angle = -Double.pi / 2 + (r.next() - 0.5) * 2.4
                    let speed = reduceMotion ? 0 : r.between(60, 180)
                    let life = r.between(0.8, 1.4)
                    guard t < life else { continue }
                    let x = center + cos(angle) * speed * t
                    let y = burst.y + sin(angle) * speed * t + 75 * t * t - (reduceMotion ? r.next() * 120 : 0)
                    let a = 1 - Ink.smooth((t - life * 0.6) / (life * 0.4))
                    c.glint(x, y, r.between(2, 5) * 0.6, SceneInk.sparkle.opacity(a))
                }
            case .hearts:
                guard t < 1.6 else { continue }
                for i in 0..<3 {
                    let k = t - Double(i) * 0.12
                    guard k > 0, k < 1.3 else { continue }
                    let a = 1 - Ink.smooth((k - 0.8) / 0.5)
                    let x = burst.x + Double(i - 1) * 14 + (reduceMotion ? 0 : sin(k * 5) * 4)
                    let y = burst.y - Double(i) * 8 - (reduceMotion ? 0 : 34 * k)
                    c.heart(x, y, 8, SceneInk.heart.opacity(a))
                }
            case .ring:
                break
            }
        }
    }
}

extension EnvironmentValues {
    /// Whether the screen around this view is scrolling, for drawings that
    /// hold still so the scroll keeps its frames.
    @Entry public var isScrolling = false
}

extension SceneSnapshot {
    /// The scene at rest: nothing easing in, nothing in flight.
    init(still companion: Companion, progress: Double, mood: Mood, stage: Int, now: Date, reduceMotion: Bool, layout: SceneLayout = SceneLayout()) {
        let epoch = Date(timeIntervalSinceReferenceDate: 0)
        self.init(
            companion: companion, progress: progress, stage: stage, layout: layout, southern: false, now: now,
            compact: false, reduceMotion: reduceMotion,
            canopy: companion.species.art == .tree ? Canopy(seed: companion.seed, species: companion.species) : nil, epoch: epoch,
            moodFrom: mood.level, moodTo: mood.level, moodAt: .distantPast, isWaking: false,
            progressFrom: progress, progressTo: progress, progressAt: .distantPast,
            revivedAt: nil, revivedFromDozing: false, stageUpAt: nil, dropAt: nil, landedAt: nil, pettedAt: nil, pours: [],
            petSide: 1, bursts: [], crowns: CrownCache()
        )
    }
}

/// What the tree layer draws from: everything that changes how it looks,
/// and nothing that only moves it.
struct TreeState: Equatable, Sendable {
    var seed: String
    var species: Species
    var mood: Double
    var progress: Double
    /// The light, in fiftieths, so the clock redraws it now and then rather
    /// than every frame.
    var day: Double
    /// Where the sun or the moon stands across the scene, -1 to 1, in tenths,
    /// for the trees that take their light from it.
    var light: Double = 0
    var decor: [String]
    var reduceMotion: Bool
}

/// The tree on a layer of its own, drawn again only when what it shows
/// changes: a mood easing in, a stage growing, the light moving with the
/// clock. Between those the same picture is reused, and the wind and the
/// painted finish are shaders over it. Drawn whole every frame, its few
/// hundred shapes took the main thread's time, and Today stuttered while it
/// scrolled.
struct TreeLayer: View, Equatable {
    let canopy: Canopy
    let state: TreeState

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.state.seed == rhs.state.seed && lhs.state.species == rhs.state.species && lhs.state.mood == rhs.state.mood
            && lhs.state.progress == rhs.state.progress && lhs.state.day == rhs.state.day
            && lhs.state.light == rhs.state.light
    }

    var body: some View {
        Canvas { context, size in Self.paint(context, size: size, canopy: canopy, state: state) }
            .drawingGroup()
    }

    /// The tree on the scene's soil, cut to it so the roots go into the earth.
    static func paint(_ context: GraphicsContext, size: CGSize, canopy: Canopy, state: TreeState) {
        let scale = size.height / SceneSpace.height
        var tree = context
        tree.scaleBy(x: scale, y: scale)
        tree.translateBy(x: size.width / scale / 2, y: SceneSpace.soil)
        var above = Path(CGRect(x: -size.width, y: -SceneSpace.soil, width: size.width * 2, height: SceneSpace.soil))
        above.addEllipse(in: SceneSpace.soilSurface)
        tree.clip(to: above)
        #if DEBUG
        let started = CACurrentMediaTime()
        defer { TreeTiming.note(state.species, light: state.light, since: started) }
        #endif
        if state.species == .pomegranate && !TreeTiming.legacyPomegranate {
            PomegranatePainter(canopy: canopy, growth: state.progress, mood: state.mood, day: state.day, light: state.light).draw(tree)
        } else {
            CanopyPainter(canopy: canopy, growth: state.progress, mood: state.mood, day: state.day).draw(tree)
        }
    }
}

/// The scene as one still picture: sky, the pot or the pet, the tree and what
/// stands in front, drawn once into a single canvas. Choose and the album show
/// seven or more at a time, and built as full live scenes — a timeline, four
/// layers and two shader passes each — opening Choose stuttered while it made
/// them.
struct ScenePortrait: View {
    let companion: Companion
    var progress = 0.97
    var mood: Mood = .content
    var stage = 5
    let now: Date
    /// What is out in the scene; none for a portrait in a grid.
    var layout = SceneLayout()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Canvas { context, size in
            let snapshot = SceneSnapshot(still: companion, progress: progress, mood: mood, stage: stage, now: now, reduceMotion: reduceMotion, layout: layout)
            let date = snapshot.epoch
            snapshot.drawBack(context, size: size, at: date)
            if let canopy = snapshot.canopy {
                TreeLayer.paint(context, size: size, canopy: canopy, state: snapshot.treeState(at: date))
            } else if let plan = PlantPlan.of(companion.species) {
                PlantLayer.paint(context, size: size, plan: plan, state: snapshot.treeState(at: date))
            }
            snapshot.drawFront(context, size: size, at: date)
        }
    }
}

/// What hangs on the tree, over it and under the same wind, but outside the
/// painted finish — a lit bulb has to look lit, and the finish's shading
/// dulled the ones against the sky. Its own layer also lets the lights
/// twinkle at night by redrawing a few bulbs, not the whole tree.
struct DecorLayer: View, Equatable {
    let state: TreeState
    let anchors: CanopyAnchors
    let twinkle: Int

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.state == rhs.state && lhs.anchors == rhs.anchors && lhs.twinkle == rhs.twinkle
    }

    var body: some View {
        Canvas { context, size in
            let scale = size.height / SceneSpace.height
            let width = size.width / scale
            var tree = context
            tree.scaleBy(x: scale, y: scale)
            tree.translateBy(x: width / 2, y: SceneSpace.soil)
            var layout = SceneLayout()
            layout.tree = state.decor
            let frame = SceneFrame(
                time: Double(twinkle) * 0.25, day: state.day, hour: 12, mood: state.mood, progress: state.progress,
                wind: 0, reduceMotion: state.reduceMotion, layout: layout, southern: false
            )
            ScenePainter(frame: frame, width: width, seed: state.seed).treeDecor(tree, anchors: anchors)
        }
    }
}


/// The crown's anchors by mood and growth. They change only while one of the
/// two eases in, and then in small steps — a fortieth of a mood, a two
/// hundredth of growth — rather than every frame: finding them costs a
/// millisecond or two on a development build, which a wake-up would pay
/// thirty times a second.
final class CrownCache {
    private var plantKey: (species: Species, seed: String, progress: Double, mood: Double)?
    private var plantCached = CrownCache.none

    /// The same for a drawn plant (`PlantPainter.anchors`).
    func anchors(_ plan: PlantPlan, species: Species, seed: String, progress: Double, mood: Double) -> CanopyAnchors {
        let progress = (progress * 200).rounded() / 200, mood = (mood * 40).rounded() / 40
        if let plantKey, plantKey.species == species, plantKey.seed == seed, plantKey.progress == progress, plantKey.mood == mood { return plantCached }
        plantCached = PlantPainter(plan: plan, seed: seed, growth: progress, mood: mood, day: 1).anchors()
        plantKey = (species, seed, progress, mood)
        return plantCached
    }

    private var key: (canopy: Canopy, progress: Double, mood: Double)?
    static let none = CanopyAnchors(left: 0, right: 0, top: 0, bottom: 0, crownTop: .zero, hangs: [], notes: [])
    private var cached = CrownCache.none

    func anchors(_ canopy: Canopy, progress: Double, mood: Double) -> CanopyAnchors {
        let progress = (progress * 200).rounded() / 200, mood = (mood * 40).rounded() / 40
        if let key, key.canopy == canopy, key.progress == progress, key.mood == mood { return cached }
        cached = CanopyPainter(canopy: canopy, growth: progress, mood: mood, day: 1).anchors()
        key = (canopy, progress, mood)
        return cached
    }
}

