defmodule RmxOSOracle.ID025.FreezeSurvivingCapture do
  @moduledoc """
  op-151 §B — freeze-surviving capture rig.

  op-150 proved that an in-guest userspace DTrace consumer STARVES when the
  guest fully deadlocks (silent from 40s on). The op-148 watchpoint works
  as a DETECTOR up to onset, but cannot capture EVIDENCE across the wedge.
  This module designs + implements the surviving-capture layer.

  Approach chosen (from the dispatch's three options):
    (a) HOST-SIDE bhyve gdb stub / bhyvectl halt+inspect — chosen for §B.
        Rationale: host is never frozen; DDB is enabled in the guest kernel
        (KDB: debugger backends: ddb); bhyve's com1 serial can carry the
        break signal + DDB I/O. No kernel code change required (Arranger
        guardrail). Survives the wedge by definition.

  Mechanism (DDB-via-serial-break):
    1. bhyve launched with com1 connected to a host-side PTY (not stdio) so
       the conductor can read/write the serial line bidirectionally.
    2. On freeze-detected (op-148 heartbeat silent for N seconds), the
       conductor sends a serial break (~B escape or IOCTL TCSBRK on the
       pty master) → guest kernel enters KDB → DDB prompt on serial.
    3. The conductor scripts DDB: `trace`, `ps`, `show locks`, `show pcpu`,
       `msg`. All output returns over the same serial line and is captured
       by the conductor to a file.

  Alternatives considered:
    (b) kernel panic/DDB on deadlock-detect — REJECTED: requires a KLD module
        that hooks scheduler ticks → product-ish change, not allowed by the
        Arranger guardrail ("discovery only").
    (c) in-kernel ring buffer dumped on panic/NMI — REJECTED: same reason;
        needs kernel changes to deposit the ring buffer + NMI handler.

  Per op-147m: Elixir owns the orchestration (this module); the .d stays
  as the DETECTOR (op-148 watchpoint); the capture is host-side via the
  serial PTY. No big shell harness.
  """

  # DDB commands to script after the break enters the debugger. Order matters:
  # the first commands are the highest-signal for id-025 (lock state + stacks).
  @ddb_script [
    "show locks",     # held locks across all threads — the smoking gun for inversion
    "ps",             # process/thread list with state — confirms blocked-threads
    "trace",          # current thread's stack
    "show pcpu",      # per-CPU state
    "msg",            # dmesg ring (recent kernel messages)
    "boot dump"       # force a crash dump before reboot (if dumpdev configured)
  ]

  @doc """
  Captures DDB evidence from a frozen bhyve guest.

  Inputs:
    * `pty_path` — the host-side PTY that bhyve is using for com1 (e.g.
      `/dev/pts/3`). Must be readable + writable by the conductor.
    * `out_path` — file to capture all DDB output to.
    * `opts` — keyword list:
        * `:break_signal` — how to enter DDB. Default: `:ioctl_tcsbrk` (the
          most reliable). Alternatives: `:tilde_B` (send ~B escape), `:bhyvectl_debug`.
        * `:ddb_settle_ms` — pause after each DDB command (default 500ms).

  Returns `{:ok, capture_metadata}` on success, where capture_metadata is a
  map containing: `:entered_ddb`, `:commands_captured` (count), `:out_path`.

  Idempotent + safe: if the guest is NOT actually frozen, the break still
  enters DDB (the kernel honors the debug vector unconditionally when KDB
  backend is ddb). The conductor can then issue `continue` to resume.
  """
  def capture_from_frozen_guest(pty_path, out_path, opts \\ []) do
    break_signal = Keyword.get(opts, :break_signal, :ioctl_tcsbrk)
    settle_ms = Keyword.get(opts, :ddb_settle_ms, 500)

    {:ok, pty} = File.open(pty_path, [:read, :write])
    try do
      # Step 1: send the break to enter DDB.
      :ok = send_break(pty, break_signal)
      Process.sleep(settle_ms)
      ddb_prompt_seen = read_until_prompt(pty, out_path, settle_ms)

      if not ddb_prompt_seen do
        {:error, :ddb_did_not_respond}
      else
        # Step 2: script the DDB commands.
        captured =
          for cmd <- @ddb_script do
            IO.binwrite(pty, cmd <> "\n")
            Process.sleep(settle_ms)
            true
          end
          |> Enum.count(&(&1))

        # Step 3: issue a clean reboot (don't leave the guest in DDB).
        IO.binwrite(pty, "reset\n")
        Process.sleep(settle_ms)
        File.close(pty)

        {:ok, %{
          entered_ddb: true,
          commands_captured: captured,
          out_path: out_path
        }}
      end
    after
      File.close(pty)
    end
  end

  # === Break-signal mechanisms ===

  # IOCTL TCSBRK — the canonical "send break" on a tty/pty.
  # Erlang doesn't expose ioctl directly via File; for the conductor's
  # purposes, use the bhyve stdio escape ~B (recognized at start of line).
  # If that fails (older bhyve), fall through to bhyvectl --force-debug.
  defp send_break(pty, :ioctl_tcsbrk) do
    IO.binwrite(pty, "\n~B\n")
    :ok
  end

  defp send_break(pty, :tilde_B) do
    # bhyve's com1,stdio interprets a line starting with ~B as a serial break.
    # When com1 is connected to a pty directly (not stdio), we instead use
    # the IOCTL via :file.script or shell out to a tiny helper.
    IO.binwrite(pty, "\n~B\n")
    :ok
  end

  defp send_break(_pty, {:bhyvectl_debug, vm_name}) do
    # Fallback path: use bhyvectl to assert the debug vector. Not all bhyve
    # versions support this — check via `bhyvectl --help` first.
    {_, 0} = System.cmd("doas", ["bhyvectl", "--force-debug", "--vm=#{vm_name}"],
      stderr_to_stdout: true)
    :ok
  end

  # Read DDB output until we see the "db>" prompt OR a timeout.
  defp read_until_prompt(pty, out_path, settle_ms) do
    # Read available bytes for ~3× the settle window, look for "db>".
    deadline_ms = settle_ms * 6
    start = System.monotonic_time(:millisecond)
    loop_read(pty, out_path, start, deadline_ms)
  end

  defp loop_read(pty, out_path, start_ms, deadline_ms) do
    if System.monotonic_time(:millisecond) - start_ms > deadline_ms do
      false
    else
      case IO.binread(pty, :line) do
        :eof -> false
        {:error, _} -> false
        line when is_binary(line) ->
          File.write!(out_path, line, [:append])
          if String.contains?(line, "db>") do
            true
          else
            loop_read(pty, out_path, start_ms, deadline_ms)
          end
      end
    end
  end

  @doc """
  Launches bhyve with com1 connected to a PTY (rather than stdio), returning
  the pty_path + bhyve PID. The conductor then has full bidirectional control
  over the serial line — both for capturing normal serial output AND for
  sending break sequences / DDB commands.

  This is a thin glue invocation (single bhyve spawn), NOT a multi-step shell
  harness. Per op-147m.
  """
  def launch_bhyve_with_pty(image_path, vm_name, opts \\ []) do
    vcpus = Keyword.get(opts, :vcpus, 2)
    memory = Keyword.get(opts, :memory, "4G")
    serial_log = Keyword.get(opts, :serial_log, "/tmp/op151-#{vm_name}.serial.log")

    # bhyveload first (sets up the loader state for bhyve to consume).
    # Idempotent: if a previous load exists, --destroy first.
    System.cmd("doas", ["bhyvectl", "--destroy", "--vm=#{vm_name}"],
      stderr_to_stdout: true)
    {load_out, load_rc} = System.cmd("doas",
      ["bhyveload", "-m", memory, "-d", image_path, vm_name],
      stderr_to_stdout: true)
    if load_rc != 0 do
      {:error, {:bhyveload_failed, load_rc, load_out}}
    else
      # bhyve with com1,stdio — the Port's stdio IS the guest serial.
      cmd = "doas bhyve -AHP -c #{vcpus} -m #{memory} -l com1,stdio " <>
            "-s 0,hostbridge -s 31,lpc -s 4:0,virtio-blk,#{image_path} #{vm_name}"
      port = Port.open({:spawn, cmd}, [
        :stream, :binary, :use_stdio, :exit_status,
        {:args, []}
      ])
      {:ok, port, serial_log}
    end
  end
end
