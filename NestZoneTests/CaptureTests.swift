import ComposableArchitecture
import Foundation
import Testing
@testable import NestZone

/// A fixed clock for everything here: Sunday 18 October 2026, three in the
/// afternoon, Istanbul. A Sunday on purpose — "Sunday" said on a Sunday, and
/// "11:00" after eleven, are where date reading goes wrong.
private enum Fixture {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar
    }()

    static let now = date(day: 18, hour: 15)

    static func date(month: Int = 10, day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    static let ali = User(id: "u1", name: "Ali Yılmaz")
    static let ayse = User(id: "u2", name: "Ayşe")
    static let members = [ali, ayse]

    static func parse(_ text: String, members: [User] = members) -> CaptureDraft {
        CaptureParser.parse(
            text,
            members: members,
            now: now,
            locale: Locale(identifier: "tr_TR"),
            calendar: calendar,
            fallbackCurrency: "TRY"
        )
    }
}

// MARK: - Parser

@Suite("Add anything: reading a line")
struct CaptureParserTests {

    @Test("A comma list is shopping, one item per comma")
    func commaListIsShopping() {
        let draft = Fixture.parse("süt, yumurta, ekmek")
        #expect(draft.kind == .shopping)
        #expect(draft.confidence == .strong)
        #expect(draft.items == ["süt", "yumurta", "ekmek"])
    }

    @Test("The words that say 'buy' are not items")
    func shoppingTriggersAreStripped() {
        #expect(Fixture.parse("buy milk, eggs and bread").items == ["milk", "eggs", "bread"])
        #expect(Fixture.parse("ekmek al").items == ["ekmek"])
        #expect(Fixture.parse("süt bitti").items == ["süt"])
        #expect(Fixture.parse("we need toilet paper").items == ["toilet paper"])
    }

    @Test("'and' splits only the last of several comma-separated things")
    func conjunctionsSplitTheTailOnly() {
        #expect(Fixture.parse("mac and cheese, milk").items == ["mac and cheese", "milk"])
        #expect(Fixture.parse("süt ve yumurta").items == ["süt", "yumurta"])
        // A decimal comma is not a separator.
        #expect(Fixture.parse("2 kg elma, 2,5 kg patates").items == ["2 kg elma", "2,5 kg patates"])
    }

    @Test("A chore keeps its words and loses its date")
    func choreWithADay() {
        let draft = Fixture.parse("take the bins out tomorrow")
        #expect(draft.kind == .chore)
        #expect(draft.confidence == .strong)
        #expect(draft.title(for: .chore) == "take the bins out")
        #expect(draft.date == CaptureDate(date: Fixture.date(day: 19), hasTime: false))
    }

    @Test("Turkish day words are read, in any case, with or without a time")
    func turkishDays() {
        let chore = Fixture.parse("yarın çöpü çıkar")
        #expect(chore.kind == .chore)
        #expect(chore.title(for: .chore) == "çöpü çıkar")
        #expect(chore.date?.date == Fixture.date(day: 19))

        // `NSDataDetector` drops the day from "YARIN" in capitals.
        let meeting = Fixture.parse("YARIN 19:30 toplantı")
        #expect(meeting.date == CaptureDate(date: Fixture.date(day: 19, hour: 19, minute: 30), hasTime: true))
        #expect(meeting.title(for: .event) == "toplantı")

        let friday = Fixture.parse("Cuma 20:00")
        #expect(friday.date == CaptureDate(date: Fixture.date(day: 23, hour: 20), hasTime: true))

        let thursday = Fixture.parse("Perşembe")
        #expect(thursday.date == CaptureDate(date: Fixture.date(day: 22), hasTime: false))
    }

    @Test("A weekday named on that weekday means next week's")
    func sameWeekdayIsNextWeek() {
        #expect(Fixture.parse("clean the bathroom on Sunday").date?.date == Fixture.date(day: 25))
        #expect(Fixture.parse("Pazar günü kahvaltı 11:00").date?.date == Fixture.date(day: 25, hour: 11))
    }

    @Test("'Pazar' is a market unless it is plainly a day")
    func pazarIsAMarket() {
        let draft = Fixture.parse("pazardan domates al")
        #expect(draft.date == nil)
        #expect(draft.kind == .shopping)
    }

