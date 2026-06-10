STATUS: Draft / Awaiting Review
GATES: M1 is blocked until this document is accepted.

# M0 Oracle Migration Inventory

Date: 2026-06-04

## Scope And Non-Goals

This is M0 for the unified oracle migration. It is an inventory and provenance checkpoint only.

This migration is also the test-language unification pass. The final canonical oracle test framework is Elixir + Zig based:

- Elixir owns orchestration, verifiers, manifest checks, artifact parsing, source transforms, and certification logic.
- Zig owns portable probes and ABI/semantic probe binaries.
- Python is legacy only and is not copied into the canonical test tree.
- Shell is legacy orchestration only; shell runners and wrappers are ported to Elixir.
- awk is legacy instrumentation only; awk logic is ported to Elixir source transforms or verifiers.
- Project-owned C probes are ported to Zig where practical, with original C retained until parity passes.
- Donor C tests or payloads may remain only as external/reference payloads when they are the canonical donor behavior being tested.
- Elixir-generated C donor instrumentation is allowed because the generator is Elixir-owned and the target source is C.

No M1 work was performed while producing this draft:

- no test files copied
- no canonical Elixir/Zig framework scaffolded
- no source files deleted
- no `catalog/`, `mismatches/`, or `certification/` directories created
- no Mix app rename
- no historical oracle artifact movement

Canonical local responsibility scope:

- local oracle agent: `nx-r64`, `rx-x64`
- macOS oracle responsibility coordinated separately as `mx-r64`, with concrete `mx-a64` and `mx-x64` evidence lanes
- historical runner IDs such as `mx-a64z`, `mx-x64z`, and `nx-v64z` are preserved only when referencing existing artifacts

Producing host: `bdw-fx15-x64z`

Host kernel: `FreeBSD bdw-fx15-x64z 15.0-RELEASE FreeBSD 15.0-RELEASE releng/15.0-n280995-7aedc8de6446 GENERIC amd64`

## Repo Provenance

| repo | path | short SHA | dirty status |
| --- | --- | --- | --- |
| oracle | `/Users/me/wip-mach/wip-gpt-oracle` | `bf21c5f` | `clean before M0 draft` |
| source | `/Users/me/wip-mach/wip-gpt` | `a30ef3f` | `dirty: docs-only outside import set` |

Path A freeze status: selected and complete. Import-relevant Phase 0.8 test/framework files are committed in source commit `a30ef3f` (`phase08: freeze test framework state for oracle migration`). The legacy source test manifest below is refreshed from that committed tree. Remaining source working-tree dirt is documentation-only and is not part of import provenance.

Canonical import provenance rule:

- Canonical imports must come from a committed source SHA.
- Untracked files marked `canonical: yes` must not silently become canonical.
- Path A is selected for this refresh: import-relevant test/framework bytes come from committed source SHA `a30ef3f`.
- Current manifest hashes committed tree `a30ef3f`, not dirty working-tree bytes.
- If source cleanup or commits change those bytes, the M0 manifest must be regenerated before M1.

Historical note: M0 originally described a parent-approved uncommitted-byte
exception. Source responsibility policy commit `e6dfa40` supersedes that
exception. Oracle may validate only committed source pins.

Raw source dirty status at M0 refresh:

```text
 M docs/ROADMAP-1.0.md
 M docs/phase-0.8-launchd-dispatch-launchctl-request-findings.md
 M docs/phase-1.0.md
 M docs/roadmap.md
 M docs/terminology.md
 M docs/test-plan.md
?? docs/asl-foundation-findings.md
?? docs/nextbsd-unported-components-inventory.md
?? docs/phase-0.8-launchd-dispatch-closure-findings.md
?? docs/phase-0.8-launchd-dispatch-json-hardfail-findings.md
?? docs/phase-0.8-launchd-dispatch-launchctl-fast-exit-findings.md
?? docs/phase-0.8-launchd-dispatch-launchctl-keepalive-restart-findings.md
?? docs/phase-0.8-launchd-dispatch-launchctl-plist-findings.md
?? docs/phase-0.8-launchd-dispatch-launchctl-reload-findings.md
?? docs/phase-0.8-launchd-dispatch-launchctl-runatload-findings.md
?? docs/phase-0.8-launchd-dispatch-launchctl-signal-exit-findings.md
?? docs/phase-0.8-launchd-dispatch-launchctl-successful-exit-findings.md
?? docs/phase-0.8-launchd-dispatch-runatload-findings.md
?? docs/phase-0.8-launchd-dispatch-spawn-findings.md
?? docs/phase-0.8-launchd-dispatch-submitjob-findings.md
?? docs/phase-0.9-launchd-instrumentation-strategy.md
```

Import-relevant dirty status at M0 refresh:

```text
clean
```

Raw oracle dirty status before this M0 draft was created:

```text
clean
```

## Dirty Source Classification

Classification vocabulary: `docs_only`, `test_data`, `transient`, `pending_fix`, `unknown`.

Hard stop: M1 is blocked if any dirty path remains classified as `unknown`. Current unknown count: `0`.

Hard stop: M1 is blocked if any import-relevant path under `mix.exs`, `test/`, `scripts/`, or `fixtures/` is dirty, unknown, gitignored, or missing from committed source SHA `a30ef3f`.

| source path | git status | classification | note |
| --- | --- | --- | --- |
| `docs/ROADMAP-1.0.md` | `M` | `docs_only` | documentation only; not part of legacy test import |
| `docs/phase-0.8-launchd-dispatch-launchctl-request-findings.md` | `M` | `docs_only` | documentation only; not part of legacy test import |
| `docs/phase-1.0.md` | `M` | `docs_only` | documentation only; not part of legacy test import |
| `docs/roadmap.md` | `M` | `docs_only` | documentation only; not part of legacy test import |
| `docs/terminology.md` | `M` | `docs_only` | documentation only; not part of legacy test import |
| `docs/test-plan.md` | `M` | `docs_only` | documentation only; not part of legacy test import |
| `docs/asl-foundation-findings.md` | `??` | `docs_only` | documentation only; not part of legacy test import |
| `docs/nextbsd-unported-components-inventory.md` | `??` | `docs_only` | documentation only; not part of legacy test import |
| `docs/phase-0.8-launchd-dispatch-closure-findings.md` | `??` | `docs_only` | documentation only; not part of legacy test import |
| `docs/phase-0.8-launchd-dispatch-json-hardfail-findings.md` | `??` | `docs_only` | documentation only; not part of legacy test import |
| `docs/phase-0.8-launchd-dispatch-launchctl-fast-exit-findings.md` | `??` | `docs_only` | documentation only; not part of legacy test import |
| `docs/phase-0.8-launchd-dispatch-launchctl-keepalive-restart-findings.md` | `??` | `docs_only` | documentation only; not part of legacy test import |
| `docs/phase-0.8-launchd-dispatch-launchctl-plist-findings.md` | `??` | `docs_only` | documentation only; not part of legacy test import |
| `docs/phase-0.8-launchd-dispatch-launchctl-reload-findings.md` | `??` | `docs_only` | documentation only; not part of legacy test import |
| `docs/phase-0.8-launchd-dispatch-launchctl-runatload-findings.md` | `??` | `docs_only` | documentation only; not part of legacy test import |
| `docs/phase-0.8-launchd-dispatch-launchctl-signal-exit-findings.md` | `??` | `docs_only` | documentation only; not part of legacy test import |
| `docs/phase-0.8-launchd-dispatch-launchctl-successful-exit-findings.md` | `??` | `docs_only` | documentation only; not part of legacy test import |
| `docs/phase-0.8-launchd-dispatch-runatload-findings.md` | `??` | `docs_only` | documentation only; not part of legacy test import |
| `docs/phase-0.8-launchd-dispatch-spawn-findings.md` | `??` | `docs_only` | documentation only; not part of legacy test import |
| `docs/phase-0.8-launchd-dispatch-submitjob-findings.md` | `??` | `docs_only` | documentation only; not part of legacy test import |
| `docs/phase-0.9-launchd-instrumentation-strategy.md` | `??` | `docs_only` | documentation only; not part of legacy test import |

## Source Asset Inventory

Legacy source root: `/Users/me/wip-mach/wip-gpt`

Generated/runtime artifacts are excluded unconditionally from the canonical framework and from the legacy source test manifest:

- `__pycache__/`
- `*.pyc`
- `*.core`

| asset | exists | files | text lines | bytes |
| --- | --- | ---: | ---: | ---: |
| `mix.exs` | yes | 1 | 13 | 228 |
| `test` | yes | 4 | 567 | 19273 |
| `scripts` | yes | 99 | 74881 | 3586914 |
| `fixtures` | yes | 17 | 296 | 7469 |

Subtree file distribution:

```text
  17 fixtures/launchd
   2 scripts
  23 scripts/bhyve
  27 scripts/dispatch
   2 scripts/inventory
  41 scripts/launchd
   4 scripts/libthr
   4 test
```

Full fixture listing:

