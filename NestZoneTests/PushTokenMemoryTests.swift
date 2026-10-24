import ComposableArchitecture
import Foundation
import Testing
@testable import NestZone

/// The device token the server may still hold from an earlier launch.
@Suite("Push token memory")
struct PushTokenMemoryTests {

    private func memory() -> PushTokenMemory {
        let suite = "PushTokenMemoryTests-\(UUID().uuidString)"
        return PushTokenMemory(suite: suite)
    }

    private struct Offline: Error {}

    @Test("Sign-out with no token this launch unregisters the remembered one, then forgets it")
    func signOutUsesTheRememberedToken() async {
        let memory = memory()
        await memory.registered("old") { _ in }
        let sent = LockIsolated<[String]>([])

        await memory.unregisterAtSignOut(current: nil) { token in
            sent.withValue { $0.append(token) }
        }
        #expect(sent.value == ["old"])
        #expect(memory.remembered == nil)
    }

    @Test("Sign-out unregisters this launch's token and the remembered one, each once")
    func signOutUnregistersBoth() async {
        let memory = memory()
        await memory.registered("old") { _ in }
        let sent = LockIsolated<[String]>([])

        await memory.unregisterAtSignOut(current: "new") { token in sent.withValue { $0.append(token) } }
        #expect(Set(sent.value) == ["old", "new"])
        #expect(sent.value.count == 2)

        // The same token twice is one call.
        let again = memory
        await again.registered("same") { _ in }
        let calls = LockIsolated<[String]>([])
        await again.unregisterAtSignOut(current: "same") { token in calls.withValue { $0.append(token) } }
        #expect(calls.value == ["same"])
    }

    @Test("A token that changed between launches: the old one is unregistered and replaced")
    func changedTokenUnregistersTheStaleOne() async {
        let memory = memory()
        await memory.registered("A") { _ in }
        let sent = LockIsolated<[String]>([])

        await memory.registered("B") { token in sent.withValue { $0.append(token) } }
        #expect(sent.value == ["A"])
        #expect(memory.remembered == "B")

        // The same token again unregisters nothing.
        await memory.registered("B") { token in sent.withValue { $0.append(token) } }
        #expect(sent.value == ["A"])
    }

    @Test("A failed unregister keeps the token, so a later sign-out tries again")
    func failureKeepsTheToken() async {
        let memory = memory()
        await memory.registered("old") { _ in }

        await memory.unregisterAtSignOut(current: nil) { _ in throw Offline() }
        #expect(memory.remembered == "old")

        await memory.registered("new") { _ in throw Offline() }
        // The stale one could not be dropped, but the new one is what this
        // launch holds; sign-out will try both.
        #expect(memory.remembered == "new")
    }
}