    @Test("An event: the date goes, the place and the meal stay")
    func eventTitles() {
        let english = Fixture.parse("dinner at Ayşe's Friday 8pm")
        #expect(english.kind == .event)
        #expect(english.confidence == .strong)
        #expect(english.title(for: .event) == "dinner at Ayşe's")
        #expect(english.date?.date == Fixture.date(day: 23, hour: 20))
        #expect(english.eventKind == .dinnerParty)

        // The detector reads "yemek cuma" as one date; the rules keep the meal.
        let turkish = Fixture.parse("Ayşe'de yemek cuma 20:00")
        #expect(turkish.kind == .event)
        #expect(turkish.title(for: .event) == "Ayşe'de yemek")
        #expect(turkish.date?.date == Fixture.date(day: 23, hour: 20))
    }

    @Test("An hour with no am/pm is read by what surrounds it")
    func meridiem() {
        #expect(Fixture.parse("dinner at 8").date?.date == Fixture.date(day: 18, hour: 20))
        #expect(Fixture.parse("yarın akşam 8'de mangal").date?.date == Fixture.date(day: 19, hour: 20))
        #expect(Fixture.parse("yarın sabah 8 koşu").date?.date == Fixture.date(day: 19, hour: 8))
    }

    @Test("A time already gone today means tomorrow")
    func pastTimeRollsOver() {
        #expect(Fixture.parse("saat 11:00 tesisatçı").date?.date == Fixture.date(day: 19, hour: 11))
        #expect(Fixture.parse("saat 18:00 tesisatçı").date?.date == Fixture.date(day: 18, hour: 18))
    }

    @Test("A written-out date is read by the detector")
    func writtenDate() throws {
        let date = try #require(Fixture.parse("doğum günü 12 Kasım").date)
        // The detector counts from the device clock, so only the day is fixed.
        let parts = Fixture.calendar.dateComponents([.month, .day], from: date.date)
        #expect(parts.month == 11)
        #expect(parts.day == 12)
        #expect(Fixture.parse("doğum günü 12 Kasım").title(for: .event) == "doğum günü")
    }

    @Test("Paid with an amount is an expense; the payer is whoever comes first")
    func expenses() {
        let bare = Fixture.parse("Ali paid 300 for internet")
        #expect(bare.kind == .expense)
        #expect(bare.confidence == .strong)
        #expect(bare.amount == CaptureAmount(minorUnits: 30_000, currency: nil))
        #expect(bare.payer == "u1")
        #expect(bare.title(for: .expense) == "Ali paid for internet")

        let turkish = Fixture.parse("Ali internete 300 TL ödedi")
        #expect(turkish.kind == .expense)
        #expect(turkish.amount == CaptureAmount(minorUnits: 30_000, currency: "TRY"))
        #expect(turkish.payer == "u1")

        // Named, but paid *to*.
        let paidTo = Fixture.parse("I paid Ali 300")
        #expect(paidTo.member == "u1")
        #expect(paidTo.payer == nil)
        #expect(Fixture.parse("Ali'ye 300 TL ödedim").payer == nil)
    }

    @Test("Currencies and separators")
    func amounts() {
        #expect(Fixture.parse("paid ₺300").amount == CaptureAmount(minorUnits: 30_000, currency: "TRY"))
        #expect(Fixture.parse("paid $20").amount == CaptureAmount(minorUnits: 2_000, currency: "USD"))
        #expect(Fixture.parse("paid 15€").amount == CaptureAmount(minorUnits: 1_500, currency: "EUR"))
        #expect(Fixture.parse("£10 taxi paid").amount == CaptureAmount(minorUnits: 1_000, currency: "GBP"))
        #expect(Fixture.parse("kira 1.250 TL ödendi").amount?.minorUnits == 125_000)
        #expect(Fixture.parse("paid 12,50 lira").amount?.minorUnits == 1_250)
        #expect(Fixture.parse("1,250.50 TL kira").amount?.minorUnits == 125_050)
        // Money with its currency is never a date.
        let bread = Fixture.parse("spent 25.10 TL on bread")
        #expect(bread.amount == CaptureAmount(minorUnits: 2_510, currency: "TRY"))
        #expect(bread.date == nil)
        // The case ending goes with the amount, not into the title.
        #expect(Fixture.parse("300 TL'yi Ayşe ödedi").title(for: .expense) == "Ayşe ödedi")
    }

    @Test("A number is only money with a currency or a paying word")
    func numbersAreNotMoney() {
        #expect(Fixture.parse("2 kg elma").amount == nil)
        #expect(Fixture.parse("Friday 8pm drinks").amount == nil)
    }

