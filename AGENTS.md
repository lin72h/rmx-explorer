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

Role here: Oracle - read-only toward source; owns evidence, guest runs, marker
authority. Mode is declared per task (`explorer` | `gatekeeper`).

## Role Governance

- Canonical project roles are defined by source
  `/Users/me/wip-mach/wip-gpt/docs/role-governance.md`: Maestro, Conductor,
  Implementer, Oracle Explorer/Gatekeeper, Validator, and Arbiter.
- Current source authority is
  `6ace1e51f76bf32156f7d39e57b4c41b404fc8c9`.
- This file remains the Oracle worktree operational testing and direct-fix
  rulebook. If role wording here conflicts with the source role-governance
  document, the source role-governance document wins.
- Every Oracle output declares `mode: explorer` or `mode: gatekeeper`.
  Explorer outputs use ready/not-ready/smallest-requirement vocabulary for
  gate and evidence-state assertions. Gatekeeper outputs use
  accepted/not-accepted/consumed/disposition vocabulary.

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

## Direct Oracle Worktree Fixes

- The Implementer may edit this Oracle worktree directly when the fix is
  obvious, host-only, and the back-and-forth request loop would add avoidable
  latency. This is a narrow standing one-way-door delegation: the acting role is
  Implementer and the owning role is Oracle.
- Allowed direct fixes include typo/pin corrections, validation/tooling bugs,
  formatting failures, missing host-only checks, and documentation that records
  already-known state.
- Pin fixes are limited to making a pin match an already-committed record, such
  as typo or path-class corrections. Repointing any evidence, authority, or
  authorization pin to a different commit is excluded and goes through the
  normal Oracle pin-update flow.
- This exception excludes marker manifests, contract checks, falsifiers, and
  evidence-validation modules.
- Do not use this exception for guest runs, evidence curation, marker authority,
  certification/artifact promotion, parity-tag movement, or any change that
  expands or judges a runtime claim.
- Preserve the Implementer/Oracle boundary in the report: state exactly what
  changed, why the direct-fix exception applied, which checks passed, and
  notify Oracle, the Conductor, and the Maestro.
