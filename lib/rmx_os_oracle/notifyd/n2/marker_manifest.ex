defmodule RmxOSOracle.Notifyd.N2.MarkerManifest do
  @moduledoc """
  Oracle-owned notifyd N2-series marker authority extracted from accepted evidence.

  Scope:

  * accepted MACH_SEND smoke claim: same-task
    `DISPATCH_SOURCE_TYPE_MACH_SEND` dead-name event delivery, accepted by
    validate-only correction over unchanged Attempt A serial evidence
  * supporting accepted split evidence: raw Mach DEAD_NAME delivery, direct
    EVFILT_MACHPORT receive, and donor-libdispatch notify trace diagnostics
  * non-claims: no notifyd N2 concurrency, no notifyd client-death cleanup, no
    direct notifyd `:launchd` or `:kernel` product facts, no generic Phase 0.85
    authority, and no certification claim
  * N2 series remains open: direct notifyd `:launchd`/`:kernel` facts and the
    concurrency batch are not closed by this authority.

  The authority owns marker keys, field policies, family order contracts,
  hard-stop families, raw rc normalization, accepted evidence citations, and the
  `phase07_dispatch_mach_send_exit` dual-namespace whitelist. Validators consume
  this module instead of maintaining independent marker literals.
  """

  @accepted_claim "dispatch_mach_send_dead_name_same_task"
  @governing_record "docs/phase-0.95a-notifyd-n2-dispatch-dead-name-decode-fix-activation-record.md"
  @governing_record_commit "1542f91ef51ba5a07dcb8c812c60be021a162aa6"
  @validator_correction_pin "64f47c37e93351851113e4ece65b6e9b2f12d2a9"
  @donor_decode_fix_pin "d08b35d57d7be8ae6d8a85f45ca22c53cfebac68"
  @runtime_source_pin "524d71df420e7c22fcd8fb03e7e9939c808c8971"
  @mach_ko_sha256 "49ac3d8970449817ebca964e0005ea05bfb2294b341425d9f54f8fcdadfeccc5"

  @families [:mach_send, :mach_raw, :mach_direct, :dispatch_notify_trace_timeout]
  @producers [:donor, :harness, :kernel]
  @roles [
    :mach_send_public_event,
    :mach_raw_dead_name,
    :mach_direct_kevent,
    :donor_libdispatch_private_trace,
    :terminal,
    :infrastructure
  ]

  @evidence %{
    mach_send: %{
      path:
        "priv/runs/notifyd-n2-mach-send/20260612T112249Z-dead-name-decode-fix-after-image-repair/attempt-a-mach-send.serial.log",
      serial_sha256: "0e2a1b5d0fe24a1859e7e9124353dc62d10dc563a95227ae7ea819ddb7beb1bf",
      disposition_path:
        "priv/runs/notifyd-n2-mach-send/20260612T112249Z-dead-name-decode-fix-after-image-repair/attempt-disposition.json",
      disposition: "accepted_by_validate_only_validator_correction",
      accepted_by: "validate_only_validator_correction",
      raw_run_guest_rc: "1"
    },
    mach_raw: %{
      path:
        "priv/runs/notifyd-n2-mach-raw/20260612T045723Z-dead-name-raw-send-surface-replacement/serial.log",
      serial_sha256: "a5701ced4969b24c184ce74a2501db432ab02c7fc07052eaa023cd4e3f8f93d0",
      raw_tree_digest: "d801ec0b66ac72e16cac3262ab939aed76d47c1e37de942c186f387f54ac9c19",
      disposition: "accepted",
      raw_run_guest_rc: "1"
    },
    mach_direct: %{
      path:
        "priv/runs/notifyd-n2-mach-direct/20260612T072033Z-dead-name-direct-kevent/serial.log",
      serial_sha256: "a3f637da1d310683daf6b2e29ec06d832593f66c4248c8f086cddf2f19643bc5",
      raw_tree_digest: "e199aa688e58fe95adce8c4ee383949f4d8505ec9027a5fb78adc160de499aa3",
      disposition: "accepted",
      raw_run_guest_rc: "1"
    },
    dispatch_notify_trace_timeout: %{
      path:
        "priv/runs/notifyd-n2-dispatch-notify-trace/20260612T082124Z-donor-libdispatch-notify-trace/serial.log",
      serial_sha256: "ff443072bc89f0fd081fe082922a9401a64ad0be4de4c67b5aca60713d8a31c8",
      preserved_run_dir_digest:
        "378caa430f8f8529c944b1e640c9a8f83f0856e9d584bce84a8b80145daad422",
      disposition: "accepted_diagnostic_user_event_timeout",
      raw_run_guest_rc: "1"
    },
    dispatch_notify_trace_delivered: %{
      path:
        "priv/runs/notifyd-n2-mach-send/20260612T112249Z-dead-name-decode-fix-after-image-repair/attempt-b-notify-trace.serial.log",
      serial_sha256: "4ab1e4d3b2a5b32c0d7c1a876caf50d6ef0bf52180066db6061bf16a0d47bd37",
      disposition: "historical_diagnostic_attempt_consumed_before_validate_only_reclassification",
      raw_run_guest_rc: "1"
    }
  }

  @phase07_exit_whitelist %{
    "phase07_dispatch_mach_send_exit" => [:mach_send],
    "phase07_mach_dead_name_raw_exit" => [:mach_raw],
    "phase07_mach_direct_kevent_exit" => [:mach_direct],
    "phase07_dispatch_notify_trace_exit" => [
      :dispatch_notify_trace_timeout,
      :dispatch_notify_trace_delivered
    ]
  }

  def accepted_claim, do: @accepted_claim
  def governing_record, do: @governing_record
  def governing_record_commit, do: @governing_record_commit
  def validator_correction_pin, do: @validator_correction_pin
  def donor_decode_fix_pin, do: @donor_decode_fix_pin
  def runtime_source_pin, do: @runtime_source_pin
  def mach_ko_sha256, do: @mach_ko_sha256
  def families, do: @families
  def producers, do: @producers
  def roles, do: @roles
  def evidence, do: @evidence
  def evidence(family), do: Map.fetch!(@evidence, family)
  def phase07_exit_whitelist, do: @phase07_exit_whitelist

  def closeout do
    %{
      accepted_claim: @accepted_claim,
      governing_record: @governing_record,
      governing_record_commit: @governing_record_commit,
      maestro_acceptance:
        "Maestro routing on 2026-06-13 explicitly accepted the validate-only reclassification",
      validator_reviews: %{
        glm: "accepted, confidence 9.5/10, no blockers",
        ds4p: "no blockers, confidence 9/10"
      },
      source_pins: %{
        validator_correction: @validator_correction_pin,
        donor_decode_fix: @donor_decode_fix_pin,
        runtime_source: @runtime_source_pin,
        mach_ko_sha256: @mach_ko_sha256
      },
      accepted_evidence: @evidence,
      non_claims: [
        "no_notifyd_n2_concurrency",
        "no_notifyd_client_death_cleanup",
        "no_direct_notifyd_launchd_product_facts",
        "no_direct_notifyd_kernel_product_facts",
        "no_generic_phase_085_authority",
        "no_certification_claim"
      ],
      open_obligations: [
        "direct_launchd_notifyd_facts",
        "direct_kernel_notifyd_facts",
        "notifyd_n2_concurrency_batch"
      ],
      raw_evidence_mutated: false,
      new_guest_run_for_authority_extraction: false
    }
  end

  def specs do
    mach_send_specs() ++ mach_raw_specs() ++ mach_direct_specs() ++ notify_trace_timeout_specs()
  end

  def specs(family), do: Enum.filter(specs(), &(&1.family == family))

  def ordered_specs(family) do
    family
    |> specs()
    |> Enum.filter(& &1.ordered)
    |> Enum.sort_by(& &1.order)
  end

  def required_lines(family), do: Enum.filter(exact_lines(), &(&1.family == family))

  def marker_keys do
    specs()
    |> Enum.map(& &1.key)
    |> Enum.uniq()
  end

  def marker_literals, do: marker_keys()

  def spec!(id) do
    Enum.find(specs(), &(&1.id == id)) ||
      raise ArgumentError, "unknown notifyd N2 marker id: #{inspect(id)}"
  end

  def role_breakdown do
    specs()
    |> Enum.frequencies_by(& &1.role)
    |> Map.new()
  end

  def producer_breakdown do
    specs()
    |> Enum.frequencies_by(& &1.producer)
    |> Map.new()
  end

  def terminal_specs do
    %{
      mach_send: spec!(:mach_send_terminal),
      mach_raw: spec!(:mach_raw_terminal),
      mach_direct: spec!(:mach_direct_terminal),
      dispatch_notify_trace_timeout: spec!(:trace_terminal)
    }
  end

  def phase_exit_lines do
    %{
      mach_send: "phase07_dispatch_mach_send_exit=0",
      mach_raw: "phase07_mach_dead_name_raw_exit=0",
      mach_direct: "phase07_mach_direct_kevent_exit=0",
      dispatch_notify_trace_timeout: "phase07_dispatch_notify_trace_exit=0"
    }
  end

  def terminal_contract(family) do
    %{
      run_guest_rc_normalization:
        "run-guest.rc=1 is acceptable only when the ordered family contract passes, hard-stop scan is clean, terminal status is 0, and the phase07 exit marker is 0",
      terminal_spec: Map.fetch!(terminal_specs(), family),
      phase_exit_line: Map.fetch!(phase_exit_lines(), family)
    }
  end

  def hard_stop_patterns do
    [
      ~r/panic/i,
      ~r/Fatal trap/i,
      ~r/KASSERT/i,
      ~r/WITNESS:|WITNESS.*lock order|lock order reversal/i,
      ~r/SIGSYS/i,
      ~r/Bad system call/i,
      ~r/UNKNOWN FreeBSD SYSCALL/i,
      ~r/nosys [0-9]+/i,
      ~r/dispatch assertion|Assertion failed/i
    ]
  end

  def negative_control_contracts do
    [
      %{id: "missing_terminal", class: :terminal, expected_error: "missing terminal"},
      %{id: "duplicate_terminal", class: :terminal, expected_error: "duplicate terminal"},
      %{id: "invalid_order", class: :order, expected_error: "order violation"},
      %{id: "wrong_value", class: :value, expected_error: "wrong field"},
      %{id: "missing_receipt", class: :receipt, expected_error: "missing field record"},
      %{id: "rc_one_without_terminal", class: :rc, expected_error: "rc normalization failed"},
      %{id: "hard_stop", class: :hard_stop, expected_error: "hard stop matched"}
    ]
  end

  defp mach_send_specs do
    [
      spec(
        :mach_send_start,
        :mach_send,
        "NOTIFYD_N2_MACH_SEND_SMOKE_START",
        %{status: eq("0")},
        :infrastructure,
        :harness,
        :probe,
        1
      ),
      spec(
        :mach_send_registration,
        :mach_send,
        "NOTIFYD_N2_MACH_SEND_REGISTRATION",
        %{count: eq("1")},
        :mach_send_public_event,
        :donor,
        :dispatch_source,
        2
      ),
      spec(
        :mach_send_early_event,
        :mach_send,
        "NOTIFYD_N2_MACH_SEND_EARLY_EVENT",
        %{count: eq("0")},
        :mach_send_public_event,
        :donor,
        :dispatch_source,
        3
      ),
      spec(
        :mach_send_receive_destroy,
        :mach_send,
        "NOTIFYD_N2_MACH_SEND_RECEIVE_DESTROY",
        %{kr: eq("0"), owner: eq("same_task")},
        :mach_send_public_event,
        :harness,
        :probe,
        4
      ),
      spec(
        :mach_send_dead_event,
        :mach_send,
        "NOTIFYD_N2_MACH_SEND_DEAD_EVENT",
        %{count: eq("1"), duplicate: eq("0"), data: positive_integer()},
        :mach_send_public_event,
        :donor,
        :dispatch_source,
        5
      ),
      spec(
        :mach_send_cancel,
        :mach_send,
        "NOTIFYD_N2_MACH_SEND_CANCEL",
        %{count: eq("1"), before_event: eq("0")},
        :mach_send_public_event,
        :donor,
        :dispatch_source,
        6
      ),
      spec(
        :mach_send_final_counts,
        :mach_send,
        "NOTIFYD_N2_MACH_SEND_FINAL_COUNTS",
        %{
          registration: eq("1"),
          event: eq("1"),
          duplicate: eq("0"),
          cancel: eq("1"),
          cancel_before_event: eq("0")
        },
        :mach_send_public_event,
        :harness,
        :summary,
        7
      ),
      spec(
        :mach_send_terminal,
        :mach_send,
        "NOTIFYD_N2_MACH_SEND_TERMINAL",
        %{status: eq("0")},
        :terminal,
        :harness,
        :terminal,
        8
      )
    ]
  end

  defp mach_raw_specs do
    [
      spec(
        :mach_raw_start,
        :mach_raw,
        "NOTIFYD_N2_MACH_RAW_SMOKE_START",
        %{status: eq("0")},
        :infrastructure,
        :harness,
        :probe,
        1
      ),
      spec(
        :mach_raw_target_allocate,
        :mach_raw,
        "NOTIFYD_N2_MACH_RAW_TARGET_ALLOCATE",
        %{kr: eq("0"), port: positive_integer()},
        :mach_raw_dead_name,
        :harness,
        :probe,
        2
      ),
      spec(
        :mach_raw_target_make_send,
        :mach_raw,
        "NOTIFYD_N2_MACH_RAW_TARGET_MAKE_SEND",
        %{kr: eq("0")},
        :mach_raw_dead_name,
        :harness,
        :probe,
        3
      ),
      spec(
        :mach_raw_notify_allocate,
        :mach_raw,
        "NOTIFYD_N2_MACH_RAW_NOTIFY_ALLOCATE",
        %{kr: eq("0"), port: positive_integer()},
        :mach_raw_dead_name,
        :harness,
        :probe,
        4
      ),
      spec(
        :mach_raw_request,
        :mach_raw,
        "NOTIFYD_N2_MACH_RAW_REQUEST",
        %{kr: eq("0"), previous: eq("0")},
        :mach_raw_dead_name,
        :kernel,
        :dead_name_notification,
        5
      ),
      spec(
        :mach_raw_early_receive,
        :mach_raw,
        "NOTIFYD_N2_MACH_RAW_EARLY_RECEIVE",
        %{mr: integer(), count: eq("0")},
        :mach_raw_dead_name,
        :kernel,
        :dead_name_notification,
        6
      ),
      spec(
        :mach_raw_receive_destroy,
        :mach_raw,
        "NOTIFYD_N2_MACH_RAW_RECEIVE_DESTROY",
        %{kr: eq("0"), owner: eq("same_task")},
        :mach_raw_dead_name,
        :harness,
        :probe,
        7
      ),
      spec(
        :mach_raw_notification_receive,
        :mach_raw,
        "NOTIFYD_N2_MACH_RAW_NOTIFICATION_RECEIVE",
        %{mr: eq("0"), id: eq("72"), not_port: positive_integer(), size: positive_integer()},
        :mach_raw_dead_name,
        :kernel,
        :dead_name_notification,
        8
      ),
      spec(
        :mach_raw_duplicate_receive,
        :mach_raw,
        "NOTIFYD_N2_MACH_RAW_DUPLICATE_RECEIVE",
        %{mr: integer(), duplicate: eq("0")},
        :mach_raw_dead_name,
        :kernel,
        :dead_name_notification,
        9
      ),
      spec(
        :mach_raw_terminal,
        :mach_raw,
        "NOTIFYD_N2_MACH_RAW_TERMINAL",
        %{status: eq("0")},
        :terminal,
        :harness,
        :terminal,
        10
      )
    ]
  end

  defp mach_direct_specs do
    [
      spec(
        :mach_direct_start,
        :mach_direct,
        "NOTIFYD_N2_MACH_DIRECT_SMOKE_START",
        %{status: eq("0")},
        :infrastructure,
        :harness,
        :probe,
        1
      ),
      spec(
        :mach_direct_target_allocate,
        :mach_direct,
        "NOTIFYD_N2_MACH_DIRECT_TARGET_ALLOCATE",
        %{kr: eq("0"), port: positive_integer()},
        :mach_direct_kevent,
        :harness,
        :probe,
        2
      ),
      spec(
        :mach_direct_target_make_send,
        :mach_direct,
        "NOTIFYD_N2_MACH_DIRECT_TARGET_MAKE_SEND",
        %{kr: eq("0")},
        :mach_direct_kevent,
        :harness,
        :probe,
        3
      ),
      spec(
        :mach_direct_notify_allocate,
        :mach_direct,
        "NOTIFYD_N2_MACH_DIRECT_NOTIFY_ALLOCATE",
        %{kr: eq("0"), port: positive_integer()},
        :mach_direct_kevent,
        :harness,
        :probe,
        4
      ),
      spec(
        :mach_direct_portset_allocate,
        :mach_direct,
        "NOTIFYD_N2_MACH_DIRECT_PORTSET_ALLOCATE",
        %{kr: eq("0"), portset: positive_integer()},
        :mach_direct_kevent,
        :harness,
        :probe,
        5
      ),
      spec(
        :mach_direct_notify_move_member,
        :mach_direct,
        "NOTIFYD_N2_MACH_DIRECT_NOTIFY_MOVE_MEMBER",
        %{kr: eq("0")},
        :mach_direct_kevent,
        :harness,
        :probe,
        6
      ),
      spec(
        :mach_direct_kqueue,
        :mach_direct,
        "NOTIFYD_N2_MACH_DIRECT_KQUEUE",
        %{fd: nonnegative_integer()},
        :mach_direct_kevent,
        :harness,
        :probe,
        7
      ),
      spec(
        :mach_direct_kevent_arm,
        :mach_direct,
        "NOTIFYD_N2_MACH_DIRECT_KEVENT_ARM",
        %{ret: eq("0")},
        :mach_direct_kevent,
        :kernel,
        :evfilt_machport,
        8
      ),
      spec(
        :mach_direct_request,
        :mach_direct,
        "NOTIFYD_N2_MACH_DIRECT_REQUEST",
        %{kr: eq("0"), previous: eq("0")},
        :mach_direct_kevent,
        :kernel,
        :dead_name_notification,
        9
      ),
      spec(
        :mach_direct_early_kevent,
        :mach_direct,
        "NOTIFYD_N2_MACH_DIRECT_EARLY_KEVENT",
        %{ret: eq("0"), count: eq("0")},
        :mach_direct_kevent,
        :kernel,
        :evfilt_machport,
        10
      ),
      spec(
        :mach_direct_receive_destroy,
        :mach_direct,
        "NOTIFYD_N2_MACH_DIRECT_RECEIVE_DESTROY",
        %{kr: eq("0"), owner: eq("same_task")},
        :mach_direct_kevent,
        :harness,
        :probe,
        11
      ),
      spec(
        :mach_direct_kevent_receive,
        :mach_direct,
        "NOTIFYD_N2_MACH_DIRECT_KEVENT_RECEIVE",
        %{
          ret: eq("1"),
          filter: eq("-16"),
          ident: positive_integer(),
          fflags: eq("0"),
          data: eq("0"),
          size: positive_integer(),
          id: eq("72"),
          local: positive_integer(),
          not_port: positive_integer()
        },
        :mach_direct_kevent,
        :kernel,
        :evfilt_machport,
        12
      ),
      spec(
        :mach_direct_kevent_rearm,
        :mach_direct,
        "NOTIFYD_N2_MACH_DIRECT_KEVENT_REARM",
        %{ret: eq("0")},
        :mach_direct_kevent,
        :kernel,
        :evfilt_machport,
        13
      ),
      spec(
        :mach_direct_duplicate_kevent,
        :mach_direct,
        "NOTIFYD_N2_MACH_DIRECT_DUPLICATE_KEVENT",
        %{ret: eq("0"), duplicate: eq("0")},
        :mach_direct_kevent,
        :kernel,
        :evfilt_machport,
        14
      ),
      spec(
        :mach_direct_terminal,
        :mach_direct,
        "NOTIFYD_N2_MACH_DIRECT_TERMINAL",
        %{status: eq("0")},
        :terminal,
        :harness,
        :terminal,
        15
      )
    ]
  end

  defp notify_trace_timeout_specs do
    [
      spec(
        :trace_start,
        :dispatch_notify_trace_timeout,
        "NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_SMOKE_START",
        %{status: eq("0")},
        :infrastructure,
        :harness,
        :probe,
        1
      ),
      spec(
        :trace_target_allocate,
        :dispatch_notify_trace_timeout,
        "NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_TARGET_ALLOCATE",
        %{kr: eq("0"), port: positive_integer()},
        :donor_libdispatch_private_trace,
        :harness,
        :probe,
        2
      ),
      spec(
        :trace_target_make_send,
        :dispatch_notify_trace_timeout,
        "NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_TARGET_MAKE_SEND",
        %{kr: eq("0")},
        :donor_libdispatch_private_trace,
        :harness,
        :probe,
        3
      ),
      spec(
        :trace_queue_create,
        :dispatch_notify_trace_timeout,
        "NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_QUEUE_CREATE",
        %{status: eq("0")},
        :donor_libdispatch_private_trace,
        :donor,
        :libdispatch,
        4
      ),
      spec(
        :trace_source_create,
        :dispatch_notify_trace_timeout,
        "NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_SOURCE_CREATE",
        %{status: eq("0")},
        :donor_libdispatch_private_trace,
        :donor,
        :libdispatch,
        5
      ),
      spec(
        :trace_update_enter,
        :dispatch_notify_trace_timeout,
        "NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_PRIVATE_NOTIFY_UPDATE_ENTER",
        %{
          port: positive_integer(),
          new: eq("1"),
          del: eq("0"),
          mask: positive_integer(),
          prev: eq("0"),
          fflags: eq("1")
        },
        :donor_libdispatch_private_trace,
        :donor,
        :libdispatch_private,
        6
      ),
      spec(
        :trace_source_resume,
        :dispatch_notify_trace_timeout,
        "NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_PRIVATE_NOTIFY_SOURCE_RESUME",
        %{status: eq("0"), port: positive_integer()},
        :donor_libdispatch_private_trace,
        :donor,
        :libdispatch_private,
        7
      ),
      spec(
        :trace_update_request,
        :dispatch_notify_trace_timeout,
        "NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_PRIVATE_NOTIFY_UPDATE_REQUEST",
        %{
          kr: eq("0"),
          previous: eq("0"),
          msgid: eq("72"),
          sync: eq("1"),
          notify_port: positive_integer()
        },
        :donor_libdispatch_private_trace,
        :kernel,
        :dead_name_notification,
        8
      ),
      spec(
        :trace_registration,
        :dispatch_notify_trace_timeout,
        "NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_REGISTRATION",
        %{count: eq("1")},
        :donor_libdispatch_private_trace,
        :donor,
        :libdispatch,
        9
      ),
      spec(
        :trace_early_event,
        :dispatch_notify_trace_timeout,
        "NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_EARLY_EVENT",
        %{count: eq("0")},
        :donor_libdispatch_private_trace,
        :donor,
        :libdispatch,
        10
      ),
      spec(
        :trace_receive_destroy,
        :dispatch_notify_trace_timeout,
        "NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_RECEIVE_DESTROY",
        %{kr: eq("0"), owner: eq("same_task")},
        :donor_libdispatch_private_trace,
        :harness,
        :probe,
        11
      ),
      spec(
        :trace_private_msg_drain_enter,
        :dispatch_notify_trace_timeout,
        "NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_PRIVATE_MSG_DRAIN_ENTER",
        %{fflags: eq("0"), data: eq("0"), ext0: positive_integer(), ext1: positive_integer()},
        :donor_libdispatch_private_trace,
        :donor,
        :libdispatch_private,
        12
      ),
      spec(
        :trace_private_msg_drain_fast,
        :dispatch_notify_trace_timeout,
        "NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_PRIVATE_MSG_DRAIN_FAST",
        %{id: eq("72"), local: positive_integer(), size: eq("36")},
        :donor_libdispatch_private_trace,
        :donor,
        :libdispatch_private,
        13
      ),
      spec(
        :trace_private_msg_recv_enter,
        :dispatch_notify_trace_timeout,
        "NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_PRIVATE_MSG_RECV_ENTER",
        %{id: eq("72"), local: positive_integer(), size: eq("36")},
        :donor_libdispatch_private_trace,
        :donor,
        :libdispatch_private,
        14
      ),
      spec(
        :trace_private_source_merge_msg,
        :dispatch_notify_trace_timeout,
        "NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_PRIVATE_SOURCE_MERGE_MSG",
        %{notify_source: eq("1"), id: eq("72"), local: positive_integer(), size: eq("36")},
        :donor_libdispatch_private_trace,
        :donor,
        :libdispatch_private,
        15
      ),
      spec(
        :trace_private_source_invoke,
        :dispatch_notify_trace_timeout,
        "NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_PRIVATE_SOURCE_INVOKE",
        %{id: eq("72"), local: positive_integer(), size: eq("36")},
        :donor_libdispatch_private_trace,
        :donor,
        :libdispatch_private,
        16
      ),
      spec(
        :trace_private_dead_name_zero,
        :dispatch_notify_trace_timeout,
        "NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_PRIVATE_DEAD_NAME",
        %{name: eq("0")},
        :donor_libdispatch_private_trace,
        :donor,
        :libdispatch_private,
        17
      ),
      spec(
        :trace_private_merge_enter_zero,
        :dispatch_notify_trace_timeout,
        "NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_PRIVATE_NOTIFY_MERGE_ENTER",
        %{name: eq("0"), flag: eq("1"), final: eq("1")},
        :donor_libdispatch_private_trace,
        :donor,
        :libdispatch_private,
        18
      ),
      spec(
        :trace_private_merge_find_zero,
        :dispatch_notify_trace_timeout,
        "NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_PRIVATE_NOTIFY_MERGE_FIND",
        %{found: eq("0"), name: eq("0")},
        :donor_libdispatch_private_trace,
        :donor,
        :libdispatch_private,
        19
      ),
      spec(
        :trace_private_invoke_result,
        :dispatch_notify_trace_timeout,
        "NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_PRIVATE_SOURCE_INVOKE_RESULT",
        %{success: eq("1"), ret: eq("0")},
        :donor_libdispatch_private_trace,
        :donor,
        :libdispatch_private,
        20
      ),
      spec(
        :trace_user_event_timeout,
        :dispatch_notify_trace_timeout,
        "NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_USER_EVENT_TIMEOUT",
        %{count: eq("0")},
        :donor_libdispatch_private_trace,
        :donor,
        :libdispatch,
        21
      ),
      spec(
        :trace_terminal,
        :dispatch_notify_trace_timeout,
        "NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_TERMINAL",
        %{status: eq("0"), diagnostic: eq("user_event_timeout")},
        :terminal,
        :harness,
        :terminal,
        22
      )
    ]
  end

  defp exact_lines do
    [
      line(:mach_send_mach_module, :mach_send, "mach_module=loaded", 0),
      line(:mach_send_phase_exit, :mach_send, "phase07_dispatch_mach_send_exit=0", 9),
      line(
        :mach_send_end_banner,
        :mach_send,
        "=== phase07 dispatch_mach_send smoke end rc=0 ===",
        10
      ),
      line(:mach_raw_mach_module, :mach_raw, "mach_module=loaded", 0),
      line(:mach_raw_phase_exit, :mach_raw, "phase07_mach_dead_name_raw_exit=0", 11),
      line(:mach_direct_mach_module, :mach_direct, "mach_module=loaded", 0),
      line(:mach_direct_phase_exit, :mach_direct, "phase07_mach_direct_kevent_exit=0", 16),
      line(:trace_mach_module, :dispatch_notify_trace_timeout, "mach_module=loaded", 0),
      line(
        :trace_phase_exit,
        :dispatch_notify_trace_timeout,
        "phase07_dispatch_notify_trace_exit=0",
        23
      )
    ]
  end

  defp spec(id, family, key, fields, role, producer, detail, order) do
    %{
      id: id,
      kind: :field_record,
      family: family,
      key: key,
      fields: fields,
      role: role,
      producer: producer,
      producer_detail: detail,
      ordered: true,
      order: order
    }
  end

  defp line(id, family, text, order) do
    %{id: id, kind: :exact_line, family: family, line: text, ordered: true, order: order}
  end

  defp eq(value), do: {:eq, value}
  defp positive_integer, do: :positive_integer
  defp nonnegative_integer, do: :nonnegative_integer
  defp integer, do: :integer
end