    @Test("Notes: a prefix, or a password")
    func notes() {
        let wifi = Fixture.parse("wifi password is on the router")
        #expect(wifi.kind == .note)
        #expect(wifi.confidence == .strong)

        let prefixed = Fixture.parse("not: kapı şifresi 1234")
        #expect(prefixed.kind == .note)
        #expect(prefixed.title(for: .note) == "kapı şifresi 1234")
    }

    @Test("Problems, with the room when one is named")
    func problems() {
        let tap = Fixture.parse("fix the bathroom tap")
        #expect(tap.kind == .problem)
        #expect(tap.confidence == .strong)
        #expect(tap.issueArea == .bathroom)

        let leak = Fixture.parse("musluk akıyor")
        #expect(leak.kind == .problem)

        // The dishwasher is a machine, not the dishes.
        let dishwasher = Fixture.parse("bulaşık makinesi bozuk")
        #expect(dishwasher.kind == .problem)
        #expect(dishwasher.confidence == .strong)
        #expect(dishwasher.issueArea == .kitchen)
    }

    @Test("Chores that look like shopping")
    func choresThatSayAl() {
        // "toz al" is dusting, whatever "al" means on its own.
        #expect(Fixture.parse("toz al").kind == .chore)
    }

    @Test("A lone word is a weak guess; nothing is no guess")
    func weakAndNone() {
        let milk = Fixture.parse("milk")
        #expect(milk.kind == .shopping)
        #expect(milk.confidence == .weak)

        #expect(Fixture.parse("   ").isEmpty)
        #expect(Fixture.parse("").kind == nil)
    }

    @Test("A date with nothing else after it is not a chore title")
    func dateAloneHasNoTitle() {
        #expect(Fixture.parse("yarın").title(for: .chore).isEmpty)
        #expect(Fixture.parse("300 TL").title(for: .expense).isEmpty)
    }

    @Test("Two members with one first name are nobody")
    func ambiguousNames() {
        let twins = [User(id: "u1", name: "Ali Yılmaz"), User(id: "u3", name: "Ali Demir")]
        #expect(Fixture.parse("Ali take the bins out", members: twins).member == nil)
        #expect(Fixture.parse("Ayşe take the bins out").member == "u2")
        // Turkish suffixes and capitals fold.
        #expect(Fixture.parse("AYŞE'ye söyle çöpü çıkarsın").member == "u2")
    }
}

// MARK: - Reducer

@MainActor
@Suite("Add anything")
struct CaptureFeatureTests {

    private static func state(kind: CaptureKind? = nil) -> CaptureFeature.State {
        CaptureFeature.State(
            homeID: "h1",
            currentUserID: "u1",
            members: IdentifiedArray(uniqueElements: Fixture.members),
            kind: kind,
            locale: Locale(identifier: "tr_TR")
        )
    }

    private static func dependencies(_ values: inout DependencyValues) {
        values.date.now = Fixture.now
        values.calendar = Fixture.calendar
    }

    @Test("A comma list goes to Shopping in one write")
    func shoppingInOneWrite() async {
        await withDependencies {
            $0.defaultAppStorage = .inMemory
        } operation: {
            let sent = LockIsolated<[[String]]>([])
            let store = TestStore(initialState: Self.state()) {
                CaptureFeature()
            } withDependencies: {
                Self.dependencies(&$0)
                $0.shopping.createMany = { _, names in
                    sent.withValue { $0.append(names) }
                    // One of the three was already on the list.
                    return ["s1", "s2"]
                }
            }
            store.exhaustivity = .off

            await store.send(.binding(.set(\.text, "süt, yumurta, ekmek")))
            #expect(store.state.kind == .shopping)
            #expect(store.state.canAdd)

            await store.send(.addTapped) {
                $0.isSaving = true
            }
            let outcome = CaptureOutcome(kind: .shopping, count: 2, alreadyListed: 1)
            await store.receive(\.saved, outcome) {
                $0.isSaving = false
                $0.$lastKind.withLock { $0 = "shopping" }
            }
            await store.receive(\.delegate.finished, outcome)

            #expect(sent.value == [["süt", "yumurta", "ekmek"]])
        }
    }

    @Test("A refused write keeps the sheet, the words, and says why")
    func failedWriteKeepsTheText() async {
        await withDependencies {
            $0.defaultAppStorage = .inMemory
        } operation: {
            let store = TestStore(initialState: Self.state()) {
                CaptureFeature()
            } withDependencies: {
                Self.dependencies(&$0)
                $0.shopping.createMany = { _, _ in throw AppError.offline }
            }
            store.exhaustivity = .off

            await store.send(.binding(.set(\.text, "süt, yumurta")))
            await store.send(.addTapped)
            await store.receive(\.saveFailed) {
                $0.isSaving = false
                $0.alert = .failure(.offline)
            }
            #expect(store.state.text == "süt, yumurta")
            #expect(store.state.lastKind == "")
        }
    }

