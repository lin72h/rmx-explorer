defmodule RmxOSOracle.ID025.WatchpointConductor do
  @moduledoc """
  op-148 §B conductor — passive freeze watchpoint driver for id-025.

  Per op-147m partition:
    * THIS module (Elixir) owns: how the run is driven — kldload individual
      providers, fire the .d, parse heartbeat lines, detect flat-slope,
      terminate, write the ledger entry.
    * DTrace .d owns: runtime observation — counters + stack() dumps.
    * Zig: NOT USED for this op (no metal assertion; static analysis + .d
      observation only).
    * Shell: thin glue only — single `kldload`/`dtrace` invocations via
      System.cmd. NO multi-step .rc/.sh harness.

  Drives: /Users/me/wip-mach/wip-gpt/wip-rmxos/findings/nx-r64z/dtrace/
          id025-watchpoint/op148-freeze-watchpoint.d

  The watchpoint is PASSIVE — it does NOT alter the runner/transport. The
  conductor reads heartbeat lines from the .d's stdout, classifies the run
  (flat-slope-detected / nominal / sign-of-life), and writes the ledger
  entry to findings/nx-r64z/.

  Use: invoked by the test suite or manually via
       `mix run -e "RmxOSOracle.ID025.WatchpointConductor.run(\"/tmp/op148.log\")"`
       after the soak workload has started.
  """

  @provider_modules ~w(dtrace opensolaris fbt profile)
  @watchpoint_script ~c"findings/nx-r64z/dtrace/id025-watchpoint/op148-freeze-watchpoint.d"
  @flat_slope_tick_threshold 3   # 3 consecutive ticks (~30s) of zero delta → freeze
  @heartbeat_interval_ms 10_000

  @doc """
  Arms the watchpoint for `duration_s` seconds (default: 1 hour).

  Returns a map with: :classification, :heartbeat_count, :flat_slope_at_tick,
  :stack_obs_count, :ledger_path. The map is also written to the ledger file.

  `dtrace_out_path` is where the raw .d stdout is captured (for post-run
  forensic review). Pass `nil` to skip the raw capture.
  """
  def run(duration_s \\ 3600, dtrace_out_path \\ nil) do
    :ok = load_providers()
    {:ok, dtrace_pid, dtrace_out} = start_dtrace(dtrace_out_path)

    # Parse the heartbeat stream until flat-slope detected OR duration elapses.
    flat_slope_tick = detect_flat_slope(dtrace_out, duration_s)

    # Stop the watchpoint (SIGINT to dtrace, then cleanup).
    stop_dtrace(dtrace_pid)

    classification =
      case flat_slope_tick do
        nil -> :nominal_no_freeze_observed
        n when n > 0 -> {:flat_slope_detected, n}
      end

    ledger_entry = %{
      op: "op-148",
      role: "explorer",
      classification: classification_to_string(classification),
      duration_s: duration_s,
      flat_slope_at_tick: flat_slope_tick,
      stack_obs_count: count_stack_obs(dtrace_out),
      dtrace_raw: dtrace_out_path,
      watchpoint_script: watchpoint_script_path(),
      timestamp_utc: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    ledger_path = write_ledger(ledger_entry)
    Map.put(ledger_entry, :ledger_path, ledger_path)
  end

  # CanonicalJSON.encode! doesn't handle atoms/tuples — coerce to JSON-safe types.
  defp classification_to_string(:nominal_no_freeze_observed), do: "nominal_no_freeze_observed"
  defp classification_to_string({:flat_slope_detected, tick}), do: "flat_slope_detected@tick#{tick}"
  defp classification_to_string(other), do: to_string(other)

  @doc "Loads the DTrace provider modules individually (NOT dtraceall)."
  def load_providers() do
    for mod <- @provider_modules do
      {out, rc} = System.cmd("doas", ["kldload", Atom.to_string(mod)], stderr_to_stdout: true)
      # Already-loaded is rc=0 with "Module ... already loaded" warning — fine.
      if rc != 0 and not String.contains?(out, "already loaded") do
        IO.puts(:stderr, "[op148] WARN kldload #{mod} rc=#{rc}: #{out}")
      end
    end
    :ok
  end

  defp start_dtrace(nil) do
    # No raw capture — pipe directly to aString IO wrapper.
    port = Port.open({:spawn, ~c"doas dtrace -s #{watchpoint_script_path()}"}, [:stream, :binary, :use_stdio, :exit_status])
    {:ok, port, :no_capture}
  end

  defp start_dtrace(path) do
    # Capture raw .d output to `path` via tee — single shell pipe, thin glue.
    cmd = ~c"doas dtrace -s #{watchpoint_script_path()} 2>&1 | tee #{path}"
    port = Port.open({:spawn, cmd}, [:stream, :binary, :use_stdio, :exit_status])
    {:ok, port, path}
  end

  defp stop_dtrace(port) do
    # Self-terminating tick-Ns in the .d handles graceful exit. For SIGINT
    # teardown, we kill the port and let dtrace's END probe fire.
    Port.close(port)
  end

  # Heartbeat parsing: read OP148_HB lines, classify, return flat-slope tick
  # or nil if none detected within duration_s.
  defp detect_flat_slope(_dtrace_out, duration_s) do
    deadline_ms = duration_s * 1000
    start_ms = System.monotonic_time(:millisecond)
    parse_heartbeats(start_ms, deadline_ms, %{last_counters: nil, zero_delta_streak: 0})
  end

  defp parse_heartbeats(start_ms, deadline_ms, state) do
    elapsed_ms = System.monotonic_time(:millisecond) - start_ms
    if elapsed_ms > deadline_ms do
      nil
    else
      receive do
        {_, {:data, line}} when is_binary(line) ->
          case parse_heartbeat_line(line) do
            {:hb, counters} ->
              streak = compute_zero_delta_streak(state.last_counters, counters, state.zero_delta_streak)
              if streak >= @flat_slope_tick_threshold do
                streak
              else
                parse_heartbeats(start_ms, deadline_ms, %{last_counters: counters, zero_delta_streak: streak})
              end

            :ignore ->
              parse_heartbeats(start_ms, deadline_ms, state)
          end

        {_, {:exit_status, _rc}} ->
          nil
      after
        @heartbeat_interval_ms ->
          parse_heartbeats(start_ms, deadline_ms, state)
      end
    end
  end

  defp parse_heartbeat_line(line) do
    case Regex.run(~r/OP148_HB mqs=(\d+) mqr=(\d+) mqsig=(\d+) mqpst=(\d+) blocked_now=(\d+) blk_obs=(\d+)/, line) do
      [_, mqs, mqr, mqsig, mqpst, blocked, blk_obs] ->
        {:hb, %{
          mqs: String.to_integer(mqs),
          mqr: String.to_integer(mqr),
          mqsig: String.to_integer(mqsig),
          mqpst: String.to_integer(mqpst),
          blocked_now: String.to_integer(blocked),
          blk_obs: String.to_integer(blk_obs)
        }}

      _ ->
        :ignore
    end
  end

  defp compute_zero_delta_streak(nil, _current, _streak), do: 0
  defp compute_zero_delta_streak(prev, current, streak) do
    delta =
      (current.mqs - prev.mqs) +
        (current.mqr - prev.mqr) +
        (current.mqsig - prev.mqsig) +
        (current.mqpst - prev.mqpst)

    if delta == 0, do: streak + 1, else: 0
  end

  defp count_stack_obs(:no_capture), do: -1
  defp count_stack_obs(path) do
    case File.read(path) do
      {:ok, data} -> String.split(data, "\n", trim: true) |> Enum.count(&String.contains?(&1, "OP148_FREEZE_OBS"))
      _ -> -1
    end
  end

  defp write_ledger(entry) do
    dir = Path.expand("findings/nx-r64z/dtrace/id025-watchpoint", repo_root())
    File.mkdir_p!(dir)
    path = Path.join(dir, "watchpoint-ledger-#{:erlang.system_time(:second)}.json")
    # Use the project's own CanonicalJSON (no Jason dep); atoms coerced to strings upstream.
    RmxOSOracle.CanonicalJSON.write!(path, entry)
    path
  end

  defp watchpoint_script_path() do
    Path.expand(@watchpoint_script, repo_root())
  end

  defp repo_root() do
    # Up from lib/rmx_os_oracle/id025/ to the rmx-explorer root.
    __DIR__ |> Path.join("../../..") |> Path.expand()
  end
end
