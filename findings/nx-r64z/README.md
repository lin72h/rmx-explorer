# Findings — nx-r64z ledger

Live mismatch/parity ledger for the `nx-r64z` contract namespace (`r` = union of
x64 + a64). This is where new Explorer parity findings live as of block-080.

The pre-split `findings/nx-v64z/` directory is retained as historical archive —
its entries were written before the `v64z → r64z` rename and are not migrated.
Do not add new entries there; add them here.

Conventions (carried from nx-v64z, unchanged by the rename):
- Reference = real macOS-27 (`mx-a64z`), captured on `mm4`.
- Compare semantic fields; ignore raw port names, pointers, struct padding, raw
  buffer layout, and absolute timing (per block-074).
- Catalog-only phase: record a triaged menu. Do not generate fix Blocks for
  parity gaps; discrepancies are backlog, not release blockers.