```text
fixtures/launchd/com.apple.notifyd.plist
fixtures/launchd/com.apple.syslogd.plist
fixtures/launchd/org.freebsd.devd.plist
fixtures/launchd/org.rmxos.phase08.d14.noop.plist
fixtures/launchd/org.rmxos.phase08.d15.json-rejected.json
fixtures/launchd/org.rmxos.phase08.d15.malformed.plist
fixtures/launchd/org.rmxos.phase08.d16.runatload.plist
fixtures/launchd/org.rmxos.phase08.d17.fast-exit.plist
fixtures/launchd/org.rmxos.phase08.d18.sigkill.plist
fixtures/launchd/org.rmxos.phase08.d18.sigterm.plist
fixtures/launchd/org.rmxos.phase08.d19.keepalive.plist
fixtures/launchd/org.rmxos.phase08.d20.successful-exit.plist
fixtures/launchd/org.rmxos.phase08.d21.remove.plist
fixtures/launchd/org.rmxos.phase08.d22.keepalive-remove.plist
fixtures/launchd/org.rmxos.phase08.d22.running-remove.plist
fixtures/launchd/org.rmxos.phase08.d23.inert-reload.plist
fixtures/launchd/org.rmxos.phase08.d23.keepalive-reload.plist
```

## Legacy Source Test Manifest

Snapshot manifest SHA256: `e59e4a08bf2be837d38f5e5758a6f1d764dd2d278b43f09d74398fb42828d298`

This manifest hashes the legacy source test assets for parity and provenance. It is not an instruction to copy every file into the canonical oracle test tree.

This manifest hashes committed source tree `a30ef3f`, not dirty working-tree bytes.

Manifest refresh checks:

- manifest path count: `121`
- all manifest-referenced files are committed at source SHA `a30ef3f`
- manifest-referenced dirty paths: `0`
- manifest-referenced gitignored paths: `0`
- generated/transient artifacts excluded: `__pycache__/`, `*.pyc`, `*.core`

Canonical manifest digest recipe used for this refresh:

- per-file `sha256`: SHA-256 over exact raw committed file bytes
- path order: lexicographic UTF-8 byte order using `/` separators
- JSON canonicalization: compact UTF-8 JSON, no insignificant whitespace, no trailing newline
- object key order: lexicographic at every object level
- array order: semantic order; `files` sorted by `path`
- digest input: top-level manifest JSON with `manifest_sha256` omitted
- hash function: SHA-256
- hex casing: lowercase

Manifest drift policy:

- `keep_fixture`, `keep_elixir`, and `keep_donor_payload_reference` drift blocks M1 unless reclassified and approved.
- `pending_fix` may change only if committed or explicitly approved by manifest.
- `docs_only` and `transient` changes do not block M1.
- M1 must include an automated preflight command that recomputes this manifest and compares it before import/scaffold work starts.

Required M1 preflight shape:

```sh
mix oracle.manifest.check --source /Users/me/wip-mach/wip-gpt --expected-sha e59e4a08bf2be837d38f5e5758a6f1d764dd2d278b43f09d74398fb42828d298 --mode committed
```

The command name is a proposed Elixir-owned interface. If M1 chooses a different name, it must provide the same behavior: recompute the legacy source test manifest, compare the SHA, report drift by target action, and fail before import/scaffold work when drift violates the policy above.

