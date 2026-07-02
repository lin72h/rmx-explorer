// op-232 concurrency corpus — shape (c): deep async/await chain
// Tests: continuation queue depth — many nested async calls resume correctly.
// Property: continuation resumption at depth works, values propagate, no drops.
// Portable: macOS-27 (swiftc) + rmxOS (when Swift toolchain lands).
// Emits structured JSON to stdout.

import Foundation

let CHAIN_DEPTH = 500      // levels of nested async calls
let CHAIN_COUNT = 10       // parallel chains

// Recursive async function: each level awaits the next
func deepChain(_ depth: Int) async -> Int {
    if depth <= 0 { return 0 }
    let child = await deepChain(depth - 1)
    return child + 1  // each level adds 1
}

let sem = DispatchSemaphore(value: 0)
var output: [String: Any] = [:]

Task {
    let start = Date()
    var allCorrect = true
    var results: [Int] = []
    let lock = NSLock()

    // Run CHAIN_COUNT parallel chains, each CHAIN_DEPTH deep
    await withTaskGroup(of: (Int, Int).self) { group in
        for chainIdx in 0..<CHAIN_COUNT {
            group.addTask {
                let value = await deepChain(CHAIN_DEPTH)
                return (chainIdx, value)
            }
        }
        for await (idx, value) in group {
            lock.lock(); results.append(value); lock.unlock()
            if value != CHAIN_DEPTH { allCorrect = false }
        }
    }

    let elapsed = Int(Date().timeIntervalSince(start) * 1000)
    let pass = allCorrect && results.count == CHAIN_COUNT &&
               results.allSatisfy { $0 == CHAIN_DEPTH }

    output = [
        "test_id": "deep_async_chain_\(CHAIN_DEPTH)x\(CHAIN_COUNT)",
        "result": pass ? "PASS" : "FAIL",
        "chain_depth": CHAIN_DEPTH,
        "chain_count": CHAIN_COUNT,
        "chains_completed": results.count,
        "all_correct_depth": allCorrect,
        "expected_value": CHAIN_DEPTH,
        "actual_values": results,
        "elapsed_ms": elapsed
    ]
    if !pass {
        output["fail_reason"] = "completed=\(results.count)/\(CHAIN_COUNT) correct=\(allCorrect)"
    }
    sem.signal()
}
sem.wait()

if let data = try? JSONSerialization.data(withJSONObject: output, options: .prettyPrinted),
   let json = String(data: data, encoding: .utf8) {
    print(json)
}
