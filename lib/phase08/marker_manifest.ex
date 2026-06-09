defmodule Phase08.MarkerManifest do
  @moduledoc false

  @d22_running_label "org.rmxos.phase08.d22.running-remove"
  @d22_keepalive_label "org.rmxos.phase08.d22.keepalive-remove"
  @d23_inert_label "org.rmxos.phase08.d23.inert-reload"
  @d23_keepalive_label "org.rmxos.phase08.d23.keepalive-reload"

  @d19_shared_order_markers [
    %{
      id: :d19_gate_start,
      key: "phase08_dispatch_launchctl_keepalive_restart_start",
      gate: :d19,
      arm: nil,
      type: :presence,
      policy: :must_be_present,
      producer: :harness,
      role: :gate_start,
      claim: "D19 KeepAlive restart gate started."
    },
    %{
      id: :d19_management_request_sent,
      key: "PHASE08_D19_MANAGEMENT_REQUEST_SENT",
      gate: :d19,
      arm: nil,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :launchctl_client,
      role: :management_request,
      claim: "D19 launchctl client sent the management request."
    },
    %{
      id: :d19_caller_pid_match,
      key: "PHASE08_D19_CALLER_PID_MATCH",
      gate: :d19,
      arm: nil,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_runtime,
      role: :caller_identity,
      claim: "D19 caller PID matched the expected management client PID."
    },
    %{
      id: :d19_runtime_demux,
      key: "PHASE08_D19_DONOR_RUNTIME_DEMUX_CALLED",
      gate: :d19,
      arm: nil,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_runtime,
      role: :runtime_demux,
      claim: "D19 donor runtime demux handled the management request."
    },
    %{
      id: :d19_start_pending,
      key: "PHASE08_D19_START_PENDING_SET",
      gate: :d19,
      arm: nil,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_job,
      role: :start_state,
      claim: "D19 start_pending was set before the initial start."
    },
    %{
      id: :d19_initial_keepalive_reason,
      key: "PHASE08_D19_JOB_KEEPALIVE_REASON",
      gate: :d19,
      arm: nil,
      type: :enum,
      policy: {:must_equal, "start_pending"},
      producer: :donor,
      producer_detail: :donor_job,
      role: :keepalive_decision,
      claim: "D19 initial keepalive reason was start_pending."
    },
    %{
      id: :d19_cycle1_start,
      key: "PHASE08_D19_CYCLE1_JOB_START_CALLED",
      gate: :d19,
      arm: :cycle1,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_job,
      role: :cycle1_start,
      claim: "D19 cycle 1 started through the donor job path."
    },
    %{
      id: :d19_cycle1_exec_bridge,
      key: "PHASE08_D19_POSIX_SPAWN_SETEXEC_BRIDGE",
      gate: :d19,
      arm: :cycle1,
      type: :enum,
      policy: {:must_equal, "direct_exec"},
      producer: :donor,
      producer_detail: :donor_exec_bridge,
      role: :exec_bridge,
      claim: "D19 cycle 1 used the direct exec bridge."
    },
    %{
      id: :d19_cycle1_reap,
      key: "PHASE08_D19_CYCLE1_REAP_PATH",
      gate: :d19,
      arm: :cycle1,
      type: :enum,
      policy: {:must_equal, "dispatch_proc_source"},
      producer: :donor,
      producer_detail: :donor_proc_source,
      role: :cycle1_reap,
      claim: "D19 cycle 1 reaped through the dispatch proc-source path."
    },
    %{
      id: :d19_cycle2_start,
      key: "PHASE08_D19_CYCLE2_JOB_START_CALLED",
      gate: :d19,
      arm: :cycle2,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_job,
      role: :cycle2_start,
      claim: "D19 cycle 2 started through the donor job path."
    },
    %{
      id: :d19_post_cycle1_keepalive,
      key: "PHASE08_D19_POST_CYCLE1_KEEPALIVE_REASON",
      gate: :d19,
      arm: :cycle1,
      type: :enum,
      policy: {:must_equal, "keepalive"},
      producer: :donor,
      producer_detail: :donor_job,
      role: :restart_decision,
      claim: "D19 post-cycle1 keepalive decision requested a restart."
    },
    %{
      id: :d19_cycle2_limit_armed,
      key: "PHASE08_D19_STOP_AFTER_CYCLE2_ARMED",
      gate: :d19,
      arm: :cycle2,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_job,
      role: :harness_cycle_limit,
      claim: "D19 armed the harness cycle limit before cycle 2 completion."
    },
    %{
      id: :d19_cycle2_reap,
      key: "PHASE08_D19_CYCLE2_REAP_PATH",
      gate: :d19,
      arm: :cycle2,
      type: :enum,
      policy: {:must_equal, "dispatch_proc_source"},
      producer: :donor,
      producer_detail: :donor_proc_source,
      role: :cycle2_reap,
      claim: "D19 cycle 2 reaped through the dispatch proc-source path."
    },
    %{
      id: :d19_restart_suppressed,
      key: "PHASE08_D19_STOP_RESTART_SUPPRESSED",
      gate: :d19,
      arm: :cycle2,
      type: :enum,
      policy: {:must_equal, "harness_cycle_limit"},
      producer: :donor,
      producer_detail: :donor_job,
      role: :restart_suppression,
      claim: "D19 suppressed the third restart because the harness cycle limit was reached."
    },
    %{
      id: :d19_confirmed,
      key: "PHASE08_D19_KEEPALIVE_RESTART_CONFIRMED",
      gate: :d19,
      arm: nil,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_job,
      role: :gate_confirmation,
      claim: "D19 KeepAlive restart behavior was confirmed."
    }
  ]

  @d20_order_and_tail_markers [
    %{
      id: :d20_gate_start,
      key: "phase08_dispatch_launchctl_successful_exit_start",
      gate: :d20,
      arm: nil,
      type: :presence,
      policy: :must_be_present,
      producer: :harness,
      role: :gate_start,
      claim: "D20 SuccessfulExit gate started."
    },
    %{
      id: :d20_management_request_sent,
      key: "PHASE08_D20_MANAGEMENT_REQUEST_SENT",
      gate: :d20,
      arm: nil,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :launchctl_client,
      role: :management_request,
      claim: "D20 launchctl client sent the management request."
    },
    %{
      id: :d20_caller_pid_match,
      key: "PHASE08_D20_CALLER_PID_MATCH",
      gate: :d20,
      arm: nil,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_runtime,
      role: :caller_identity,
      claim: "D20 caller PID matched the expected management client PID."
    },
    %{
      id: :d20_runtime_demux,
      key: "PHASE08_D20_DONOR_RUNTIME_DEMUX_CALLED",
      gate: :d20,
      arm: nil,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_runtime,
      role: :runtime_demux,
      claim: "D20 donor runtime demux handled the management request."
    },
    %{
      id: :d20_start_pending,
      key: "PHASE08_D20_START_PENDING_SET",
      gate: :d20,
      arm: nil,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_job,
      role: :start_state,
      claim: "D20 start_pending was set before the initial start."
    },
    %{
      id: :d20_initial_keepalive_reason,
      key: "PHASE08_D20_JOB_KEEPALIVE_REASON",
      gate: :d20,
      arm: nil,
      type: :enum,
      policy: {:must_equal, "start_pending"},
      producer: :donor,
      producer_detail: :donor_job,
      role: :keepalive_decision,
      claim: "D20 initial keepalive reason was start_pending."
    },
    %{
      id: :d20_cycle1_start,
      key: "PHASE08_D20_CYCLE1_JOB_START_CALLED",
      gate: :d20,
      arm: :cycle1,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_job,
      role: :cycle1_start,
      claim: "D20 cycle 1 started through the donor job path."
    },
    %{
      id: :d20_cycle1_exec_bridge,
      key: "PHASE08_D20_POSIX_SPAWN_SETEXEC_BRIDGE",
      gate: :d20,
      arm: :cycle1,
      type: :enum,
      policy: {:must_equal, "direct_exec"},
      producer: :donor,
      producer_detail: :donor_exec_bridge,
      role: :exec_bridge,
      claim: "D20 cycle 1 used the direct exec bridge."
    },
    %{
      id: :d20_cycle1_reap,
      key: "PHASE08_D20_CYCLE1_REAP_PATH",
      gate: :d20,
      arm: :cycle1,
      type: :enum,
      policy: {:must_equal, "dispatch_proc_source"},
      producer: :donor,
      producer_detail: :donor_proc_source,
      role: :cycle1_reap,
      claim: "D20 cycle 1 reaped through the dispatch proc-source path."
    },
    %{
      id: :d20_postreap_keepalive_reason,
      key: "PHASE08_D20_POSTREAP_KEEPALIVE_REASON",
      gate: :d20,
      arm: :cycle1,
      type: :enum,
      policy: {:must_include, "successful_exit"},
      producer: :donor,
      producer_detail: :donor_job,
      role: :postreap_keepalive_decision,
      claim: "D20 postreap keepalive reason after cycle 1 was SuccessfulExit."
    },
    %{
      id: :d20_cycle2_start,
      key: "PHASE08_D20_CYCLE2_JOB_START_CALLED",
      gate: :d20,
      arm: :cycle2,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_job,
      role: :cycle2_start,
      claim: "D20 cycle 2 started through the donor job path."
    },
    %{
      id: :d20_post_cycle1_keepalive,
      key: "PHASE08_D20_POST_CYCLE1_KEEPALIVE_REASON",
      gate: :d20,
      arm: :cycle1,
      type: :enum,
      policy: {:must_equal, "successful_exit"},
      producer: :donor,
      producer_detail: :donor_job,
      role: :restart_decision,
      claim: "D20 post-cycle1 keepalive decision requested a restart."
    },
    %{
      id: :d20_cycle2_reap,
      key: "PHASE08_D20_CYCLE2_REAP_PATH",
      gate: :d20,
      arm: :cycle2,
      type: :enum,
      policy: {:must_equal, "dispatch_proc_source"},
      producer: :donor,
      producer_detail: :donor_proc_source,
      role: :cycle2_reap,
      claim: "D20 cycle 2 reaped through the dispatch proc-source path."
    },
    %{
      id: :d20_post_cycle2_keepalive,
      key: "PHASE08_D20_POST_CYCLE2_KEEPALIVE_REASON",
      gate: :d20,
      arm: :cycle2,
      type: :enum,
      policy: {:must_equal, "successful_exit_mismatch"},
      producer: :donor,
      producer_detail: :donor_job,
      role: :restart_suppression,
      claim: "D20 post-cycle2 keepalive reason suppressed the third start."
    },
    %{
      id: :d20_confirmed,
      key: "PHASE08_D20_CONDITIONAL_KEEPALIVE_CONFIRMED",
      gate: :d20,
      arm: nil,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_job,
      role: :gate_confirmation,
      claim: "D20 SuccessfulExit conditional KeepAlive behavior was confirmed."
    },
    %{
      id: :d20_no_third_start,
      key: "PHASE08_D20_NO_THIRD_START",
      gate: :d20,
      arm: nil,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_job,
      role: :tail_no_third_start,
      claim: "D20 did not launch a third cycle after the failed second exit."
    }
  ]

  @d21_remove_markers [
    %{
      id: :d21_gate_start,
      key: "phase08_dispatch_launchctl_remove_start",
      gate: :d21,
      arm: nil,
      type: :presence,
      policy: :must_be_present,
      producer: :harness,
      role: :gate_start,
      claim: "D21 inert RemoveJob gate started."
    },
    %{
      id: :d21_load_confirmed,
      key: "PHASE08_D21_LOAD_CONFIRMED",
      gate: :d21,
      arm: :load,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_load,
      role: :load_confirmation,
      claim: "D21 inert job was loaded before RemoveJob."
    },
    %{
      id: :d21_inert_load_confirmed,
      key: "PHASE08_D21_INERT_LOAD_CONFIRMED",
      gate: :d21,
      arm: :load,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_job,
      role: :inert_load_confirmation,
      claim: "D21 load left the job inert."
    },
    %{
      id: :d21_removejob_seen,
      key: "PHASE08_D21_REMOVEJOB_SEEN",
      gate: :d21,
      arm: :remove,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_runtime,
      role: :removejob_seen,
      claim: "D21 donor runtime saw the RemoveJob request."
    },
    %{
      id: :d21_remove_target_label_match,
      key: "PHASE08_D21_REMOVE_TARGET_LABEL_MATCH",
      gate: :d21,
      arm: :remove,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_runtime,
      role: :remove_target,
      claim: "D21 RemoveJob target label matched the inert job."
    },
    %{
      id: :d21_remove_handler_called,
      key: "PHASE08_D21_REMOVE_HANDLER_CALLED",
      gate: :d21,
      arm: :remove,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_job_remove,
      role: :remove_handler,
      claim: "D21 donor job_remove handler ran."
    },
    %{
      id: :d21_job_found_before_remove,
      key: "PHASE08_D21_JOB_FOUND_BEFORE_REMOVE",
      gate: :d21,
      arm: :remove,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_job_remove,
      role: :pre_remove_state,
      claim: "D21 donor job existed before RemoveJob."
    },
    %{
      id: :d21_job_active_at_remove,
      key: "PHASE08_D21_JOB_ACTIVE_AT_REMOVE",
      gate: :d21,
      arm: :remove,
      type: :bool_int,
      policy: {:must_equal, "0"},
      producer: :donor,
      producer_detail: :donor_job_remove,
      role: :pre_remove_state,
      claim: "D21 donor job was inactive at RemoveJob."
    },
    %{
      id: :d21_job_pid_at_remove,
      key: "PHASE08_D21_JOB_PID_AT_REMOVE",
      gate: :d21,
      arm: :remove,
      type: :pid,
      policy: {:must_equal, "0"},
      producer: :donor,
      producer_detail: :donor_job_remove,
      role: :pre_remove_state,
      claim: "D21 donor job had no process at RemoveJob."
    },
    %{
      id: :d21_inert_remove_branch,
      key: "PHASE08_D21_INERT_REMOVE_BRANCH",
      gate: :d21,
      arm: :remove,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_job_remove,
      role: :inert_remove_branch,
      claim: "D21 remove used the inert branch."
    },
    %{
      id: :d21_job_detached_from_jobmgr,
      key: "PHASE08_D21_JOB_DETACHED_FROM_JOBMGR",
      gate: :d21,
      arm: :remove,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_job_remove,
      role: :detach,
      claim: "D21 job was detached from the job manager."
    },
    %{
      id: :d21_job_removed_from_label_table,
      key: "PHASE08_D21_JOB_REMOVED_FROM_LABEL_TABLE",
      gate: :d21,
      arm: :remove,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_job_remove,
      role: :detach,
      claim: "D21 job was removed from the label table."
    },
    %{
      id: :d21_label_count_after_detach,
      key: "PHASE08_D21_LABEL_COUNT_AFTER_DETACH",
      gate: :d21,
      arm: :remove,
      type: :count,
      policy: {:must_equal, "0"},
      producer: :donor,
      producer_detail: :donor_job_remove,
      role: :detach,
      claim: "D21 label table was empty after detach."
    },
    %{
      id: :d21_mach_service_removed_or_none,
      key: "PHASE08_D21_MACH_SERVICE_REMOVED_OR_NONE",
      gate: :d21,
      arm: :remove,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_job_remove,
      role: :resource_cleanup,
      claim: "D21 had no Mach service leak after remove."
    },
    %{
      id: :d21_proc_source_torn_down_or_none,
      key: "PHASE08_D21_JOB_PROC_SOURCE_TORN_DOWN_OR_NONE",
      gate: :d21,
      arm: :remove,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_job_remove,
      role: :resource_cleanup,
      claim: "D21 had no proc-source leak after remove."
    },
    %{
      id: :d21_remove_handler_enter_count,
      key: "PHASE08_D21_REMOVE_HANDLER_ENTER_COUNT",
      gate: :d21,
      arm: :remove,
      type: :count,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_job_remove,
      role: :remove_handler,
      claim: "D21 remove handler entered exactly once."
    },
    %{
      id: :d21_job_removing_recorded,
      key: "PHASE08_D21_JOB_REMOVING_RECORDED",
      gate: :d21,
      arm: :remove,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_job_remove,
      role: :remove_state_record,
      claim: "D21 recorded job removing state."
    },
    %{
      id: :d21_job_detached_recorded,
      key: "PHASE08_D21_JOB_DETACHED_RECORDED",
      gate: :d21,
      arm: :remove,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_job_remove,
      role: :remove_state_record,
      claim: "D21 recorded job detached state."
    },
    %{
      id: :d21_job_freeing_recorded,
      key: "PHASE08_D21_JOB_FREEING_RECORDED",
      gate: :d21,
      arm: :remove,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_job_remove,
      role: :remove_state_record,
      claim: "D21 recorded job freeing state."
    },
    %{
      id: :d21_job_find_after_remove,
      key: "PHASE08_D21_JOB_FIND_AFTER_REMOVE",
      gate: :d21,
      arm: :remove,
      type: :bool_int,
      policy: {:must_equal, "0"},
      producer: :donor,
      producer_detail: :donor_job_remove,
      role: :post_remove_state,
      claim: "D21 job lookup missed after remove."
    },
    %{
      id: :d21_label_count_after_remove,
      key: "PHASE08_D21_LABEL_COUNT_AFTER_REMOVE",
      gate: :d21,
      arm: :remove,
      type: :count,
      policy: {:must_equal, "0"},
      producer: :donor,
      producer_detail: :donor_job_remove,
      role: :post_remove_state,
      claim: "D21 label count was zero after remove."
    },
    %{
      id: :d21_job_table_count_delta_ok,
      key: "PHASE08_D21_DONOR_JOB_TABLE_COUNT_DELTA_OK",
      gate: :d21,
      arm: :remove,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_job_remove,
      role: :post_remove_state,
      claim: "D21 donor job table count decreased by one."
    },
    %{
      id: :d21_job_struct_no_leak,
      key: "PHASE08_D21_JOB_STRUCT_NO_LEAK",
      gate: :d21,
      arm: :remove,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_job_remove,
      role: :post_remove_state,
      claim: "D21 job struct was not leaked."
    },
    %{
      id: :d21_job_removed_from_table,
      key: "PHASE08_D21_JOB_REMOVED_FROM_TABLE",
      gate: :d21,
      arm: :remove,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_job_remove,
      role: :post_remove_state,
      claim: "D21 job was removed from donor job tables."
    },
    %{
      id: :d21_start_count_final,
      key: "PHASE08_D21_START_COUNT_FINAL",
      gate: :d21,
      arm: :remove,
      type: :count,
      policy: {:must_equal, "0"},
      producer: :donor,
      producer_detail: :donor_job_remove,
      role: :post_remove_state,
      claim: "D21 never started the inert job."
    },
    %{
      id: :d21_proc_source_event_count_total,
      key: "PHASE08_D21_PROC_SOURCE_EVENT_COUNT_TOTAL",
      gate: :d21,
      arm: :remove,
      type: :count,
      policy: {:must_equal, "0"},
      producer: :donor,
      producer_detail: :donor_job_remove,
      role: :post_remove_state,
      claim: "D21 observed no proc-source events."
    },
    %{
      id: :d21_reap_count_total,
      key: "PHASE08_D21_REAP_COUNT_TOTAL",
      gate: :d21,
      arm: :remove,
      type: :count,
      policy: {:must_equal, "0"},
      producer: :donor,
      producer_detail: :donor_job_remove,
      role: :post_remove_state,
      claim: "D21 observed no reaps."
    },
    %{
      id: :d21_no_restart_after_remove,
      key: "PHASE08_D21_NO_RESTART_AFTER_REMOVE",
      gate: :d21,
      arm: :remove,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_job_remove,
      role: :tail_no_restart,
      claim: "D21 did not restart after remove."
    },
    %{
      id: :d21_confirmed,
      key: "PHASE08_D21_INERT_REMOVE_CONFIRMED",
      gate: :d21,
      arm: :remove,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      producer_detail: :donor_job_remove,
      role: :gate_confirmation,
      claim: "D21 inert RemoveJob behavior was confirmed."
    }
  ]

  @d22_d23_markers [
    %{
      id: :d22_running_live_job_label,
      key: "PHASE08_D22_RUNNING_REMOVE_LIVE_JOB_LABEL",
      gate: :d22,
      arm: :running,
      type: :string,
      policy: {:must_equal, @d22_running_label},
      producer: :donor,
      claim: "Remove handler observed the live donor j->label for the running non-KeepAlive arm."
    },
    %{
      id: :d22_running_live_job_label_match,
      key: "PHASE08_D22_RUNNING_REMOVE_LIVE_JOB_LABEL_MATCH",
      gate: :d22,
      arm: :running,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim: "Live donor j->label matched the expected running non-KeepAlive fixture label."
    },
    %{
      id: :d22_running_keepalive_true_before_remove,
      key: "PHASE08_D22_RUNNING_KEEPALIVE_CONFIG_TRUE_BEFORE_REMOVE",
      gate: :d22,
      arm: :running,
      type: :bool_int,
      policy: {:must_equal, "0"},
      producer: :donor,
      claim: "KeepAlive was false before removing the running non-KeepAlive arm."
    },
    %{
      id: :d22_running_keepalive_configured,
      key: "PHASE08_D22_RUNNING_KEEPALIVE_CONFIGURED",
      gate: :d22,
      arm: :running,
      type: :bool_int,
      policy: {:must_equal, "0"},
      producer: :donor,
      claim: "The running non-KeepAlive arm had no KeepAlive key configured."
    },
    %{
      id: :d22_running_removal_pending_before_signal,
      key: "PHASE08_D22_RUNNING_REMOVAL_PENDING_SET_BEFORE_SIGNAL",
      gate: :d22,
      arm: :running,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim: "removal_pending was set before donor termination in the running non-KeepAlive arm."
    },
    %{
      id: :d22_running_donor_sent_signal,
      key: "PHASE08_D22_RUNNING_DONOR_SENT_SIGNAL",
      gate: :d22,
      arm: :running,
      type: :enum,
      policy: {:must_be_one_of, ["SIGTERM", "SIGKILL"]},
      producer: :donor,
      claim: "job_stop terminated the running non-KeepAlive arm through the donor signal path."
    },
    %{
      id: :d22_running_job_useless_reason,
      key: "PHASE08_D22_RUNNING_JOB_USELESS_REASON",
      gate: :d22,
      arm: :running,
      type: :enum,
      policy: {:must_equal, "removal_pending"},
      producer: :donor,
      claim: "job_useless short-circuited post-reap dispatch because removal was pending."
    },
    %{
      id: :d22_running_keepalive_not_reached,
      key: "PHASE08_D22_RUNNING_KEEPALIVE_REACHED_POST_REAP",
      gate: :d22,
      arm: :running,
      type: :bool_int,
      policy: {:must_equal, "0"},
      producer: :donor,
      claim: "Post-reap teardown preempted job_keepalive in the running non-KeepAlive arm."
    },
    %{
      id: :d22_running_no_restart_after_remove,
      key: "PHASE08_D22_RUNNING_KEEPALIVE_RESTART_AFTER_REMOVE",
      gate: :d22,
      arm: :running,
      type: :bool_int,
      policy: {:must_equal, "0"},
      producer: :donor,
      claim: "No replacement process started after RemoveJob for the running non-KeepAlive arm."
    },
    %{
      id: :d22_running_deferred_enter_count,
      key: "PHASE08_D22_RUNNING_REMOVE_HANDLER_ENTER_COUNT",
      gate: :d22,
      arm: :running,
      type: :count,
      policy: {:must_include, "2"},
      producer: :donor,
      claim: "job_remove re-entered for deferred cleanup after the running non-KeepAlive reap."
    },
    %{
      id: :d22_running_deferred_removal_completed,
      key: "PHASE08_D22_RUNNING_DEFERRED_REMOVAL_COMPLETED",
      gate: :d22,
      arm: :running,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim: "Deferred table removal completed for the running non-KeepAlive arm."
    },
    %{
      id: :d22_running_job_removed_from_table,
      key: "PHASE08_D22_RUNNING_JOB_REMOVED_FROM_TABLE",
      gate: :d22,
      arm: :running,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim: "The running non-KeepAlive job was no longer present in donor job tables."
    },
    %{
      id: :d22_running_no_orphan,
      key: "PHASE08_D22_RUNNING_ORPHANED_PROCESS_CHECK",
      gate: :d22,
      arm: :running,
      type: :bool_int,
      policy: {:must_equal, "0"},
      producer: :donor,
      claim: "The original running non-KeepAlive PID did not survive as an orphan."
    },
    %{
      id: :d22_running_arm_confirmed,
      key: "PHASE08_D22_RUNNING_RUNNING_REMOVE_CONFIRMED",
      gate: :d22,
      arm: :running,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim: "The running non-KeepAlive RemoveJob arm satisfied its terminal proof."
    },
    %{
      id: :d22_keepalive_live_job_label,
      key: "PHASE08_D22_KEEPALIVE_REMOVE_LIVE_JOB_LABEL",
      gate: :d22,
      arm: :keepalive,
      type: :string,
      policy: {:must_equal, @d22_keepalive_label},
      producer: :donor,
      claim: "Remove handler observed the live donor j->label for the running KeepAlive arm."
    },
    %{
      id: :d22_keepalive_live_job_label_match,
      key: "PHASE08_D22_KEEPALIVE_REMOVE_LIVE_JOB_LABEL_MATCH",
      gate: :d22,
      arm: :keepalive,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim: "Live donor j->label matched the expected KeepAlive fixture label."
    },
    %{
      id: :d22_keepalive_true_before_remove,
      key: "PHASE08_D22_KEEPALIVE_KEEPALIVE_CONFIG_TRUE_BEFORE_REMOVE",
      gate: :d22,
      arm: :keepalive,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim: "KeepAlive was true before removing the running KeepAlive arm."
    },
    %{
      id: :d22_keepalive_configured,
      key: "PHASE08_D22_KEEPALIVE_KEEPALIVE_CONFIGURED",
      gate: :d22,
      arm: :keepalive,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim: "The running KeepAlive arm had KeepAlive configured."
    },
    %{
      id: :d22_keepalive_removal_pending_before_signal,
      key: "PHASE08_D22_KEEPALIVE_REMOVAL_PENDING_SET_BEFORE_SIGNAL",
      gate: :d22,
      arm: :keepalive,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim: "removal_pending was set before donor termination in the running KeepAlive arm."
    },
    %{
      id: :d22_keepalive_donor_sent_signal,
      key: "PHASE08_D22_KEEPALIVE_DONOR_SENT_SIGNAL",
      gate: :d22,
      arm: :keepalive,
      type: :enum,
      policy: {:must_be_one_of, ["SIGTERM", "SIGKILL"]},
      producer: :donor,
      claim: "job_stop terminated the running KeepAlive arm through the donor signal path."
    },
    %{
      id: :d22_keepalive_job_useless_reason,
      key: "PHASE08_D22_KEEPALIVE_JOB_USELESS_REASON",
      gate: :d22,
      arm: :keepalive,
      type: :enum,
      policy: {:must_equal, "removal_pending"},
      producer: :donor,
      claim: "job_useless short-circuited post-reap dispatch because removal was pending."
    },
    %{
      id: :d22_keepalive_keepalive_not_reached,
      key: "PHASE08_D22_KEEPALIVE_KEEPALIVE_REACHED_POST_REAP",
      gate: :d22,
      arm: :keepalive,
      type: :bool_int,
      policy: {:must_equal, "0"},
      producer: :donor,
      claim: "Post-reap teardown preempted job_keepalive in the running KeepAlive arm."
    },
    %{
      id: :d22_keepalive_no_restart_after_remove,
      key: "PHASE08_D22_KEEPALIVE_KEEPALIVE_RESTART_AFTER_REMOVE",
      gate: :d22,
      arm: :keepalive,
      type: :bool_int,
      policy: {:must_equal, "0"},
      producer: :donor,
      claim: "No replacement process started after RemoveJob for the running KeepAlive arm."
    },
    %{
      id: :d22_keepalive_deferred_enter_count,
      key: "PHASE08_D22_KEEPALIVE_REMOVE_HANDLER_ENTER_COUNT",
      gate: :d22,
      arm: :keepalive,
      type: :count,
      policy: {:must_include, "2"},
      producer: :donor,
      claim: "job_remove re-entered for deferred cleanup after the running KeepAlive reap."
    },
    %{
      id: :d22_keepalive_deferred_removal_completed,
      key: "PHASE08_D22_KEEPALIVE_DEFERRED_REMOVAL_COMPLETED",
      gate: :d22,
      arm: :keepalive,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim: "Deferred table removal completed for the running KeepAlive arm."
    },
    %{
      id: :d22_keepalive_job_removed_from_table,
      key: "PHASE08_D22_KEEPALIVE_JOB_REMOVED_FROM_TABLE",
      gate: :d22,
      arm: :keepalive,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim: "The running KeepAlive job was no longer present in donor job tables."
    },
    %{
      id: :d22_keepalive_no_orphan,
      key: "PHASE08_D22_KEEPALIVE_ORPHANED_PROCESS_CHECK",
      gate: :d22,
      arm: :keepalive,
      type: :bool_int,
      policy: {:must_equal, "0"},
      producer: :donor,
      claim: "The original running KeepAlive PID did not survive as an orphan."
    },
    %{
      id: :d22_keepalive_arm_confirmed,
      key: "PHASE08_D22_KEEPALIVE_RUNNING_REMOVE_CONFIRMED",
      gate: :d22,
      arm: :keepalive,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim: "The running KeepAlive RemoveJob arm satisfied its terminal proof."
    },
    %{
      id: :d22_gate_confirmed,
      key: "PHASE08_D22_RUNNING_REMOVE_CONFIRMED",
      gate: :d22,
      arm: nil,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :harness,
      claim: "Both D22 running RemoveJob arms completed."
    },
    %{
      id: :d23_requested,
      key: "PHASE08_D23_RELOAD_REQUESTED",
      gate: :d23,
      arm: nil,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :harness,
      claim: "D23 same-label reload gate was requested."
    },
    %{
      id: :d23_inert_expected_label,
      key: "PHASE08_D23_INERT_EXPECTED_LABEL",
      gate: :d23,
      arm: :inert,
      type: :string,
      policy: {:must_equal, @d23_inert_label},
      producer: :harness,
      claim: "The inert reload arm targets the D23 inert fixture label."
    },
    %{
      id: :d23_inert_load_delta,
      key: "PHASE08_D23_INERT_LOAD_MIG437_DELTA",
      gate: :d23,
      arm: :inert,
      type: :count,
      policy: {:must_equal, "1"},
      producer: :harness,
      claim: "Initial inert load sent exactly one MIG 437 management request."
    },
    %{
      id: :d23_inert_remove_delta,
      key: "PHASE08_D23_INERT_REMOVE_MIG437_DELTA",
      gate: :d23,
      arm: :inert,
      type: :count,
      policy: {:must_equal, "1"},
      producer: :harness,
      claim: "Inert remove sent exactly one MIG 437 management request."
    },
    %{
      id: :d23_inert_reload_delta,
      key: "PHASE08_D23_INERT_RELOAD_MIG437_DELTA",
      gate: :d23,
      arm: :inert,
      type: :count,
      policy: {:must_equal, "1"},
      producer: :harness,
      claim: "Same-label inert reload sent exactly one MIG 437 management request."
    },
    %{
      id: :d23_inert_reload_find_null,
      key: "PHASE08_D23_INERT_RELOAD_JOB_FIND_RETURNED_NULL",
      gate: :d23,
      arm: :inert,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim: "The reload EEXIST gate evaluated job_find and found no stale inert label."
    },
    %{
      id: :d23_inert_duplicate_rejected,
      key: "PHASE08_D23_INERT_RELOAD_DUPLICATE_REJECTED",
      gate: :d23,
      arm: :inert,
      type: :bool_int,
      policy: {:must_equal, "0"},
      producer: :donor,
      claim: "The inert reload was not rejected as a duplicate label."
    },
    %{
      id: :d23_inert_removed_label_count,
      key: "PHASE08_D23_INERT_LABEL_COUNT_AFTER_REMOVE",
      gate: :d23,
      arm: :inert,
      type: :count,
      policy: {:must_equal, "0"},
      producer: :donor,
      claim: "The inert label hash entry was gone before reload."
    },
    %{
      id: :d23_inert_remove_delta_ok,
      key: "PHASE08_D23_INERT_DONOR_JOB_TABLE_COUNT_REMOVE_DELTA_OK",
      gate: :d23,
      arm: :inert,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim: "The inert remove reduced the donor job table by exactly one."
    },
    %{
      id: :d23_inert_no_leak,
      key: "PHASE08_D23_INERT_JOB_STRUCT_NO_LEAK_AFTER_REMOVE",
      gate: :d23,
      arm: :inert,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim: "The old inert job struct was no longer represented in the donor label table."
    },
    %{
      id: :d23_inert_proc_source_removed,
      key: "PHASE08_D23_INERT_OLD_PROC_SOURCE_CANCELLED_OR_NONE",
      gate: :d23,
      arm: :inert,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim: "The inert old job had no dangling proc source at remove completion."
    },
    %{
      id: :d23_inert_kqueue_removed,
      key: "PHASE08_D23_INERT_OLD_KQUEUE_PROC_IDENT_DEREGISTERED_OR_NONE",
      gate: :d23,
      arm: :inert,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim: "The inert old job had no stale EVFILT_PROC ident at remove completion."
    },
    %{
      id: :d23_inert_timers_removed,
      key: "PHASE08_D23_INERT_OLD_TIMER_IDENTS_DEREGISTERED_OR_NONE",
      gate: :d23,
      arm: :inert,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim: "The inert old job had no stale timer ident at remove completion."
    },
    %{
      id: :d23_inert_global_baseline,
      key: "PHASE08_D23_INERT_GLOBAL_ON_DEMAND_CNT_BASELINE",
      gate: :d23,
      arm: :inert,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim: "The inert remove returned global on-demand accounting to baseline."
    },
    %{
      id: :d23_inert_reload_accepted,
      key: "PHASE08_D23_INERT_RELOAD_ACCEPTED",
      gate: :d23,
      arm: :inert,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim: "The same-label inert reload created a valid donor job."
    },
    %{
      id: :d23_inert_arm_confirmed,
      key: "PHASE08_D23_INERT_ARM_CONFIRMED",
      gate: :d23,
      arm: :inert,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :harness,
      claim: "The inert remove then same-label reload arm completed."
    },
    %{
      id: :d23_keepalive_expected_label,
      key: "PHASE08_D23_KEEPALIVE_EXPECTED_LABEL",
      gate: :d23,
      arm: :keepalive,
      type: :string,
      policy: {:must_equal, @d23_keepalive_label},
      producer: :harness,
      claim: "The running KeepAlive reload arm targets the D23 KeepAlive fixture label."
    },
    %{
      id: :d23_keepalive_load_delta,
      key: "PHASE08_D23_KEEPALIVE_LOAD_MIG437_DELTA",
      gate: :d23,
      arm: :keepalive,
      type: :count,
      policy: {:must_equal, "1"},
      producer: :harness,
      claim: "Initial running KeepAlive load sent exactly one MIG 437 management request."
    },
    %{
      id: :d23_keepalive_remove_delta,
      key: "PHASE08_D23_KEEPALIVE_REMOVE_MIG437_DELTA",
      gate: :d23,
      arm: :keepalive,
      type: :count,
      policy: {:must_equal, "1"},
      producer: :harness,
      claim: "Running KeepAlive remove sent exactly one MIG 437 management request."
    },
    %{
      id: :d23_keepalive_reload_delta,
      key: "PHASE08_D23_KEEPALIVE_RELOAD_MIG437_DELTA",
      gate: :d23,
      arm: :keepalive,
      type: :count,
      policy: {:must_equal, "1"},
      producer: :harness,
      claim: "Same-label running KeepAlive reload sent exactly one MIG 437 management request."
    },
    %{
      id: :d23_keepalive_reload_find_null,
      key: "PHASE08_D23_KEEPALIVE_RELOAD_JOB_FIND_RETURNED_NULL",
      gate: :d23,
      arm: :keepalive,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim:
        "The reload EEXIST gate evaluated job_find and found no stale running KeepAlive label."
    },
    %{
      id: :d23_keepalive_duplicate_rejected,
      key: "PHASE08_D23_KEEPALIVE_RELOAD_DUPLICATE_REJECTED",
      gate: :d23,
      arm: :keepalive,
      type: :bool_int,
      policy: {:must_equal, "0"},
      producer: :donor,
      claim: "The running KeepAlive reload was not rejected as a duplicate label."
    },
    %{
      id: :d23_keepalive_removed_label_count,
      key: "PHASE08_D23_KEEPALIVE_LABEL_COUNT_AFTER_REMOVE",
      gate: :d23,
      arm: :keepalive,
      type: :count,
      policy: {:must_equal, "0"},
      producer: :donor,
      claim: "The running KeepAlive label hash entry was gone before reload."
    },
    %{
      id: :d23_keepalive_remove_delta_ok,
      key: "PHASE08_D23_KEEPALIVE_DONOR_JOB_TABLE_COUNT_REMOVE_DELTA_OK",
      gate: :d23,
      arm: :keepalive,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim: "The running KeepAlive remove reduced the donor job table by exactly one."
    },
    %{
      id: :d23_keepalive_no_leak,
      key: "PHASE08_D23_KEEPALIVE_JOB_STRUCT_NO_LEAK_AFTER_REMOVE",
      gate: :d23,
      arm: :keepalive,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim:
        "The old running KeepAlive job struct was no longer represented in the donor label table."
    },
    %{
      id: :d23_keepalive_proc_source_removed,
      key: "PHASE08_D23_KEEPALIVE_OLD_PROC_SOURCE_CANCELLED_OR_NONE",
      gate: :d23,
      arm: :keepalive,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim: "The old running KeepAlive job had no dangling proc source at remove completion."
    },
    %{
      id: :d23_keepalive_kqueue_removed,
      key: "PHASE08_D23_KEEPALIVE_OLD_KQUEUE_PROC_IDENT_DEREGISTERED_OR_NONE",
      gate: :d23,
      arm: :keepalive,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim: "The old running KeepAlive job had no stale EVFILT_PROC ident at remove completion."
    },
    %{
      id: :d23_keepalive_timers_removed,
      key: "PHASE08_D23_KEEPALIVE_OLD_TIMER_IDENTS_DEREGISTERED_OR_NONE",
      gate: :d23,
      arm: :keepalive,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim: "The old running KeepAlive job had no stale timer ident at remove completion."
    },
    %{
      id: :d23_keepalive_global_baseline,
      key: "PHASE08_D23_KEEPALIVE_GLOBAL_ON_DEMAND_CNT_BASELINE",
      gate: :d23,
      arm: :keepalive,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim: "The running KeepAlive remove returned global on-demand accounting to baseline."
    },
    %{
      id: :d23_keepalive_no_restart,
      key: "PHASE08_D23_KEEPALIVE_REPLACEMENT_PID_OBSERVED",
      gate: :d23,
      arm: :keepalive,
      type: :bool_int,
      policy: {:must_equal, "0"},
      producer: :harness,
      claim: "No KeepAlive replacement appeared between remove completion and reload."
    },
    %{
      id: :d23_keepalive_no_orphan,
      key: "PHASE08_D23_KEEPALIVE_ORPHANED_PROCESS_CHECK",
      gate: :d23,
      arm: :keepalive,
      type: :bool_int,
      policy: {:must_equal, "0"},
      producer: :harness,
      claim: "The original running KeepAlive PID did not survive as an orphan before reload."
    },
    %{
      id: :d23_keepalive_reload_accepted,
      key: "PHASE08_D23_KEEPALIVE_RELOAD_ACCEPTED",
      gate: :d23,
      arm: :keepalive,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :donor,
      claim: "The same-label running KeepAlive reload created a valid donor job."
    },
    %{
      id: :d23_keepalive_arm_confirmed,
      key: "PHASE08_D23_KEEPALIVE_ARM_CONFIRMED",
      gate: :d23,
      arm: :keepalive,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :harness,
      claim: "The running KeepAlive remove then same-label reload arm completed."
    },
    %{
      id: :d23_gate_confirmed,
      key: "PHASE08_D23_SAME_LABEL_RELOAD_CONFIRMED",
      gate: :d23,
      arm: nil,
      type: :bool_int,
      policy: {:must_equal, "1"},
      producer: :harness,
      claim: "Both D23 same-label reload arms completed."
    }
  ]

  @markers @d19_shared_order_markers ++
             @d20_order_and_tail_markers ++ @d21_remove_markers ++ @d22_d23_markers

  @d19_frozen_generator_anchor_specs [
    %{
      id: :d19_gate_start,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :literal,
      source_fragment: ~S|printf("phase08_dispatch_launchctl_keepalive_restart_start\n");|,
      expands_to: ["phase08_dispatch_launchctl_keepalive_restart_start"]
    },
    %{
      id: :d19_management_request_sent,
      source_path: "scripts/launchd/build-phase08-d15-launchctl-json-hardfail.sh",
      kind: :literal,
      source_fragment: ~S|PHASE08_D19_MANAGEMENT_REQUEST_SENT=1\\n|,
      expands_to: ["PHASE08_D19_MANAGEMENT_REQUEST_SENT=1"]
    },
    %{
      id: :d19_caller_pid_match,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_value,
      dynamic: %{accepted_value: "1"},
      source_fragment: ~S|printf("PHASE08_D19_CALLER_PID_MATCH=%d\n",|,
      expands_to: ["PHASE08_D19_CALLER_PID_MATCH=1"]
    },
    %{
      id: :d19_runtime_demux,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_value,
      dynamic: %{accepted_value: "1"},
      source_fragment: ~S|printf("PHASE08_D19_DONOR_RUNTIME_DEMUX_CALLED=%d\n",|,
      expands_to: ["PHASE08_D19_DONOR_RUNTIME_DEMUX_CALLED=1"]
    },
    %{
      id: :d19_start_pending,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :literal,
      source_fragment: ~S|printf("PHASE08_D19_START_PENDING_SET=1\n");|,
      expands_to: ["PHASE08_D19_START_PENDING_SET=1"]
    },
    %{
      id: :d19_initial_keepalive_reason,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :literal,
      source_fragment: ~S|printf("PHASE08_D19_JOB_KEEPALIVE_REASON=start_pending\n");|,
      expands_to: ["PHASE08_D19_JOB_KEEPALIVE_REASON=start_pending"]
    },
    %{
      id: :d19_cycle_job_start,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_cycle,
      dynamic: %{cycles: [1, 2], source_format: "PHASE08_D19_CYCLE%d_JOB_START_CALLED=1"},
      source_fragment: ~S|printf("PHASE08_D19_CYCLE%d_JOB_START_CALLED=1\n",|,
      expands_to: [
        "PHASE08_D19_CYCLE1_JOB_START_CALLED=1",
        "PHASE08_D19_CYCLE2_JOB_START_CALLED=1"
      ]
    },
    %{
      id: :d19_exec_bridge,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :literal,
      source_fragment: ~S|PHASE08_D19_POSIX_SPAWN_SETEXEC_BRIDGE=direct_exec\\n|,
      expands_to: ["PHASE08_D19_POSIX_SPAWN_SETEXEC_BRIDGE=direct_exec"]
    },
    %{
      id: :d19_cycle_reap_path,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_cycle_value,
      dynamic: %{
        cycles: [1, 2],
        accepted_value: "dispatch_proc_source",
        source_format: "PHASE08_D19_CYCLE%d_REAP_PATH=%s"
      },
      source_fragment: ~S|printf("PHASE08_D19_CYCLE%d_REAP_PATH=%s\n",|,
      expands_to: [
        "PHASE08_D19_CYCLE1_REAP_PATH=dispatch_proc_source",
        "PHASE08_D19_CYCLE2_REAP_PATH=dispatch_proc_source"
      ]
    },
    %{
      id: :d19_post_cycle1_keepalive,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_value,
      dynamic: %{accepted_value: "keepalive"},
      source_fragment: ~S|printf("PHASE08_D19_POST_CYCLE1_KEEPALIVE_REASON=%s\n",|,
      expands_to: ["PHASE08_D19_POST_CYCLE1_KEEPALIVE_REASON=keepalive"]
    },
    %{
      id: :d19_cycle2_limit_armed,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :literal,
      source_fragment: ~S|printf("PHASE08_D19_STOP_AFTER_CYCLE2_ARMED=1\n");|,
      expands_to: ["PHASE08_D19_STOP_AFTER_CYCLE2_ARMED=1"]
    },
    %{
      id: :d19_restart_suppressed,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :literal,
      source_fragment: ~S|printf("PHASE08_D19_STOP_RESTART_SUPPRESSED=harness_cycle_limit\n");|,
      expands_to: ["PHASE08_D19_STOP_RESTART_SUPPRESSED=harness_cycle_limit"]
    },
    %{
      id: :d19_confirmation,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_value,
      dynamic: %{accepted_value: "1"},
      source_fragment: ~S|printf("PHASE08_D19_KEEPALIVE_RESTART_CONFIRMED=%d\n",|,
      expands_to: ["PHASE08_D19_KEEPALIVE_RESTART_CONFIRMED=1"]
    }
  ]

  @d20_d21_frozen_generator_anchor_specs [
    %{
      id: :d20_gate_start,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :literal,
      source_fragment: ~S|printf("phase08_dispatch_launchctl_successful_exit_start\n");|,
      expands_to: ["phase08_dispatch_launchctl_successful_exit_start"]
    },
    %{
      id: :d20_management_request_sent,
      source_path: "scripts/launchd/build-phase08-d15-launchctl-json-hardfail.sh",
      kind: :literal,
      source_fragment: ~S|PHASE08_D20_MANAGEMENT_REQUEST_SENT=1\\n|,
      expands_to: ["PHASE08_D20_MANAGEMENT_REQUEST_SENT=1"]
    },
    %{
      id: :d20_caller_pid_match,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_value,
      dynamic: %{accepted_value: "1"},
      source_fragment: ~S|printf("PHASE08_D20_CALLER_PID_MATCH=%d\n",|,
      expands_to: ["PHASE08_D20_CALLER_PID_MATCH=1"]
    },
    %{
      id: :d20_runtime_demux,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_value,
      dynamic: %{accepted_value: "1"},
      source_fragment: ~S|printf("PHASE08_D20_DONOR_RUNTIME_DEMUX_CALLED=%d\n",|,
      expands_to: ["PHASE08_D20_DONOR_RUNTIME_DEMUX_CALLED=1"]
    },
    %{
      id: :d20_start_pending,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :literal,
      source_fragment: ~S|printf("PHASE08_D20_START_PENDING_SET=1\n");|,
      expands_to: ["PHASE08_D20_START_PENDING_SET=1"]
    },
    %{
      id: :d20_initial_keepalive_reason,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :literal,
      source_fragment: ~S|printf("PHASE08_D20_JOB_KEEPALIVE_REASON=start_pending\n");|,
      expands_to: ["PHASE08_D20_JOB_KEEPALIVE_REASON=start_pending"]
    },
    %{
      id: :d20_cycle_job_start,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_cycle,
      dynamic: %{cycles: [1, 2], source_format: "PHASE08_D20_CYCLE%d_JOB_START_CALLED=1"},
      source_fragment: ~S|printf("PHASE08_D20_CYCLE%d_JOB_START_CALLED=1\n",|,
      expands_to: [
        "PHASE08_D20_CYCLE1_JOB_START_CALLED=1",
        "PHASE08_D20_CYCLE2_JOB_START_CALLED=1"
      ]
    },
    %{
      id: :d20_exec_bridge,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :literal,
      source_fragment: ~S|PHASE08_D20_POSIX_SPAWN_SETEXEC_BRIDGE=direct_exec\\n|,
      expands_to: ["PHASE08_D20_POSIX_SPAWN_SETEXEC_BRIDGE=direct_exec"]
    },
    %{
      id: :d20_cycle_reap_path,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_cycle_value,
      dynamic: %{
        cycles: [1, 2],
        accepted_value: "dispatch_proc_source",
        source_format: "PHASE08_D20_CYCLE%d_REAP_PATH=%s"
      },
      source_fragment: ~S|printf("PHASE08_D20_CYCLE%d_REAP_PATH=%s\n",|,
      expands_to: [
        "PHASE08_D20_CYCLE1_REAP_PATH=dispatch_proc_source",
        "PHASE08_D20_CYCLE2_REAP_PATH=dispatch_proc_source"
      ]
    },
    %{
      id: :d20_postreap_keepalive,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :literal,
      source_fragment: ~S|printf("PHASE08_D20_POSTREAP_KEEPALIVE_REASON=successful_exit\n");|,
      expands_to: ["PHASE08_D20_POSTREAP_KEEPALIVE_REASON=successful_exit"]
    },
    %{
      id: :d20_post_cycle1_keepalive,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_value,
      dynamic: %{accepted_value: "successful_exit"},
      source_fragment: ~S|printf("PHASE08_D20_POST_CYCLE1_KEEPALIVE_REASON=%s\n",|,
      expands_to: ["PHASE08_D20_POST_CYCLE1_KEEPALIVE_REASON=successful_exit"]
    },
    %{
      id: :d20_post_cycle2_keepalive,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_value,
      dynamic: %{accepted_value: "successful_exit_mismatch"},
      source_fragment: ~S|printf("PHASE08_D20_POST_CYCLE2_KEEPALIVE_REASON=%s\n",|,
      expands_to: ["PHASE08_D20_POST_CYCLE2_KEEPALIVE_REASON=successful_exit_mismatch"]
    },
    %{
      id: :d20_no_third_start,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_value,
      dynamic: %{accepted_value: "1"},
      source_fragment: ~S|printf("PHASE08_D20_NO_THIRD_START=%d\n",|,
      expands_to: ["PHASE08_D20_NO_THIRD_START=1"]
    },
    %{
      id: :d20_confirmation,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_value,
      dynamic: %{accepted_value: "1"},
      source_fragment: ~S|printf("PHASE08_D20_CONDITIONAL_KEEPALIVE_CONFIRMED=%d\n",|,
      expands_to: ["PHASE08_D20_CONDITIONAL_KEEPALIVE_CONFIRMED=1"]
    },
    %{
      id: :d21_gate_start,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :literal,
      source_fragment: ~S|printf("phase08_dispatch_launchctl_remove_start\n");|,
      expands_to: ["phase08_dispatch_launchctl_remove_start"]
    },
    %{
      id: :d21_load_confirmed,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :literal,
      source_fragment: ~S|printf("PHASE08_D21_LOAD_CONFIRMED=1\n");|,
      expands_to: ["PHASE08_D21_LOAD_CONFIRMED=1"]
    },
    %{
      id: :d21_inert_load_confirmed,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_value,
      dynamic: %{accepted_value: "1"},
      source_fragment: ~S|printf("PHASE08_D21_INERT_LOAD_CONFIRMED=%d\n",|,
      expands_to: ["PHASE08_D21_INERT_LOAD_CONFIRMED=1"]
    },
    %{
      id: :d21_removejob_seen,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :literal,
      source_fragment: ~S|printf("PHASE08_D21_REMOVEJOB_SEEN=1\n");|,
      expands_to: ["PHASE08_D21_REMOVEJOB_SEEN=1"]
    },
    %{
      id: :d21_remove_target_label_match,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :literal,
      source_fragment: ~S|printf("PHASE08_D21_REMOVE_TARGET_LABEL_MATCH=1\n");|,
      expands_to: ["PHASE08_D21_REMOVE_TARGET_LABEL_MATCH=1"]
    },
    %{
      id: :d21_remove_handler_called,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :literal,
      source_fragment: ~S|printf("PHASE08_D21_REMOVE_HANDLER_CALLED=1\n");|,
      expands_to: ["PHASE08_D21_REMOVE_HANDLER_CALLED=1"]
    },
    %{
      id: :d21_job_found_before_remove,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :literal,
      source_fragment: ~S|printf("PHASE08_D21_JOB_FOUND_BEFORE_REMOVE=1\n");|,
      expands_to: ["PHASE08_D21_JOB_FOUND_BEFORE_REMOVE=1"]
    },
    %{
      id: :d21_job_active_at_remove,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_value,
      dynamic: %{accepted_value: "0"},
      source_fragment: ~S|printf("PHASE08_D21_JOB_ACTIVE_AT_REMOVE=%d\n",|,
      expands_to: ["PHASE08_D21_JOB_ACTIVE_AT_REMOVE=0"]
    },
    %{
      id: :d21_job_pid_at_remove,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_value,
      dynamic: %{accepted_value: "0"},
      source_fragment: ~S|printf("PHASE08_D21_JOB_PID_AT_REMOVE=%d\n",|,
      expands_to: ["PHASE08_D21_JOB_PID_AT_REMOVE=0"]
    },
    %{
      id: :d21_inert_remove_branch,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :literal,
      source_fragment: ~S|printf("PHASE08_D21_INERT_REMOVE_BRANCH=1\n");|,
      expands_to: ["PHASE08_D21_INERT_REMOVE_BRANCH=1"]
    },
    %{
      id: :d21_job_detached_from_jobmgr,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :literal,
      source_fragment: ~S|printf("PHASE08_D21_JOB_DETACHED_FROM_JOBMGR=1\n");|,
      expands_to: ["PHASE08_D21_JOB_DETACHED_FROM_JOBMGR=1"]
    },
    %{
      id: :d21_job_removed_from_label_table,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :literal,
      source_fragment: ~S|printf("PHASE08_D21_JOB_REMOVED_FROM_LABEL_TABLE=1\n");|,
      expands_to: ["PHASE08_D21_JOB_REMOVED_FROM_LABEL_TABLE=1"]
    },
    %{
      id: :d21_label_count_after_detach,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_value,
      dynamic: %{accepted_value: "0"},
      source_fragment: ~S|printf("PHASE08_D21_LABEL_COUNT_AFTER_DETACH=%d\n",|,
      expands_to: ["PHASE08_D21_LABEL_COUNT_AFTER_DETACH=0"]
    },
    %{
      id: :d21_mach_service_removed_or_none,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_value,
      dynamic: %{accepted_value: "1"},
      source_fragment: ~S|printf("PHASE08_D21_MACH_SERVICE_REMOVED_OR_NONE=%d\n",|,
      expands_to: ["PHASE08_D21_MACH_SERVICE_REMOVED_OR_NONE=1"]
    },
    %{
      id: :d21_proc_source_torn_down_or_none,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :literal,
      source_fragment: ~S|printf("PHASE08_D21_JOB_PROC_SOURCE_TORN_DOWN_OR_NONE=1\n");|,
      expands_to: ["PHASE08_D21_JOB_PROC_SOURCE_TORN_DOWN_OR_NONE=1"]
    },
    %{
      id: :d21_remove_handler_enter_count,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_value,
      dynamic: %{accepted_value: "1"},
      source_fragment: ~S|printf("PHASE08_D21_REMOVE_HANDLER_ENTER_COUNT=%d\n",|,
      expands_to: ["PHASE08_D21_REMOVE_HANDLER_ENTER_COUNT=1"]
    },
    %{
      id: :d21_job_removing_recorded,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_value,
      dynamic: %{accepted_value: "1"},
      source_fragment: ~S|printf("PHASE08_D21_JOB_REMOVING_RECORDED=%d\n",|,
      expands_to: ["PHASE08_D21_JOB_REMOVING_RECORDED=1"]
    },
    %{
      id: :d21_job_detached_recorded,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_value,
      dynamic: %{accepted_value: "1"},
      source_fragment: ~S|printf("PHASE08_D21_JOB_DETACHED_RECORDED=%d\n",|,
      expands_to: ["PHASE08_D21_JOB_DETACHED_RECORDED=1"]
    },
    %{
      id: :d21_job_freeing_recorded,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_value,
      dynamic: %{accepted_value: "1"},
      source_fragment: ~S|printf("PHASE08_D21_JOB_FREEING_RECORDED=%d\n",|,
      expands_to: ["PHASE08_D21_JOB_FREEING_RECORDED=1"]
    },
    %{
      id: :d21_job_find_after_remove,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_value,
      dynamic: %{accepted_value: "0"},
      source_fragment: ~S|printf("PHASE08_D21_JOB_FIND_AFTER_REMOVE=%d\n",|,
      expands_to: ["PHASE08_D21_JOB_FIND_AFTER_REMOVE=0"]
    },
    %{
      id: :d21_label_count_after_remove,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_value,
      dynamic: %{accepted_value: "0"},
      source_fragment: ~S|printf("PHASE08_D21_LABEL_COUNT_AFTER_REMOVE=%d\n",|,
      expands_to: ["PHASE08_D21_LABEL_COUNT_AFTER_REMOVE=0"]
    },
    %{
      id: :d21_job_table_count_delta_ok,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_value,
      dynamic: %{accepted_value: "1"},
      source_fragment: ~S|printf("PHASE08_D21_DONOR_JOB_TABLE_COUNT_DELTA_OK=%d\n",|,
      expands_to: ["PHASE08_D21_DONOR_JOB_TABLE_COUNT_DELTA_OK=1"]
    },
    %{
      id: :d21_job_struct_no_leak,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_value,
      dynamic: %{accepted_value: "1"},
      source_fragment: ~S|printf("PHASE08_D21_JOB_STRUCT_NO_LEAK=%d\n",|,
      expands_to: ["PHASE08_D21_JOB_STRUCT_NO_LEAK=1"]
    },
    %{
      id: :d21_job_removed_from_table,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_value,
      dynamic: %{accepted_value: "1"},
      source_fragment: ~S|printf("PHASE08_D21_JOB_REMOVED_FROM_TABLE=%d\n",|,
      expands_to: ["PHASE08_D21_JOB_REMOVED_FROM_TABLE=1"]
    },
    %{
      id: :d21_start_count_final,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_value,
      dynamic: %{accepted_value: "0"},
      source_fragment: ~S|printf("PHASE08_D21_START_COUNT_FINAL=%d\n",|,
      expands_to: ["PHASE08_D21_START_COUNT_FINAL=0"]
    },
    %{
      id: :d21_proc_source_event_count_total,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :literal,
      source_fragment: ~S|printf("PHASE08_D21_PROC_SOURCE_EVENT_COUNT_TOTAL=0\n");|,
      expands_to: ["PHASE08_D21_PROC_SOURCE_EVENT_COUNT_TOTAL=0"]
    },
    %{
      id: :d21_reap_count_total,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :literal,
      source_fragment: ~S|printf("PHASE08_D21_REAP_COUNT_TOTAL=0\n");|,
      expands_to: ["PHASE08_D21_REAP_COUNT_TOTAL=0"]
    },
    %{
      id: :d21_no_restart_after_remove,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :literal,
      source_fragment: ~S|printf("PHASE08_D21_NO_RESTART_AFTER_REMOVE=1\n");|,
      expands_to: ["PHASE08_D21_NO_RESTART_AFTER_REMOVE=1"]
    },
    %{
      id: :d21_confirmation,
      source_path: "scripts/launchd/link-launchd-harness.sh",
      kind: :dynamic_value,
      dynamic: %{accepted_value: "1"},
      source_fragment: ~S|printf("PHASE08_D21_INERT_REMOVE_CONFIRMED=%d\n",|,
      expands_to: ["PHASE08_D21_INERT_REMOVE_CONFIRMED=1"]
    }
  ]

  def markers, do: @markers

  def for_gate(gate) do
    Enum.filter(@markers, &(&1.gate == gate))
  end

  def for_arm(gate, arm) do
    Enum.filter(@markers, &(&1.gate == gate and &1.arm == arm))
  end

  def key!(id) do
    spec!(id).key
  end

  def spec!(id) do
    case Enum.find(@markers, &(&1.id == id)) do
      nil -> raise ArgumentError, "unknown Phase 0.8 marker id: #{inspect(id)}"
      spec -> spec
    end
  end

  def emit_c(id, value_expr, fmt_or_opts \\ "%s", opts \\ [])

  def emit_c(id, value_expr, fmt, opts)
      when is_atom(id) and is_binary(fmt) and is_list(opts) do
    spec = spec!(id)
    validate_emit_c_policy!(spec)
    value_expr = validate_value_expr!(id, value_expr)
    validate_static_value!(spec, Keyword.fetch(opts, :value))

    ~s|printf("#{c_printf_escape(spec.key)}=#{c_escape(fmt)}\\n", #{value_expr});|
  end

  def emit_c(id, value_expr, opts, []) when is_atom(id) and is_list(opts) do
    fmt = Keyword.get(opts, :fmt, "%s")
    emit_c(id, value_expr, fmt, opts)
  end

  def c_key!(id) when is_atom(id), do: c_escape(key!(id))

  def c_string_literal(value) when is_binary(value), do: ~s|"#{c_escape(value)}"|

  def marker_literal(%{policy: :must_be_present} = spec), do: spec.key

  def marker_literal(%{policy: {:must_equal, expected}} = spec) do
    "#{spec.key}=#{expected}"
  end

  def marker_literal(%{policy: {:must_include, expected}} = spec) do
    "#{spec.key}=#{expected}"
  end

  def marker_literal(%{policy: {:must_be_one_of, [expected | _rest]}} = spec) do
    "#{spec.key}=#{expected}"
  end

  def d19_frozen_generator_anchor_source_reference do
    %{
      source_repo: "/Users/me/wip-mach/wip-gpt",
      commit: "089311cff65bf116323a1e2e2d5ccf602432a22c",
      short_commit: "089311cff65b",
      fixture:
        "test/fixtures/phase08/launchctl/d19_frozen_generator_anchors_089311cff65b.source.txt",
      source_refs: [
        %{
          path: "scripts/launchd/build-phase08-d15-launchctl-json-hardfail.sh",
          sha256: "b46b055378b85e4e07c6bbda29420100ea8c878d6c1f53943ccab74ce850a356"
        },
        %{
          path: "scripts/launchd/link-launchd-harness.sh",
          sha256: "622e039124dcc58d094d8c19b931dd225fe8986960ef4d77d2f3fddd814378f3"
        }
      ]
    }
  end

  def d19_frozen_generator_anchor_specs, do: @d19_frozen_generator_anchor_specs

  def d20_d21_frozen_generator_anchor_source_reference do
    %{
      source_repo: "/Users/me/wip-mach/wip-gpt",
      commit: "089311cff65bf116323a1e2e2d5ccf602432a22c",
      short_commit: "089311cff65b",
      fixture:
        "test/fixtures/phase08/launchctl/d20_d21_frozen_generator_anchors_089311cff65b.source.txt",
      source_refs: [
        %{
          path: "scripts/launchd/build-phase08-d15-launchctl-json-hardfail.sh",
          sha256: "b46b055378b85e4e07c6bbda29420100ea8c878d6c1f53943ccab74ce850a356"
        },
        %{
          path: "scripts/launchd/link-launchd-harness.sh",
          sha256: "622e039124dcc58d094d8c19b931dd225fe8986960ef4d77d2f3fddd814378f3"
        }
      ]
    }
  end

  def d20_d21_frozen_generator_anchor_specs, do: @d20_d21_frozen_generator_anchor_specs

  def d19_frozen_generator_anchors_from_text(source_text) when is_binary(source_text) do
    @d19_frozen_generator_anchor_specs
    |> Enum.filter(&String.contains?(source_text, &1.source_fragment))
    |> Enum.flat_map(fn spec ->
      Enum.map(spec.expands_to, fn literal ->
        spec
        |> Map.take([:id, :source_path, :kind, :dynamic])
        |> Map.put(:literal, literal)
      end)
    end)
  end

  def d20_d21_frozen_generator_anchors_from_text(source_text) when is_binary(source_text) do
    @d20_d21_frozen_generator_anchor_specs
    |> Enum.filter(&String.contains?(source_text, &1.source_fragment))
    |> Enum.flat_map(fn spec ->
      Enum.map(spec.expands_to, fn literal ->
        spec
        |> Map.take([:id, :source_path, :kind, :dynamic])
        |> Map.put(:literal, literal)
      end)
    end)
  end

  def validate_d19_frozen_generator_anchor_drift!(source_text) when is_binary(source_text) do
    validate_d19_frozen_generator_anchor_drift!(source_text, d19_manifest_literals())
  end

  def validate_d20_d21_frozen_generator_anchor_drift!(source_text) when is_binary(source_text) do
    validate_d20_d21_frozen_generator_anchor_drift!(source_text, d20_d21_manifest_literals())
  end

  def validate_d19_frozen_generator_anchor_drift!(source_text, manifest_literals)
      when is_binary(source_text) and is_list(manifest_literals) do
    source_literals =
      source_text
      |> d19_frozen_generator_anchors_from_text()
      |> Enum.map(& &1.literal)

    unless MapSet.new(manifest_literals) == MapSet.new(source_literals) do
      raise ArgumentError,
            "D19 manifest/frozen generator anchor drift manifest=#{inspect(manifest_literals)} source=#{inspect(source_literals)}"
    end

    :ok
  end

  def validate_d20_d21_frozen_generator_anchor_drift!(source_text, manifest_literals)
      when is_binary(source_text) and is_list(manifest_literals) do
    source_literals =
      source_text
      |> d20_d21_frozen_generator_anchors_from_text()
      |> Enum.map(& &1.literal)

    unless MapSet.new(manifest_literals) == MapSet.new(source_literals) do
      raise ArgumentError,
            "D20/D21 manifest/frozen generator anchor drift manifest=#{inspect(manifest_literals)} source=#{inspect(source_literals)}"
    end

    :ok
  end

  defp d19_manifest_literals do
    :d19
    |> for_gate()
    |> Enum.map(&marker_literal/1)
  end

  defp d20_d21_manifest_literals do
    [:d20, :d21]
    |> Enum.flat_map(&for_gate/1)
    |> Enum.map(&marker_literal/1)
  end

  def validate_unique! do
    duplicate_ids =
      @markers
      |> Enum.group_by(& &1.id)
      |> Enum.filter(fn {_id, specs} -> length(specs) > 1 end)
      |> Enum.map(&elem(&1, 0))

    duplicate_keys =
      @markers
      |> Enum.group_by(& &1.key)
      |> Enum.filter(fn {_key, specs} -> length(specs) > 1 end)
      |> Enum.map(&elem(&1, 0))

    case {duplicate_ids, duplicate_keys} do
      {[], []} ->
        :ok

      _ ->
        raise ArgumentError,
              "duplicate marker manifest entries ids=#{inspect(duplicate_ids)} keys=#{inspect(duplicate_keys)}"
    end
  end

  def validate_log!(log, gate) when is_binary(log) do
    validate_unique!()

    gate
    |> for_gate()
    |> Enum.each(&validate_marker_in_log!(log, &1))

    :ok
  end

  def marker_values(log, key) do
    regex = ~r/^#{Regex.escape(key)}=([^\r\n]*)/m

    regex
    |> Regex.scan(log)
    |> Enum.map(fn [_, value] -> String.trim(value) end)
  end

  defp validate_marker_in_log!(log, spec) do
    if spec.policy == :must_be_present do
      unless String.contains?(log, spec.key) do
        raise ArgumentError, "missing marker #{spec.key}: #{spec.claim}"
      end

      :ok
    else
      validate_keyed_marker_in_log!(log, spec)
    end
  end

  defp validate_keyed_marker_in_log!(log, spec) do
    values = marker_values(log, spec.key)

    if values == [] do
      raise ArgumentError, "missing marker #{spec.key}: #{spec.claim}"
    end

    validate_policy!(spec, values)
  end

  defp validate_policy!(%{policy: {:must_equal, expected}} = spec, values) do
    expected = to_string(expected)

    unless Enum.all?(values, &(&1 == expected)) do
      raise ArgumentError,
            "marker #{spec.key} expected all values #{inspect(expected)}, got #{inspect(values)}"
    end
  end

  defp validate_policy!(%{policy: {:must_include, expected}} = spec, values) do
    expected = to_string(expected)

    unless expected in values do
      raise ArgumentError,
            "marker #{spec.key} expected to include #{inspect(expected)}, got #{inspect(values)}"
    end
  end

  defp validate_policy!(%{policy: {:must_be_one_of, allowed}} = spec, values) do
    allowed = MapSet.new(Enum.map(allowed, &to_string/1))
    bad = Enum.reject(values, &MapSet.member?(allowed, &1))

    unless bad == [] do
      raise ArgumentError,
            "marker #{spec.key} expected values in #{inspect(MapSet.to_list(allowed))}, got bad values #{inspect(bad)}"
    end
  end

  defp validate_value_expr!(id, value_expr) when is_binary(value_expr) do
    if value_expr == "" do
      raise ArgumentError, "marker #{inspect(id)} emit_c requires a non-empty value expression"
    end

    value_expr
  end

  defp validate_value_expr!(id, value_expr) do
    raise ArgumentError,
          "marker #{inspect(id)} emit_c requires a binary value expression, got #{inspect(value_expr)}"
  end

  defp validate_emit_c_policy!(%{policy: :must_be_present} = spec) do
    raise ArgumentError, "presence-only marker cannot be emitted with emit_c/...: #{spec.key}"
  end

  defp validate_emit_c_policy!(_spec), do: :ok

  defp validate_static_value!(_spec, :error), do: :ok

  defp validate_static_value!(%{policy: :must_be_present}, {:ok, _value}), do: :ok

  defp validate_static_value!(%{policy: {:must_equal, expected}} = spec, {:ok, value}) do
    unless to_string(value) == to_string(expected) do
      raise ArgumentError,
            "marker #{spec.key}: emit_c value #{inspect(value)} != manifest expected #{inspect(expected)}"
    end
  end

  defp validate_static_value!(%{policy: {:must_include, expected}} = spec, {:ok, value}) do
    unless to_string(value) == to_string(expected) do
      raise ArgumentError,
            "marker #{spec.key}: emit_c value #{inspect(value)} is not the required included value #{inspect(expected)}"
    end
  end

  defp validate_static_value!(%{policy: {:must_be_one_of, allowed}} = spec, {:ok, value}) do
    allowed = MapSet.new(Enum.map(allowed, &to_string/1))

    unless MapSet.member?(allowed, to_string(value)) do
      raise ArgumentError,
            "marker #{spec.key}: emit_c value #{inspect(value)} is not in #{inspect(MapSet.to_list(allowed))}"
    end
  end

  defp c_printf_escape(value) do
    value
    |> c_escape()
    |> String.replace("%", "%%")
  end

  defp c_escape(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", "\\n")
    |> String.replace("\t", "\\t")
  end
end
