defmodule RmxOSOracle.Notifyd.N1.MarkerManifest do
  @moduledoc """
  Oracle-owned notifyd N1 marker authority extracted from accepted runtime evidence.

  Closeout/provenance:

  * accepted claim: donor libnotify lookup/version/register/post/check path for
    `com.apple.system.notification_center`, with generated notify MIG delivery,
    a fresh poster `_notify_server_post_4`, notifyd server post entry/return,
    and fresh shared-memory observation
  * non-claims: no N2 concurrency, no MACH_SEND runtime behavior, no direct
    launchd check-in dictionary or receive-right marker, no kernel audit-trailer
    facts, no generic Phase 0.85 authority, no certification claim
  * accepted evidence:
    `priv/runs/notifyd-n1/20260610T072550Z-notification-center-second-replacement`
  * accepted serial SHA256:
    `5a6a743e435a2e835734f8ddd197c71cf8bfd36f99f28cd8b95ea2205a5d3dde`
  * raw six-file evidence tree digest before post-hoc artifacts:
    `6f58346344fe81f64204dd14af53f85936fdd1510f634bd80016539426b3f639`
  * runtime binary, kernel, and guest-image hashes were not captured during the
    accepted run and must not be backfilled from mutable host paths.

  N1 has only indirect launchd handoff attestation: reduced fixture import,
  donor-bootstrap harness success, SETEXEC_COMPAT bridge witness, and donor
  libnotify lookup success. It deliberately does not promote ASL A2 launchd
  facts or future Phase 0.85 facts into notifyd N1.
  """

  @accepted_claim "notifyd_n1_notification_center_lookup_post_observe"
  @accepted_evidence_dir "priv/runs/notifyd-n1/20260610T072550Z-notification-center-second-replacement"
  @accepted_serial_sha256 "5a6a743e435a2e835734f8ddd197c71cf8bfd36f99f28cd8b95ea2205a5d3dde"
  @raw_evidence_tree_digest "6f58346344fe81f64204dd14af53f85936fdd1510f634bd80016539426b3f639"
  @accepted_source_pin "230d2284d8547edfd8d2b63f36ce3d3737d7524d"
  @runtime_scaffold_pin "ff78566aef26798f3f0b9878539a2e2279dfd9dc"
  @source_closeout_pin "7ed745400a640ca292a2944c3ff0ae08c5b97fdc"
  @service_name "com.apple.system.notification_center"
  @notify_name "org.rmxos.phase095a.notifyd.n1"
  @client_guest_path "/root/nxplatform/notifyd/notifyd-n1-client"
  @fixture_guest_path "/root/nxplatform/phase1/org.rmxos.notifyd.n1.notification-center.plist"

  @roles [
    :indirect_handoff_attestation,
    :donor_lookup,
    :version_triplet,
    :registration,
    :baseline_consumption,
    :fresh_poster_post,
    :generated_mig_delivery,
    :server_post,
    :shared_memory_observation,
    :terminal,
    :infrastructure,
    :summary
  ]

  @producers [:donor, :harness]

  @raw_evidence_files [
    "preflight.log",
    "run-guest.host.log",
    "run-guest.rc",
    "run-provenance.env",
    "serial.log",
    "stage.log"
  ]

  def accepted_claim, do: @accepted_claim
  def accepted_evidence_dir, do: @accepted_evidence_dir
  def accepted_serial_sha256, do: @accepted_serial_sha256
  def raw_evidence_tree_digest, do: @raw_evidence_tree_digest
  def accepted_source_pin, do: @accepted_source_pin
  def runtime_scaffold_pin, do: @runtime_scaffold_pin
  def source_closeout_pin, do: @source_closeout_pin
  def service_name, do: @service_name
  def notify_name, do: @notify_name
  def client_guest_path, do: @client_guest_path
  def fixture_guest_path, do: @fixture_guest_path
  def roles, do: @roles
  def producers, do: @producers
  def raw_evidence_files, do: @raw_evidence_files

  def closeout do
    %{
      accepted_claim: @accepted_claim,
      accepted_evidence_path: @accepted_evidence_dir,
      accepted_serial_sha256: @accepted_serial_sha256,
      raw_evidence_tree_digest: @raw_evidence_tree_digest,
      source_pins: %{
        accepted_source_pin: @accepted_source_pin,
        runtime_scaffold_pin: @runtime_scaffold_pin,
        source_closeout_pin: @source_closeout_pin
      },
      non_claims: [
        "no_n2_concurrency",
        "no_mach_send_runtime_smoke",
        "no_direct_launchd_checkin_dictionary_or_receive_right_marker",
        "no_kernel_audit_trailer_facts",
        "no_generic_phase_085_authority",
        "no_certification_claim"
      ],
      provenance_limitations: [
        "runtime binary hashes were not captured during the accepted run",
        "kernel hash was not captured during the accepted run",
        "guest image hash was not captured during the accepted run",
        "missing hashes must not be backfilled from current host paths"
      ],
      handoff_attestation: %{
        mode: "indirect",
        accepted_witnesses: [
          "reduced notifyd MachServices fixture import",
          "donor-bootstrap harness success",
          "SETEXEC_COMPAT bridge witness",
          "donor libnotify lookup success"
        ],
        absent_facts: [
          "direct launchd-produced check-in dictionary marker",
          "direct launchd-produced receive-right marker",
          "kernel audit-trailer marker"
        ]
      },
      raw_evidence_mutated: false,
      runtime_evidence_count: 1
    }
  end

  def specs do
    indirect_handoff_specs() ++
      parent_client_specs() ++
      poster_specs() ++
      fresh_observation_specs() ++
      terminal_specs()
  end

  def marker_keys do
    specs()
    |> Enum.map(& &1.key)
    |> Enum.uniq()
  end

  def marker_literals do
    specs()
    |> Enum.map(& &1.key)
    |> Enum.uniq()
  end

  def spec!(id) when is_atom(id) do
    Enum.find(specs(), &(&1.id == id)) ||
      raise ArgumentError, "unknown notifyd N1 marker id: #{inspect(id)}"
  end

  def key!(id), do: spec!(id).key
  def fields!(id), do: spec!(id).fields

  def required_order do
    [
      :ldd_begin,
      :ldd_end,
      :client_start,
      :parent_lookup_before,
      :parent_lookup_after,
      :parent_version_register_plain_user_before,
      :parent_version_register_plain_server_before,
      :parent_version_register_plain_server_after,
      :parent_version_register_plain_user_after,
      :parent_version_get_state_user_before,
      :parent_version_get_state_server_before,
      :parent_version_get_state_server_after,
      :parent_version_get_state_user_after,
      :parent_version_cancel_user_before,
      :parent_version_cancel_server_before,
      :parent_version_cancel_server_after,
      :parent_version_cancel_user_after,
      :parent_register_check_user_before,
      :parent_register_check_server_before,
      :parent_register_check_server_after,
      :parent_register_check_user_after,
      :parent_register_check_status,
      :observer_register_check_user_before,
      :observer_register_check_server_before,
      :observer_register_check_server_after,
      :observer_register_check_user_after,
      :observer_register_check_status,
      :parent_baseline_check,
      :observer_baseline_check,
      :baseline_consumed,
      :poster_spawn,
      :poster_start,
      :poster_lookup_before,
      :poster_lookup_after,
      :poster_version_register_plain_user_before,
      :poster_version_register_plain_server_before,
      :poster_version_register_plain_server_after,
      :poster_version_register_plain_user_after,
      :poster_version_get_state_user_before,
      :poster_version_get_state_server_before,
      :poster_version_get_state_server_after,
      :poster_version_get_state_user_after,
      :poster_version_cancel_user_before,
      :poster_version_cancel_server_before,
      :poster_version_cancel_server_after,
      :poster_version_cancel_user_after,
      :poster_post_user_before,
      :poster_post_user_after,
      :poster_post_status,
      :poster_terminal,
      :poster_post_server_before,
      :poster_wait_status,
      :server_post_entry,
      :server_post_return,
      :poster_post_server_after,
      :client_poster_status,
      :client_check_status,
      :shared_memory_observation,
      :second_check_observation,
      :observer_cancel_status,
      :client_cancel_status,
      :fresh_observation,
      :terminal
    ]
  end

  def ordered_specs do
    Enum.map(required_order(), &spec!/1)
  end

  def indirect_attestation_lines do
    [
      "phase1_launchd_harness_mode=donor-bootstrap",
      "launchd donor-bootstrap harness: fixture_import label=com.apple.notifyd",
      "launchd donor-bootstrap harness: fixture path=#{@fixture_guest_path} imported",
      "LAUNCHD_DONOR_BOOTSTRAP_POSIX_SPAWN_SETEXEC_COMPAT=direct_exec label=com.apple.notifyd",
      "launchd donor-bootstrap harness: client status=0",
      "launchd donor-bootstrap harness: launchd_runtime_init2() returned rc=0",
      "=== phase1 launchd harness end rc=0 ==="
    ]
  end

  def terminal_contract do
    %{
      run_guest_rc_normalization:
        "run-guest.rc=1 is acceptable only with NOTIFYD_N1_TERMINAL status=0 and the launchd harness end rc=0 marker",
      terminal_spec: spec!(:terminal),
      harness_end_marker: "=== phase1 launchd harness end rc=0 ==="
    }
  end

  def negative_control_contracts do
    [
      %{
        id: "missing_terminal",
        class: :terminal,
        expected_error: "missing field record terminal"
      },
      %{id: "duplicate_terminal", class: :terminal, expected_error: "duplicate terminal"},
      %{id: "invalid_order", class: :order, expected_error: "order violation"},
      %{
        id: "missing_server_post_entry",
        class: :receipt,
        expected_error: "missing field record server_post_entry"
      },
      %{
        id: "server_post_return_wrong_status",
        class: :receipt,
        expected_error: "wrong field server_post_return.status"
      },
      %{
        id: "wrong_service_name",
        class: :service_name,
        expected_error: "wrong field parent_lookup_before.service"
      },
      %{
        id: "fresh_observation_missing",
        class: :receipt,
        expected_error: "missing field record fresh_observation"
      },
      %{
        id: "token_pairing_drift",
        class: :pairing,
        expected_error: "wrong field shared_memory_observation.token"
      },
      %{id: "rc_one_without_terminal", class: :rc, expected_error: "rc normalization failed"},
      %{id: "rc_one_without_harness_end", class: :rc, expected_error: "rc normalization failed"}
    ]
  end

  def producer_breakdown do
    specs()
    |> Enum.frequencies_by(& &1.producer)
    |> Map.new()
  end

  def role_breakdown do
    specs()
    |> Enum.frequencies_by(& &1.role)
    |> Map.new()
  end

  defp indirect_handoff_specs do
    [
      spec(:ldd_begin, "NOTIFYD_N1_LDD_BEGIN", %{}, :infrastructure, :harness, :ldd),
      spec(:ldd_end, "NOTIFYD_N1_LDD_END", %{}, :infrastructure, :harness, :ldd)
    ]
  end

  defp parent_client_specs do
    [
      spec(
        :client_start,
        "NOTIFYD_N1_CLIENT_START",
        %{name: eq(@notify_name)},
        :infrastructure,
        :harness,
        :client_probe
      ),
      lookup_spec(:parent_lookup_before, "NOTIFYD_N1_LOOKUP_BEFORE"),
      lookup_after_spec(:parent_lookup_after, "NOTIFYD_N1_LOOKUP_AFTER"),
      mig(
        :parent_version_register_plain_user_before,
        "NOTIFYD_N1_MIG_USER_SEND",
        "before",
        "rpc",
        "78945669",
        "_notify_server_register_plain",
        :version_triplet
      ),
      mig(
        :parent_version_register_plain_server_before,
        "NOTIFYD_N1_MIG_SERVER_RCV",
        "before",
        "rpc",
        "78945669",
        "_notify_server_register_plain",
        :version_triplet
      ),
      mig(
        :parent_version_register_plain_server_after,
        "NOTIFYD_N1_MIG_SERVER_RCV",
        "after",
        "rpc",
        "78945669",
        "_notify_server_register_plain",
        :version_triplet
      ),
      mig(
        :parent_version_register_plain_user_after,
        "NOTIFYD_N1_MIG_USER_SEND",
        "after",
        "rpc",
        "78945669",
        "_notify_server_register_plain",
        :version_triplet
      ),
      mig(
        :parent_version_get_state_user_before,
        "NOTIFYD_N1_MIG_USER_SEND",
        "before",
        "rpc",
        "78945681",
        "_notify_server_get_state",
        :version_triplet
      ),
      mig(
        :parent_version_get_state_server_before,
        "NOTIFYD_N1_MIG_SERVER_RCV",
        "before",
        "rpc",
        "78945681",
        "_notify_server_get_state",
        :version_triplet
      ),
      mig(
        :parent_version_get_state_server_after,
        "NOTIFYD_N1_MIG_SERVER_RCV",
        "after",
        "rpc",
        "78945681",
        "_notify_server_get_state",
        :version_triplet
      ),
      mig(
        :parent_version_get_state_user_after,
        "NOTIFYD_N1_MIG_USER_SEND",
        "after",
        "rpc",
        "78945681",
        "_notify_server_get_state",
        :version_triplet
      ),
      mig(
        :parent_version_cancel_user_before,
        "NOTIFYD_N1_MIG_USER_SEND",
        "before",
        "rpc",
        "78945679",
        "_notify_server_cancel",
        :version_triplet
      ),
      mig(
        :parent_version_cancel_server_before,
        "NOTIFYD_N1_MIG_SERVER_RCV",
        "before",
        "rpc",
        "78945679",
        "_notify_server_cancel",
        :version_triplet
      ),
      mig(
        :parent_version_cancel_server_after,
        "NOTIFYD_N1_MIG_SERVER_RCV",
        "after",
        "rpc",
        "78945679",
        "_notify_server_cancel",
        :version_triplet
      ),
      mig(
        :parent_version_cancel_user_after,
        "NOTIFYD_N1_MIG_USER_SEND",
        "after",
        "rpc",
        "78945679",
        "_notify_server_cancel",
        :version_triplet
      ),
      mig(
        :parent_register_check_user_before,
        "NOTIFYD_N1_MIG_USER_SEND",
        "before",
        "rpc",
        "78945695",
        "_notify_server_register_check_2",
        :registration
      ),
      mig(
        :parent_register_check_server_before,
        "NOTIFYD_N1_MIG_SERVER_RCV",
        "before",
        "rpc",
        "78945695",
        "_notify_server_register_check_2",
        :registration
      ),
      mig(
        :parent_register_check_server_after,
        "NOTIFYD_N1_MIG_SERVER_RCV",
        "after",
        "rpc",
        "78945695",
        "_notify_server_register_check_2",
        :registration
      ),
      mig(
        :parent_register_check_user_after,
        "NOTIFYD_N1_MIG_USER_SEND",
        "after",
        "rpc",
        "78945695",
        "_notify_server_register_check_2",
        :registration
      ),
      spec(
        :parent_register_check_status,
        "NOTIFYD_N1_CLIENT_REGISTER_CHECK_STATUS",
        %{status: eq("0"), token: eq("0")},
        :registration,
        :donor,
        :libnotify_client
      ),
      mig(
        :observer_register_check_user_before,
        "NOTIFYD_N1_MIG_USER_SEND",
        "before",
        "rpc",
        "78945695",
        "_notify_server_register_check_2",
        :registration
      ),
      mig(
        :observer_register_check_server_before,
        "NOTIFYD_N1_MIG_SERVER_RCV",
        "before",
        "rpc",
        "78945695",
        "_notify_server_register_check_2",
        :registration
      ),
      mig(
        :observer_register_check_server_after,
        "NOTIFYD_N1_MIG_SERVER_RCV",
        "after",
        "rpc",
        "78945695",
        "_notify_server_register_check_2",
        :registration
      ),
      mig(
        :observer_register_check_user_after,
        "NOTIFYD_N1_MIG_USER_SEND",
        "after",
        "rpc",
        "78945695",
        "_notify_server_register_check_2",
        :registration
      ),
      spec(
        :observer_register_check_status,
        "NOTIFYD_N1_CLIENT_OBSERVER_REGISTER_CHECK_STATUS",
        %{status: eq("0"), token: eq("1")},
        :registration,
        :donor,
        :libnotify_client
      ),
      spec(
        :parent_baseline_check,
        "NOTIFYD_N1_CLIENT_BASELINE_CHECK_STATUS",
        %{status: eq("0"), token: eq("0"), check: eq("1")},
        :baseline_consumption,
        :donor,
        :libnotify_client
      ),
      spec(
        :observer_baseline_check,
        "NOTIFYD_N1_OBSERVER_BASELINE_CHECK_STATUS",
        %{status: eq("0"), token: eq("1"), check: eq("1")},
        :baseline_consumption,
        :donor,
        :libnotify_client
      ),
      spec(
        :baseline_consumed,
        "NOTIFYD_N1_SHM_BASELINE_CONSUMED",
        %{
          token: eq("0"),
          baseline_check: eq("1"),
          observer_token: eq("1"),
          observer_baseline_check: eq("1")
        },
        :baseline_consumption,
        :harness,
        :orchestration
      ),
      spec(
        :poster_spawn,
        "NOTIFYD_N1_POSTER_SPAWN",
        %{path: eq(@client_guest_path), name: eq(@notify_name)},
        :fresh_poster_post,
        :harness,
        :orchestration
      )
    ]
  end

  defp poster_specs do
    [
      spec(
        :poster_start,
        "NOTIFYD_N1_POSTER_START",
        %{name: eq(@notify_name)},
        :fresh_poster_post,
        :harness,
        :client_probe
      ),
      lookup_spec(:poster_lookup_before, "NOTIFYD_N1_LOOKUP_BEFORE"),
      lookup_after_spec(:poster_lookup_after, "NOTIFYD_N1_LOOKUP_AFTER"),
      mig(
        :poster_version_register_plain_user_before,
        "NOTIFYD_N1_MIG_USER_SEND",
        "before",
        "rpc",
        "78945669",
        "_notify_server_register_plain",
        :version_triplet
      ),
      mig(
        :poster_version_register_plain_server_before,
        "NOTIFYD_N1_MIG_SERVER_RCV",
        "before",
        "rpc",
        "78945669",
        "_notify_server_register_plain",
        :version_triplet
      ),
      mig(
        :poster_version_register_plain_server_after,
        "NOTIFYD_N1_MIG_SERVER_RCV",
        "after",
        "rpc",
        "78945669",
        "_notify_server_register_plain",
        :version_triplet
      ),
      mig(
        :poster_version_register_plain_user_after,
        "NOTIFYD_N1_MIG_USER_SEND",
        "after",
        "rpc",
        "78945669",
        "_notify_server_register_plain",
        :version_triplet
      ),
      mig(
        :poster_version_get_state_user_before,
        "NOTIFYD_N1_MIG_USER_SEND",
        "before",
        "rpc",
        "78945681",
        "_notify_server_get_state",
        :version_triplet
      ),
      mig(
        :poster_version_get_state_server_before,
        "NOTIFYD_N1_MIG_SERVER_RCV",
        "before",
        "rpc",
        "78945681",
        "_notify_server_get_state",
        :version_triplet
      ),
      mig(
        :poster_version_get_state_server_after,
        "NOTIFYD_N1_MIG_SERVER_RCV",
        "after",
        "rpc",
        "78945681",
        "_notify_server_get_state",
        :version_triplet
      ),
      mig(
        :poster_version_get_state_user_after,
        "NOTIFYD_N1_MIG_USER_SEND",
        "after",
        "rpc",
        "78945681",
        "_notify_server_get_state",
        :version_triplet
      ),
      mig(
        :poster_version_cancel_user_before,
        "NOTIFYD_N1_MIG_USER_SEND",
        "before",
        "rpc",
        "78945679",
        "_notify_server_cancel",
        :version_triplet
      ),
      mig(
        :poster_version_cancel_server_before,
        "NOTIFYD_N1_MIG_SERVER_RCV",
        "before",
        "rpc",
        "78945679",
        "_notify_server_cancel",
        :version_triplet
      ),
      mig(
        :poster_version_cancel_server_after,
        "NOTIFYD_N1_MIG_SERVER_RCV",
        "after",
        "rpc",
        "78945679",
        "_notify_server_cancel",
        :version_triplet
      ),
      mig(
        :poster_version_cancel_user_after,
        "NOTIFYD_N1_MIG_USER_SEND",
        "after",
        "rpc",
        "78945679",
        "_notify_server_cancel",
        :version_triplet
      ),
      mig(
        :poster_post_user_before,
        "NOTIFYD_N1_MIG_USER_SEND",
        "before",
        "simple",
        "78945693",
        "_notify_server_post_4",
        :fresh_poster_post
      ),
      mig(
        :poster_post_user_after,
        "NOTIFYD_N1_MIG_USER_SEND",
        "after",
        "simple",
        "78945693",
        "_notify_server_post_4",
        :fresh_poster_post
      ),
      spec(
        :poster_post_status,
        "NOTIFYD_N1_POSTER_POST_STATUS",
        %{status: eq("0")},
        :fresh_poster_post,
        :donor,
        :libnotify_client
      ),
      spec(
        :poster_terminal,
        "NOTIFYD_N1_POSTER_TERMINAL",
        %{status: eq("0")},
        :fresh_poster_post,
        :harness,
        :orchestration
      ),
      mig(
        :poster_post_server_before,
        "NOTIFYD_N1_MIG_SERVER_RCV",
        "before",
        "simple",
        "78945693",
        "_notify_server_post_4",
        :generated_mig_delivery
      ),
      spec(
        :poster_wait_status,
        "NOTIFYD_N1_POSTER_WAIT_STATUS",
        %{exited: eq("1"), status: eq("0")},
        :fresh_poster_post,
        :harness,
        :orchestration
      ),
      spec(
        :server_post_entry,
        "NOTIFYD_N1_SERVER_POST_ENTRY",
        %{name: eq(@notify_name), uid: eq("0"), gid: eq("0")},
        :server_post,
        :donor,
        :notifyd_server
      ),
      spec(
        :server_post_return,
        "NOTIFYD_N1_SERVER_POST_RETURN",
        %{name: eq(@notify_name), status: eq("0")},
        :server_post,
        :donor,
        :notifyd_server
      ),
      mig(
        :poster_post_server_after,
        "NOTIFYD_N1_MIG_SERVER_RCV",
        "after",
        "simple",
        "78945693",
        "_notify_server_post_4",
        :generated_mig_delivery
      ),
      spec(
        :client_poster_status,
        "NOTIFYD_N1_CLIENT_POSTER_STATUS",
        %{status: eq("0")},
        :fresh_poster_post,
        :harness,
        :orchestration
      )
    ]
  end

  defp fresh_observation_specs do
    [
      spec(
        :client_check_status,
        "NOTIFYD_N1_CLIENT_CHECK_STATUS",
        %{status: eq("0"), token: eq("0"), check: eq("1")},
        :shared_memory_observation,
        :donor,
        :libnotify_client
      ),
      spec(
        :shared_memory_observation,
        "NOTIFYD_N1_SHM_OBSERVATION",
        %{token: eq("0"), check: eq("1")},
        :shared_memory_observation,
        :harness,
        :shared_memory
      ),
      spec(
        :second_check_observation,
        "NOTIFYD_N1_SECOND_CHECK_OBSERVATION",
        %{status: eq("0"), token: eq("1"), check: eq("1")},
        :shared_memory_observation,
        :donor,
        :libnotify_client
      ),
      spec(
        :observer_cancel_status,
        "NOTIFYD_N1_CLIENT_OBSERVER_CANCEL_STATUS",
        %{status: eq("0"), token: eq("1")},
        :registration,
        :donor,
        :libnotify_client
      ),
      spec(
        :client_cancel_status,
        "NOTIFYD_N1_CLIENT_CANCEL_STATUS",
        %{status: eq("0"), token: eq("0")},
        :registration,
        :donor,
        :libnotify_client
      ),
      spec(
        :fresh_observation,
        "NOTIFYD_N1_SHM_FRESH_OBSERVATION",
        %{
          baseline_check: eq("1"),
          observer_baseline_check: eq("1"),
          check: eq("1"),
          observer_check: eq("1")
        },
        :shared_memory_observation,
        :harness,
        :shared_memory
      )
    ]
  end

  defp terminal_specs do
    [
      spec(
        :terminal,
        "NOTIFYD_N1_TERMINAL",
        %{
          status: eq("0"),
          baseline_check: eq("1"),
          observer_baseline_check: eq("1"),
          check: eq("1"),
          observer_check: eq("1")
        },
        :terminal,
        :harness,
        :orchestration
      )
    ]
  end

  defp lookup_spec(id, key) do
    spec(
      id,
      key,
      %{service: eq(@service_name), target_pid: eq("0"), flags: eq("8")},
      :donor_lookup,
      :donor,
      :libnotify_lookup
    )
  end

  defp lookup_after_spec(id, key) do
    spec(
      id,
      key,
      %{service: eq(@service_name), kr: eq("0"), port: positive_integer()},
      :donor_lookup,
      :donor,
      :libnotify_lookup
    )
  end

  defp mig(id, key, phase, kind, msgid, name, role) do
    producer = if String.ends_with?(key, "SERVER_RCV"), do: :donor, else: :harness

    spec(
      id,
      key,
      %{phase: eq(phase), kind: eq(kind), msgid: eq(msgid), name: eq(name)},
      role,
      producer,
      :generated_notify_mig
    )
  end

  defp spec(id, key, fields, role, producer, producer_detail) do
    %{
      id: id,
      key: key,
      fields: stringify_field_keys(fields),
      role: role,
      producer: producer,
      producer_detail: producer_detail,
      required: true
    }
  end

  defp stringify_field_keys(fields) do
    Map.new(fields, fn {key, value} -> {to_string(key), value} end)
  end

  defp eq(value), do: %{policy: :must_equal, value: value}
  defp positive_integer, do: %{policy: :must_be_positive_integer}
end
