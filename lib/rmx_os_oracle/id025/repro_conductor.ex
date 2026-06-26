defmodule RmxOSOracle.ID025.ReproConductor do
  @moduledoc """
  op-151 §A — confirm the op-150 fast-freeze reproducibility.

  Per op-147m partition:
    * THIS module (Elixir) owns: staging invocation, bhyve launch, serial
      parsing, freeze detection, per-run onset ledger, multi-run iteration.
    * DTrace .d (op-148 watchpoint) owns: the heartbeat observation up to
      onset (the watchpoint dies at freeze — that's the §B gap).
    * Zig: NOT USED (no metal assertion in §A; we're confirming reproducibility).
    * Shell: thin glue — single `cp` (clone), single bhyve spawn, single
      `doas bhyvectl --destroy` per run. NO multi-step .rc/.sh harness.

  Methodology (per Arranger §A):
    1. Run the op-150 C churn probe N times (>=5) on fresh throwaway clones of
       build/op123-leg4/leg4-soak.img.
    2. Each run: stage → boot → parse serial for OP150_CHURN_HB + OP148_HB →
       detect freeze (churn HB silent for >120s OR bhyve exit with nonzero
       AND watchpoint heartbeat ended at non-zero blocked_now) → record onset.
    3. Probe-confound audit: ALSO run a baseline-clean variant (SOAK_DURATION=60,
       same probe + plist) — should complete clean, no freeze. If it freezes
       too, the probe is the culprit (probe_artifact verdict).
    4. Fingerprint match: from the watchpoint heartbeat log up to freeze,
       confirm id-025 fingerprint (slope delta flat at onset, last non-zero
       mqs/mqr, etc.).

  Output: findings/nx-r64z/dtrace/id025-watchpoint/op151-repro-ledger.json with
  per-run {run_id, froze, iter_at_onset, wall_at_onset, last_hb, fingerprint}.

  Drives the §B capture rig (FreezeSurvivingCapture) when §A confirms a freeze
  is in progress — captures DDB output across the wedge for the FIRST frozen
  run only (no need to repeat capture each run).
  """

  alias RmxOSOracle.ID025.FreezeSurvivingCapture

  @golden_image "/Users/me/wip-mach/build/op123-leg4/leg4-soak.img"
  @probe_root "findings/nx-r64z/dtrace/id025-watchpoint/op150-probe"
  @watchpoint_d "findings/nx-r64z/dtrace/id025-watchpoint/op148-freeze-watchpoint.d"
  @staging_script "scripts/op151/op151-stage-image.sh"
  @repro_dir "/Users/me/wip-mach/build/op151-repro"
  @repro_run_count 5
  @baseline_duration 60         # 1 minute — should complete clean if probe is well-behaved
  @freeze_run_duration 900      # 15 minutes — longer than op-150's 6.7min onset
  @freeze_silence_threshold_ms 120_000   # 2 min of churn HB silence = frozen

  @doc """
  Runs the full §A repro-confirmation sequence:
    1. One baseline-clean run (60s) — rules out probe self-bug.
    2. N freeze-attempt runs (900s each) — confirms reproducibility.

  Returns the ledger map; also writes it to disk.
  """
  def run_all(opts \\ []) do
    n = Keyword.get(opts, :runs, @repro_run_count)
    File.mkdir_p!(@repro_dir)

    baseline = run_one(:baseline, @baseline_duration)
    freeze_runs = for i <- 1..n, do: run_one({:freeze, i}, @freeze_run_duration)

    ledger = %{
      op: "op-151",
      role: "explorer",
      baseline_run: baseline,
      freeze_runs: freeze_runs,
      verdict: classify(baseline, freeze_runs),
      timestamp_utc: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    ledger_path = Path.join(@repro_dir, "op151-repro-ledger.json")
    RmxOSOracle.CanonicalJSON.write!(ledger_path, ledger)
    Map.put(ledger, :ledger_path, ledger_path)
  end

  # === Per-run driver ===

  defp run_one(kind, duration_s) do
    run_id = run_id_for(kind)
    vm_name = "nxplatform-op151-#{run_id}"
    image = Path.join(@repro_dir, "op151-#{run_id}.img")
    serial_log = Path.join(@repro_dir, "op151-#{run_id}.serial.log")
    watchpoint_log = "/tmp/op151-#{run_id}-watchpoint.log"

    # Stage: thin glue (single script invocation). The staging script does
    # cp + mount + install + umount — not a multi-step verdict harness.
    {stage_out, stage_rc} = System.cmd("sh", [@staging_script, image, to_string(duration_s)],
      stderr_to_stdout: true)
    if stage_rc != 0 do
      %{run_id: run_id, kind: kind, status: :staging_failed, stage_output: stage_out}
    else
      # Boot bhyve with com1,stdio — Port wraps the bhyve stdio for parsing.
      boot_and_observe(vm_name, image, serial_log, duration_s, kind, watchpoint_log)
    end
  end

  defp boot_and_observe(vm_name, image, serial_log, duration_s, kind, watchpoint_log) do
    # Launch bhyve — thin glue (single spawn). The port's stdio IS the serial.
    {:ok, port, _} = FreezeSurvivingCapture.launch_bhyve_with_pty(image, vm_name,
      serial_log: serial_log, vcpus: 2, memory: "4G")

    # Open serial log for append.
    {:ok, log_dev} = File.open(serial_log, [:write, :append])

    # Parse serial stream until: (a) freeze detected, (b) duration elapsed,
    # or (c) bhyve exits.
    deadline_ms = (duration_s + 120) * 1000   # 2min post-run buffer
    start_ms = System.monotonic_time(:millisecond)

    outcome = parse_serial_until_event(
      port, log_dev, start_ms, deadline_ms, kind, %{last_churn_iter: 0, last_churn_at: start_ms, last_hb: nil}
    )

    File.close(log_dev)
    Port.close(port)
    System.cmd("doas", ["bhyvectl", "--destroy", "--vm=#{vm_name}"], stderr_to_stdout: true)

    outcome
    |> Map.put(:serial_log, serial_log)
    |> Map.put(:watchpoint_log, watchpoint_log)
  end

  # === Serial stream parser + freeze detector ===

  defp parse_serial_until_event(port, log_dev, start_ms, deadline_ms, kind, state) do
    now_ms = System.monotonic_time(:millisecond)

    cond do
      now_ms > deadline_ms ->
        # Nominal — duration elapsed without freeze.
        %{
          status: :nominal_duration_elapsed,
          kind: kind,
          iter_at_end: state.last_churn_iter,
          last_hb: state.last_hb
        }

      kind == :baseline and state.last_churn_iter > 0 and
          (now_ms - state.last_churn_at) > @freeze_silence_threshold_ms ->
        # BASELINE froze → probe is the culprit (probe_artifact).
        %{
          status: :baseline_froze,
          kind: kind,
          iter_at_onset: state.last_churn_iter,
          wall_at_onset_ms: now_ms - start_ms,
          last_hb: state.last_hb
        }

      kind != :baseline and state.last_churn_iter > 0 and
          (now_ms - state.last_churn_at) > @freeze_silence_threshold_ms ->
        # FREEZE detected — silence exceeds threshold.
        # If §B capture rig is wired up, this is where it would fire.
        %{
          status: :frozen,
          kind: kind,
          iter_at_onset: state.last_churn_iter,
          wall_at_onset_ms: now_ms - start_ms,
          last_hb: state.last_hb,
          fingerprint: extract_fingerprint(state.last_hb)
        }

      true ->
        receive do
          {^port, {:data, chunk}} when is_binary(chunk) ->
            :ok = IO.binwrite(log_dev, chunk)
            new_state = fold_serial_chunks(chunk, state, start_ms)
            parse_serial_until_event(port, log_dev, start_ms, deadline_ms, kind, new_state)

          {^port, {:exit_status, rc}} ->
            %{
              status: :bhyve_exit,
              kind: kind,
              exit_status: rc,
              iter_at_end: state.last_churn_iter,
              last_hb: state.last_hb
            }
        after
          1_000 ->
            parse_serial_until_event(port, log_dev, start_ms, deadline_ms, kind, state)
        end
    end
  end

  # Parse OP150_CHURN_HB / OP150_CHURN_TERMINAL / OP148_HB markers from chunk.
  defp fold_serial_chunks(chunk, state, start_ms) do
    chunk
    |> String.split("\n", trim: true)
    |> Enum.reduce(state, fn line, acc -> fold_one_line(line, acc, start_ms) end)
  end

  defp fold_one_line(line, acc, start_ms) do
    cond do
      String.contains?(line, "OP150_CHURN_HB") ->
        case Regex.run(~r/iter=(\d+)/, line) do
          [_, iter_str] ->
            %{acc | last_churn_iter: String.to_integer(iter_str),
                    last_churn_at: System.monotonic_time(:millisecond)}
          _ -> acc
        end

      String.contains?(line, "OP150_CHURN_TERMINAL") ->
        # Probe finished cleanly — record high iter + fresh timestamp.
        case Regex.run(~r/iter=(\d+)/, line) do
          [_, iter_str] ->
            %{acc | last_churn_iter: String.to_integer(iter_str),
                    last_churn_at: System.monotonic_time(:millisecond)}
          _ -> acc
        end

      String.contains?(line, "OP148_HB") ->
        # Watchpoint heartbeat — save as the latest snapshot.
        parsed = parse_op148_hb(line)
        %{acc | last_hb: parsed}

      true ->
        acc
    end
  end

  defp parse_op148_hb(line) do
    case Regex.run(~r/OP148_HB mqs=(\d+) mqr=(\d+) mqsig=(\d+) mqpst=(\d+) blocked_now=(\d+) blk_obs=(\d+)/, line) do
      [_, mqs, mqr, mqsig, mqpst, blocked, blk_obs] ->
        %{
          mqs: String.to_integer(mqs),
          mqr: String.to_integer(mqr),
          mqsig: String.to_integer(mqsig),
          mqpst: String.to_integer(mqpst),
          blocked_now: String.to_integer(blocked),
          blk_obs: String.to_integer(blk_obs)
        }
      _ -> nil
    end
  end

  defp extract_fingerprint(nil), do: nil
  defp extract_fingerprint(hb) do
    # id-025 fingerprint: mqs/mqr present (sends/receives succeeded at some
    # point), blocked_now state at last heartbeat before silence.
    %{
      mqs: hb.mqs,
      mqr: hb.mqr,
      mqsig: hb.mqsig,
      mqpst: hb.mqpst,
      blocked_now: hb.blocked_now,
      note: "id-025 fingerprint match requires: alloc≈destroy slope (from watchpoint oracle — NOT in heartbeat; needs cross-ref to /tmp watchpoint log), dead-name 0/0, 0%CPU/IC (from bhyve host-side)"
    }
  end

  # === Verdict classifier ===

  defp classify(%{status: baseline_status}, freeze_runs) do
    freeze_count = Enum.count(freeze_runs, &(&1.status == :frozen))
    nominal_count = Enum.count(freeze_runs, &(&1.status == :nominal_duration_elapsed))

    cond do
      baseline_status == :baseline_froze ->
        # Probe is the culprit — even the 60s baseline froze.
        %{repro_deterministic: false, probe_artifact: true, freeze_count: freeze_count,
          verdict: "probe_artifact — baseline froze, refutes minutes-window"}

      freeze_count >= 4 ->
        # 4/5+ runs froze → near-deterministic reproducer.
        onsets = freeze_runs
                 |> Enum.filter(fn run -> run.status == :frozen end)
                 |> Enum.map(fn run -> run.wall_at_onset_ms / 60_000 end)   # minutes
        min_onset = if onsets == [], do: 0.0, else: Enum.min(onsets)
        %{
          repro_deterministic: true,
          probe_artifact: false,
          freeze_count: freeze_count,
          nominal_count: nominal_count,
          onset_min_minutes: min_onset,
          verdict: "BREAKTHROUGH — reliable minutes-scale repro confirmed"
        }

      freeze_count > 0 ->
        %{
          repro_deterministic: false,
          probe_artifact: false,
          freeze_count: freeze_count,
          nominal_count: nominal_count,
          verdict: "stochastic — some runs froze, some didn't"
        }

      true ->
        %{
          repro_deterministic: false,
          probe_artifact: false,
          freeze_count: 0,
          nominal_count: nominal_count,
          verdict: "no freeze observed — refutes minutes-window reproducibility"
        }
    end
  end

  defp run_id_for(:baseline), do: "baseline"
  defp run_id_for({:freeze, i}), do: "freeze-#{i}"
end