| path | size | sha256 | lines |
| --- | ---: | --- | ---: |
| `mix.exs` | 228 | `b027a59e0b295271aa8163b458a5aee2d05251cf8ce28f8e9473978494d28efc` | 13 |
| `fixtures/launchd/com.apple.notifyd.plist` | 645 | `746fc9c5c44a1374d9e5d902075763d8b2b656adff947360da7a39d7bb35879f` | 28 |
| `fixtures/launchd/com.apple.syslogd.plist` | 991 | `12c9067af924feac060b43d56d280fbdb74b69d8b56c5a06f78aec5db3bb6474` | 47 |
| `fixtures/launchd/org.freebsd.devd.plist` | 373 | `044f25cd3b44f8402cd02b585f7421e63883c23c4e5e8121041b3c33e7941bd0` | 16 |
| `fixtures/launchd/org.rmxos.phase08.d14.noop.plist` | 362 | `27a0dd69ca86f3f3ea732de6ea1d55680955fb9ccf6063594b286761d44cb310` | 13 |
| `fixtures/launchd/org.rmxos.phase08.d15.json-rejected.json` | 131 | `1adc20b8aec1adf6029045e197f3f433622010811601f216ccc764fc59be65fd` | 6 |
| `fixtures/launchd/org.rmxos.phase08.d15.malformed.plist` | 137 | `074ca9b72113f88fd65a176af010c1c99bbb65f4f0834827b0a1d71ee6518b0a` | 6 |
| `fixtures/launchd/org.rmxos.phase08.d16.runatload.plist` | 408 | `ecbafba38881fa10faf9a859dfd5f6f9584092fdd1c9aa1e3aa3e928429ba5a0` | 15 |
| `fixtures/launchd/org.rmxos.phase08.d17.fast-exit.plist` | 398 | `9d7b4f831a5b3f46d7febba0cc4a39898f5b32901e2ffaee74e6a39c3bd922e9` | 15 |
| `fixtures/launchd/org.rmxos.phase08.d18.sigkill.plist` | 399 | `7b5d9641ebd76f55e0025a551c96712a82fa3b1c030470e9c5c3ce14398497c0` | 15 |
| `fixtures/launchd/org.rmxos.phase08.d18.sigterm.plist` | 399 | `e06782c063aa2c7e701c4aac36488b24d64b4fe2993be447c339cd00def8856e` | 15 |
| `fixtures/launchd/org.rmxos.phase08.d19.keepalive.plist` | 522 | `1960137b283c2e0320cf388d239170af3ad58be0c7560702a30b3ee2019af935` | 19 |
| `fixtures/launchd/org.rmxos.phase08.d20.successful-exit.plist` | 547 | `25a95d07b900d6669fd7b61e673e2f500f958f8a25b68c32e203607f130a4be8` | 22 |
| `fixtures/launchd/org.rmxos.phase08.d21.remove.plist` | 373 | `ced0452bcda4adcd3051c6a86660f421db34685458e2975ea5520b451c7bd608` | 13 |
| `fixtures/launchd/org.rmxos.phase08.d22.keepalive-remove.plist` | 503 | `3dedd6314a02de7c4e1b809a2d5dacd02ff66775a0a7ac6ce685a076b0eabe5e` | 19 |
| `fixtures/launchd/org.rmxos.phase08.d22.running-remove.plist` | 417 | `3f39714304e5c7695fa99a4a603d7abce382c862aac96aca1acfaade696f0f16` | 15 |
| `fixtures/launchd/org.rmxos.phase08.d23.inert-reload.plist` | 370 | `4e2700a18b73a04a5f7cf3364d7626668368ef524fece56813a6314880492ed5` | 13 |
| `fixtures/launchd/org.rmxos.phase08.d23.keepalive-reload.plist` | 494 | `62903a9fb962637c4f863e492f55b0546441af2b58e0b8be302a5b75830bb1c7` | 19 |
| `scripts/bhyve/build-m7b-mig-clock.sh` | 3664 | `dad6e815ef91bca67d501ef39643626847192b609810ccb3568cc1739bef77e1` | 111 |
| `scripts/bhyve/build-m8-bootstrap-service.sh` | 3767 | `e758251a6e608222f0ccb1787c5b6386c7cdade7a45360d76a35b8762febd368` | 111 |
| `scripts/bhyve/build-phase1-launchctl.sh` | 4876 | `24e6918af7886eee31af5037a918aa03dd22b9d7f5d26cd86b7bed059c4f73e5` | 179 |
| `scripts/bhyve/build-phase1-minibootstrap.sh` | 5614 | `6f2973246190e31dec7a98b54456759250150d5c57ad1a1c99b518b0b6fdf86c` | 183 |
| `scripts/bhyve/collect-crash.sh` | 3199 | `ae3fa1dc657bcf241e6e9e2a2674daab7b4b68841273201b677eb857182b3b62` | 110 |
| `scripts/bhyve/compare-m2-oracle.py` | 17396 | `02b63062306eed8b9ab0c37d77b49ea68aa1635929fee04dd5013bbf59c3eef8` | 484 |
| `scripts/bhyve/m5-kqueue-compat.c` | 1761 | `8fa5aa9a29baaf4c1534cad5398336640a815e9ab6f2c4ec5c7e7a6feeae1cf6` | 81 |
| `scripts/bhyve/m5-kqueue-compat.h` | 1225 | `c2cc3360f6c2113e9a42fe8eb4e93c1b513c4aaa37b11ec6dc41572efd8fbcfd` | 51 |
| `scripts/bhyve/m7b-mig-clock-test.c` | 6490 | `e6f821444f74ad1651c2ea2a0dc61bcacc0e0d059566ba64aa5a6f745d6bb995` | 233 |
| `scripts/bhyve/m8-bootstrap-service-proof.c` | 13835 | `cc74f6a3c8b09fc68800168818e760582cee819a5b2b1a4888840d7604859c41` | 450 |
| `scripts/bhyve/minibootstrap-runner.c` | 14393 | `fb3c410a55ef9056a54c388e3a2cefd0044237eb084ada8424c079877a186f88` | 533 |
| `scripts/bhyve/nxplatform-mach-probe.c` | 380797 | `cc3e77d3c168d0e85851d976ed9c74a8b51e87cdd89d4cfa49207bb2602ff88a` | 10414 |
| `scripts/bhyve/parse-characterize.py` | 8394 | `b337d882f78f0b3334deb37cfac4bec91cde8316e17fc21c24a68ad2053dcd97` | 236 |
| `scripts/bhyve/parse-serial.py` | 2732 | `0989230170cda70731c39fec7f3f6990bca382a52f8799e5bd6cc75ee7337773` | 92 |
| `scripts/bhyve/run-guest.sh` | 2807 | `251ab6ddc5b09e333629cd7be5450c480b39be8acb2d70dfb5b1bbc88d2d8630` | 98 |
| `scripts/bhyve/stage-guest.sh` | 16013 | `3bce1c9da6017482bf0e73712b371ccc713c0177fc9b671673204d4f4ce32d70` | 467 |
| `scripts/bhyve/stage-libmach.sh` | 11534 | `f8b885a3d003b6c0a20b0dae4251c3cfeb98b9258859c0a644ea49f30f10f063` | 309 |
| `scripts/bhyve/stage-m5-guest.sh` | 5617 | `45a4dc5d1bdd17b7542f1d39f76c477f76ac7219174e03af392b9bf672bb5f23` | 219 |
| `scripts/bhyve/stage-m7b-guest.sh` | 4017 | `fb215e440bd058f426747c83aede96d1eab62691fd2e3f5a5226eb3cdb761caf` | 167 |
| `scripts/bhyve/stage-m8-guest.sh` | 4056 | `ed94c71f8f21803bf614fcbfa2f86d12f6a12ee8ed80d60cf0260f548b9dad14` | 167 |
| `scripts/bhyve/stage-phase1-launchctl-guest.sh` | 9789 | `e69f163b83f7243e9915289ce9d3ace282277aa1ce7df6e53ead4f2d5243a606` | 312 |
| `scripts/bhyve/stage-phase1-launchd-harness-guest.sh` | 43673 | `46a43b026ffbb1210db9d36c44839d344c186ee318746d579501f47442665847` | 973 |
| `scripts/bhyve/stage-phase1-minibootstrap-guest.sh` | 5582 | `1b7ad08bcd0b5e116bd7985148dfc50c17db909e9cfc348fed32cc425c1aea66` | 209 |
| `scripts/dispatch/compile-libdispatch-build-lane.sh` | 41771 | `9392dfdf5491c2904e571beccd8b39960cb09848144029f7398ad8a6673263e7` | 1306 |
| `scripts/dispatch/compile-libdispatch-object-gate.sh` | 3519 | `f7b47f34f3e7196488f1685881bba6033733091cbb54909a9e00a52896629be2` | 131 |
| `scripts/dispatch/libdispatch-phase07-bootstrap-reply-smoke.c` | 10654 | `a5c504845d73f357aa4d26120c039370cd52eb5ef85a78a9385e01babb1555d9` | 414 |
| `scripts/dispatch/libdispatch-phase07-compat.h` | 2459 | `8ee412ff470e66bcc755dc582755341ea6ddfc430006ff83b99b238adedcf486` | 94 |
| `scripts/dispatch/libdispatch-phase07-dispatch-once-smoke.c` | 375 | `508cb388f1b87f04fc500ef7a8e3d1cff3421163c693095b87b14e49922770da` | 21 |
| `scripts/dispatch/libdispatch-phase07-kevent64.c` | 1916 | `2becee1d9a698a2399d6a684543cac1f44dbe9dac5479319626d3a1b7c732960` | 90 |
| `scripts/dispatch/libdispatch-phase07-mach-recv-smoke.c` | 8878 | `0aacbdc3e6c1c7d1d179de15798a0658d8f63df4b01a858b2847dc0167e0dc6d` | 358 |
| `scripts/dispatch/libdispatch-phase07-p5-workqueue-smoke.c` | 8898 | `b39209669b1572c4d971882dc5dd23b3bdbd8c6cd688a450811216de3531e8a2` | 323 |
| `scripts/dispatch/libdispatch-phase07-proc-exit-smoke.c` | 4585 | `a2cbf831c2c905b5ebf145d50d3c6a552465a5a153dd6e55fe62e25d52b1f394` | 216 |
| `scripts/dispatch/libdispatch-phase07-qos-twq-smoke.zig` | 18022 | `5dac78174072a3ec0b8268da3b7bbbb0bbb7251b351b04ecee88f48c738218c8` | 528 |
| `scripts/dispatch/libdispatch-phase07-queue-async-smoke.c` | 973 | `6fddc4914616a22b410985f64dbe187a9fe79a2733403df57b0f6a5a14109935` | 49 |
| `scripts/dispatch/libdispatch-phase07-thread-switch.c` | 381 | `5efb9703846e1c04568b81d6d31945f876c33c9b61b8224fe1c3db35779ef677` | 18 |
| `scripts/dispatch/libdispatch-phase07-timer-after-smoke.c` | 1168 | `41bcff6837b3a9f85e3ce9f326f7625c2ade955e1731b06127d566df0095ba7c` | 53 |
| `scripts/dispatch/libdispatch-phase07-timer-source-smoke.c` | 2731 | `1d3ad351529af2d3852807bfda8e584076c954675440cde2278267bf3c56939e` | 107 |
| `scripts/dispatch/libdispatch-phase07-voucher-stubs.c` | 3824 | `e001f234bb1421b5e2d2f8d6339af81f361d3583193604f82e24a474b8c0b241` | 191 |
| `scripts/dispatch/libdispatch-phase07-workqueue-compat.c` | 4008 | `efc461bff5df15a0d05a43360d0dbe938d5321a4de72e20613bd8c46a307cc46` | 190 |
| `scripts/dispatch/libthr-phase07-sched-pri-smoke.zig` | 9148 | `85f8efd89b03f9adc634f69fb1a344799076208d2603c532baf9871f8c7a5c3e` | 243 |
| `scripts/dispatch/verify-phase07-dispatch-bootstrap-reply-smoke.sh` | 12394 | `e4b0a2ab9f697124a0c5be1446ac6198fa590e475e1ecb6c64b4f78455fb9911` | 363 |
| `scripts/dispatch/verify-phase07-dispatch-mach-recv-smoke.sh` | 11399 | `542b88102583a197cdc222097ef384d8063b6a4a92a3e018b3f407bf213da7c9` | 343 |
| `scripts/dispatch/verify-phase07-dispatch-once-smoke.sh` | 11105 | `6e4d2b5a6465c9ea0c468e0dc67a155411f205a662bd3fb0a96f4637b09c0553` | 341 |
| `scripts/dispatch/verify-phase07-dispatch-p5-workqueue-smoke.sh` | 12859 | `e6767fe47fad74e59c0b6b55146fca5d62bc5daf6966a34683779a73f98a7fd0` | 376 |
| `scripts/dispatch/verify-phase07-dispatch-proc-smoke.sh` | 11195 | `86f84c80084e4ba5078a415d4260639553926f5535f6a147eb74f593173c832d` | 344 |
| `scripts/dispatch/verify-phase07-dispatch-qos-twq-smoke.exs` | 23891 | `a216b4ce5bcffd68452928fb943f2ee359e34b58b737e6d9b811be7569e1cc82` | 683 |
| `scripts/dispatch/verify-phase07-dispatch-queue-smoke.sh` | 11153 | `1801517410d848b38fe66bd7d07d34da5bdc187c081c39ba840e7e6c3a1ae615` | 341 |
| `scripts/dispatch/verify-phase07-dispatch-timer-after-smoke.sh` | 11795 | `f43351f13302506a4c7b998bb56be169522fecab9cb8190a7b79aea03f69b996` | 349 |
| `scripts/dispatch/verify-phase07-dispatch-timer-source-smoke.sh` | 11869 | `beed7fac47e85f69e1dbfd2ea53bf15c7ddad0613d92c03f2cd7eebd5a3a1227` | 349 |
| `scripts/dispatch/verify-phase07-libthr-sched-pri-smoke.exs` | 18774 | `889fc1b8e5a0ca0e4b4f4c19f62b8b486ef909916028ff0f6a95852993533920` | 537 |
| `scripts/inventory/classify-donor.sh` | 11011 | `2cef894314531ece57542bbe66bac03a8c5d185f15057cf28a948afaa1ac6ebc` | 278 |
| `scripts/inventory/nextbsd-history.sh` | 1402 | `49161421e3c399262088021dabe5ef18ea2756db4d77d886ebf17535590ade6f` | 75 |
| `scripts/launchd/build-bootstrap-donor-tests.sh` | 42798 | `d79d1ce2afc476061a2de7963ba6dd3bdaa8c33d2df3bd4dbd25f6ebc3d54e12` | 1479 |
| `scripts/launchd/build-phase08-d14-launchctl.sh` | 12467 | `e79045d3996588f344117c8287d7095f0c285c624bb99c5b5e5240d5c16d8f99` | 387 |
| `scripts/launchd/build-phase08-d15-launchctl-json-hardfail.sh` | 45266 | `b46b055378b85e4e07c6bbda29420100ea8c878d6c1f53943ccab74ce850a356` | 902 |
| `scripts/launchd/check-plist-fixtures.py` | 2243 | `da9e27e710b652fcdba2b32cb4ce27a172f715f8fc63c8deb2b12711cfdcc512` | 81 |
| `scripts/launchd/classify-launchd-symbols.sh` | 5459 | `7ecf03a041acc48367884c17916da2d3d69deb13562b1f44c97e40daa29e2b6a` | 165 |
| `scripts/launchd/compile-launchctl-object.sh` | 2612 | `c4972c056c670051f870df6dd4f0b83722ca9a335929dd9d701d74f0e3453f6f` | 87 |
| `scripts/launchd/compile-launchd-objects.sh` | 6183 | `cd5352b6ccf715952b9f70c855041667fc236fa7d6dc4c3ebf3eabee3a4ab132` | 253 |
| `scripts/launchd/generate-phase08-d23-core.exs` | 32104 | `894f3f1aa2d8cca991b19d737a94ff8701872936b0a6a272d45669e060d8f93c` | 943 |
| `scripts/launchd/link-launchd-harness.sh` | 487568 | `38c4db8c792b894863dee73c26bd1a173e4ba2375095a9ef5be855037ee8b55a` | 13060 |
| `scripts/launchd/phase08_marker_manifest.exs` | 25606 | `ad24b34d79637bab36b497089a352499c31138a41580d6c8f26f546e575e9aba` | 809 |
| `scripts/launchd/phase08_source_transform.exs` | 6763 | `823b57c2af917aacbac090889e103b56baa0469290c7bdef367ae996dc5ff290` | 217 |
| `scripts/launchd/test-plist-parser.c` | 1975 | `eaeab7874d987c720168218333d94b6dd55e1b45e9d4ffc8d25fc2e490d77bd8` | 92 |
| `scripts/launchd/verify-phase08-d22-instrumentation-parity.exs` | 7631 | `83c95135e5e5d6872b150ca0cfa4e8d346d79eb177f6db7a0d7d5cdaafd56140` | 230 |
| `scripts/launchd/verify-phase08-launchd-dispatch-bootstrap.exs` | 12581 | `9ce7e31e72ed0ae7bea4c8eeba9f7d26c7d58530d98a4235cb5ceb8eb4d69e74` | 306 |
| `scripts/launchd/verify-phase08-launchd-dispatch-caller-creds.exs` | 19447 | `a6add09bc309ce1897b34849b7e32092c6a192b5e7127561d2035b39629aef81` | 423 |
| `scripts/launchd/verify-phase08-launchd-dispatch-donor-state.exs` | 18463 | `b25776b6a3dc24f835baa23ff77939dc0912248dee08ec3b8b201312784509ae` | 405 |
| `scripts/launchd/verify-phase08-launchd-dispatch-exit-state.exs` | 23316 | `97d0d9d56342734871f539a8726bbd1955b08fb35080c25910360988ae281341` | 479 |
| `scripts/launchd/verify-phase08-launchd-dispatch-json-hardfail.exs` | 107493 | `236f4377fc68d09f75cb2fc0dff03772dedf2dffbc48731a4df6a39431f8e6d2` | 1528 |
| `scripts/launchd/verify-phase08-launchd-dispatch-launchctl-fast-exit.exs` | 137556 | `2070e54aa0bf38647e773c0f93f22af70802b77b1f2724cee5f169d5a41180f7` | 1895 |
| `scripts/launchd/verify-phase08-launchd-dispatch-launchctl-keepalive-restart.exs` | 179407 | `20ef462e81b498d4bc7a3472ec7bc9a83c4acbdb9efa4d73dc5f6cf64877fd2d` | 2368 |
| `scripts/launchd/verify-phase08-launchd-dispatch-launchctl-plist.exs` | 97867 | `2b5527ae750f7df7decc0f90ebe33998db452a2b7eb08a3482ba02a55731727f` | 1406 |
| `scripts/launchd/verify-phase08-launchd-dispatch-launchctl-reload.exs` | 15623 | `c221777ddebaf4538f7a818574d7f739e6bb79be61482f1d98fc2b4f8c9a1b87` | 335 |
| `scripts/launchd/verify-phase08-launchd-dispatch-launchctl-remove.exs` | 216971 | `4f7d73735fe2aecbaa3f52394a7b7a77fd9a28cef3d52d75907b89250a1109b4` | 2792 |
| `scripts/launchd/verify-phase08-launchd-dispatch-launchctl-request.exs` | 44549 | `0666053ca1de44e7814f7aecbb2c86c7f9cdec156bfbd7da4fb7a9012a96dd68` | 741 |
| `scripts/launchd/verify-phase08-launchd-dispatch-launchctl-runatload.exs` | 121126 | `7d6c97fd2e20e965ba7f6250de7fcfd52be917fea61e7a4347601a52ab9d1302` | 1702 |
| `scripts/launchd/verify-phase08-launchd-dispatch-launchctl-running-remove.exs` | 243280 | `3e254a7042b1f3029d7dcd4502b8b835229269669e7c4ae4c17aac4a96aafb44` | 3086 |
| `scripts/launchd/verify-phase08-launchd-dispatch-launchctl-signal-exit.exs` | 159330 | `74bffb5b0f6a912e721593b371ad70065a09e15a10095ead6691c10aad8ecf45` | 2136 |
| `scripts/launchd/verify-phase08-launchd-dispatch-launchctl-successful-exit.exs` | 201661 | `734166909ea3d3529bfebbd89f5acd59d115777ccd520e89ef328bee3090536f` | 2619 |
| `scripts/launchd/verify-phase08-launchd-dispatch-lifecycle.exs` | 14354 | `dfa4bee27f2265347eb47964d6d91fc7410eefa39a8e5e47af016e74c8412073` | 337 |
| `scripts/launchd/verify-phase08-launchd-dispatch-main.exs` | 28854 | `80781ba67d30c61bd32cb49142090f1cb695a71f13ad734ae6cddd60a0c0e125` | 552 |
| `scripts/launchd/verify-phase08-launchd-dispatch-proc-event.exs` | 32531 | `d7c70a1a6c75840d1809805d802daaa039ce95b0548f69f6aeca76622618bc0a` | 596 |
| `scripts/launchd/verify-phase08-launchd-dispatch-restart.exs` | 27549 | `99dce3db19842614a2ab307b43d4213e35e1477828f300140d3f640b781c49e5` | 535 |
| `scripts/launchd/verify-phase08-launchd-dispatch-runatload.exs` | 68806 | `682aa84ee1938a7461321631ee5673887fa320c344a7331c21e963479b738058` | 1033 |
| `scripts/launchd/verify-phase08-launchd-dispatch-runtime.exs` | 30369 | `e17f8cb534bd6364287fd0e85a53e393a268ff705ac294bb23cb5448372f0a35` | 574 |
| `scripts/launchd/verify-phase08-launchd-dispatch-spawn.exs` | 86317 | `3e6b65f724a32da875c4e31cb646a23e82d69e583dd3c0c7ee1727a1c25906e1` | 1263 |
| `scripts/launchd/verify-phase08-launchd-dispatch-state.exs` | 16665 | `9e9723363c5cca7a1d58739b5b32eb246209114a6d9e85e114c7723469b05e02` | 377 |
| `scripts/launchd/verify-phase08-launchd-dispatch-submitjob.exs` | 54732 | `a24f0e719ec0c8703485d1c203022241ddf08f04ae604a45578a28d5e4c7243e` | 864 |
| `scripts/launchd/verify-phase08-launchd-dispatch-supervision.exs` | 36277 | `d5e152a7643778ec4ff275a8d9c12aed4228a294569756fd556f79eac4d7acb1` | 640 |
| `scripts/launchd/verify-phase1-bootstrap.sh` | 6084 | `65f77ae16a12369e4b7ff7841c5ba4e7fc28652741ca9450dc69fc2b417af454` | 201 |
| `scripts/launchd/verify-phase1-liblaunch-ownership.sh` | 6066 | `44dfa2fdd497d5cc3e5d010a046dd7e2711274504e15df595f8a24261747dab0` | 195 |
| `scripts/launchd/verify-phase1-plist.sh` | 10303 | `35c2aaa4f00a95358f68ce15ae8450b445931af1931d6b5ea90ae1d0f5fb79de` | 341 |
| `scripts/libthr/twq-libthr-init-probe.c` | 6360 | `5cb84a639982762f5b4363a4b3f7604a4b4969766b50ff1cba8f5bf314c34207` | 237 |
| `scripts/libthr/twq-libthr-worker-probe.c` | 9937 | `3f353a9f62da13268492103376a2ce6739af2691d5ab27ad745f7e8a9ecfdc0e` | 346 |
| `scripts/libthr/verify-phase07-twq-libthr-init-probe.sh` | 11805 | `c50536c2f6dedb46d1b2a84c6ec911508601675bcd40f3a82f2e2237308042e6` | 368 |
| `scripts/libthr/verify-phase07-twq-libthr-worker-probe.sh` | 12216 | `a8da77869b66ac183cc43f63ba29815d4736877fdfe8a6c54a0543ec030bcef6` | 371 |
| `scripts/test` | 678 | `286990b24c7a0065b1821ffba75de389df93ba3e2b96d391d6698903156397ef` | 31 |
| `scripts/verify-phase1-current-tree.sh` | 6278 | `6febe66ca73f81d4214e8534ade6961d4e843d8667b63d72950b27917f586794` | 194 |
| `test/bhyve_scripts_test.exs` | 9833 | `9f657d5ca0be716632bb741d274676b843f22093334a18306367c35b6effd492` | 291 |
| `test/donor_mach_tests_test.exs` | 2947 | `099cc1e293fa51266582ae5916f3344a5813d51762440264101bc80972a880d5` | 83 |
| `test/phase08_source_transform_test.exs` | 6478 | `cc73e451a1b5d91f0356c8e38f5948d344f96b1378ac04212d36a0f2d450d5e0` | 192 |
| `test/test_helper.exs` | 15 | `b086ec47f0c6c7aaeb4cffca5ae5243dd05e0dc96ab761ced93325d5315f4b12` | 1 |

