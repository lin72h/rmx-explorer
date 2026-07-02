defmodule RmxOSOracle.Concurrency.Comparator do
  @moduledoc """
  op-232 — Swift concurrency corpus comparator.

  Drives the 3 stress-shape probes on both targets (macOS-27 = truth,
  rmxOS = match), captures JSON output, and diffs behavior vectors.

  Probes live in macos-validation/probes/concurrency/:
    - fan_out_taskgroup.swift  (shape a: wide fan-out)
    - actor_churn.swift        (shape b: actor churn)
    - deep_async_chain.swift   (shape c: deep async/await)

  Each probe emits structured JSON with test_id, result, and metrics.
  The comparator:
    1. Compiles + runs each probe on the target
    2. Parses the JSON output
    3. Diffs rx vs mx per behavior vector
    4. Labels any mismatch with regime info (op-230)

  Parked status: all 3 probes are PARKED on rx (waiting on the P1
  executor join). The mx (macOS-27) truth capture can proceed immediately.
  """

  @probes %{
    "fan_out_taskgroup" => %{
      source: "macos-validation/probes/concurrency/fan_out_taskgroup.swift",
      shape: "wide fan-out TaskGroup",
      property: "all tasks complete, values propagate, no drops",
      parked_reason: "P1 executor join (Swift concurrency runtime not yet wired to libdispatch on rmxOS)"
    },
    "actor_churn" => %{
      source: "macos-validation/probes/concurrency/actor_churn.swift",
      shape: "actor create/use/teardown churn",
      property: "actor serial isolation holds, state consistent",
      parked_reason: "P1 executor join"
    },
    "deep_async_chain" => %{
      source: "macos-validation/probes/concurrency/deep_async_chain.swift",
      shape: "deep async/await continuation chain",
      property: "continuation resumption at depth, values propagate",
      parked_reason: "P1 executor join"
    }
  }

  @doc """
  Runs a single probe on the given target and returns the parsed JSON result.
  Target is :mx (macOS-27) or :rx (rmxOS).

  For :mx — compiles with swiftc and runs on mm4 (macOS-27).
  For :rx — PARKED until the executor join lands. Returns :parked.
  """
  def run_probe(probe_id, target) do
    probe = Map.fetch!(@probes, probe_id)

    case target do
      :mx ->
        run_on_macos(probe_id, probe)
      :rx ->
        # rx is parked — the Swift toolchain + executor join aren't built yet
        {:parked, %{reason: probe.parked_reason, probe: probe_id}}
    end
  end

  @doc """
  Captures macOS-27 truth for all 3 probes.
  Called by explorer-mx on mm4.
  """
  def capture_macos_truth(output_dir) do
    results =
      @probes
      |> Enum.map(fn {id, probe} ->
        {id, run_on_macos(id, probe)}
      end)
      |> Map.new()

    path = Path.join(output_dir, "macos27_concurrency_truth.json")
    File.mkdir_p!(Path.dirname(path))
    RmxOSOracle.CanonicalJSON.write!(path, results)
    {:ok, path}
  end

  @doc """
  Diffs rx vs mx behavior vectors for a given probe.
  Returns :match | {:mismatch, fields} | :parked.
  """
  def diff_vectors(rx_result, mx_result) do
    cond do
      rx_result == :parked ->
        :parked

      rx_result["result"] == mx_result["result"] ->
        # Compare key behavioral properties (not timing — timing differs)
        behavioral_keys = ~w(tasks_completed sum_actual all_unique all_consistent all_correct_depth)
        mismatches =
          behavioral_keys
          |> Enum.filter(fn k ->
            Map.get(rx_result, k) != Map.get(mx_result, k)
          end)

        if Enum.empty?(mismatches), do: :match, else: {:mismatch, mismatches}

      true ->
        {:mismatch, ["result"]}
    end
  end

  # Private: compile + run on macOS-27
  defp run_on_macos(probe_id, probe) do
    source = probe.source
    binary = "/tmp/op232_#{probe_id}"
    repo_root = repo_root()

    # Compile
    {compile_out, compile_rc} =
      System.cmd("swiftc", ["-o", binary, Path.join(repo_root, source)],
        stderr_to_stdout: true)

    if compile_rc != 0 do
      %{test_id: probe_id, result: "COMPILE_FAIL", error: compile_out}
    else
      # Run
      {run_out, run_rc} = System.cmd(binary, [], stderr_to_stdout: true)
      # Parse JSON
      case Jason.decode(run_out) do
        {:ok, json} -> json
        {:error, _} -> %{test_id: probe_id, result: "RUN_FAIL", rc: run_rc, output: run_out}
      end
    end
  end

  defp repo_root do
    __DIR__
    |> Path.join("../../..")
    |> Path.expand()
  end

  @doc "Returns the probe catalog (for op-229 park/activate wiring)"
  def probe_catalog, do: @probes
end