    @Test("A chore is written with its due day and the person it names")
    func choreIsWritten() async {
        await withDependencies {
            $0.defaultAppStorage = .inMemory
        } operation: {
            let created = LockIsolated<[NewTask]>([])
            let store = TestStore(initialState: Self.state()) {
                CaptureFeature()
            } withDependencies: {
                Self.dependencies(&$0)
                $0.tasks.create = { task in created.withValue { $0.append(task) } }
            }
            store.exhaustivity = .off

            await store.send(.binding(.set(\.text, "Ayşe take the bins out tomorrow")))
            #expect(store.state.kind == .chore)
            await store.send(.addTapped)
            await store.receive(\.saved, CaptureOutcome(kind: .chore, count: 1))
            await store.receive(\.delegate.finished)

            // Due by the end of tomorrow, not at noon.
            #expect(created.value == [NewTask(
                title: "Ayşe take the bins out",
                homeID: "h1",
                assignedTo: "u2",
                dueDate: Fixture.date(day: 19, hour: 23, minute: 59)
            )])
        }
    }

    @Test("A note is written without its prefix")
    func noteIsWritten() async {
        await withDependencies {
            $0.defaultAppStorage = .inMemory
        } operation: {
            let written = LockIsolated<[String]>([])
            let store = TestStore(initialState: Self.state()) {
                CaptureFeature()
            } withDependencies: {
                Self.dependencies(&$0)
                $0.notes.create = { body, _, _ in written.withValue { $0.append(body) } }
            }
            store.exhaustivity = .off

            await store.send(.binding(.set(\.text, "note: wifi is NestZone-5G")))
            #expect(store.state.kind == .note)
            await store.send(.addTapped)
            await store.receive(\.saved, CaptureOutcome(kind: .note, count: 1))
            #expect(written.value == ["wifi is NestZone-5G"])
        }
    }

    @Test("A problem opens the full form, filled in, and its save is the finish")
    func problemOpensTheComposer() async {
        await withDependencies {
            $0.defaultAppStorage = .inMemory
        } operation: {
            let store = TestStore(initialState: Self.state()) {
                CaptureFeature()
            } withDependencies: {
                Self.dependencies(&$0)
            }
            store.exhaustivity = .off

            await store.send(.binding(.set(\.text, "fix the bathroom tap")))
            await store.send(.addTapped)
            let issue = store.state.composer?.problem
            #expect(issue?.title == "fix the bathroom tap")
            #expect(issue?.area == .bathroom)

            await store.send(.composer(.presented(.problem(.delegate(.saved))))) {
                $0.composer = nil
            }
            await store.receive(\.saved, CaptureOutcome(kind: .problem, count: 1))
            await store.receive(\.delegate.finished, CaptureOutcome(kind: .problem, count: 1))
        }
    }

    @Test("An expense opens with the amount and the payer the line named")
    func expenseOpensTheComposer() async {
        await withDependencies {
            $0.defaultAppStorage = .inMemory
        } operation: {
            @Shared(.householdCurrency) var householdCurrency: String?
            $householdCurrency.withLock { $0 = "TRY" }

            let store = TestStore(initialState: Self.state()) {
                CaptureFeature()
            } withDependencies: {
                Self.dependencies(&$0)
            }
            store.exhaustivity = .off

            await store.send(.binding(.set(\.text, "Ali paid 300 for internet")))
            #expect(store.state.kind == .expense)
            await store.send(.addTapped)

            let expense = store.state.composer?.expense
            #expect(expense?.currency == "TRY")
            #expect(expense?.amountMinor == 30_000)
            #expect(expense?.paidBy == "u1")
            #expect(expense?.title == "Ali paid for internet")
        }
    }

    @Test("A dinner with a day but no time opens at seven in the evening")
    func eventOpensInTheEvening() async {
        await withDependencies {
            $0.defaultAppStorage = .inMemory
        } operation: {
            let store = TestStore(initialState: Self.state()) {
                CaptureFeature()
            } withDependencies: {
                Self.dependencies(&$0)
                $0.recipes.byHome = { _ in AsyncThrowingStream { $0.finish() } }
                $0.recipes.samples = { [] }
            }
            store.exhaustivity = .off

            await store.send(.binding(.set(\.text, "dinner Friday")))
            await store.send(.addTapped)
            let event = store.state.composer?.event
            #expect(event?.title == "dinner")
            #expect(event?.kind == .dinnerParty)
            #expect(event?.startsAt == Fixture.date(day: 23, hour: 19))
        }
    }

    @Test("A chip the person picked is never moved again")
    func pickedChipStays() async {
        await withDependencies {
            $0.defaultAppStorage = .inMemory
        } operation: {
            let asked = LockIsolated(0)
            let store = TestStore(initialState: Self.state()) {
                CaptureFeature()
            } withDependencies: {
                Self.dependencies(&$0)
                $0.captureClassifier.isAvailable = { _ in true }
                $0.captureClassifier.classify = { _, _ in
                    asked.withValue { $0 += 1 }
                    return .event
                }
                $0.continuousClock = ImmediateClock()
            }
            store.exhaustivity = .off

            await store.send(.kindTapped(.note)) {
                $0.kind = .note
                $0.isKindLocked = true
            }
            await store.send(.binding(.set(\.text, "fix the bathroom tap")))
            await store.send(.binding(.set(\.text, "milk")))
            await store.finish()

            #expect(store.state.kind == .note)
            #expect(asked.value == 0)
        }
    }

    @Test("The model moves the chip when the rules only lean, once typing pauses")
    func modelDecidesAWeakLine() async {
        await withDependencies {
            $0.defaultAppStorage = .inMemory
        } operation: {
            let clock = TestClock()
            let asked = LockIsolated<[String]>([])
            let store = TestStore(initialState: Self.state()) {
                CaptureFeature()
            } withDependencies: {
                Self.dependencies(&$0)
                $0.captureClassifier.isAvailable = { _ in true }
                $0.captureClassifier.classify = { text, _ in
                    asked.withValue { $0.append(text) }
                    return .chore
                }
                $0.continuousClock = clock
            }
            store.exhaustivity = .off

            await store.send(.binding(.set(\.text, "call")))
            await store.send(.binding(.set(\.text, "call the landlord")))
            // The rules lean towards shopping for a three-word line…
            #expect(store.state.kind == .shopping)
            #expect(store.state.draft.confidence == .weak)

            await clock.advance(by: CaptureFeature.modelDebounce)
            await store.receive(\.classified)

            // …the model says chore, and only the last words were asked about.
            #expect(store.state.kind == .chore)
            #expect(asked.value == ["call the landlord"])
        }
    }

    @Test("The model is not asked when the rules are sure")
    func modelSkippedWhenRulesAreSure() async {
        await withDependencies {
            $0.defaultAppStorage = .inMemory
        } operation: {
            let asked = LockIsolated(0)
            let store = TestStore(initialState: Self.state()) {
                CaptureFeature()
            } withDependencies: {
                Self.dependencies(&$0)
                $0.captureClassifier.isAvailable = { _ in true }
                $0.captureClassifier.classify = { _, _ in
                    asked.withValue { $0 += 1 }
                    return .note
                }
                $0.continuousClock = ImmediateClock()
            }
            store.exhaustivity = .off

            await store.send(.binding(.set(\.text, "süt, yumurta, ekmek")))
            await store.finish()
            #expect(store.state.kind == .shopping)
            #expect(asked.value == 0)
        }
    }

    @Test("Empty field: Add is off, and the chip is where it was last used")
    func emptyFieldFallsBackToHabit() {
        withDependencies {
            $0.defaultAppStorage = .inMemory
        } operation: {
            @Shared(.captureLastKind) var lastKind: String
            $lastKind.withLock { $0 = CaptureKind.note.rawValue }

            let state = Self.state()
            #expect(state.kind == .note)
            #expect(!state.isKindLocked)
            #expect(!state.canAdd)

            // Opened from a module, the chip is that module's, and held.
            let locked = Self.state(kind: .shopping)
            #expect(locked.kind == .shopping)
            #expect(locked.isKindLocked)
        }
    }

    @Test("Cancel finishes with nothing")
    func cancel() async {
        await withDependencies {
            $0.defaultAppStorage = .inMemory
        } operation: {
            let store = TestStore(initialState: Self.state()) {
                CaptureFeature()
            } withDependencies: {
                Self.dependencies(&$0)
            }
            await store.send(.cancelTapped)
            await store.receive(\.delegate.finished, nil)
        }
    }
}