## Language And Role Classification

Canonical framework rule: only Elixir, Zig, fixtures, and explicitly approved donor/reference payloads become canonical oracle assets. Existing Zig probes are marked `relocate_zig` because they are already in the canonical language but still need layout/adaptation.

Target actions:

- `keep_elixir`: keep as Elixir-owned canonical logic, possibly after namespace/path cleanup.
- `keep_fixture`: copy safe data fixtures.
- `port_to_elixir`: legacy orchestration, parsing, comparison, or instrumentation logic to rewrite in Elixir.
- `port_to_zig`: project-owned C/Zig probe logic to place in the Zig probe layer; C is ported where practical.
- `keep_c_support`: keep C support/glue only where a C ABI support payload is still justified.
- `evaluate_c_support`: decide whether C support/glue should stay as support or be replaced during Zig migration.
- `retain_c_reference_until_zig_parity`: keep original C probe/reference until the Zig equivalent passes parity.
- `relocate_zig`: move/adapt existing Zig into the canonical Zig probe layout.
- `keep_donor_payload_reference`: preserve only as external/reference payload if parent confirms donor behavior requires it.
- `exclude_generated`: generated/runtime artifact; never canonical.
- `delete_after_parity`: legacy reference to remove after equivalent canonical coverage exists.

Additional roles:

