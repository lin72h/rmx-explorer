defmodule Phase08.LaunchctlVerifierCommon do
  @moduledoc """
  Oracle-owned Phase 0.8 launchctl verifier contracts shared by D19-D22.

  This module intentionally owns only the host-verifiable marker/order
  authority migrated so far. It does not run guests, stage artifacts, or read
  source-side verifier scripts at runtime.

  Ordered marker validation deliberately preserves the transitional source
  verifier's first-global-match semantics: if a marker appears multiple times,
  its first occurrence is authoritative. A later duplicate cannot rescue an
  earlier out-of-order occurrence.
  """

  alias Phase08.MarkerManifest

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

  @d20_order_contract [
    %{
      id: :d20_gate_start,
      marker: "phase08_dispatch_launchctl_successful_exit_start",
      producer: :harness,
      role: :gate_start
    },
    %{
      id: :d20_management_request_sent,
      marker: "PHASE08_D20_MANAGEMENT_REQUEST_SENT=1",
      producer: :donor,
      producer_detail: :launchctl_client,
      role: :management_request
    },
    %{
      id: :d20_caller_pid_match,
      marker: "PHASE08_D20_CALLER_PID_MATCH=1",
      producer: :donor,
      producer_detail: :donor_runtime,
      role: :caller_identity
    },
    %{
      id: :d20_runtime_demux,
      marker: "PHASE08_D20_DONOR_RUNTIME_DEMUX_CALLED=1",
      producer: :donor,
      producer_detail: :donor_runtime,
      role: :runtime_demux
    },
    %{
      id: :d20_start_pending,
      marker: "PHASE08_D20_START_PENDING_SET=1",
      producer: :donor,
      producer_detail: :donor_job,
      role: :start_state
    },
    %{
      id: :d20_initial_keepalive_reason,
      marker: "PHASE08_D20_JOB_KEEPALIVE_REASON=start_pending",
      producer: :donor,
      producer_detail: :donor_job,
      role: :keepalive_decision
    },
    %{
      id: :d20_cycle1_start,
      marker: "PHASE08_D20_CYCLE1_JOB_START_CALLED=1",
      producer: :donor,
      producer_detail: :donor_job,
      role: :cycle1_start
    },
    %{
      id: :d20_cycle1_exec_bridge,
      marker: "PHASE08_D20_POSIX_SPAWN_SETEXEC_BRIDGE=direct_exec",
      producer: :donor,
      producer_detail: :donor_exec_bridge,
      role: :exec_bridge
    },
    %{
      id: :d20_cycle1_reap,
      marker: "PHASE08_D20_CYCLE1_REAP_PATH=dispatch_proc_source",
      producer: :donor,
      producer_detail: :donor_proc_source,
      role: :cycle1_reap
    },
    %{
      id: :d20_postreap_keepalive_reason,
      marker: "PHASE08_D20_POSTREAP_KEEPALIVE_REASON=successful_exit",
      producer: :donor,
      producer_detail: :donor_job,
      role: :postreap_keepalive_decision
    },
    %{
      id: :d20_cycle2_start,
      marker: "PHASE08_D20_CYCLE2_JOB_START_CALLED=1",
      producer: :donor,
      producer_detail: :donor_job,
      role: :cycle2_start
    },
    %{
      id: :d20_post_cycle1_keepalive,
      marker: "PHASE08_D20_POST_CYCLE1_KEEPALIVE_REASON=successful_exit",
      producer: :donor,
      producer_detail: :donor_job,
      role: :restart_decision
    },
    %{
      id: :d20_cycle2_reap,
      marker: "PHASE08_D20_CYCLE2_REAP_PATH=dispatch_proc_source",
      producer: :donor,
      producer_detail: :donor_proc_source,
      role: :cycle2_reap
    },
    %{
      id: :d20_post_cycle2_keepalive,
      marker: "PHASE08_D20_POST_CYCLE2_KEEPALIVE_REASON=successful_exit_mismatch",
      producer: :donor,
      producer_detail: :donor_job,
      role: :restart_suppression
    },
    %{
      id: :d20_confirmed,
      marker: "PHASE08_D20_CONDITIONAL_KEEPALIVE_CONFIRMED=1",
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

  @d20_downstream_consumers [
    %{
      id: :d20,
      gate: "D20 SuccessfulExit",
      order_ref: :d20_successful_exit_order,
      positive_fixture: "test/fixtures/phase08/launchctl/d20_successful_exit.accepted.serial.log"
    },
    %{id: :d21, gate: "D21 inert RemoveJob", order_ref: :d20_successful_exit_order},
    %{
      id: :d22,
      gate: "D22 running RemoveJob / KeepAlive remove",
      order_ref: :d20_successful_exit_order
    }
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

  @d20_not_applicable_consumers [
    %{
      id: :d23,
      gate: "D23 same-label reload",
      status: :not_applicable,
      reason:
        "D23 is audited as not a direct D20 order consumer in this migration slice; full D23 marker/name-value migration is deferred"
    }
  ]

  @d21_marker_ids [
    :d21_gate_start,
    :d21_load_confirmed,
    :d21_inert_load_confirmed,
    :d21_removejob_seen,
    :d21_remove_target_label_match,
    :d21_remove_handler_called,
    :d21_job_found_before_remove,
    :d21_job_active_at_remove,
    :d21_job_pid_at_remove,
    :d21_inert_remove_branch,
    :d21_job_detached_from_jobmgr,
    :d21_job_removed_from_label_table,
    :d21_label_count_after_detach,
    :d21_mach_service_removed_or_none,
    :d21_proc_source_torn_down_or_none,
    :d21_remove_handler_enter_count,
    :d21_job_removing_recorded,
    :d21_job_detached_recorded,
    :d21_job_freeing_recorded,
    :d21_job_find_after_remove,
    :d21_label_count_after_remove,
    :d21_job_table_count_delta_ok,
    :d21_job_struct_no_leak,
    :d21_job_removed_from_table,
    :d21_start_count_final,
    :d21_proc_source_event_count_total,
    :d21_reap_count_total,
    :d21_no_restart_after_remove,
    :d21_confirmed
  ]

  @d19_required_tail_markers [
    "PHASE08_D19_CYCLE2_PROC_SOURCE_CANCELLED=1",
    "PHASE08_D19_STOP_AFTER_CYCLE2_ARMED=1",
    "PHASE08_D19_STOP_RESTART_SUPPRESSED=harness_cycle_limit",
    "PHASE08_D19_KEEPALIVE_RESTART_CONFIRMED=1"
  ]

  @d20_required_tail_markers [
    "PHASE08_D20_NO_THIRD_START=1"
  ]

  @terminal_markers [
    "phase08_dispatch_launchctl_plist_exit=0",
    "=== phase1 launchd harness end rc=0 ==="
  ]

  @ordering_checkpoint %{
    decision: :option_b_helper_owns_ordering,
    manifest_must_precede: :not_implemented,
    reason:
      "D19/D20 ordering stays in the Oracle helper until the D19-D23 marker name/value migration is complete and generator ownership is collapsed.",
    revisit_when: [
      "D20-D23 marker names and values are fully manifest-backed",
      "source-side shell/AWK/C marker generators are retired or represented by Zig/Elixir-owned generation",
      "parent approves manifest must_precede/must_follow schema"
    ]
  }

  @d22_d23_reconciliation_audit [
    %{
      item: :d22_inherits_d19_order,
      status: :pass,
      evidence: :d19_downstream_consumers
    },
    %{
      item: :d22_inherits_d20_order,
      status: :pass,
      evidence: :d20_downstream_consumers
    },
    %{
      item: :d23_inherits_d19_order,
      status: :not_applicable,
      reason: "D23 remains not a direct D19 inherited-order consumer in this chunk."
    },
    %{
      item: :d23_inherits_d20_order,
      status: :not_applicable,
      reason:
        "D23 full marker/order migration is deferred; no direct D20 order consumer is claimed."
    },
    %{
      item: :d22_d23_producer_attribution,
      status: :pass,
      reason: "D22/D23 manifest producer values are constrained to :donor or :harness."
    },
    %{
      item: :d22_d23_producer_detail_role,
      status: :deferred,
      trigger: "full D22/D23 marker/name-value migration",
      reason:
        "D22/D23 entries currently carry producer attribution, but producer_detail and role normalization are deferred until the D22/D23 manifest migration."
    },
    %{
      item: :multi_arm_isolation,
      status: :deferred,
      reason:
        "D22/D23 arm-specific manifest entries exist, but full D22/D23 positive fixture migration is deferred."
    },
    %{
      item: :manifest_ordering_primitives,
      status: :deferred,
      reason:
        "Option B keeps ordering in the helper; no must_precede/must_follow schema in this pass."
    }
  ]

  def source_reference, do: @source_reference
  def d19_order_contract, do: @d19_order_contract
  def d19_order_markers, do: Enum.map(@d19_order_contract, & &1.marker)
  def d19_downstream_consumers, do: @d19_downstream_consumers
  def d19_not_applicable_consumers, do: @d19_not_applicable_consumers
  def d20_order_contract, do: @d20_order_contract
  def d20_order_markers, do: Enum.map(@d20_order_contract, & &1.marker)
  def d20_downstream_consumers, do: @d20_downstream_consumers
  def d20_not_applicable_consumers, do: @d20_not_applicable_consumers
  def d21_marker_ids, do: @d21_marker_ids
  def terminal_markers, do: @terminal_markers
  def ordering_checkpoint, do: @ordering_checkpoint
  def d22_d23_reconciliation_audit, do: @d22_d23_reconciliation_audit

  def required_tail_marker_declarations do
    [
      %{
        gate: :d19,
        marker: "PHASE08_D19_CYCLE2_PROC_SOURCE_CANCELLED=1",
        backing: :tail_only,
        reason:
          "D19 proc-source cancellation is a finalization tail marker; ordering remains in the helper but this marker is not part of the D19 ordered source contract."
      },
      %{
        gate: :d19,
        id: :d19_cycle2_limit_armed,
        marker: "PHASE08_D19_STOP_AFTER_CYCLE2_ARMED=1",
        backing: :order_and_manifest
      },
      %{
        gate: :d19,
        id: :d19_restart_suppressed,
        marker: "PHASE08_D19_STOP_RESTART_SUPPRESSED=harness_cycle_limit",
        backing: :order_and_manifest
      },
      %{
        gate: :d19,
        id: :d19_confirmed,
        marker: "PHASE08_D19_KEEPALIVE_RESTART_CONFIRMED=1",
        backing: :order_and_manifest
      },
      %{
        gate: :d20,
        id: :d20_confirmed,
        marker: "PHASE08_D20_CONDITIONAL_KEEPALIVE_CONFIRMED=1",
        backing: :order_and_manifest
      },
      %{
        gate: :d20,
        id: :d20_no_third_start,
        marker: "PHASE08_D20_NO_THIRD_START=1",
        backing: :manifest
      },
      %{gate: :d21, ids: @d21_marker_ids, backing: :manifest},
      %{
        gate: :all,
        marker: "phase08_dispatch_launchctl_plist_exit=0",
        backing: :tail_only,
        reason: "harness terminal status marker"
      },
      %{
        gate: :all,
        marker: "=== phase1 launchd harness end rc=0 ===",
        backing: :tail_only,
        reason: "host runner terminal status marker"
      }
    ]
  end

  def d19_order_hash, do: hash_markers(d19_order_markers())
  def d20_order_hash, do: hash_markers(d20_order_markers())

  def required_tail_markers(:d19), do: @d19_required_tail_markers
  def required_tail_markers(:d20), do: @d20_required_tail_markers
  def required_tail_markers(:d21), do: d21_marker_literals()

  def d21_marker_literals do
    Enum.map(@d21_marker_ids, &marker_literal!/1)
  end

  def validate_d19(serial), do: validate_consumer(serial, :d19)
  def validate_d20(serial), do: validate_consumer(serial, :d20)
  def validate_d21(serial), do: validate_consumer(serial, :d21)

  def validate_d19!(serial), do: raise_unless_ok(validate_d19(serial))
  def validate_d20!(serial), do: raise_unless_ok(validate_d20(serial))
  def validate_d21!(serial), do: raise_unless_ok(validate_d21(serial))

  def validate_consumer(serial, :d19) do
    with :ok <- require_d19_order(serial, :d19),
         :ok <- require_markers(serial, required_tail_markers(:d19), :d19),
         :ok <- require_terminal_markers(serial, :d19) do
      :ok
    end
  end

  def validate_consumer(serial, :d20) do
    with :ok <- require_d19_order(serial, :d20),
         :ok <- require_d20_order(serial, :d20),
         :ok <- require_markers(serial, required_tail_markers(:d20), :d20),
         :ok <- require_terminal_markers(serial, :d20) do
      :ok
    end
  end

  def validate_consumer(serial, :d21) do
    with :ok <- require_d19_order(serial, :d21),
         :ok <- require_d20_order(serial, :d21),
         :ok <- require_markers(serial, d21_marker_literals(), :d21),
         :ok <- require_terminal_markers(serial, :d21) do
      :ok
    end
  end

  def validate_consumer(serial, :d22) do
    with :ok <- require_d19_order(serial, :d22),
         :ok <- require_d20_order(serial, :d22) do
      :ok
    end
  end

  def validate_inherited_d19_order(serial, consumer)
      when consumer in [:d20, :d21, :d22] do
    require_d19_order(serial, consumer)
  end

  def validate_inherited_d20_order(serial, consumer)
      when consumer in [:d21, :d22] do
    require_d20_order(serial, consumer)
  end

  defp require_d19_order(serial, consumer),
    do: require_order(serial, d19_order_markers(), consumer)

  defp require_d20_order(serial, consumer),
    do: require_order(serial, d20_order_markers(), consumer)

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

  defp marker_literal!(id), do: MarkerManifest.marker_literal(MarkerManifest.spec!(id))

  defp hash_markers(markers) do
    :sha256
    |> :crypto.hash(Enum.join(markers, "\n"))
    |> Base.encode16(case: :lower)
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
