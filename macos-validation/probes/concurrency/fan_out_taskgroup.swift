// op-232 concurrency corpus — shape (a): wide fan-out TaskGroup
// Tests: worker-pool can handle wide fan-out without dropping work.
// Property: all tasks complete, values propagate, no duplicates.
// Portable: macOS-27 (swiftc) + rmxOS (when Swift toolchain lands).
// Emits structured JSON to stdout.

import Foundation

let TASK_COUNT = 1000

let sem = DispatchSemaphore(value: 0)
var output: [String: Any] = [:]

Task {
    let start = Date()
    var results: [Int: Int] = [:]
    let lock = NSLock()

    await withTaskGroup(of: (Int, Int).self) { group in
        for i in 0..<TASK_COUNT {
            group.addTask { (i, i * 2) }
        }
        for await (idx, val) in group {
            lock.lock(); results[idx] = val; lock.unlock()
        }
    }

    let elapsed = Int(Date().timeIntervalSince(start) * 1000)
    let sumExpected = (0..<TASK_COUNT).map { $0 * 2 }.reduce(0, +)
    let sumActual = results.values.reduce(0, +)
    let pass = results.count == TASK_COUNT && sumActual == sumExpected

    output = [
        "test_id": "fan_out_taskgroup_\(TASK_COUNT)",
        "result": pass ? "PASS" : "FAIL",
        "tasks_spawned": TASK_COUNT,
        "tasks_completed": results.count,
        "sum_expected": sumExpected,
        "sum_actual": sumActual,
        "all_unique": results.count == TASK_COUNT,
        "elapsed_ms": elapsed
    ]
    if !pass {
        output["fail_reason"] = "dropped=\(TASK_COUNT - results.count) sum_mismatch=\(sumExpected != sumActual)"
    }
    sem.signal()
}
sem.wait()

if let data = try? JSONSerialization.data(withJSONObject: output, options: .prettyPrinted),
   let json = String(data: data, encoding: .utf8) {
    print(json)
}