- `compat_shim`: compatibility glue, not a semantic probe.
- `support_header`: support/header glue, not a semantic probe.
- `probe`: semantic or ABI probe payload.
- `donor_payload`: external donor behavior payload.
- `legacy_reference`: retained source for parity/history only.

| path | language | role | target action | complexity | contains_embedded_awk | canonical |
| --- | --- | --- | --- | --- | --- | --- |
| `mix.exs` | `elixir` | `orchestrator` | `keep_elixir` | `low` | `no` | `yes` |
| `fixtures/launchd/com.apple.notifyd.plist` | `fixture` | `fixture` | `keep_fixture` | `low` | `no` | `yes` |
| `fixtures/launchd/com.apple.syslogd.plist` | `fixture` | `fixture` | `keep_fixture` | `low` | `no` | `yes` |
| `fixtures/launchd/org.freebsd.devd.plist` | `fixture` | `fixture` | `keep_fixture` | `low` | `no` | `yes` |
| `fixtures/launchd/org.rmxos.phase08.d14.noop.plist` | `fixture` | `fixture` | `keep_fixture` | `low` | `no` | `yes` |
| `fixtures/launchd/org.rmxos.phase08.d15.json-rejected.json` | `fixture` | `fixture` | `keep_fixture` | `low` | `no` | `yes` |
| `fixtures/launchd/org.rmxos.phase08.d15.malformed.plist` | `fixture` | `fixture` | `keep_fixture` | `low` | `no` | `yes` |
| `fixtures/launchd/org.rmxos.phase08.d16.runatload.plist` | `fixture` | `fixture` | `keep_fixture` | `low` | `no` | `yes` |
| `fixtures/launchd/org.rmxos.phase08.d17.fast-exit.plist` | `fixture` | `fixture` | `keep_fixture` | `low` | `no` | `yes` |
| `fixtures/launchd/org.rmxos.phase08.d18.sigkill.plist` | `fixture` | `fixture` | `keep_fixture` | `low` | `no` | `yes` |
| `fixtures/launchd/org.rmxos.phase08.d18.sigterm.plist` | `fixture` | `fixture` | `keep_fixture` | `low` | `no` | `yes` |
| `fixtures/launchd/org.rmxos.phase08.d19.keepalive.plist` | `fixture` | `fixture` | `keep_fixture` | `low` | `no` | `yes` |
| `fixtures/launchd/org.rmxos.phase08.d20.successful-exit.plist` | `fixture` | `fixture` | `keep_fixture` | `low` | `no` | `yes` |
| `fixtures/launchd/org.rmxos.phase08.d21.remove.plist` | `fixture` | `fixture` | `keep_fixture` | `low` | `no` | `yes` |
| `fixtures/launchd/org.rmxos.phase08.d22.keepalive-remove.plist` | `fixture` | `fixture` | `keep_fixture` | `low` | `no` | `yes` |
| `fixtures/launchd/org.rmxos.phase08.d22.running-remove.plist` | `fixture` | `fixture` | `keep_fixture` | `low` | `no` | `yes` |
| `fixtures/launchd/org.rmxos.phase08.d23.inert-reload.plist` | `fixture` | `fixture` | `keep_fixture` | `low` | `no` | `yes` |
| `fixtures/launchd/org.rmxos.phase08.d23.keepalive-reload.plist` | `fixture` | `fixture` | `keep_fixture` | `low` | `no` | `yes` |
| `scripts/bhyve/__pycache__/compare-m2-oracle.cpython-311.pyc` | `other` | `generated_artifact` | `exclude_generated` | `low` | `no` | `no` |
| `scripts/bhyve/build-m7b-mig-clock.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `no` | `no` |
| `scripts/bhyve/build-m8-bootstrap-service.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `no` | `no` |
| `scripts/bhyve/build-phase1-launchctl.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `no` | `no` |
| `scripts/bhyve/build-phase1-minibootstrap.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `no` | `no` |
| `scripts/bhyve/collect-crash.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `yes` | `no` |
| `scripts/bhyve/compare-m2-oracle.py` | `python` | `legacy oracle comparison tool` | `port_to_elixir` | `medium` | `no` | `no` |
| `scripts/bhyve/m5-kqueue-compat.c` | `c` | `compat_shim` | `evaluate_c_support` | `medium` | `no` | `no` |
| `scripts/bhyve/m5-kqueue-compat.h` | `c` | `support_header` | `keep_c_support` | `low` | `no` | `no` |
| `scripts/bhyve/m7b-mig-clock-test.c` | `c` | `probe` | `retain_c_reference_until_zig_parity` | `medium` | `no` | `no` |
| `scripts/bhyve/m8-bootstrap-service-proof.c` | `c` | `probe` | `retain_c_reference_until_zig_parity` | `medium` | `no` | `no` |
| `scripts/bhyve/minibootstrap-runner.c` | `c` | `probe` | `retain_c_reference_until_zig_parity` | `medium` | `no` | `no` |
| `scripts/bhyve/nxplatform-mach-probe.c` | `c` | `probe` | `retain_c_reference_until_zig_parity` | `very_high` | `no` | `no` |
| `scripts/bhyve/parse-characterize.py` | `python` | `verifier` | `port_to_elixir` | `medium` | `no` | `no` |
| `scripts/bhyve/parse-serial.py` | `python` | `verifier` | `port_to_elixir` | `medium` | `no` | `no` |
| `scripts/bhyve/run-guest.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `no` | `no` |
| `scripts/bhyve/stage-guest.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `yes` | `no` |
| `scripts/bhyve/stage-libmach.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `no` | `no` |
| `scripts/bhyve/stage-m5-guest.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `yes` | `no` |
| `scripts/bhyve/stage-m7b-guest.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `yes` | `no` |
| `scripts/bhyve/stage-m8-guest.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `yes` | `no` |
| `scripts/bhyve/stage-phase1-launchctl-guest.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `yes` | `no` |
| `scripts/bhyve/stage-phase1-launchd-harness-guest.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `yes` | `no` |
| `scripts/bhyve/stage-phase1-minibootstrap-guest.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `yes` | `no` |
| `scripts/dispatch/compile-libdispatch-build-lane.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `yes` | `no` |
| `scripts/dispatch/compile-libdispatch-object-gate.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `no` | `no` |
| `scripts/dispatch/libdispatch-phase07-bootstrap-reply-smoke.c` | `c` | `probe` | `retain_c_reference_until_zig_parity` | `medium` | `no` | `no` |
| `scripts/dispatch/libdispatch-phase07-compat.h` | `c` | `support_header` | `keep_c_support` | `low` | `no` | `no` |
| `scripts/dispatch/libdispatch-phase07-dispatch-once-smoke.c` | `c` | `probe` | `retain_c_reference_until_zig_parity` | `medium` | `no` | `no` |
| `scripts/dispatch/libdispatch-phase07-kevent64.c` | `c` | `compat_shim` | `evaluate_c_support` | `medium` | `no` | `no` |
| `scripts/dispatch/libdispatch-phase07-mach-recv-smoke.c` | `c` | `probe` | `retain_c_reference_until_zig_parity` | `medium` | `no` | `no` |
| `scripts/dispatch/libdispatch-phase07-p5-workqueue-smoke.c` | `c` | `probe` | `retain_c_reference_until_zig_parity` | `medium` | `no` | `no` |
| `scripts/dispatch/libdispatch-phase07-proc-exit-smoke.c` | `c` | `probe` | `retain_c_reference_until_zig_parity` | `medium` | `no` | `no` |
| `scripts/dispatch/libdispatch-phase07-qos-twq-smoke.zig` | `zig` | `probe` | `relocate_zig` | `medium` | `no` | `yes` |
| `scripts/dispatch/libdispatch-phase07-queue-async-smoke.c` | `c` | `probe` | `retain_c_reference_until_zig_parity` | `medium` | `no` | `no` |
| `scripts/dispatch/libdispatch-phase07-thread-switch.c` | `c` | `probe` | `retain_c_reference_until_zig_parity` | `medium` | `no` | `no` |
| `scripts/dispatch/libdispatch-phase07-timer-after-smoke.c` | `c` | `probe` | `retain_c_reference_until_zig_parity` | `medium` | `no` | `no` |
| `scripts/dispatch/libdispatch-phase07-timer-source-smoke.c` | `c` | `probe` | `retain_c_reference_until_zig_parity` | `medium` | `no` | `no` |
| `scripts/dispatch/libdispatch-phase07-voucher-stubs.c` | `c` | `compat_shim` | `evaluate_c_support` | `medium` | `no` | `no` |
| `scripts/dispatch/libdispatch-phase07-workqueue-compat.c` | `c` | `compat_shim` | `evaluate_c_support` | `medium` | `no` | `no` |
| `scripts/dispatch/libthr-phase07-sched-pri-smoke.zig` | `zig` | `probe` | `relocate_zig` | `medium` | `no` | `yes` |
| `scripts/dispatch/verify-phase07-dispatch-bootstrap-reply-smoke.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `yes` | `no` |
| `scripts/dispatch/verify-phase07-dispatch-mach-recv-smoke.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `yes` | `no` |
| `scripts/dispatch/verify-phase07-dispatch-once-smoke.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `yes` | `no` |
| `scripts/dispatch/verify-phase07-dispatch-p5-workqueue-smoke.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `yes` | `no` |
| `scripts/dispatch/verify-phase07-dispatch-proc-smoke.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `yes` | `no` |
| `scripts/dispatch/verify-phase07-dispatch-qos-twq-smoke.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/dispatch/verify-phase07-dispatch-queue-smoke.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `yes` | `no` |
| `scripts/dispatch/verify-phase07-dispatch-timer-after-smoke.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `yes` | `no` |
| `scripts/dispatch/verify-phase07-dispatch-timer-source-smoke.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `yes` | `no` |
| `scripts/dispatch/verify-phase07-libthr-sched-pri-smoke.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/inventory/classify-donor.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `yes` | `no` |
| `scripts/inventory/nextbsd-history.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `no` | `no` |
| `scripts/launchd/build-bootstrap-donor-tests.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `no` | `no` |
| `scripts/launchd/build-phase08-d14-launchctl.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `yes` | `no` |
| `scripts/launchd/build-phase08-d15-launchctl-json-hardfail.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `yes` | `no` |
| `scripts/launchd/check-plist-fixtures.py` | `python` | `verifier` | `port_to_elixir` | `medium` | `no` | `no` |
| `scripts/launchd/classify-launchd-symbols.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `yes` | `no` |
| `scripts/launchd/compile-launchctl-object.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `no` | `no` |
| `scripts/launchd/compile-launchd-objects.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `yes` | `no` |
| `scripts/launchd/generate-phase08-d23-core.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/link-launchd-harness.sh` | `shell` | `orchestrator` | `port_to_elixir` | `very_high` | `yes` | `no` |
| `scripts/launchd/phase08_marker_manifest.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/phase08_source_transform.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/test-plist-parser.c` | `c` | `probe` | `retain_c_reference_until_zig_parity` | `medium` | `no` | `no` |
| `scripts/launchd/verify-phase08-d22-instrumentation-parity.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/verify-phase08-launchd-dispatch-bootstrap.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/verify-phase08-launchd-dispatch-caller-creds.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/verify-phase08-launchd-dispatch-donor-state.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/verify-phase08-launchd-dispatch-exit-state.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/verify-phase08-launchd-dispatch-json-hardfail.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/verify-phase08-launchd-dispatch-launchctl-fast-exit.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/verify-phase08-launchd-dispatch-launchctl-keepalive-restart.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/verify-phase08-launchd-dispatch-launchctl-plist.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/verify-phase08-launchd-dispatch-launchctl-reload.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/verify-phase08-launchd-dispatch-launchctl-remove.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/verify-phase08-launchd-dispatch-launchctl-request.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/verify-phase08-launchd-dispatch-launchctl-runatload.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/verify-phase08-launchd-dispatch-launchctl-running-remove.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/verify-phase08-launchd-dispatch-launchctl-signal-exit.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/verify-phase08-launchd-dispatch-launchctl-successful-exit.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/verify-phase08-launchd-dispatch-lifecycle.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/verify-phase08-launchd-dispatch-main.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/verify-phase08-launchd-dispatch-proc-event.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/verify-phase08-launchd-dispatch-restart.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/verify-phase08-launchd-dispatch-runatload.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/verify-phase08-launchd-dispatch-runtime.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/verify-phase08-launchd-dispatch-spawn.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/verify-phase08-launchd-dispatch-state.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/verify-phase08-launchd-dispatch-submitjob.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/verify-phase08-launchd-dispatch-supervision.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `scripts/launchd/verify-phase1-bootstrap.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `no` | `no` |
| `scripts/launchd/verify-phase1-liblaunch-ownership.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `no` | `no` |
| `scripts/launchd/verify-phase1-plist.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `no` | `no` |
| `scripts/libthr/twq-libthr-init-probe.c` | `c` | `probe` | `retain_c_reference_until_zig_parity` | `medium` | `no` | `no` |
| `scripts/libthr/twq-libthr-worker-probe.c` | `c` | `probe` | `retain_c_reference_until_zig_parity` | `medium` | `no` | `no` |
| `scripts/libthr/verify-phase07-twq-libthr-init-probe.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `yes` | `no` |
| `scripts/libthr/verify-phase07-twq-libthr-worker-probe.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `yes` | `no` |
| `scripts/test` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `no` | `no` |
| `scripts/verify-phase1-current-tree.sh` | `shell` | `orchestrator` | `port_to_elixir` | `medium` | `no` | `no` |
| `test/bhyve_scripts_test.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `test/donor_mach_tests_test.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `test/phase08_source_transform_test.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |
| `test/test_helper.exs` | `elixir` | `verifier` | `keep_elixir` | `medium` | `no` | `yes` |

## Dependency Edges

A `keep_elixir` file is not fully canonical if it still depends on `port_to_elixir` shell/Python or other non-canonical scripts. These edges must be removed or ported before the verifier can be treated as fully canonical.

| Elixir file | non-canonical dependency | dependency action | canonical status |
| --- | --- | --- | --- |
| `test/bhyve_scripts_test.exs` | `scripts/bhyve/parse-serial.py` | `port_to_elixir` | blocked on Python parser port |
| `test/bhyve_scripts_test.exs` | `scripts/bhyve/parse-characterize.py` | `port_to_elixir` | blocked on Python parser port |
| `test/bhyve_scripts_test.exs` | `scripts/bhyve/stage-guest.sh` | `port_to_elixir` | blocked on shell runner port |
| `test/bhyve_scripts_test.exs` | `scripts/bhyve/run-guest.sh` | `port_to_elixir` | blocked on shell runner port |
| `test/bhyve_scripts_test.exs` | `scripts/bhyve/collect-crash.sh` | `port_to_elixir` | blocked on shell runner port |
| `test/bhyve_scripts_test.exs` | `scripts/inventory/classify-donor.sh` | `port_to_elixir` | blocked on shell inventory port |
| `test/bhyve_scripts_test.exs` | `scripts/inventory/nextbsd-history.sh` | `port_to_elixir` | blocked on shell inventory port |
| `test/phase08_source_transform_test.exs` | `scripts/launchd/phase08_source_transform.exs` | `keep_elixir` | canonical candidate after namespace/path cleanup |
| `test/phase08_source_transform_test.exs` | `scripts/launchd/phase08_marker_manifest.exs` | `keep_elixir` | canonical candidate after namespace/path cleanup |
| `scripts/launchd/verify-phase08-d22-instrumentation-parity.exs` | `scripts/launchd/link-launchd-harness.sh` | `port_to_elixir` | blocked on shell harness port |
| `scripts/launchd/verify-phase08-launchd-dispatch-*.exs` | `scripts/bhyve/build-phase1-minibootstrap.sh` | `port_to_elixir` | blocked on shell build wrapper port |
| `scripts/launchd/verify-phase08-launchd-dispatch-*.exs` | `scripts/launchd/build-bootstrap-donor-tests.sh` | `port_to_elixir` | blocked on shell donor-build wrapper port |
| `scripts/launchd/verify-phase08-launchd-dispatch-*.exs` | `scripts/dispatch/compile-libdispatch-build-lane.sh` | `port_to_elixir` | blocked on shell dispatch-build wrapper port |
| `scripts/launchd/verify-phase08-launchd-dispatch-*.exs` | `scripts/launchd/link-launchd-harness.sh` | `port_to_elixir` | blocked on shell harness port |
| `scripts/launchd/verify-phase08-launchd-dispatch-*.exs` | `scripts/bhyve/stage-phase1-launchd-harness-guest.sh` | `port_to_elixir` | blocked on shell staging port |
| `scripts/launchd/verify-phase08-launchd-dispatch-*.exs` | `scripts/bhyve/run-guest.sh` | `port_to_elixir` | blocked on shell runner port |
| `scripts/dispatch/verify-phase07-dispatch-qos-twq-smoke.exs` | legacy dispatch build/run shell conventions | `port_to_elixir` | needs dependency audit before fully canonical |
| `scripts/dispatch/verify-phase07-libthr-sched-pri-smoke.exs` | legacy dispatch/libthr build/run shell conventions | `port_to_elixir` | needs dependency audit before fully canonical |
| `test/donor_mach_tests_test.exs` | external NextBSD donor tree under workspace | `keep_donor_payload_reference` | canonical only as donor-reference verifier |

## Existing Oracle Asset Inventory

| asset | classification | M0-M7 decision |
| --- | --- | --- |
| root planning docs | historical planning/review docs | preserve at root during M1; no `docs/legacy/` move during M0-M7 |
| `macos-validation/` | macOS oracle probes/results/summaries | preserve in place |
| `mx-a64z/` | historical runner artifact dir for pre-terminology arm64 macOS evidence | preserve as-is; new schemas use canonical `mx-a64` |
| `mx-x64z/` | historical runner artifact dir for pre-terminology Intel macOS evidence | preserve as-is; new schemas use canonical `mx-x64` |
| `findings/` | accepted oracle findings and contracts | preserve in place |

Root planning/doc files currently present:

| path | classification | decision |
| --- | --- | --- |
| `.gitignore` | root planning/doc artifact | preserve at root during M1 |
| `README.md` | root planning/doc artifact | preserve at root during M1 |
| `Roadmap.md` | root planning/doc artifact | preserve at root during M1 |
| `comprehensive-nx-v64z-macos-oracle-plan.md` | root planning/doc artifact | preserve at root during M1 |
| `comprehensive-plan-review-request.md` | root planning/doc artifact | preserve at root during M1 |
| `elixir-test-migration-plan.md` | root planning/doc artifact | preserve at root during M1 |
| `final-preimplementation-plan.md` | root planning/doc artifact | preserve at root during M1 |
| `final-round-review-opus.md` | root planning/doc artifact | preserve at root during M1 |
| `final-round-review-request.md` | root planning/doc artifact | preserve at root during M1 |
| `gpt-stage12-integration-review.md` | root planning/doc artifact | preserve at root during M1 |
| `implementation-readiness-summary.md` | root planning/doc artifact | preserve at root during M1 |
| `macos-runner-agent-handoff.md` | root planning/doc artifact | preserve at root during M1 |
| `nextbsd-test-inventory-and-oracle-transfer-plan.md` | root planning/doc artifact | preserve at root during M1 |
| `opus-oracle-batch-request.md` | root planning/doc artifact | preserve at root during M1 |
| `opus-stage12-review-and-handoff.md` | root planning/doc artifact | preserve at root during M1 |
| `parent-acceptance-ob2-closed.md` | root planning/doc artifact | preserve at root during M1 |
| `parent-agent-questions.md` | root planning/doc artifact | preserve at root during M1 |
| `parent-approval-ob1.4.md` | root planning/doc artifact | preserve at root during M1 |
| `parent-approval-ob1.5-ob2.md` | root planning/doc artifact | preserve at root during M1 |
| `parent-approval-ob2.1.md` | root planning/doc artifact | preserve at root during M1 |
| `parent-approval-ob2.2.md` | root planning/doc artifact | preserve at root during M1 |
| `parent-approval-ob2.3.md` | root planning/doc artifact | preserve at root during M1 |
| `parent-approval-ob2.4.md` | root planning/doc artifact | preserve at root during M1 |
| `parent-batch1-directive.md` | root planning/doc artifact | preserve at root during M1 |
| `parent-gpt-stage12-integration-review.md` | root planning/doc artifact | preserve at root during M1 |
| `parent-progress-and-first-batch-request.md` | root planning/doc artifact | preserve at root during M1 |
| `parent-request-start-ob2.1.md` | root planning/doc artifact | preserve at root during M1 |
| `parent-response-to-opus-oracle-batches.md` | root planning/doc artifact | preserve at root during M1 |
| `parent-start-ob1.5-only.md` | root planning/doc artifact | preserve at root during M1 |
| `post-final-parent-gpt-resolution.md` | root planning/doc artifact | preserve at root during M1 |
| `rx-macos-oracle-plan-and-parent-questions.md` | root planning/doc artifact | preserve at root during M1 |
| `second-round-review-opus.md` | root planning/doc artifact | preserve at root during M1 |
| `second-round-review-request.md` | root planning/doc artifact | preserve at root during M1 |
| `test-migration-map.md` | root planning/doc artifact | preserve at root during M1 |

## Expected Post-M1 Layout

M1 no longer copies `scripts/` wholesale. M1 creates or scaffolds the oracle-owned Elixir/Zig test framework and imports only safe canonical assets according to the language classification above. M2 creates authority directories.

```text
/Users/me/wip-mach/wip-gpt-oracle/
  (existing) macos-validation/
  (existing) mx-a64z/              historical runner artifacts
  (existing) mx-x64z/              historical runner artifacts
  (existing) findings/
  (existing) docs/                 contains this M0 doc
  (new/create) mix.exs             oracle-owned Elixir project config if appropriate
  (new/import) test/               Elixir tests/helpers that remain valid
  (new/import) fixtures/           safe fixture data only
  (new/scaffold) zig/              canonical Zig probe layer
  (legacy reference only) scripts/ not copied wholesale; selected logic is ported
  (planned M2) catalog/
  (planned M2) mismatches/
  (planned M2) certification/
