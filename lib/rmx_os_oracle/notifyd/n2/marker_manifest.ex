defmodule RmxOSOracle.Notifyd.N2.MarkerManifest do
  @moduledoc """
  Oracle-owned notifyd N2-series marker authority extracted from accepted evidence.

  Scope:

  * accepted MACH_SEND smoke claim: same-task
    `DISPATCH_SOURCE_TYPE_MACH_SEND` dead-name event delivery, accepted by
    validate-only correction over unchanged Attempt A serial evidence
  * supporting accepted split evidence: raw Mach DEAD_NAME delivery, direct
    EVFILT_MACHPORT receive, and donor-libdispatch notify trace diagnostics
  * narrowed accepted N2 concurrency evidence: N2C-1 direct notifyd-side
    `:launchd` check-in facts, N2C-2a kernel receive plus dispatch source
    creation, and N2C-3 unidirectional notify delivery
  * non-claims: no N2C-2b cross-process client-death observation, no broad
    libdispatch/thread-workqueue parity, no generic Phase 0.85 authority, and no
    certification claim
  * N2 series remains open: N2C-2b is deferred to a focused sub-gate.

  The authority owns marker keys, field policies, family order contracts,
  hard-stop families, raw rc normalization, accepted evidence citations, and the
  `phase07_dispatch_mach_send_exit` dual-namespace whitelist. Validators consume
  this module instead of maintaining independent marker literals.
  """

  alias RmxOSOracle.Phase085.LaunchdHandoff.MarkerManifest, as: Phase085Handoff

  @accepted_claim "dispatch_mach_send_dead_name_same_task"
  @narrowed_concurrency_claim "n2c_1_launchd_checkin_n2c_2a_kernel_receive_mach_send_source_create_n2c_3_unidirectional_concurrency"
  @governing_record "docs/phase-0.95a-notifyd-n2-dispatch-dead-name-decode-fix-activation-record.md"
  @governing_record_commit "1542f91ef51ba5a07dcb8c812c60be021a162aa6"
  @concurrency_governing_record "docs/phase-0.95a-notifyd-n2-concurrency-activation-record.md"
  @concurrency_governing_record_commit "85021e3fbc34b771877ec9a121d5768856e30814"
  @concurrency_validator_pin "ff3b7257a08c725090712741eb06304c49ea4189d4e7e783018eeac93ecb3b8a"
  @validator_correction_pin "64f47c37e93351851113e4ece65b6e9b2f12d2a9"
  @donor_decode_fix_pin "d08b35d57d7be8ae6d8a85f45ca22c53cfebac68"
  @runtime_source_pin "524d71df420e7c22fcd8fb03e7e9939c808c8971"
  @mach_ko_sha256 "49ac3d8970449817ebca964e0005ea05bfb2294b341425d9f54f8fcdadfeccc5"

  @families [:mach_send, :mach_raw, :mach_direct, :dispatch_notify_trace_timeout, :concurrency]
  @producers [:donor, :harness, :kernel, :launchd]
  @roles [
    :mach_send_public_event,
    :mach_raw_dead_name,
    :mach_direct_kevent,
    :donor_libdispatch_private_trace,
    :launchd_direct,
    :kernel_direct,
    :donor_dispatch_source,
    :concurrency_unidirectional,
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
    },
    concurrency: %{
      path:
        "priv/runs/notifyd-n2-concurrency/20260616T090236Z-token0-fixed-attempt-a/attempt-a.serial.log",
      serial_sha256: "af1a56ee8d9b81def49babf3b6c211700416658253a83152b253f94146711500",
      raw_tree_digest_pre_curation:
        "1a9f90557fd016d1863901e78b41b69360e08c36a2b4335b62439bacb85c19a6",
      disposition_path:
        "priv/runs/notifyd-n2-concurrency/20260616T090236Z-token0-fixed-attempt-a/validate-only-reclassification.json",
      disposition: "accepted_narrowed_by_validate_only_reclassification",
      accepted_by:
        "coordinator_accepted_narrowed_claims_and_gatekeeper_validate_only_reclassification",
      accepted_claim: @narrowed_concurrency_claim,
      governing_record: @concurrency_governing_record,
      governing_record_commit: @concurrency_governing_record_commit,
      validator_pin: @concurrency_validator_pin,
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
  def narrowed_concurrency_claim, do: @narrowed_concurrency_claim
  def governing_record, do: @governing_record
  def governing_record_commit, do: @governing_record_commit
  def concurrency_governing_record, do: @concurrency_governing_record
  def concurrency_governing_record_commit, do: @concurrency_governing_record_commit
  def concurrency_validator_pin, do: @concurrency_validator_pin
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
      accepted_claims: %{
        mach_send: @accepted_claim,
        concurrency: @narrowed_concurrency_claim
      },
      governing_record: @governing_record,
      governing_record_commit: @governing_record_commit,
      concurrency_governing_record: @concurrency_governing_record,
      concurrency_governing_record_commit: @concurrency_governing_record_commit,
      coordinator_acceptance:
        "Coordinator accepted narrowed N2C-1/N2C-2a/N2C-3 claims on 2026-06-16; validate-only reclassification uses the unchanged 090236Z serial",
      validator_reviews: %{
        glm: "accepted, confidence 9.5/10, no blockers",
        ds4p: "no blockers, confidence 9/10"
      },
      source_pins: %{
        validator_correction: @validator_correction_pin,
        concurrency_validator: @concurrency_validator_pin,
        donor_decode_fix: @donor_decode_fix_pin,
        runtime_source: @runtime_source_pin,
        mach_ko_sha256: @mach_ko_sha256
      },
      accepted_evidence: @evidence,
      phase085_launchd_handoff_binding: launchd_handoff_binding(),
      non_claims: [
        "no_notifyd_client_death_cleanup",
        "no_n2c_2b_cross_process_client_death_observation",
        "no_bidirectional_notify_check_no_contamination_claim",
        "no_broad_libdispatch_thread_workqueue_parity",
        "no_generic_phase_085_authority",
        "no_certification_claim"
      ],
      satisfied_obligations: [
        "direct_launchd_notifyd_facts_for_n2c_1",
        "direct_kernel_receive_facts_for_n2c_2a",
        "notifyd_n2_concurrency_unidirectional_batch_for_n2c_3"
      ],
      open_obligations: [
        "n2c_2b_cross_process_client_death_observation",
        "notifyd_n2_series_closeout_after_n2c_2b"
      ],
      deferred_marker_families: %{
        n2c_2b: [
          "NOTIFYD_N2_MACH_SEND_DEAD_EVENT",
          "NOTIFYD_N2_PROC_SOURCE_EVENT",
          "SOURCE_CREATE_registered_name_to_DEAD_EVENT_registered_name_correlation"
        ]
      },
      raw_evidence_mutated: false,
      new_guest_run_for_authority_extraction: false
    }
  end

  def specs, do: local_specs() ++ imported_generic_specs()

  def local_specs do
    mach_send_specs() ++
      mach_raw_specs() ++
      mach_direct_specs() ++
      notify_trace_timeout_specs() ++ concurrency_specs()
  end

  def imported_generic_specs, do: launchd_handoff_specs()

  def launchd_handoff_binding do
    %{
      consumer: :notifyd_n2,
      generic_source: Phase085Handoff.authority_id(),
      service_name: "com.apple.system.notification_center",
      fixture_form: :boolean,
      identity_instrument: :notify_native_register_post_check,
      facts: %{
        checkin_response_materialized: %{
          markers: [
            generic_marker(
              :concurrency_launchd_checkin_request,
              %{checkin_response_present: true, successful_checkin: true}
            )
          ]
        },
        machservices_dictionary_present: %{
          markers: [
            generic_marker(
              :concurrency_launchd_mach_services_dict,
              %{machservices_dictionary_present: true}
            )
          ]
        },
        selected_service_entry_present: %{
          service_name: "com.apple.system.notification_center",
          markers: [
            generic_marker(:concurrency_launchd_service_entry, %{
              selected_service_entry_present: true,
              service_name: :parameterized
            })
          ]
        },
        receive_right_materialized: %{
          service_name: "com.apple.system.notification_center",
          markers: [
            generic_marker(:concurrency_launchd_receive_right, %{
              receive_right_materialized: true,
              receive_port: :positive_integer_or_equivalent_right_handle,
              service_name: :parameterized
            })
          ]
        }
      },
      local_specs: local_specs(),
      imported_specs: imported_generic_specs()
    }
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
      dispatch_notify_trace_timeout: spec!(:trace_terminal),
      concurrency: spec!(:concurrency_terminal)
    }
  end

  def phase_exit_lines do
    %{
      mach_send: "phase07_dispatch_mach_send_exit=0",
      mach_raw: "phase07_mach_dead_name_raw_exit=0",
      mach_direct: "phase07_mach_direct_kevent_exit=0",
      dispatch_notify_trace_timeout: "phase07_dispatch_notify_trace_exit=0",
      concurrency: "phase095a_notifyd_n2_concurrency_exit=0"
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
      ~r/KDB:\s+stack backtrace/i,
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

  defp concurrency_specs do
    [
      spec(
        :concurrency_launchd_terminal,
        :concurrency,
        "NOTIFYD_N2_LAUNCHD_CHECKIN_TERMINAL",
        %{status: eq("0")},
        :launchd_direct,
        :launchd,
        :terminal,
        5
      ),
      spec(
        :concurrency_start,
        :concurrency,
        "NOTIFYD_N2_CONCURRENCY_START",
        %{status: eq("0"), clients: eq("2")},
        :infrastructure,
        :harness,
        :orchestration,
        6
      ),
      spec(
        :concurrency_twq_before,
        :concurrency,
        "NOTIFYD_N2_TWQ_COUNTERS_BEFORE",
        %{workers: positive_integer(), source: eq("kern.smp.cpus")},
        :concurrency_unidirectional,
        :harness,
        :twq_observation,
        7
      ),
      min_spec(
        :concurrency_kernel_mach_msg_receive,
        :concurrency,
        "NOTIFYD_N2_KERNEL_MACH_MSG_RECEIVE",
        %{
          msgid: positive_integer(),
          local_port: positive_integer(),
          size: positive_integer(),
          trailer_type: eq("0")
        },
        :kernel_direct,
        :kernel,
        :mach_msg_receive,
        8,
        1
      ),
      min_spec(
        :concurrency_kernel_audit_trailer,
        :concurrency,
        "NOTIFYD_N2_KERNEL_AUDIT_TRAILER",
        %{
          msgid: positive_integer(),
          client_pid: positive_integer(),
          auid: integer(),
          euid: integer(),
          egid: integer(),
          trailer_size: positive_integer()
        },
        :kernel_direct,
        :kernel,
        :audit_trailer,
        9,
        1
      ),
      min_spec(
        :concurrency_proc_source_create,
        :concurrency,
        "NOTIFYD_N2_PROC_SOURCE_CREATE",
        %{pid: positive_integer(), source_created: eq("1")},
        :donor_dispatch_source,
        :donor,
        :proc_source_create,
        10,
        1
      ),
      spec(
        :concurrency_client_1_register,
        :concurrency,
        "NOTIFYD_N2_CONCURRENCY_REGISTER",
        %{
          client: eq("1"),
          name: eq("org.rmxos.notifyd.n2.concurrency.client_a"),
          token: nonnegative_integer(),
          status: eq("0")
        },
        :concurrency_unidirectional,
        :donor,
        :libnotify_register,
        11
      ),
      spec(
        :concurrency_client_2_register,
        :concurrency,
        "NOTIFYD_N2_CONCURRENCY_REGISTER",
        %{
          client: eq("2"),
          name: eq("org.rmxos.notifyd.n2.concurrency.client_b"),
          token: nonnegative_integer(),
          status: eq("0")
        },
        :concurrency_unidirectional,
        :donor,
        :libnotify_register,
        12
      ),
      spec(
        :concurrency_baseline_checks,
        :concurrency,
        "NOTIFYD_N2_CONCURRENCY_CHECK",
        %{
          phase: eq("baseline"),
          expected: eq("1"),
          observed: eq("1"),
          status: eq("0"),
          attempts: eq("1")
        },
        :concurrency_unidirectional,
        :donor,
        :notify_check_baseline,
        13,
        count: 2
      ),
      spec(
        :concurrency_twq_registered,
        :concurrency,
        "NOTIFYD_N2_TWQ_PROGRESS",
        %{point: eq("registered"), status: eq("0")},
        :concurrency_unidirectional,
        :harness,
        :twq_observation,
        14
      ),
      spec(
        :concurrency_dead_client_spawn,
        :concurrency,
        "NOTIFYD_N2_CONCURRENCY_CLIENT_SPAWN",
        %{client: eq("dead"), pid: positive_integer(), status: eq("0")},
        :infrastructure,
        :harness,
        :dead_client_orchestration,
        15
      ),
      spec(
        :concurrency_dead_client_port,
        :concurrency,
        "NOTIFYD_N2_CONCURRENCY_DEAD_CLIENT_PORT",
        %{kr: eq("0"), port: positive_integer()},
        :infrastructure,
        :harness,
        :dead_client_orchestration,
        16
      ),
      spec(
        :concurrency_dead_client_make_send,
        :concurrency,
        "NOTIFYD_N2_CONCURRENCY_DEAD_CLIENT_MAKE_SEND",
        %{kr: eq("0")},
        :infrastructure,
        :harness,
        :dead_client_orchestration,
        17
      ),
      spec(
        :concurrency_dead_client_register,
        :concurrency,
        "NOTIFYD_N2_CONCURRENCY_REGISTER",
        %{
          client: eq("dead"),
          name: eq("org.rmxos.notifyd.n2.concurrency.dead_client"),
          token: nonnegative_integer(),
          status: eq("0")
        },
        :concurrency_unidirectional,
        :donor,
        :libnotify_register,
        18
      ),
      spec(
        :concurrency_mach_send_source_create,
        :concurrency,
        "NOTIFYD_N2_MACH_SEND_SOURCE_CREATE",
        %{
          notify_port: positive_integer(),
          registered_name: positive_integer(),
          source_created: eq("1")
        },
        :donor_dispatch_source,
        :donor,
        :mach_send_source_create,
        19
      ),
      spec(
        :concurrency_posts,
        :concurrency,
        "NOTIFYD_N2_CONCURRENCY_POST",
        %{client: positive_integer(), name: notification_name(), status: eq("0")},
        :concurrency_unidirectional,
        :donor,
        :notify_post,
        20,
        count: 3
      ),
      spec(
        :concurrency_target_checks,
        :concurrency,
        "NOTIFYD_N2_CONCURRENCY_CHECK",
        %{
          phase: eq("target"),
          expected: eq("1"),
          observed: eq("1"),
          status: eq("0"),
          attempts: positive_integer()
        },
        :concurrency_unidirectional,
        :donor,
        :notify_check_target,
        21,
        count: 3
      ),
      spec(
        :concurrency_check_samples,
        :concurrency,
        "NOTIFYD_N2_CONCURRENCY_CHECK_SAMPLE",
        %{
          reason: eq("nontarget"),
          observed: zero_or_one(),
          status: eq("0"),
          allowed_false_positive: eq("1")
        },
        :concurrency_unidirectional,
        :harness,
        :notify_check_false_positive_sample,
        22,
        count: 3
      ),
      spec(
        :concurrency_cancel,
        :concurrency,
        "NOTIFYD_N2_CONCURRENCY_CANCEL",
        %{client: eq("1"), token: nonnegative_integer(), status: eq("0")},
        :concurrency_unidirectional,
        :donor,
        :notify_cancel,
        23
      ),
      spec(
        :concurrency_dead_client_exit,
        :concurrency,
        "NOTIFYD_N2_CONCURRENCY_CLIENT_EXIT",
        %{client: eq("dead"), pid: positive_integer(), status: eq("0")},
        :infrastructure,
        :harness,
        :dead_client_orchestration,
        24
      ),
      spec(
        :concurrency_twq_after,
        :concurrency,
        "NOTIFYD_N2_TWQ_COUNTERS_AFTER",
        %{workers: positive_integer(), source: eq("kern.smp.cpus")},
        :concurrency_unidirectional,
        :harness,
        :twq_observation,
        25
      ),
      spec(
        :concurrency_twq_final,
        :concurrency,
        "NOTIFYD_N2_TWQ_PROGRESS",
        %{point: eq("final"), status: eq("0")},
        :concurrency_unidirectional,
        :harness,
        :twq_observation,
        26
      ),
      spec(
        :concurrency_final_counts,
        :concurrency,
        "NOTIFYD_N2_CONCURRENCY_FINAL_COUNTS",
        %{
          clients: eq("2"),
          posts: eq("3"),
          baseline_checks: eq("2"),
          target_checks: eq("3"),
          samples: eq("3"),
          checks: eq("8"),
          cancels: eq("1"),
          dead_clients: eq("1"),
          status: eq("0")
        },
        :concurrency_unidirectional,
        :harness,
        :summary,
        27
      ),
      spec(
        :concurrency_terminal,
        :concurrency,
        "NOTIFYD_N2_CONCURRENCY_TERMINAL",
        %{status: eq("0")},
        :terminal,
        :harness,
        :terminal,
        28
      )
    ]
  end

  defp launchd_handoff_specs do
    [
      imported_spec(
        :concurrency_launchd_checkin_request,
        :checkin_response_materialized,
        :concurrency,
        "NOTIFYD_N2_LAUNCHD_CHECKIN_REQUEST",
        %{kr: eq("0"), result: eq("dict")},
        :launch_msg_checkin,
        %{checkin_response_present: true, successful_checkin: true},
        1
      ),
      imported_spec(
        :concurrency_launchd_mach_services_dict,
        :machservices_dictionary_present,
        :concurrency,
        "NOTIFYD_N2_LAUNCHD_MACH_SERVICES_DICT",
        %{present: eq("1"), type: eq("dict")},
        :mach_services_dictionary,
        %{machservices_dictionary_present: true},
        2
      ),
      imported_spec(
        :concurrency_launchd_service_entry,
        :selected_service_entry_present,
        :concurrency,
        "NOTIFYD_N2_LAUNCHD_SERVICE_ENTRY",
        %{
          service: eq("com.apple.system.notification_center"),
          present: eq("1"),
          type: eq("machport")
        },
        :mach_services_entry,
        %{selected_service_entry_present: true, service_name: :parameterized},
        3,
        service_name: "com.apple.system.notification_center"
      ),
      imported_spec(
        :concurrency_launchd_receive_right,
        :receive_right_materialized,
        :concurrency,
        "NOTIFYD_N2_LAUNCHD_RECEIVE_RIGHT",
        %{
          service: eq("com.apple.system.notification_center"),
          port: positive_integer(),
          right: eq("receive")
        },
        :receive_right,
        %{
          receive_right_materialized: true,
          receive_port: :positive_integer_or_equivalent_right_handle,
          service_name: :parameterized
        },
        4,
        service_name: "com.apple.system.notification_center"
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
      ),
      line(
        :concurrency_phase_exit,
        :concurrency,
        "phase095a_notifyd_n2_concurrency_exit=0",
        29
      ),
      line(
        :concurrency_end_banner,
        :concurrency,
        "=== phase095a notifyd n2 concurrency end rc=0 ===",
        30
      )
    ]
  end

  defp generic_marker(spec_id, generic_policy) do
    spec = spec!(spec_id)

    %{
      id: spec.id,
      key: spec.key,
      producer: spec.producer,
      producer_detail: spec.producer_detail,
      generic_source: spec.generic_source,
      generic_fact_id: spec.generic_fact_id,
      generic_policy: generic_policy
    }
  end

  defp imported_spec(
         id,
         generic_fact_id,
         family,
         key,
         fields,
         producer_detail,
         generic_policy,
         order,
         opts \\ []
       ) do
    spec(
      id,
      family,
      key,
      fields,
      :launchd_direct,
      :launchd,
      producer_detail,
      order,
      opts
    )
    |> Map.merge(%{
      generic_source: Phase085Handoff.authority_id(),
      generic_fact_id: generic_fact_id,
      generic_policy: generic_policy,
      service_name: Keyword.get(opts, :service_name)
    })
  end

  defp spec(id, family, key, fields, role, producer, detail, order, opts \\ []) do
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
      order: order,
      count_policy: :exact,
      count: Keyword.get(opts, :count, 1)
    }
  end

  defp min_spec(id, family, key, fields, role, producer, detail, order, minimum) do
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
      order: order,
      count_policy: :minimum,
      count: minimum
    }
  end

  defp line(id, family, text, order) do
    %{id: id, kind: :exact_line, family: family, line: text, ordered: true, order: order}
  end

  defp eq(value), do: {:eq, value}

  defp notification_name,
    do:
      {:one_of,
       ["org.rmxos.notifyd.n2.concurrency.client_a", "org.rmxos.notifyd.n2.concurrency.client_b"]}

  defp zero_or_one, do: {:one_of, ["0", "1"]}
  defp positive_integer, do: :positive_integer
  defp nonnegative_integer, do: :nonnegative_integer
  defp integer, do: :integer
end
