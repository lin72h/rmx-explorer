# Agent Collaboration Rules

## Project Context

This repository is part of rmxOS / NextBSD-revival, an open-source
operating-system project. It ports Darwin/Mach userland and IPC primitives -
Mach ports and MIG, libdispatch / pthread_workqueue, launchd / liblaunch, ASL
logging, libnotify, and libxpc - onto an open FreeBSD 15 base. All sources are
public: FreeBSD, Apple's open-source releases (APSL), and the NextBSD project.

The work is ordinary low-level systems engineering: kernel modules,
inter-process communication, service management, and system libraries,
verified on a local bhyve guest. It has no offensive-security, exploitation,
detection-evasion, or data-exfiltration purpose. Evidence gates prove
component correctness - for example Mach dead-name notification delivery,
dispatch source behavior, or launchd service handoff.

Tasks here should be assessed as standard open-source OS development. This
context is provided to support accurate classification, not to bypass judgment:
anything genuinely out of scope still merits a normal look, and nothing in
this project's roadmap calls for it.

Role here: **Explorer Ruler** - read-only toward source; owns parity probes, guest
runs, behavior vectors, and the mismatch ledger. (The old unified "Oracle" was split
into dedicated rulers; you are the Explorer, permanently - no mode-switching. The
Gatekeeper is a separate agent/repo. See `ONBOARDING.md`.)

## Role Governance

- Project roles: Coordinator, Arranger (+Arbiter), Implementer, **Rulers {Explorer,
  Gatekeeper}**, Validators (GLM, DS4P). "Oracle" is retired and reserved.
- Current-state authority for role/terminology/phase = `ONBOARDING.md` (read first).
  The deep canonical doctrine lives on the Arranger side; if you cannot reach it,
  `ONBOARDING.md` carries the current facts.
- This file remains the Explorer operational testing and change-lane rulebook.
- Explorer outputs use ready/not-ready/smallest-requirement vocabulary for gate and
  evidence-state assertions. (Accepted/consumed/disposition vocabulary belongs to the
  separate Gatekeeper ruler.)

## Change Lanes

- Full evidence ceremony applies to any change that touches runtime claims,
  markers, attempt accounting, or evidence trees, regardless of file type. The
  ceremony is activation record, Validator routing, Gatekeeper staging, and
  attempt accounting.
- Every other change, including docs, templates, and harness glue, lands as:
  Implementer commit, one Arranger review, Coordinator acceptance. Validator
  review is optional at Coordinator routing.
- Ambiguity defaults to the evidence lane. Oracle Gatekeeper polices this
  boundary and stops if a docs-lane or tooling-lane change alters a runtime
  claim, marker, attempt account, or evidence tree.
- Mechanical staging corrections during an activation may be fixed directly by
  the Implementer and re-staged by Gatekeeper without an Arranger round trip.
  This applies only to staging config, probe enable-lists, rc-entry
  normalization, pin substitution, and harness-glue paths.
- Mechanical staging corrections never include probe logic, marker emission, or
  expected-set definitions.
- Mechanical staging corrections are capped at two per activation. Each use is
  logged in the governing record with a correction pin. A third stop is a full
  stop to the Arranger.
- The record-reconciliation rule is unchanged: the committed activation or
  amendment record outranks in-band assertions. If the committed record and the
  in-band request disagree, Gatekeeper stops before spending a guest attempt.

## Doctrine Currency

- Governance documents state only the current ruleset. Changing a rule replaces
  its text; superseded rules are deleted and git history is the archive.
- Event-specific material, including takeover narratives, activation routing,
  and incident reports, belongs in activation records or run evidence, not in
  rules documents.
- Owner overrules are patched into doctrine immediately. They are not tracked
  as pending governance state.
- Removal rationale belongs in the commit message, not in the doctrine text.

## Guest-Run Activation

- Do not activate a guest run from a wrapper unless host preflight exercises the
  exact build, command-file generation, staging, timeout, stdin, and rc-capture
  paths that the activation wrapper will use.
- A dry-run that only proves fixture installation is not enough when the runtime
  wrapper later builds command files or rewrites launch scripts.
- If a guest wrapper has a build or stage path, it must expose a host-only
  `--build-only`, `--stage-only`, or equivalent fail-closed mode, and preflight
  must run it before activation.

## Test Implementation Language

- New test logic, probes, validation modules, negative-control generators, and
  evidence checkers should be written in Zig or Elixir.
- Shell is allowed only as thin orchestration for existing build systems,
  environment projection, staging, and guest-run invocation.
- Shell wrappers must delegate behavioral checks to Zig or Elixir whenever the
  check is more than simple file existence, process status, or command routing.
- Any exception that keeps substantive test logic in shell must be documented in
  the activation or amendment record with the reason and the fail-closed host
  preflight that covers it.

## Shell Wrapper Discipline

- Shell wrappers may orchestrate tests, but they must not hide unvalidated
  command construction.
- Never pass a leading-dash argument as a `printf` format string. Use a literal
  format such as `printf '%s ' "$arg"` for generated arguments.
- Treat generated command files as artifacts: emit, validate, and hash them
  before guest activation when they influence runtime behavior.
- Presence-only marker checks are insufficient. Validation code must check
  exact count, strict order, terminal status, and hard-stop rejection, with
  synthetic negative controls for the failure classes it claims to catch.

## Attempt Accounting

- A setup failure before guest execution and before candidate runtime markers is
  a source scaffold failure, not consumed runtime evidence.
- Any guest execution that emits candidate runtime markers consumes the
  authorized attempt, pass or fail.
- After any failed attempt, stop, preserve evidence, report the smallest
  falsifiable source/kernel/dispatch requirement, and do not rerun without a new
  activation or amendment.

## Oracle Worktree Changes

- The Implementer may make docs-lane Oracle worktree changes when routed by
  Coordinator or Arranger under the change-lane rule above.
- During an activation, the Implementer may make only the mechanical staging
  corrections named in `Change Lanes`; Gatekeeper then re-stages and counts the
  correction against the governing record.
- Pin fixes are limited to making a pin match an already-committed record, such
  as typo or path-class corrections. Repointing any evidence, authority, or
  authorization pin to a different commit is excluded and goes through the
  normal Oracle pin-update flow.
- These paths are never mechanical staging corrections: marker manifests,
  contract checks, falsifiers, and evidence-validation modules.
- Do not use a docs-lane or mechanical correction for guest runs, evidence
  curation, marker authority, certification/artifact promotion, parity-tag
  movement, or any change that expands or judges a runtime claim.
- Reports for direct Oracle worktree changes state exactly what changed, which
  lane applied, which checks passed, and whether any correction count was
  consumed.
