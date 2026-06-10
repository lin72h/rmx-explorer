defmodule RmxOSOracle.Migration.AslA2LaunchdHandoffTest do
  use ExUnit.Case, async: true

  alias RmxOSOracle.Migration.AslA2LaunchdHandoff

  @payload_sha "fab284180de734bdd4374aea271ca34a96c759f3053ccb14a22945a1f50c373b"

  @valid_serial """
  mach_module=loaded
  ASL_A2_SERVER_START=1
  ASL_A2_SERVICE_NAME=com.apple.system.logger
  ASL_A2_LAUNCH_CHECKIN_CALLED=1
  ASL_A2_LAUNCH_CHECKIN_KEY=CheckIn
  ASL_A2_LAUNCH_CHECKIN_REPLY_PRESENT=1
  ASL_A2_MACHSERVICES_DICT_PRESENT=1
  ASL_A2_SERVICE_ENTRY_PRESENT=1
  ASL_A2_SERVER_CHECKIN_RECEIVE_PORT=112
  ASL_A2_SERVER_RECEIVE_RIGHT_USABLE=1
  ASL_A2_SUBCLAIM_A_PASSED=1
  ASL_A2_CLIENT_START=1
  ASL_A2_SERVICE_NAME=com.apple.system.logger
  ASL_A2_DONOR_LOOKUP_FUNCTION=asl_core_get_service_port
  ASL_A2_DONOR_LOOKUP_CALLED=1
  ASL_A2_CLIENT_LOOKUP_SEND_RIGHT=112
  ASL_A2_CLIENT_LOOKUP_SUCCESS=1
  ASL_A2_EXPECTED_OOL_BYTE_COUNT=104
  ASL_A2_EXPECTED_OOL_SHA256=#{@payload_sha}
  ASL_A2_NONCE=rmxos-asl-a2-nonce-v1
  ASL_A2_CLIENT_VM_ALLOCATE_KR=0
  ASL_A2_CLIENT_SEND_STARTED=1
  ASL_A2_CLIENT_SEND_KR=0
  ASL_A2_SUBCLAIM_B_CLIENT_SEND=1
  ASL_A2_SERVER_RECEIVE_KR=0
  ASL_A2_SERVER_RECEIVED_MSG_ID=118
  ASL_A2_SERVER_RECEIVED_COMPLEX=1
  ASL_A2_SERVER_DESCRIPTOR_COUNT=1
  ASL_A2_RECEIVED_OOL_BYTE_COUNT=104
  ASL_A2_SERVER_REQUESTED_AUDIT_TRAILER=1
  ASL_A2_SERVER_AUDIT_TRAILER_PRESENT=1
  ASL_A2_RECEIVED_OOL_SHA256=#{@payload_sha}
  ASL_A2_NONCE_MATCH=1
  ASL_A2_PORT_IDENTITY_NONCE_RECEIVED=1
  ASL_A2_SUBCLAIM_B_SERVER_RECEIPT=1
  ASL_A2_DONE=1
  """

  test "validates A2 only when check-in, donor lookup, and nonce receipt all pass" do
    result = AslA2LaunchdHandoff.validate_serial(@valid_serial)

    assert result["passed"]
    assert result["subclaim_a_passed"]
    assert result["subclaim_b_passed"]
    assert result["port_identity_passed"]
  end

  test "subclaim A alone is not accepted A2" do
    serial =
      @valid_serial
      |> String.replace("ASL_A2_SUBCLAIM_B_CLIENT_SEND=1", "")
      |> String.replace("ASL_A2_SUBCLAIM_B_SERVER_RECEIPT=1", "")
      |> String.replace("ASL_A2_PORT_IDENTITY_NONCE_RECEIVED=1", "")

    result = AslA2LaunchdHandoff.validate_serial(serial)

    refute result["passed"]
    assert result["subclaim_a_passed"]
    refute result["subclaim_b_passed"]
    refute result["port_identity_passed"]
  end

  test "negative controls fail closed for launchd handoff and port identity" do
    controls = AslA2LaunchdHandoff.negative_controls(@valid_serial)

    assert controls["passed"]
    assert length(controls["controls"]) == 12
  end

  test "hard-stop scanner allows normal WITNESS banner and rejects diagnostics" do
    assert AslA2LaunchdHandoff.hard_stop_scan(
             "WARNING: WITNESS option enabled, expect reduced performance.\n"
           )["passed"]

    refute AslA2LaunchdHandoff.hard_stop_scan("WITNESS: lock diagnostic\n")["passed"]
    refute AslA2LaunchdHandoff.hard_stop_scan("lock order reversal\n")["passed"]
  end

  test "fixture is reduced to MachServices-only ASL service handoff" do
    path = Path.join(File.cwd!(), "fixtures/launchd/org.rmxos.asl.a2.system-logger.plist")
    result = AslA2LaunchdHandoff.fixture_shape(path)

    assert result["passed"]
    assert result["checks"]["has_machservices"]
    assert result["checks"]["has_service_name"]
    assert result["checks"]["forbidden_product_keys"] == []
  end

  test "A2 has no marker manifest authority before accepted evidence" do
    result = AslA2LaunchdHandoff.static_no_marker_manifest_entries(File.cwd!())

    assert result["passed"]
    refute result["a2_authority_module_dir_exists"]
    assert result["asl_a2_marker_matches_outside_runner"] == []
  end

  test "source staging capability fails when donor-bootstrap fixture staging is absent" do
    result =
      AslA2LaunchdHandoff.staging_capability("""
      fixture=${NXPLATFORM_PHASE1_LAUNCHD_HARNESS_FIXTURE:-$default_fixture}
      if [ "$mode" = import ] || [ "$mode" = bootstrap ]; then
        doas install -m 644 "$fixture" "$guest_root${payload_path}"
      fi
      """)

    refute result["passed"]
    assert result["fixture_variable_present"]
    refute result["donor_bootstrap_installs_fixture"]
    assert String.contains?(result["reason"], "cannot prove the MachServices fixture is consumed")
  end

  test "source staging capability recognizes committed donor-bootstrap fixture support" do
    result =
      AslA2LaunchdHandoff.staging_capability("""
      fixture=${NXPLATFORM_PHASE1_LAUNCHD_HARNESS_FIXTURE:-$default_fixture}
      if [ "$mode" = donor-bootstrap ] && [ "$donor_bootstrap_fixture" = 1 ]; then
        doas install -m 644 "$fixture" "$guest_root${payload_path}"
      fi
      """)

    assert result["passed"]
    assert result["fixture_variable_present"]
    assert result["donor_bootstrap_installs_fixture"]
  end

  test "staged root guard catches stale ASL A1 rc state" do
    root = tmp_dir("stale-a1-root")
    File.mkdir_p!(Path.join(root, "etc/rc.d"))
    File.mkdir_p!(Path.join(root, "root/nxplatform/asl"))
    File.write!(Path.join(root, "etc/rc.conf"), ~s|nxplatform_asl_a1_enable="YES"\n|)
    File.write!(Path.join(root, "etc/rc.d/nxplatform_asl_a1"), "echo ASL_A1_DONE=1\n")
    File.write!(Path.join(root, "root/nxplatform/asl/asl-a1-server-message-ool"), "probe")

    result = AslA2LaunchdHandoff.staged_root_guard(root)

    refute result["passed"]
    assert "etc/rc.d/nxplatform_asl_a1" in result["stale_a1_paths"]
    assert "root/nxplatform/asl/asl-a1-server-message-ool" in result["stale_a1_paths"]
    assert ~s|nxplatform_asl_a1_enable="YES"| in result["enabled_a1_rc_lines"]
    assert "etc/rc.d/nxplatform_asl_a1" in result["asl_a1_text_matches"]
  end

  test "staged root guard accepts A2-only rc state" do
    root = tmp_dir("a2-root")
    File.mkdir_p!(Path.join(root, "etc/rc.d"))
    File.write!(Path.join(root, "etc/rc.conf"), ~s|nxplatform_asl_a1_enable="NO"\n|)

    File.write!(
      Path.join(root, "etc/rc.d/nxplatform_phase1_launchd_harness"),
      "echo ASL_A2_DONE=1\n"
    )

    result = AslA2LaunchdHandoff.staged_root_guard(root)

    assert result["passed"]
    assert result["stale_a1_paths"] == []
    assert result["enabled_a1_rc_lines"] == []
    assert result["asl_a1_text_matches"] == []
  end

  test "first A2 staging failure disposition classifies preserved evidence" do
    disposition = AslA2LaunchdHandoff.first_staging_failure_disposition()

    assert disposition["schema"] == "rmxos_oracle.asl_a2.first_staging_failure_disposition.v1"

    assert disposition["evidence_path"] ==
             "priv/runs/asl-a2/20260609T1310016671Z-system-logger-handoff"

    assert disposition["evidence_tree_digest"] ==
             "60d5c1de40627841d3edc3a9eb780a08e3b87b0c0a792fb28a6b4e78db58a24c"

    assert disposition["classification"] == "runner_staging_setup_failure"
    assert disposition["attempt_consumed"] == false
    assert disposition["accepted_claim"] == "not_accepted"
    assert disposition["raw_evidence_copied"] == false
    assert disposition["observed"]["serial_contains_asl_a1_markers"] == true
    assert disposition["observed"]["serial_contains_asl_a2_markers"] == false
  end

  defp tmp_dir(label) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "rmxos-oracle-asl-a2-#{label}-#{System.unique_integer([:positive])}"
      )

    File.rm_rf!(dir)
    File.mkdir_p!(dir)
    dir
  end
end
