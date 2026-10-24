import Foundation

/// Holds back everything that needs a session while the launch restores one in
/// the background.
///
/// convex-swift does not wait for auth. `subscribe`, `mutation` and `action`
/// each push their message onto the Rust client's queue the moment they are
/// called, and the queue sends it with whatever identity the socket has at that
/// moment, which before `setAuthCallback` is none. A query that calls
/// `requireUser` throws, and a thrown query ends the Combine publisher, so the
/// subscription is dead before the token arrives and nothing revives it. A
/// mutation is run unauthenticated and refused, not parked until later.
///
/// The app never ran into this because nothing started before the session was
/// restored. An optimistic launch draws Today from the cached home first, so
/// its screens start their reads and writes while the restore is still on the
/// wire. This gate is what makes that safe: `ConvexConnection.subscribe`,
/// `mutate` and `act` wait here first.
///
/// Open by default, so a launch that is not optimistic (first run, signed out,
/// no cached home) never sees it.
///
/// **Every way out of a closed gate ends open or rejected**, never closed:
/// `open()` when the session is back, `reject()` when it is refused, when the
/// restore is cancelled, and when the person signs out. A gate that stayed
/// closed would leave `users:me` and `homes:listMine` waiting for a session that
/// is not coming.
final class AuthGate: @unchecked Sendable {
    enum State: Equatable {
        /// Nothing is held back.
        case open
        /// The session is being restored. Reads and writes wait.
        case restoring
        /// The restore could not reach the server and is trying again. Reads
        /// keep waiting, because they cost nothing and start the moment the
        /// session is back; a write fails at once with `.offline`, so the
        /// screen that made it puts the old value back instead of showing a
        /// change that is stuck behind a network that may be gone for minutes.
        case offline
    }

    /// How long a write waits for the restore before it gives up with
    /// `.offline`. Long enough for a slow network to answer, short enough that
    /// an optimistic toggle does not sit on screen unconfirmed.
    static let writeLimit: Duration = .seconds(8)

    private let writeLimit: Duration
    private let sleep: @Sendable (Duration) async throws -> Void

    /// `sleep` is what the write limit counts with, so a test can drive it with
    /// a clock of its own.
    init(
        writeLimit: Duration = AuthGate.writeLimit,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.writeLimit = writeLimit
        self.sleep = sleep
    }

    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, any Error>
    }

    private let lock = NSLock()
    private var state = State.open
    private var readers: [Waiter] = []
    /// Writes that arrived while the gate was closed, in the order they were
    /// made.
    private var writers: [Waiter] = []
    private var timers: [UUID: Task<Void, Never>] = [:]

    var current: State { lock.withLock { state } }

    /// How many callers are parked. For tests, which need to know a caller has
    /// reached the gate before they change it.
    var waiting: Int { lock.withLock { readers.count + writers.count } }

    // MARK: Launch side

    /// Closes the gate. Called once, synchronously, before the first screen that
    /// starts a read exists.
    func begin() {
        lock.withLock { state = .restoring }
    }

    /// The session is back: everything goes, writes in the order they were
    /// made and then in parallel like any other write. Nothing else in the app
    /// orders writes, and a chain would let one stalled write hold every other.
    func open() {
        let (reads, writes) = lock.withLock { () -> ([Waiter], [Waiter]) in
            state = .open
            cancelTimers()
            defer { readers = []; writers = [] }
            return (readers, writers)
        }
        for waiter in reads + writes { waiter.continuation.resume() }
    }

    /// The restore could not reach the server. Writes that were waiting fail
    /// now; reads keep waiting.
    func markOffline() {
        let failed = lock.withLock { () -> [Waiter] in
            guard state != .open else { return [] }
            state = .offline
            cancelTimers()
            let failed = writers
            writers = []
            return failed
        }
        for waiter in failed { waiter.continuation.resume(throwing: AppError.offline) }
    }

    /// The session is not coming: it was refused, the restore was cancelled, or
    /// the person signed out. Whoever waits is told so, and the gate opens: what
    /// follows is the signed-out app, which is exactly what an open gate with no
    /// session has always been.
    func reject() {
        let failed = lock.withLock { () -> [Waiter] in
            state = .open
            cancelTimers()
            let all = readers + writers
            readers = []
            writers = []
            return all
        }
        for waiter in failed { waiter.continuation.resume(throwing: AppError.notAuthenticated) }
    }

    // MARK: Caller side

    /// Returns once a session is ready. Throws `.notAuthenticated` if the
    /// session was refused and `CancellationError` if the caller goes away
    /// first. A read does not give up on a slow or absent network.
    func wait() async throws {
        // The normal case, once per read: one lock read, nothing allocated.
        if current == .open { return }
        try await park(isWrite: false)
    }

    /// The same for a write, which also throws `.offline` when the restore has
    /// found no network or has taken longer than the write limit.
    func admit() async throws {
        if current == .open { return }
        try await park(isWrite: true)
    }

    private func park(isWrite: Bool) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let verdict: Result<Void, any Error>? = lock.withLock {
                    // Everything below is decided under the lock: the gate may
                    // have changed since the caller looked.
                    if Task.isCancelled { return .failure(CancellationError()) }
                    let waiter = Waiter(id: id, continuation: continuation)
                    switch (isWrite, state) {
                    case (_, .open):
                        // Opened since the caller looked.
                        return .success(())
                    case (true, .offline):
                        return .failure(AppError.offline)
                    case (true, .restoring):
                        writers.append(waiter)
                        let limit = writeLimit, sleep = sleep
                        timers[id] = Task { [weak self] in
                            do { try await sleep(limit) } catch { return }
                            self?.expire(id)
                        }
                        return nil
                    case (false, .restoring), (false, .offline):
                        readers.append(waiter)
                        return nil
                    }
                }
                if let verdict { continuation.resume(with: verdict) }
            }
        } onCancel: {
            let gone = lock.withLock { () -> Waiter? in
                timers.removeValue(forKey: id)?.cancel()
                if let index = readers.firstIndex(where: { $0.id == id }) {
                    return readers.remove(at: index)
                }
                if let index = writers.firstIndex(where: { $0.id == id }) {
                    return writers.remove(at: index)
                }
                return nil
            }
            gone?.continuation.resume(throwing: CancellationError())
        }
    }

    /// A write has waited as long as it may.
    private func expire(_ id: UUID) {
        let gone = lock.withLock { () -> Waiter? in
            timers.removeValue(forKey: id)
            guard state != .open,
                  let index = writers.firstIndex(where: { $0.id == id })
            else { return nil }
            return writers.remove(at: index)
        }
        gone?.continuation.resume(throwing: AppError.offline)
    }

    /// Caller holds the lock.
    private func cancelTimers() {
        for timer in timers.values { timer.cancel() }
        timers = [:]
    }
}
