defmodule Mix.Tasks.Oracle.Parked do
  @moduledoc """
  Lists all parked conformance probes and their pending gates.

  ## Usage

      mix oracle.parked

  Shows probes that are authored and ready but parked behind a
  pending feature gate (e.g., the P1 executor join).
  """
  use Mix.Task

  alias RmxOSOracle.Concurrency.ParkedLedger

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("compile", [])

    parked = ParkedLedger.all()
    count = map_size(parked)

    IO.puts("\n=== Parked Conformance Corpus (#{count} probes) ===\n")

    Enum.each(parked, fn {id, entry} ->
      IO.puts("  #{id}")
      IO.puts("    shape:     #{entry.shape}")
      IO.puts("    gate:      #{entry.gate}")
      IO.puts("    invariants: #{Enum.join(entry.match_invariants, ", ")}")
      IO.puts("    excludes:   #{Enum.join(entry.match_excludes, ", ")}")
      IO.puts("    activates:  #{entry.activates_when}")
      IO.puts("    source:     #{entry.source}")
      IO.puts("")
    end)

    IO.puts("Total: #{count} parked probes waiting on feature gates.")
    IO.puts("")
  end
end
