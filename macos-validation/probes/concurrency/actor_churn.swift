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

let sem = DispatchSemaphore(value: 0)
var output: [String: Any] = [:]

Task {
    let start = Date()
    var allConsistent = true
    var totalOps = 0
    var totalExpected = 0
    let lock = NSLock()

    // Churn: create actors, hammer them from multiple tasks, verify state
    await withTaskGroup(of: Bool.self) { group in
        for churn in 0..<CHURN_COUNT {
            group.addTask {
                let counter = Counter()

                // Each actor gets OPS_PER_ACTOR increments from concurrent tasks
                await withTaskGroup(of: Void.self) { subgroup in
                    for _ in 0..<OPS_PER_ACTOR {
                        subgroup.addTask {
                            await counter.increment()
                        }
                    }
                }

                let finalValue = await counter.read()
                let consistent = (finalValue == OPS_PER_ACTOR)

                lock.lock()
                if !consistent { allConsistent = false }
                totalOps += OPS_PER_ACTOR
                totalExpected += OPS_PER_ACTOR
                lock.unlock()

                return consistent
            }
        }
        for await ok in group {
            if !ok { allConsistent = false }
        }
    }

    let elapsed = Int(Date().timeIntervalSince(start) * 1000)
    let pass = allConsistent && totalOps == totalExpected

    output = [
        "test_id": "actor_churn_\(CHURN_COUNT)x\(OPS_PER_ACTOR)",
        "result": pass ? "PASS" : "FAIL",
        "actors_churned": CHURN_COUNT,
        "ops_per_actor": OPS_PER_ACTOR,
        "total_ops": totalOps,
        "total_expected": totalExpected,
        "all_consistent": allConsistent,
        "elapsed_ms": elapsed
    ]
    if !pass {
        output["fail_reason"] = "consistent=\(allConsistent) ops_match=\(totalOps == totalExpected)"
    }
    sem.signal()
}
sem.wait()

if let data = try? JSONSerialization.data(withJSONObject: output, options: .prettyPrinted),
   let json = String(data: data, encoding: .utf8) {
    print(json)
}
