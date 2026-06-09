defmodule Phase08.LaunchctlVerifierCommon do
  @moduledoc """
  Oracle-owned Phase 0.8 launchctl verifier contracts shared by D19-D22.

  This module intentionally owns only the host-verifiable marker/order
  authority migrated in this chunk. It does not run guests, stage artifacts, or
  read source-side verifier scripts at runtime.

  Ordered marker validation deliberately preserves the transitional source
  verifier's first-global-match semantics: if a marker appears multiple times,
  its first occurrence is authoritative. A later duplicate cannot rescue an
  earlier out-of-order occurrence.
  """

  defmodule ValidationError do
    @moduledoc false

    defexception [:consumer, :reason, :marker, :message]
  end

  @source_reference %{
    source_repo: "/Users/me/wip-mach/wip-gpt",
    commit: "089311cff65bf116323a1e2e2d5ccf602432a22c",
    short_commit: "089311cff65b",
    path: "scripts/launchd/phase08_launchctl_verifier_common.exs",
    status: :transitional_reference
  }

  @d19_order_contract [
    %{
      id: :d19_gate_start,
      marker: "phase08_dispatch_launchctl_keepalive_restart_start",
      producer: :harness,
      role: :gate_start
    },
    %{
      id: :d19_management_request_sent,
      marker: "PHASE08_D19_MANAGEMENT_REQUEST_SENT=1",
      producer: :donor,
      producer_detail: :launchctl_client,
      role: :management_request
    },
    %{
      id: :d19_caller_pid_match,
      marker: "PHASE08_D19_CALLER_PID_MATCH=1",
      producer: :donor,
      producer_detail: :donor_runtime,
      role: :caller_identity
    },
    %{
      id: :d19_runtime_demux,
      marker: "PHASE08_D19_DONOR_RUNTIME_DEMUX_CALLED=1",
      producer: :donor,
      producer_detail: :donor_runtime,
      role: :runtime_demux
    },
    %{
      id: :d19_start_pending,
      marker: "PHASE08_D19_START_PENDING_SET=1",
      producer: :donor,
      producer_detail: :donor_job,
      role: :start_state
    },
    %{
      id: :d19_initial_keepalive_reason,
      marker: "PHASE08_D19_JOB_KEEPALIVE_REASON=start_pending",
      producer: :donor,
      producer_detail: :donor_job,
      role: :keepalive_decision
    },
    %{
      id: :d19_cycle1_start,
      marker: "PHASE08_D19_CYCLE1_JOB_START_CALLED=1",
      producer: :donor,
      producer_detail: :donor_job,
      role: :cycle1_start
    },
    %{
      id: :d19_cycle1_exec_bridge,
      marker: "PHASE08_D19_POSIX_SPAWN_SETEXEC_BRIDGE=direct_exec",
      producer: :donor,
      producer_detail: :donor_exec_bridge,
      role: :exec_bridge
    },
    %{
      id: :d19_cycle1_reap,
      marker: "PHASE08_D19_CYCLE1_REAP_PATH=dispatch_proc_source",
      producer: :donor,
      producer_detail: :donor_proc_source,
      role: :cycle1_reap
    },
    %{
      id: :d19_cycle2_start,
      marker: "PHASE08_D19_CYCLE2_JOB_START_CALLED=1",
      producer: :donor,
      producer_detail: :donor_job,
      role: :cycle2_start
    },
    %{
      id: :d19_post_cycle1_keepalive,
      marker: "PHASE08_D19_POST_CYCLE1_KEEPALIVE_REASON=keepalive",
      producer: :donor,
      producer_detail: :donor_job,
      role: :restart_decision
    },
    %{
      id: :d19_cycle2_limit_armed,
      marker: "PHASE08_D19_STOP_AFTER_CYCLE2_ARMED=1",
      producer: :donor,
      producer_detail: :donor_job,
      role: :harness_cycle_limit
    },
    %{
      id: :d19_cycle2_reap,
      marker: "PHASE08_D19_CYCLE2_REAP_PATH=dispatch_proc_source",
      producer: :donor,
      producer_detail: :donor_proc_source,
      role: :cycle2_reap
    },
    %{
      id: :d19_restart_suppressed,
      marker: "PHASE08_D19_STOP_RESTART_SUPPRESSED=harness_cycle_limit",
      producer: :donor,
      producer_detail: :donor_job,
      role: :restart_suppression
    },
    %{
      id: :d19_confirmed,
      marker: "PHASE08_D19_KEEPALIVE_RESTART_CONFIRMED=1",
      producer: :donor,
      producer_detail: :donor_job,
      role: :gate_confirmation
    }
  ]

  @d19_downstream_consumers [
    %{
      id: :d19,
      gate: "D19 KeepAlive restart",
      order_ref: :d19_shared_order,
      positive_fixture:
        "test/fixtures/phase08/launchctl/d19_keepalive_restart.accepted.serial.log"
    },
    %{
      id: :d20,
      gate: "D20 SuccessfulExit",
      order_ref: :d19_shared_order,
      positive_fixture: "test/fixtures/phase08/launchctl/d20_successful_exit.accepted.serial.log"
    },
    %{id: :d21, gate: "D21 inert RemoveJob", order_ref: :d19_shared_order},
    %{id: :d22, gate: "D22 running RemoveJob / KeepAlive remove", order_ref: :d19_shared_order}
  ]

  @d19_not_applicable_consumers [
    %{
      id: :d23,
      gate: "D23 same-label reload",
      status: :not_applicable,
      reason:
        "source commit 089311cff65b wires the shared D19 order helper into D19-D22 only; D23 delegates through D22 and is not a direct D19 order consumer in this migration slice"
    }
  ]

  @d19_required_tail_markers [
    "PHASE08_D19_CYCLE2_PROC_SOURCE_CANCELLED=1",
    "PHASE08_D19_STOP_AFTER_CYCLE2_ARMED=1",
    "PHASE08_D19_STOP_RESTART_SUPPRESSED=harness_cycle_limit",
    "PHASE08_D19_KEEPALIVE_RESTART_CONFIRMED=1"
  ]

  @d20_required_tail_markers [
    "PHASE08_D20_NO_THIRD_START=1",
    "PHASE08_D20_CONDITIONAL_KEEPALIVE_CONFIRMED=1"
  ]

  @terminal_markers [
    "phase08_dispatch_launchctl_plist_exit=0",
    "=== phase1 launchd harness end rc=0 ==="
  ]

  def source_reference, do: @source_reference
  def d19_order_contract, do: @d19_order_contract
  def d19_order_markers, do: Enum.map(@d19_order_contract, & &1.marker)
  def d19_downstream_consumers, do: @d19_downstream_consumers
  def d19_not_applicable_consumers, do: @d19_not_applicable_consumers
  def terminal_markers, do: @terminal_markers

  def d19_order_hash do
    :sha256
    |> :crypto.hash(Enum.join(d19_order_markers(), "\n"))
    |> Base.encode16(case: :lower)
  end

  def validate_d19(serial), do: validate_consumer(serial, :d19)
  def validate_d20(serial), do: validate_consumer(serial, :d20)

  def validate_d19!(serial), do: raise_unless_ok(validate_d19(serial))
  def validate_d20!(serial), do: raise_unless_ok(validate_d20(serial))

  def validate_consumer(serial, consumer) when consumer in [:d19, :d20] do
    with :ok <- require_d19_order(serial, consumer),
         :ok <- require_markers(serial, required_tail_markers(consumer), consumer),
         :ok <- require_terminal_markers(serial, consumer) do
      :ok
    end
  end

  def validate_consumer(serial, consumer) when consumer in [:d21, :d22] do
    validate_inherited_d19_order(serial, consumer)
  end

  def validate_inherited_d19_order(serial, consumer)
      when consumer in [:d20, :d21, :d22] do
    require_d19_order(serial, consumer)
  end

  defp required_tail_markers(:d19), do: @d19_required_tail_markers
  defp required_tail_markers(:d20), do: @d20_required_tail_markers

  defp require_d19_order(serial, consumer),
    do: require_order(serial, d19_order_markers(), consumer)

  defp require_order(serial, markers, consumer) do
    case find_order(serial, markers) do
      {:ok, _positions} -> :ok
      {:error, reason, marker} -> validation_error(consumer, reason, marker)
    end
  end

  defp require_markers(serial, markers, consumer) do
    case Enum.find(markers, &(not String.contains?(serial, &1))) do
      nil -> :ok
      marker -> validation_error(consumer, :missing_marker, marker)
    end
  end

  defp require_terminal_markers(serial, consumer) do
    case Enum.find(@terminal_markers, &(not String.contains?(serial, &1))) do
      nil -> :ok
      marker -> validation_error(consumer, :incomplete_serial, marker)
    end
  end

  defp find_order(serial, markers) do
    Enum.reduce_while(markers, {:ok, -1, []}, fn marker, {:ok, last_idx, positions} ->
      case :binary.match(serial, marker) do
        {idx, _length} when idx > last_idx ->
          {:cont, {:ok, idx, [{marker, idx} | positions]}}

        {idx, _length} when idx <= last_idx ->
          {:halt, {:error, :out_of_order_marker, marker}}

        :nomatch ->
          {:halt, {:error, :missing_marker, marker}}
      end
    end)
    |> case do
      {:ok, _last_idx, positions} -> {:ok, Enum.reverse(positions)}
      error -> error
    end
  end

  defp validation_error(consumer, reason, marker) do
    {:error,
     %ValidationError{
       consumer: consumer,
       reason: reason,
       marker: marker,
       message: "#{consumer} #{reason}: #{marker}"
     }}
  end

  defp raise_unless_ok(:ok), do: :ok

  defp raise_unless_ok({:error, error}) do
    raise error
  end
end
