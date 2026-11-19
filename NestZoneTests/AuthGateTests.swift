import ComposableArchitecture
import Foundation
import Testing
@testable import NestZone

/// What holds reads and writes back while an optimistic launch restores the
/// session. See `AuthGate`.
@Suite("Auth gate")
struct AuthGateTests {

    /// Waits until `count` callers are parked, so a test never changes the gate
    /// before the caller it is about has reached it.
    private func parked(_ gate: AuthGate, _ count: Int) async {
        while gate.waiting < count { await Task.yield() }
    }

    /// What a parked call came back with: nothing if it went through.
    private func error(of task: Task<Void, any Error>) async -> AppError? {
        switch await task.result {
        case .success: nil
        case let .failure(error): AppError(error)
        }
    }

    @Test("An open gate lets reads and writes straight through")
    func openPassesThrough() async throws {
        let gate = AuthGate()
        try await gate.wait()
        try await gate.admit()
        #expect(gate.waiting == 0)
    }

    @Test("A write parked while restoring goes when the gate opens")
    func openReleasesWrites() async throws {
        let gate = AuthGate()
        gate.begin()
        let write = Task { try await gate.admit() }
        let read = Task { try await gate.wait() }
        await parked(gate, 2)

        gate.open()
        #expect(await error(of: write) == nil)
        #expect(await error(of: read) == nil)
        #expect(gate.current == .open)
    }

    @Test("A write gives up with .offline after the limit; a read does not")
    func writeExpires() async {
        let clock = TestClock()
        let gate = AuthGate(sleep: { try await clock.sleep(for: $0) })
        gate.begin()
        let write = Task { try await gate.admit() }
        let read = Task { try await gate.wait() }
        await parked(gate, 2)
        await Task.megaYield()

        await clock.advance(by: .seconds(7))
        #expect(gate.waiting == 2)

        await clock.advance(by: .seconds(1))
        #expect(await error(of: write) == .offline)
        #expect(gate.waiting == 1)

        gate.open()
        #expect(await error(of: read) == nil)
    }

    @Test("Going offline fails the writes that wait and any that follow, not the reads")
    func offlineFailsWritesNotReads() async {
        let gate = AuthGate()
        gate.begin()
        let write = Task { try await gate.admit() }
        let read = Task { try await gate.wait() }
        await parked(gate, 2)

        gate.markOffline()
        #expect(await error(of: write) == .offline)
        #expect(gate.waiting == 1)
        #expect(gate.current == .offline)

        let later = Task { try await gate.admit() }
        #expect(await error(of: later) == .offline)

        gate.open()
        #expect(await error(of: read) == nil)
    }

    @Test("A refusal fails everything that waits, and leaves the gate open")
    func rejectFailsEverything() async {
        let gate = AuthGate()
        gate.begin()
        let write = Task { try await gate.admit() }
        let read = Task { try await gate.wait() }
        await parked(gate, 2)

        gate.reject()
        #expect(await error(of: write) == .notAuthenticated)
        #expect(await error(of: read) == .notAuthenticated)
        #expect(gate.current == .open)
        #expect(gate.waiting == 0)
    }

    @Test("A caller that is cancelled while parked is removed")
    func cancellationRemovesTheWaiter() async {
        let gate = AuthGate()
        gate.begin()
        let read = Task { try await gate.wait() }
        let write = Task { try await gate.admit() }
        await parked(gate, 2)

        read.cancel()
        write.cancel()
        #expect(await error(of: read) == .cancelled)
        #expect(await error(of: write) == .cancelled)
        #expect(gate.waiting == 0)
    }
}
