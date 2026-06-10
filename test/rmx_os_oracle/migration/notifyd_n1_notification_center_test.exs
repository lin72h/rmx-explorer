defmodule RmxOSOracle.Migration.NotifydN1NotificationCenterTest do
  use ExUnit.Case, async: true

  alias RmxOSOracle.Migration.NotifydN1NotificationCenter
  alias RmxOSOracle.Notifyd.N1.{ContractCheck, MarkerManifest}

  @valid_serial """
  WARNING: WITNESS option enabled, expect reduced performance.
  mach_module=loaded
  phase1_launchd_harness_mode=donor-bootstrap
  NOTIFYD_N1_LDD_BEGIN
  NOTIFYD_N1_LDD_END
  launchd donor-bootstrap harness: fixture_import label=com.apple.notifyd imported=0x13060382a280 import_errno=9 found=0x13060382a280
  launchd donor-bootstrap harness: fixture path=/root/nxplatform/phase1/org.rmxos.notifyd.n1.notification-center.plist imported
  LAUNCHD_DONOR_BOOTSTRAP_POSIX_SPAWN_SETEXEC_COMPAT=direct_exec label=com.apple.notifyd
  NOTIFYD_N1_CLIENT_START name=org.rmxos.phase095a.notifyd.n1
  NOTIFYD_N1_LOOKUP_BEFORE service=com.apple.system.notification_center target_pid=0 flags=8
  NOTIFYD_N1_LOOKUP_AFTER service=com.apple.system.notification_center kr=0 port=21
  NOTIFYD_N1_MIG_USER_SEND phase=before kind=rpc msgid=78945669 name=_notify_server_register_plain
  NOTIFYD_N1_MIG_SERVER_RCV phase=before kind=rpc msgid=78945669 name=_notify_server_register_plain
  NOTIFYD_N1_MIG_SERVER_RCV phase=after kind=rpc msgid=78945669 name=_notify_server_register_plain
  NOTIFYD_N1_MIG_USER_SEND phase=after kind=rpc msgid=78945669 name=_notify_server_register_plain
  NOTIFYD_N1_MIG_USER_SEND phase=before kind=rpc msgid=78945681 name=_notify_server_get_state
  NOTIFYD_N1_MIG_SERVER_RCV phase=before kind=rpc msgid=78945681 name=_notify_server_get_state
  NOTIFYD_N1_MIG_SERVER_RCV phase=after kind=rpc msgid=78945681 name=_notify_server_get_state
  NOTIFYD_N1_MIG_USER_SEND phase=after kind=rpc msgid=78945681 name=_notify_server_get_state
  NOTIFYD_N1_MIG_USER_SEND phase=before kind=rpc msgid=78945679 name=_notify_server_cancel
  NOTIFYD_N1_MIG_SERVER_RCV phase=before kind=rpc msgid=78945679 name=_notify_server_cancel
  NOTIFYD_N1_MIG_SERVER_RCV phase=after kind=rpc msgid=78945679 name=_notify_server_cancel
  NOTIFYD_N1_MIG_USER_SEND phase=after kind=rpc msgid=78945679 name=_notify_server_cancel
  NOTIFYD_N1_MIG_USER_SEND phase=before kind=rpc msgid=78945695 name=_notify_server_register_check_2
  NOTIFYD_N1_MIG_SERVER_RCV phase=before kind=rpc msgid=78945695 name=_notify_server_register_check_2
  NOTIFYD_N1_MIG_SERVER_RCV phase=after kind=rpc msgid=78945695 name=_notify_server_register_check_2
  NOTIFYD_N1_MIG_USER_SEND phase=after kind=rpc msgid=78945695 name=_notify_server_register_check_2
  NOTIFYD_N1_CLIENT_REGISTER_CHECK_STATUS status=0 token=0
  NOTIFYD_N1_MIG_USER_SEND phase=before kind=rpc msgid=78945695 name=_notify_server_register_check_2
  NOTIFYD_N1_MIG_SERVER_RCV phase=before kind=rpc msgid=78945695 name=_notify_server_register_check_2
  NOTIFYD_N1_MIG_SERVER_RCV phase=after kind=rpc msgid=78945695 name=_notify_server_register_check_2
  NOTIFYD_N1_MIG_USER_SEND phase=after kind=rpc msgid=78945695 name=_notify_server_register_check_2
  NOTIFYD_N1_CLIENT_OBSERVER_REGISTER_CHECK_STATUS status=0 token=1
  NOTIFYD_N1_CLIENT_BASELINE_CHECK_STATUS status=0 token=0 check=1
  NOTIFYD_N1_OBSERVER_BASELINE_CHECK_STATUS status=0 token=1 check=1
  NOTIFYD_N1_SHM_BASELINE_CONSUMED token=0 baseline_check=1 observer_token=1 observer_baseline_check=1
  NOTIFYD_N1_POSTER_SPAWN path=/root/nxplatform/notifyd/notifyd-n1-client name=org.rmxos.phase095a.notifyd.n1
  NOTIFYD_N1_POSTER_START name=org.rmxos.phase095a.notifyd.n1
  NOTIFYD_N1_LOOKUP_BEFORE service=com.apple.system.notification_center target_pid=0 flags=8
  NOTIFYD_N1_LOOKUP_AFTER service=com.apple.system.notification_center kr=0 port=21
  NOTIFYD_N1_MIG_USER_SEND phase=before kind=rpc msgid=78945669 name=_notify_server_register_plain
  NOTIFYD_N1_MIG_SERVER_RCV phase=before kind=rpc msgid=78945669 name=_notify_server_register_plain
  NOTIFYD_N1_MIG_SERVER_RCV phase=after kind=rpc msgid=78945669 name=_notify_server_register_plain
  NOTIFYD_N1_MIG_USER_SEND phase=after kind=rpc msgid=78945669 name=_notify_server_register_plain
  NOTIFYD_N1_MIG_USER_SEND phase=before kind=rpc msgid=78945681 name=_notify_server_get_state
  NOTIFYD_N1_MIG_SERVER_RCV phase=before kind=rpc msgid=78945681 name=_notify_server_get_state
  NOTIFYD_N1_MIG_SERVER_RCV phase=after kind=rpc msgid=78945681 name=_notify_server_get_state
  NOTIFYD_N1_MIG_USER_SEND phase=after kind=rpc msgid=78945681 name=_notify_server_get_state
  NOTIFYD_N1_MIG_USER_SEND phase=before kind=rpc msgid=78945679 name=_notify_server_cancel
  NOTIFYD_N1_MIG_SERVER_RCV phase=before kind=rpc msgid=78945679 name=_notify_server_cancel
  NOTIFYD_N1_MIG_SERVER_RCV phase=after kind=rpc msgid=78945679 name=_notify_server_cancel
  NOTIFYD_N1_MIG_USER_SEND phase=after kind=rpc msgid=78945679 name=_notify_server_cancel
  NOTIFYD_N1_MIG_USER_SEND phase=before kind=simple msgid=78945693 name=_notify_server_post_4
  NOTIFYD_N1_MIG_USER_SEND phase=after kind=simple msgid=78945693 name=_notify_server_post_4
  NOTIFYD_N1_POSTER_POST_STATUS status=0
  NOTIFYD_N1_POSTER_TERMINAL status=0
  NOTIFYD_N1_MIG_SERVER_RCV phase=before kind=simple msgid=78945693 name=_notify_server_post_4
  NOTIFYD_N1_POSTER_WAIT_STATUS exited=1 status=0
  NOTIFYD_N1_SERVER_POST_ENTRY name=org.rmxos.phase095a.notifyd.n1 uid=0 gid=0
  NOTIFYD_N1_SERVER_POST_RETURN name=org.rmxos.phase095a.notifyd.n1 status=0
  NOTIFYD_N1_MIG_SERVER_RCV phase=after kind=simple msgid=78945693 name=_notify_server_post_4
  NOTIFYD_N1_CLIENT_POSTER_STATUS status=0
  NOTIFYD_N1_CLIENT_CHECK_STATUS status=0 token=0 check=1
  NOTIFYD_N1_SHM_OBSERVATION token=0 check=1
  NOTIFYD_N1_SECOND_CHECK_OBSERVATION status=0 token=1 check=1
  NOTIFYD_N1_CLIENT_OBSERVER_CANCEL_STATUS status=0 token=1
  NOTIFYD_N1_CLIENT_CANCEL_STATUS status=0 token=0
  NOTIFYD_N1_SHM_FRESH_OBSERVATION baseline_check=1 observer_baseline_check=1 check=1 observer_check=1
  NOTIFYD_N1_TERMINAL status=0 baseline_check=1 observer_baseline_check=1 check=1 observer_check=1
  launchd donor-bootstrap harness: client status=0
  launchd donor-bootstrap harness: launchd_runtime_init2() returned rc=0
  === phase1 launchd harness end rc=0 ===
  """

  test "validates accepted N1 protocol order and rc normalization" do
    result = NotifydN1NotificationCenter.validate_serial(@valid_serial, run_guest_rc: "1")

    assert result["passed"]
    assert result["terminal_contract"]["run_guest_rc_accepted"]
    assert result["ordered_marker_count"] == length(MarkerManifest.required_order())
  end

  test "N1 marker authority records provenance limitations and producer model" do
    closeout = MarkerManifest.closeout()

    assert closeout.accepted_claim == MarkerManifest.accepted_claim()
    assert closeout.accepted_serial_sha256 == MarkerManifest.accepted_serial_sha256()
    assert closeout.raw_evidence_tree_digest == MarkerManifest.raw_evidence_tree_digest()
    assert closeout.source_pins.accepted_source_pin == MarkerManifest.accepted_source_pin()
    assert closeout.handoff_attestation.mode == "indirect"

    assert "runtime binary hashes were not captured during the accepted run" in closeout.provenance_limitations

    producers =
      MarkerManifest.specs()
      |> Enum.map(& &1.producer)
      |> Enum.uniq()
      |> Enum.sort()

    assert producers == [:donor, :harness]
    assert MarkerManifest.producer_breakdown()[:donor] > 0
    assert MarkerManifest.producer_breakdown()[:harness] > 0
  end

  test "coverage maps every accepted NOTIFYD_N1 key to field-record authority" do
    coverage = NotifydN1NotificationCenter.marker_coverage(@valid_serial)

    assert coverage["passed"]
    assert coverage["unmapped_serial_keys"] == []
    assert coverage["authority_keys_missing_from_serial"] == []
    assert coverage["authority_specs_missing_from_serial"] == []
  end

  test "negative controls cover terminal order receipt pairing service-name and rc classes" do
    controls = NotifydN1NotificationCenter.negative_controls(@valid_serial, "1")

    assert controls["passed"]
    assert length(controls["controls"]) == 10

    classes = controls["controls"] |> Enum.map(& &1["class"]) |> Enum.sort() |> Enum.uniq()
    assert classes == ~w(order pairing rc receipt service_name terminal)
  end

  test "hard-stop policy allows normal WITNESS banner and rejects diagnostics" do
    assert NotifydN1NotificationCenter.hard_stop_scan(
             "WARNING: WITNESS option enabled, expect reduced performance.\n"
           )["passed"]

    refute NotifydN1NotificationCenter.hard_stop_scan("WITNESS: lock diagnostic\n")["passed"]
    refute NotifydN1NotificationCenter.hard_stop_scan("lock order reversal\n")["passed"]
    refute NotifydN1NotificationCenter.hard_stop_scan("nosys 468\n")["passed"]
  end

  test "rc=1 is rejected without both terminal and harness end markers" do
    missing_terminal =
      String.replace(
        @valid_serial,
        "NOTIFYD_N1_TERMINAL status=0 baseline_check=1 observer_baseline_check=1 check=1 observer_check=1",
        ""
      )

    missing_harness_end =
      String.replace(@valid_serial, "=== phase1 launchd harness end rc=0 ===", "")

    refute NotifydN1NotificationCenter.validate_serial(missing_terminal, run_guest_rc: "1")[
             "passed"
           ]

    refute NotifydN1NotificationCenter.validate_serial(missing_harness_end, run_guest_rc: "1")[
             "passed"
           ]
  end

  test "no-copy check catches seeded copied N1 marker literals" do
    report = NotifydN1NotificationCenter.static_authority_contract_checks(File.cwd!())

    assert report["passed"]
    assert report["no_copy"]["passed"]
    assert report["cross_series"]["passed"]

    seeded =
      ContractCheck.no_copy_check(%{
        "lib/rmx_os_oracle/migration/seeded_notifyd_copy.ex" =>
          ~s|def copied, do: "NOTIFYD_N1_SERVER_POST_ENTRY"|
      })

    refute seeded["passed"]
    assert [%{"literal" => "NOTIFYD_N1_SERVER_POST_ENTRY"}] = seeded["matches"]
  end

  test "cross-series check rejects seeded ASL and Phase08 prefix mixing" do
    registry = ContractCheck.series_prefix_registry()

    assert registry["notifyd_n1"] == "NOTIFYD_N1_"
    assert registry["asl_a1"] == "ASL_A1_"
    assert registry["asl_a2"] == "ASL_A2_"
    assert registry["phase08"] == "PHASE08_"
  end

  test "data-only A2/N1 comparison is explicitly non-authoritative" do
    finding = NotifydN1NotificationCenter.a2_n1_comparison_finding()

    assert finding.authority == "non_authoritative_data_only"
    assert "N1 has no direct notifyd launchd check-in dictionary marker" in finding.gaps
    assert String.contains?(finding.conclusion, "N1 authority is notify-specific")
  end
end
