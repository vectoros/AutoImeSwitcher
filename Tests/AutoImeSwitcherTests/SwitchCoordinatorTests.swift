import Testing
@testable import AutoImeSwitcher

final class SwitchCoordinatorTests {
    private var jobs: [() -> Void] = []
    private var pid: Int32 = 1
    private var source: String? = "old"
    private var selected: [String] = []
    private var reports: [Bool] = []
    private var succeeds = true

    private func coordinator() -> SwitchCoordinator {
        SwitchCoordinator(schedule: { _, action in self.jobs.append(action) },
                          isCurrent: { pid, _ in self.pid == pid },
                          currentSource: { self.source },
                          select: { source in
                              self.selected.append(source)
                              if self.succeeds { self.source = source }
                              return self.succeeds ? 0 : -50
                          },
                          report: { success, _ in self.reports.append(success) })
    }

    private func drain() {
        var count = 0
        while !jobs.isEmpty && count < 20 {
            jobs.removeFirst()()
            count += 1
        }
        #expect(jobs.isEmpty, "Retries must terminate")
    }

    @Test func testRapidAppChangeOnlyAppliesLatestRule() {
        let coordinator = coordinator()
        coordinator.request(pid: 1, source: "ABC")
        pid = 2
        coordinator.request(pid: 2, source: "Pinyin")
        drain()
        #expect(selected == ["Pinyin"])
        #expect(reports == [true])
    }

    @Test func testUnobservedAppChangeInvalidatesPendingSwitch() {
        let coordinator = coordinator()
        coordinator.request(pid: 1, source: "ABC")
        pid = 2
        drain()
        #expect(selected.isEmpty)
    }

    @Test func testPauseCancelsPendingRetry() {
        succeeds = false
        let coordinator = coordinator()
        coordinator.request(pid: 1, source: "ABC")
        jobs.removeFirst()()
        coordinator.cancel()
        drain()
        #expect(selected == ["ABC"])
        #expect(reports.isEmpty)
    }

    @Test func testFailureHasExactlyThreeAttempts() {
        succeeds = false
        let coordinator = coordinator()
        coordinator.request(pid: 1, source: "ABC")
        drain()
        #expect(selected == ["ABC", "ABC", "ABC"])
        #expect(reports == [false])
    }

    @Test func testMatchingSourceDoesNotSwitchAgain() {
        source = "ABC"
        let coordinator = coordinator()
        coordinator.request(pid: 1, source: "ABC")
        drain()
        #expect(selected.isEmpty)
        #expect(reports == [true])
    }

    @Test func testRestoredOldSourceIsRetriedAfterSelection() {
        let coordinator = coordinator()
        coordinator.request(pid: 1, source: "ABC")
        jobs.removeFirst()()
        source = "old" // Simulates macOS restoring a window's previous input source.
        drain()
        #expect(selected == ["ABC", "ABC"])
        #expect(reports == [true])
    }

    @Test func testAlreadyMatchingSourceIsVerifiedAfterFocusSettles() {
        source = "ABC"
        let coordinator = coordinator()
        coordinator.request(pid: 1, source: "ABC")
        jobs.removeFirst()()
        source = "restored"
        drain()
        #expect(selected == ["ABC"])
        #expect(reports == [true])
    }

    @Test func testManualSwitchAfterCompletedTransactionIsNotOverridden() {
        let coordinator = coordinator()
        coordinator.request(pid: 1, source: "ABC")
        drain()
        source = "manual"
        drain()
        #expect(source == "manual")
        #expect(selected == ["ABC"])
    }
}
