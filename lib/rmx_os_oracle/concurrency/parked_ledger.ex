defmodule RmxOSOracle.Concurrency.ParkedLedger do
  @moduledoc """
  op-232 items 2-4 — park-ahead ledger for the concurrency corpus (op-229 mechanism).

  First live consumer of the op-229 park-ahead pipeline. Each parked probe
  has a pending-gate entry naming the feature it waits on. Visible via
  `mix oracle.parked`.

  Parked probes:
    - fan_out_taskgroup  → waiting on P1 executor join
    - actor_churn        → waiting on P1 executor join
    - deep_async_chain   → waiting on P1 executor join

  Match domain (op-231 D3 — invariants ONLY):
    MATCH: completion, exclusion, ordering (where guaranteed), liveness, counts
    EXCLUDE: thread IDs/counts, cross-actor interleavings, timing, scheduler placement
  """

  alias RmxOSOracle.Concurrency.Comparator

  @parked %{
    "fan_out_taskgroup" => %{
      gate: "P1 executor join",
      shape: "wide fan-out TaskGroup",
      match_invariants: [:completion, :counts],
      match_excludes: [:thread_ids, :timing, :scheduler_placement],
      source: "macos-validation/probes/concurrency/fan_out_taskgroup.swift",
      status: :parked,
      parked_at: "2026-06-30",
      activates_when: "Implementer P1 join-op retirement → op-229 lock-2 → drive rx→match"
    },
    "actor_churn" => %{
      gate: "P1 executor join",
      shape: "actor churn (serial-queue create/teardown + hop)",
      match_invariants: [:completion, :exclusion, :counts],
      match_excludes: [:cross_actor_interleavings, :timing, :scheduler_placement],
      source: "macos-validation/probes/concurrency/actor_churn.swift",
      status: :parked,
      parked_at: "2026-06-30",
      activates_when: "Implementer P1 join-op retirement → op-229 lock-2 → drive rx→match"
    },
    "deep_async_chain" => %{
      gate: "P1 executor join",
      shape: "deep async/await chain (continuation queue depth)",
      match_invariants: [:completion, :liveness, :counts],
      match_excludes: [:thread_ids, :timing, :scheduler_placement],
      source: "macos-validation/probes/concurrency/deep_async_chain.swift",
      status: :parked,
      parked_at: "2026-06-30",
      activates_when: "Implementer P1 join-op retirement → op-229 lock-2 → drive rx→match"
    }
  }

  @doc "Returns all parked entries"
  def all, do: @parked

  @doc "Returns count of parked entries"
  def count, do: map_size(@parked)

  @doc "Returns a formatted summary for `mix oracle.parked`"
  def summary do
    @parked
    |> Enum.map(fn {id, entry} ->
      "#{id}: PARKED (gate=#{entry.gate}, invariants=#{Enum.join(entry.match_invariants, ",")})"
    end)
    |> Enum.join("\n")
  end

  @doc "Returns regime labels for a comparison record (op-225 M1 / op-230)"
  def regime_labels(opts \\ []) do
    %{
      kernel_ident: Keyword.get(opts, :kernel_ident, "unknown"),
      mach_ko_loaded: Keyword.get(opts, :mach_ko_loaded, false),
      libdispatch_version: Keyword.get(opts, :libdispatch_version, "unknown"),
      engine_evidence: Keyword.get(opts, :engine_evidence, "not_captured"),
      mismatch_v1: Keyword.get(opts, :mismatch_v1, nil)
    }
  end

  @doc "Checks if a probe is currently parked"
  def parked?(probe_id), do: Map.has_key?(@parked, probe_id)

  @doc "Gets the gate reason for a parked probe"
  def gate_reason(probe_id) do
    case Map.get(@parked, probe_id) do
      nil -> nil
      entry -> entry.gate
    end
  end
end
