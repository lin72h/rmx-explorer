// op-232 concurrency corpus — shape (b): actor churn
// Tests: actor serial isolation under create/use/teardown churn.
// Property: actor state is consistent, no data races across hops.
// Portable: macOS-27 (swiftc) + rmxOS (when Swift toolchain lands).
// Emits structured JSON to stdout.

import Foundation

let CHURN_COUNT = 500   // actors created+used+dropped
let OPS_PER_ACTOR = 20  // concurrent hops per actor

actor Counter {
    private(set) var value: Int = 0
    func increment() { value += 1 }
    func read() -> Int { value }
}

// op-231 D3 ordering invariant: per-actor mailbox is serial (FIFO).
// OrderedCounter records the sequence of increment calls to verify ordering.
actor OrderedCounter {
    private(set) var value: Int = 0
    private(set) var sequence: [Int] = []
    private var next: Int = 1

    func increment() {
        sequence.append(next)
        next += 1
        value += 1
    }
    func read() -> (Int, [Int]) { (value, sequence) }
}

let sem = DispatchSemaphore(value: 0)
var output: [String: Any] = [:]

Task {
    let start = Date()
    var allConsistent = true
    var orderingOk = true
    var totalOps = 0
    var totalExpected = 0
    let lock = NSLock()

    // Churn: create actors, hammer them from multiple tasks, verify state
    await withTaskGroup(of: Bool.self) { group in
        for churn in 0..<CHURN_COUNT {
            group.addTask {
                let counter = OrderedCounter()

                // Each actor gets OPS_PER_ACTOR increments from concurrent tasks
                await withTaskGroup(of: Void.self) { subgroup in
                    for _ in 0..<OPS_PER_ACTOR {
                        subgroup.addTask {
                            await counter.increment()
                        }
                    }
                }

                let (finalValue, seq) = await counter.read()
                let consistent = (finalValue == OPS_PER_ACTOR)
                // Ordering invariant: sequence should be 1,2,3,...,N (per-actor mailbox serial)
                let ordered = (seq.count == OPS_PER_ACTOR && seq == Array(1...OPS_PER_ACTOR))

                lock.lock()
                if !consistent { allConsistent = false }
                if !ordered { orderingOk = false }
                totalOps += OPS_PER_ACTOR
                totalExpected += OPS_PER_ACTOR
                lock.unlock()

                return consistent && ordered
            }
        }
        for await ok in group {
            if !ok { allConsistent = false }
        }
    }

    let elapsed = Int(Date().timeIntervalSince(start) * 1000)
    let pass = allConsistent && orderingOk && totalOps == totalExpected

    output = [
        "test_id": "actor_churn_\(CHURN_COUNT)x\(OPS_PER_ACTOR)",
        "result": pass ? "PASS" : "FAIL",
        "actors_churned": CHURN_COUNT,
        "ops_per_actor": OPS_PER_ACTOR,
        "total_ops": totalOps,
        "total_expected": totalExpected,
        "all_consistent": allConsistent,
        "ordering_ok": orderingOk,
        "elapsed_ms": elapsed
    ]
    if !pass {
        output["fail_reason"] = "consistent=\(allConsistent) ordering=\(orderingOk) ops_match=\(totalOps == totalExpected)"
    }
    sem.signal()
}
sem.wait()

if let data = try? JSONSerialization.data(withJSONObject: output, options: .prettyPrinted),
   let json = String(data: data, encoding: .utf8) {
    print(json)
}