```

Old source tests remain frozen in `wip-gpt` as parity reference until each accepted test has an Elixir/Zig equivalent or approved donor-payload exception. This is a temporary reference state, not two maintained test systems.

M1 must define the canonical Zig probe layout before any C/Zig probe migration. Suggested starting point:

```text
zig/
  build.zig
  probes/
    mach/
    dispatch/
    launchd/
    libthr/
```

This is a proposed layout only. M0 does not create it.

## Path Audit

| item | classification | local resolution / formula | M0 decision |
| --- | --- | --- | --- |
| `repo_root` | repo-root-relative | source scripts compute from script location; after M1 this becomes `/Users/me/wip-mach/wip-gpt-oracle` | acceptable only for oracle-owned Elixir/Zig assets, not FreeBSD source defaults |
| `workspace_root` | workspace-root-relative | `/Users/me/wip-mach`; source and oracle are siblings so default `repo_root/..` currently resolves equivalently | preserve with `NXPLATFORM_WORKSPACE_ROOT=/Users/me/wip-mach` |
| `NXPLATFORM_WORKSPACE_ROOT` | env-pinned | `/Users/me/wip-mach` | required for artifact/build/vm paths |
| `NXPLATFORM_FREEBSD_SRC` | env-pinned absolute | `/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15` | required; must not default to oracle repo root |
| `NXPLATFORM_KERNEL_OBJDIRPREFIX` | env-pinned / lane-dependent | selected from explicit lane configuration and projected into the legacy runtime variable | M1 env/path handling must disambiguate per lane before guest/objdir gates |
| fixture paths | repo-root-relative | `repo_root/fixtures/...` after M1 points to imported oracle fixtures | acceptable after selected fixture import |
| artifact paths | workspace-root-relative/env-pinned | generally `${NXPLATFORM_ARTIFACTS_DIR:-${NXPLATFORM_WORKSPACE_ROOT}/artifacts/nxplatform}` | preserve under workspace root, not oracle root |
| serial logs | workspace-root-relative/env-pinned | generally under `/Users/me/wip-mach/artifacts/nxplatform/*.serial.log` or explicit `NXPLATFORM_SERIAL_LOG` | M0 flags for M4 validation |
| guest images | workspace-root-relative/env-pinned | generally `${NXPLATFORM_VM_IMAGE:-${NXPLATFORM_WORKSPACE_ROOT}/vm/runs/<vm>.img}` | preserve under workspace root |
| build outputs | workspace-root-relative/env-pinned | generally `/Users/me/wip-mach/build/...` | preserve under workspace root |
| objdir paths | env-pinned absolute string-keyed | see objdir invariant below | hard stop if source path changes |

Observed path/env reference counts in legacy source test set:

| pattern | matching files |
| --- | ---: |
| `NXPLATFORM_FREEBSD_SRC` | 15 |
| `NXPLATFORM_WORKSPACE_ROOT` | 64 |
| `NXPLATFORM_KERNEL_OBJDIRPREFIX` | 41 |
| `NXPLATFORM_ARTIFACTS_DIR` | 40 |
| `NXPLATFORM_SERIAL_LOG` | 42 |
| `NXPLATFORM_VM_IMAGE` | 22 |
| `NXPLATFORM_GUEST_ROOT` | 20 |
| `repo_root` | 71 |
| `workspace_root` | 67 |
| `freebsd-src-stable-15` | 40 |
| `/usr/obj` | 13 |
| `/Users/me` | 1 |

## Concrete Local Resolution

```sh
export NXPLATFORM_WORKSPACE_ROOT=/Users/me/wip-mach
export NXPLATFORM_FREEBSD_SRC=/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15
```

`NXPLATFORM_KERNEL_OBJDIRPREFIX` is lane-dependent and must be configured explicitly by lane. M0 records observed legacy defaults only as provenance:

| lane | observed legacy default | canonical? | M0 decision |
| --- | --- | --- | --- |
| launchd | `/Users/me/wip-mach/build/releng151-mach-obj` | no | record only; require explicit configured value in M1 |
| current-tree | `/Users/me/wip-mach/build/releng151-rc1-mach-obj` | no | record only; require explicit configured value in M1 |
| dispatch | `/usr/obj` | no | record only; require explicit configured value in M1 |
| libthr | `/usr/obj` | no | record only; require explicit configured value in M1 |

Hard stop: no guest/objdir gate until env handling disambiguates objdir prefix per lane, not only the FreeBSD source path. No lane may silently fall back to `releng151*`, `releng151-rc1*`, `/usr/obj`, or repo-root-derived objdir paths unless that value is explicitly pinned in env.local or lane configuration.

`NXPLATFORM_FREEBSD_SRC` exists: `yes`

`NXPLATFORM_FREEBSD_SRC` is symlink: `no`

Source tree boundary: `/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15` is the canonical FreeBSD source tree for this migration. It remains in `wip-gpt`; it is not copied into the oracle repo.

Other referenced FreeBSD tree `/Users/me/wip-mach/freebsd-src-official-stable-15`: `exists`. It is not the canonical certification source for this migration unless parent later changes the pin explicitly.

## Objdir Invariant

FreeBSD objdirs are keyed by the literal source path string. Therefore the canonical `NXPLATFORM_FREEBSD_SRC` must remain the absolute non-symlink path `/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15`.

The objdir prefix is also part of the lookup. `NXPLATFORM_FREEBSD_SRC` must be stable across all lanes, but `NXPLATFORM_KERNEL_OBJDIRPREFIX` must be selected by lane before any guest gate runs.

Formulas:

```text
kernel = ${NXPLATFORM_KERNEL_OBJDIRPREFIX}${NXPLATFORM_FREEBSD_SRC}/amd64.amd64/sys/${KERNEL_CONF}/kernel
module = ${NXPLATFORM_KERNEL_OBJDIRPREFIX}${NXPLATFORM_FREEBSD_SRC}/amd64.amd64/sys/modules/mach/mach.ko
```

Objdir path examples after lane-specific prefix selection:

```text
kernel: ${CONFIGURED_LANE_OBJDIRPREFIX}/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15/amd64.amd64/sys/${KERNEL_CONF}/kernel
module: ${CONFIGURED_LANE_OBJDIRPREFIX}/Users/me/wip-mach/wip-gpt/freebsd-src-stable-15/amd64.amd64/sys/modules/mach/mach.ko
```

Silent failure mode: if imported or ported tests default to `/Users/me/wip-mach/wip-gpt-oracle/freebsd-src-stable-15`, objdir lookup forks to `${CONFIGURED_LANE_OBJDIRPREFIX}/Users/me/wip-mach/wip-gpt-oracle/freebsd-src-stable-15/...`, which does not name the intended kernel/module tree. M1 must not rely on repo-root-derived source or objdir defaults.

## Verification Credibility

Legacy `scripts/test` is a shell wrapper around ExUnit. It executes `mix test` and does not exercise guest, objdir, serial log, or bhyve path behavior. Therefore `scripts/test` green is not migration acceptance, and the wrapper itself must be ported to Elixir or replaced by an oracle-owned Mix task before becoming canonical.

Required later gates remain:

- M3: oracle-owned env/path check plus `mix test` for unit/ExUnit layer only
- M4: guest smoke from oracle root to validate path and objdir behavior
- M6: full accepted foundation baseline before any source deletion

## Placement Decisions

- M1 creates/scaffolds the oracle Elixir/Zig framework and imports only selected canonical assets.
- `mix.exs` may be copied only if still appropriate; otherwise create an oracle-owned `mix.exs`.
- Existing Elixir tests/helpers may be imported when valid under oracle ownership.
- `fixtures/` may be imported as safe data.
- Python is not canonical; Python tools are legacy references to port to Elixir.
- Shell is not canonical runner code; shell wrappers/runners are ported to Elixir.
- Project-owned C probes are retained as references until Zig parity is proven.
- C compatibility shims/support headers are classified separately as `compat_shim` or `support_header` and may be kept only with parent-approved support rationale.
- Donor C payloads remain only as approved external/reference payload exceptions.
- `__pycache__/`, `*.pyc`, and `*.core` are excluded unconditionally.
- Historical oracle content stays in place during M0-M7.
- `mx-a64z/` and `mx-x64z/` stay as historical runner artifact dirs during M0-M7.
- New schemas use canonical `mx-a64` and `mx-x64`; old IDs are preserved only for existing artifacts.
- `catalog/`, `mismatches/`, and `certification/` are M2 additions, not M1 copy outputs.
- Root planning docs are not moved during M1.
- `NXPLATFORM_FREEBSD_SRC` must be pinned for behavior-preserving M1 execution.
- Stable/15 base update remains blocked while this harness migration is in progress; pin the base until the migrated harness is accepted.

## Import Collision Assessment

| target | current oracle state | collision risk | decision |
| --- | --- | --- | --- |
| `mix.exs` | missing | none | M1 create or import only after deciding oracle ownership shape |
| `test` | missing | none | M1 import selected Elixir tests/helpers only |
| `scripts` | missing | none | do not copy wholesale; port selected shell/python/awk logic to Elixir |
| `fixtures` | missing | none | M1 import safe fixtures only |
| Zig probe layer | missing | none | M1 must define canonical layout before any C/Zig probe migration |
| `catalog` | missing | none | planned M2 authority, do not create in M0/M1 |
| `mismatches` | missing | none | planned M2 authority, do not create in M0/M1 |
| `certification` | missing | none | planned M2 authority, do not create in M0/M1 |

## Hard Stops

- no M1 until this M0 document is accepted
- no canonical import from untracked source without parent approval or a source commit
- no M1 unless canonical imports come from committed source SHA `a30ef3f` or a later parent-approved refreshed source SHA using manifest SHA `e59e4a08bf2be837d38f5e5758a6f1d764dd2d278b43f09d74398fb42828d298`
- no M1 unless an automated preflight recomputes the legacy manifest and applies the drift policy above
- no M1 if `keep_fixture`, `keep_elixir`, or `keep_donor_payload_reference` files drift without reclassification and approval
- no M1 if any import-relevant path is dirty, unknown, gitignored, or missing
- no M1 if dirty files remain classified as `unknown`
- no M1 that copies `scripts/` wholesale into the canonical oracle tree
- no Python in the canonical test tree
- no shell as canonical runner code
- no generated/runtime artifacts in the canonical test tree
- no M1 if canonical `NXPLATFORM_FREEBSD_SRC` would change, become symlinked, become relative, or default to the oracle repo root
- no guest/objdir gate until lane-specific `NXPLATFORM_KERNEL_OBJDIRPREFIX` is resolved
- `scripts/test` green alone is not migration acceptance
- no empty/unowned top-level authority directories
- no Zig migration before the canonical Zig layout is defined
- no C-to-Zig port accepted without parity against the original C
- original C reference retained until Zig parity passes
- no Elixir verifier marked fully canonical while it depends on unported shell/Python
- no deletion from source repo until every accepted test has an Elixir/Zig equivalent or approved donor-payload exception, parity is proven gate-by-gate, and M6 is green from oracle root
- do not call M6 a certification pass until `certification/claims/` exists and is populated
- no stable/15 base update during this harness migration; pin base until migration completes

## Blockers Found While Drafting

- Path A freeze is complete: import-relevant Phase 0.8 test/framework bytes are committed in source SHA `a30ef3f`, and this M0 manifest is refreshed against that committed tree.
- Source repo remains dirty only under documentation paths. This does not block M1 import provenance, but those docs-only changes must not be treated as canonical import input.
- Source scripts contain repo-root-relative defaults for `freebsd-src-stable-15`; after M1 these would point at the oracle repo unless `NXPLATFORM_FREEBSD_SRC` is pinned. This is a hard stop for M1 execution.
- `NXPLATFORM_KERNEL_OBJDIRPREFIX` is lane-dependent. M0 records releng151 and `/usr/obj` values only as observed legacy defaults; M1 must require explicit lane configuration and projection into the legacy runtime variable.
- `scripts/bhyve/__pycache__/compare-m2-oracle.cpython-311.pyc` exists in the legacy source tree and is classified as `exclude_generated`. It is excluded from the legacy manifest and must not enter the canonical oracle tree.
- `scripts/bhyve/compare-m2-oracle.py` is classified as Python legacy oracle comparison logic. It must be ported to Elixir before it can become canonical.
- Existing Elixir verifiers are canonical candidates, but several still depend on non-canonical shell/Python runners. They are not fully canonical until those dependency edges are ported or removed.

## Review State

This document is a draft awaiting parent review. If accepted, M1 may create/scaffold the oracle Elixir/Zig framework and import only selected safe assets according to the classification table above, subject to the hard stops above.
