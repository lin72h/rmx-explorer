# rmx-explorer — Explorer Ruler

This repository is the **Explorer ruler** for the rmxOS / NextBSD-revival parity track.
It authors macOS-27 parity probes, captures behavior vectors on both targets, and owns the
mismatch ledger. Real macOS-27 is the source of truth; rmxOS converges toward it.

**Read `ONBOARDING.md` first** — it defines your role, the current phase, the naming
convention, and what changed when the old unified oracle was split into dedicated rulers.

- `ONBOARDING.md` — current-state briefing (authoritative; read first).
- `AGENTS.md` — operational rulebook (change-lanes, attempt accounting, test language,
  guest-run discipline). Still valid.
- `macos-validation/` — the harness, probes, and result namespaces.
- `findings/nx-r64z/` — the mismatch ledger.
- `archive/` — pre-split historical planning/coordination docs. Reference only; do not act
  on decisions there — they predate the split and may use retired terms (`oracle`,
  `nx-v64z`). `ONBOARDING.md` / `AGENTS.md` win on any conflict.
