# Stable/15 Minor Rebase Candidate f71260cf4c9e

Status: accepted candidate run. This is not a certification claim and not an
activation/adoption decision.

Durable machine-readable record:

- `docs/stable15-minor-rebase-f71260cf4c9e.json`

Key points:

- Oracle run commit: `32e2a0f0d49d`.
- Source policy/docs commit: `f89bcad`. This is not an Oracle commit.
- Candidate source stayed at `f71260cf4c9e` across the failed and passed D17
  runs.
- S3, D14, D17, and D18 passed with the official stable/15 candidate source and
  objdir.
- The prior D17 failure was runner/stdin setup or finalization evidence, not a
  D18 failure and not accepted as a stable/15 candidate runtime gap.
- `run-guest.rc=1` is non-authoritative only when validate-only passes, the
  marker contract passes, the serial contains harness `rc=0`, and the
  hard-stop scan is clean.

Accepted evidence remains under ignored `priv/runs/`; the JSON file above is the
committed curated provenance record.
