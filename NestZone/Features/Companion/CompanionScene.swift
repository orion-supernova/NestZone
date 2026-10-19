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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var plant: PlantModel?
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
    @State private var careAt: Date?
    @State private var landedAt: Date?
    @State private var pettedAt: Date?
    @State private var petSide = 1.0
    @State private var bursts: [Burst] = []
    @State private var isVisible = true
    @State private var didSettle = false
    @State private var viewSize = CGSize(width: 360, height: 360)

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
            Canvas { context, size in
                snapshot.draw(context, size: size, at: timeline.date)
            }
        }
        .contentShape(.rect)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { viewSize = $0 }
        .onTapGesture(coordinateSpace: .local) { location in pet(at: location) }
        .onScrollVisibilityChange(threshold: 0.05) { isVisible = $0 }
        .onAppear(perform: settle)
        .onChange(of: companion.seed) { _, _ in plant = nil; settle() }
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
        .onChange(of: careTick) { _, _ in
            careAt = Date()
            land(after: reduceMotion ? 0 : 0.7)
        }
    }

    /// Thirty frames a second is plenty for swaying leaves; the small one on
    /// a busy day gets fifteen.
    private var frameInterval: Double { compact ? 1.0 / 15 : 1.0 / 30 }

    /// Nothing is drawn while the card is scrolled away or the app is not in
    /// front, so the scene costs nothing when nobody is looking at it.
    private var isPaused: Bool { !isVisible || scenePhase != .active }

    // MARK: - Changes into motion

    private func settle() {
        if plant == nil, !companion.species.isPet {
            plant = PlantModel(seed: companion.seed, species: companion.species)
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
    private var snapshot: Snapshot {
        Snapshot(
            companion: companion, progress: progress, stage: stage, layout: layout, southern: southern, now: now,
            compact: compact, reduceMotion: reduceMotion, plant: plant, epoch: epoch,
            moodFrom: moodFrom, moodTo: moodTo, moodAt: moodAt, isWaking: isWaking,
            progressFrom: progressFrom, progressTo: progressTo, progressAt: progressAt,
            revivedAt: revivedAt, revivedFromDozing: revivedFromDozing, stageUpAt: stageUpAt,
            dropAt: dropAt, careAt: careAt, landedAt: landedAt, pettedAt: pettedAt, petSide: petSide, bursts: bursts
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
private struct Snapshot {
    let companion: Companion
    let progress: Double
    let stage: Int
    let layout: SceneLayout
    let southern: Bool
    let now: Date
    let compact: Bool
    let reduceMotion: Bool
    let plant: PlantModel?
    let epoch: Date
    let moodFrom: Double, moodTo: Double, moodAt: Date, isWaking: Bool
    let progressFrom: Double, progressTo: Double, progressAt: Date
    let revivedAt: Date?, revivedFromDozing: Bool
    let stageUpAt: Date?, dropAt: Date?, careAt: Date?, landedAt: Date?, pettedAt: Date?
    let petSide: Double
    let bursts: [CompanionScene.Burst]

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


    func draw(_ context: GraphicsContext, size: CGSize, at date: Date) {
        let scale = size.height / SceneSpace.height
        let width = size.width / scale
        let center = width / 2
        let seconds = date.timeIntervalSince(epoch)
        let hour = Double(Calendar.current.component(.hour, from: now)) + Double(Calendar.current.component(.minute, from: now)) / 60

        let revive = revivedAt.map { date.timeIntervalSince($0) }
        let domeLift: Double = {
            guard let revive, revivedFromDozing else { return 0 }
            return revive < 1.2 ? Ink.ease(revive / 0.9) : 0
        }()
        var bounce = landedAt.map { Ink.settle(date.timeIntervalSince($0), amplitude: 0.18, frequency: 12.6, damping: 5.5) } ?? 0
        if let stageUpAt { bounce += Ink.settle(date.timeIntervalSince(stageUpAt) - 0.2, amplitude: 0.12, frequency: 10, damping: 4) }
        if let revive { bounce += Ink.settle(revive - 0.6, amplitude: 0.12, frequency: 11, damping: 5) }
        if reduceMotion { bounce = 0 }
        let wobble = pettedAt.map { petSide * Ink.settle(date.timeIntervalSince($0), amplitude: 0.22, frequency: 7.3, damping: 2.5) } ?? 0

        let frame = SceneFrame(
            time: seconds, day: SceneFrame.dayness(hour), hour: hour,
            mood: shownMood(at: date), progress: shownProgress(at: date),
            reduceMotion: reduceMotion, bounce: bounce, wobble: reduceMotion ? 0 : wobble,
            layout: compact ? SceneLayout() : layout, southern: southern, domeLift: domeLift
        )
        let painter = ScenePainter(frame: frame, width: width, seed: companion.seed)

        var c = context
        c.scaleBy(x: scale, y: scale)
        painter.sky(c)
        painter.above(c)
        painter.rug(c)

        var crown = CGRect(x: center - 80, y: SceneSpace.soil - 200, width: 160, height: 160)
        if companion.species.isPet {
            let pet = PetPainter(
                frame: frame, stage: stage,
                hop: [landedAt, stageUpAt].compactMap { $0 }.map { date.timeIntervalSince($0) }.min(),
                wiggle: pettedAt.map { date.timeIntervalSince($0) },
                waking: revive.flatMap { $0 < 1.8 ? $0 : nil }
            )
            pet.draw(c, x: center, floor: SceneSpace.floor - 4, size: 190)
            crown = CGRect(x: center - 90, y: SceneSpace.floor - 190, width: 180, height: 150)
        } else if let plant {
            painter.pot(c, model: plant)
            painter.fallenLeaves(c, model: plant)
            if frame.mood > 0.82 {
                let k = (frame.mood - 0.82) / 0.18
                c.glow(center, SceneSpace.soil - 120, 150, Ink.color(0xFFDC82, 0.16 * k))
            }
            let pose = plant.layout(progress: frame.progress, mood: frame.mood, time: reduceMotion ? 0 : seconds,
                                    wind: reduceMotion ? 0 : frame.wind, wobble: frame.wobble)
            var tree = c
            tree.translateBy(x: center, y: SceneSpace.soil)
            tree.scaleBy(x: 1 - bounce * 0.35, y: 1 + bounce)
            PlantPainter(model: plant, frame: frame, pose: pose).draw(tree)
            painter.treeDecor(tree, model: plant, pose: pose)
            crown = CGRect(x: center + pose.left - 10, y: SceneSpace.soil + pose.top - 10,
                           width: pose.right - pose.left + 20, height: max(-pose.top * 0.75, 40))
        }
        painter.floor(c)
        painter.fireflies(c)
        if !compact {
            painter.butterflies(c, around: CGPoint(x: crown.midX, y: crown.midY))
            painter.weather(c)
        }
        painter.glints(c, in: crown)

        // Ready to graduate: a slow golden breath around it.
        if progress >= 1 {
            let pulse = reduceMotion ? 0.7 : 0.5 + 0.5 * sin(seconds * 2)
            c.glow(crown.midX, crown.midY, 170, Ink.color(0xFFD27A, 0.18 + 0.12 * pulse))
        }
        if companion.species.isPet {
            if frame.mood < 0.42, revive == nil, stage > 1 { painter.zees(c, x: center + 46, y: SceneSpace.floor - 150) }
        } else {
            painter.thirstBubble(c, near: crown)
            let domeAlpha = frame.mood < 0.15 ? 1 : domeLift > 0 ? 1 - domeLift : 0
            painter.dome(c, top: crown.minY - 14, alpha: domeAlpha)
        }

        flights(c, at: date, center: center, width: width)
        waking(c, at: date, revive: revive, center: center)
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
        if let careAt {
            let t = date.timeIntervalSince(careAt)
            for i in 0..<3 {
                let start = Double(i) * 0.12
                let k = (t - start) / 0.55
                guard k >= 0, k < 1 else { continue }
                if companion.species.isPet {
                    // A pet is petted, not watered: hearts rise off it.
                    let x = center - 20 + Double(i) * 20, y = target - 20 - 70 * k
                    c.heart(x, y, 8, SceneInk.heart.opacity(1 - Ink.smooth((k - 0.6) / 0.4)))
                } else {
                    let x = center - 18 + Double(i) * 18, y = Ink.lerp(SceneSpace.soil - 190, target, k * k)
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
