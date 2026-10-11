import Foundation

/// A bounded transaction: stale focus events must never switch a newer application.
final class SwitchCoordinator {
    typealias Schedule = (TimeInterval, @escaping () -> Void) -> Void
    private let schedule: Schedule
    private let isCurrent: (Int32, String) -> Bool
    private let currentSource: () -> String?
    private let select: (String) -> Int32
    private let report: (Bool, String) -> Void
    private var generation = 0

    init(
        schedule: @escaping Schedule = { delay, action in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
        },
        isCurrent: @escaping (Int32, String) -> Bool,
        currentSource: @escaping () -> String?,
        select: @escaping (String) -> Int32,
        report: @escaping (Bool, String) -> Void
    ) {
        self.schedule = schedule
        self.isCurrent = isCurrent
        self.currentSource = currentSource
        self.select = select
        self.report = report
    }

    func cancel() { generation += 1 }

    func request(pid: Int32, source: String) {
        cancel()
        let token = generation
        schedule(0.08) { [weak self] in
            self?.attempt(pid: pid, source: source, token: token, remaining: 3)
        }
    }

    private func attempt(pid: Int32, source: String, token: Int, remaining: Int) {
        guard token == generation, isCurrent(pid, source) else { return }
        // Even an already matching source may be restored by macOS as focus settles.
        let status: Int32 = currentSource() == source ? 0 : select(source)
        schedule(0.18) { [weak self] in
            guard let self = self, token == self.generation, self.isCurrent(pid, source) else { return }
            if self.currentSource() == source {
                self.report(true, source)
            } else if remaining > 1 {
                self.attempt(pid: pid, source: source, token: token, remaining: remaining - 1)
            } else {
                self.report(false, "\(source) (OSStatus: \(status))")
            }
        }
    }
}
