import ComposableArchitecture
import Foundation
import Testing

@testable import NestZone

/// Deleting the account (Guideline 5.1.1(v)) and removing a member: the two
/// writes Settings gained for review. Written to be run in Xcode; not run by
/// the agent that wrote them.
@MainActor
@Suite("Account deletion and members")
struct AccountDeletionTests {

    @Test("Confirming asks the server with Apple's code, then ends the session")
    func deletesAndSignsOut() async {
        let sent = LockIsolated<[String?]>([])
        let store = TestStore(initialState: SettingsFeature.State(homeID: "h1")) {
            SettingsFeature()
        } withDependencies: {
            $0.auth.deleteAccount = { code in sent.withValue { $0.append(code) } }
        }

        await store.send(.deleteAccountTapped) { $0.isConfirmingDelete = true }
        // The dialog closes itself through its binding.
        await store.send(.set(\.isConfirmingDelete, false)) { $0.isConfirmingDelete = false }
        await store.send(.deleteAccountAuthorized(code: "apple-code")) { $0.isDeletingAccount = true }
        await store.receive(\.deleteAccountFinished) { $0.isDeletingAccount = false }
        await store.receive(\.delegate.signedOut)
        #expect(sent.value == ["apple-code"])
    }

    @Test("A deletion the server refuses puts the row back and says why")
    func refusedDeletion() async {
        let store = TestStore(initialState: SettingsFeature.State(homeID: "h1")) {
            SettingsFeature()
        } withDependencies: {
            $0.auth.deleteAccount = { _ in throw AppError.offline }
        }

        await store.send(.deleteAccountAuthorized(code: nil)) { $0.isDeletingAccount = true }
        await store.receive(\.deleteAccountFinished) {
            $0.isDeletingAccount = false
            $0.alert = .failure(.offline)
        }
    }

    @Test("Backing out of Apple's sheet stops the deletion without an alert")
    func cancelledReauthorization() async {
        let store = TestStore(initialState: SettingsFeature.State(homeID: "h1")) {
            SettingsFeature()
        }
        await store.send(.deleteAccountAuthorizationFailed(.cancelled))
    }

    @Test("Removing a member takes them out at once and the write names them")
    func removesMember() async {
        let removed = LockIsolated<[String]>([])
        var state = SettingsFeature.State(homeID: "h1", user: User(id: "me", name: "Ada"))
        state.members = [User(id: "me", name: "Ada"), User(id: "u2", name: "Bea")]
        let store = TestStore(initialState: state) {
            SettingsFeature()
        } withDependencies: {
            $0.homes.removeMember = { home, user in
                removed.withValue { $0.append("\(home.rawValue)/\(user.rawValue)") }
            }
        }

        await store.send(.alert(.presented(.confirmRemoveMember("u2")))) {
            $0.removingMember = "u2"
            $0.members.remove(id: "u2")
        }
        await store.receive(\.memberRemoved) { $0.removingMember = nil }
        #expect(removed.value == ["h1/u2"])
    }

    @Test("A removal the server refuses brings the person back where they were")
    func refusedRemovalRollsBack() async {
        var state = SettingsFeature.State(homeID: "h1", user: User(id: "me", name: "Ada"))
        let bea = User(id: "u2", name: "Bea")
        state.members = [User(id: "me", name: "Ada"), bea, User(id: "u3", name: "Cem")]
        let store = TestStore(initialState: state) {
            SettingsFeature()
        } withDependencies: {
            $0.homes.removeMember = { _, _ in throw AppError.offline }
        }

        await store.send(.alert(.presented(.confirmRemoveMember("u2")))) {
            $0.removingMember = "u2"
            $0.members.remove(id: "u2")
        }
        await store.receive(\.removeMemberFailed) {
            $0.removingMember = nil
            $0.members.insert(bea, at: 1)
            $0.alert = .failure(.offline)
        }
    }

    @Test("You cannot remove yourself from the members list")
    func cannotRemoveSelf() async {
        var state = SettingsFeature.State(homeID: "h1", user: User(id: "me", name: "Ada"))
        state.members = [User(id: "me", name: "Ada")]
        let store = TestStore(initialState: state) { SettingsFeature() }
        await store.send(.alert(.presented(.confirmRemoveMember("me"))))
    }
}
