// op-232 libdispatch<->Swift-concurrency corpus — macOS-27 TRUTH probe.
// Pure Swift stdlib + Concurrency (NO Foundation/Dispatch/Darwin — portable to both
// targets; the macOS 27 beta SDK's Foundation.swiftmodule is unparseable by the
// installed Swift toolchains, so this probe is import-free). Builds with
// `xcrun --toolchain XcodeDefault swiftc -O op232-concurrency-truth.swift -o ...`.
//
// Three shapes that stress the dispatch worker-pool (the sub-fix #1 surface):
//   (a) wide fan-out TaskGroup
//   (b) actor churn (serial-queue create/teardown + hop)
//   (c) deep async/await chain (continuation queue depth)
// Emits one JSON line per shape (the macOS-27 truth vector) + a regime header line.

import _Concurrency  // explicit; stdlib

let clock = ContinuousClock()

func elapsedNS(_ start: ContinuousClock.Instant) -> UInt64 {
    let d = start.duration(to: clock.now)
    let (s, a) = d.components
    return UInt64(s) * 1_000_000_000 &+ UInt64(a / 1_000_000_000)
}

// ---- (a) wide fan-out TaskGroup ----
// busy work that can't be DCE'd (result returned)
@inline(__always)
func burn(_ seed: Int) -> Int {
    var s = seed; var i = 0
    while i < 30_000 { s &+= i; i &+= 1 }
    return s
}

// single-task baseline (for the parallelism ratio)
let singleStart = clock.now
let singleSum = await Task.detached { burn(7) }.value
let singleNS = elapsedNS(singleStart)

let N = 256
let fanStart = clock.now
let fanChecksum = await withTaskGroup(of: Int.self) { g in
    for i in 0..<N { g.addTask { burn(i) } }
    var t = 0
    for await r in g { t &+= r }
    return t
}
let fanNS = elapsedNS(fanStart)
let fanRatio = (fanNS > 0) ? (Double(N) * Double(singleNS) / Double(fanNS)) : 0.0
print("{\"shape\":\"a_fanout_taskgroup\",\"completed\":\(N),\"checksum\":\(fanChecksum),\"single_ns\":\(singleNS),\"elapsed_ns\":\(fanNS),\"parallelism_ratio\":\(fanRatio)}")

// ---- (b) actor churn (serial-queue create/teardown + hop) ----
actor Hopper {
    var hops = 0
    func hop() -> Int { hops &+= 1; return hops }
    func final() -> Int { hops }
}
let M = 256  // actors created/destroyed
let H = 32   // hops each
let churnStart = clock.now
var consistencySum = 0
for _ in 0..<M {
    let a = Hopper()
    for _ in 0..<H { consistencySum &+= await a.hop() }
    consistencySum &+= await a.final()
}
let churnNS = elapsedNS(churnStart)
// expected: each actor contributes sum(1..H) + H == H*(H+1)/2 + H
let expectedPerActor = H * (H + 1) / 2 + H
let churnExpected = expectedPerActor * M
print("{\"shape\":\"b_actor_churn\",\"actors\":\(M),\"hops_each\":\(H),\"consistency_sum\":\(consistencySum),\"expected_sum\":\(churnExpected),\"consistency_ok\":\(consistencySum == churnExpected),\"elapsed_ns\":\(churnNS)}")

// ---- (c) deep async/await chain (continuation queue depth) ----
let D = 800
func chain(_ x: Int) async -> Int {
    if x == 0 { return 0 }
    return await chain(x - 1) &+ 1
}
let chainStart = clock.now
let chainResult = await chain(D)
let chainNS = elapsedNS(chainStart)
print("{\"shape\":\"c_deep_chain\",\"depth\":\(D),\"result\":\(chainResult),\"depth_reached\":\(chainResult),\"elapsed_ns\":\(chainNS)}")
