defmodule RmxOSOracle.Migration.AslA2LaunchdHandoffTest do
  use ExUnit.Case, async: true

  alias RmxOSOracle.Asl.A2.{ContractCheck, MarkerManifest}
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

  test "ASL A2 marker authority records accepted closeout and producer model" do
    closeout = MarkerManifest.closeout()

    assert closeout.accepted_claim == "launchd_handoff_plus_donor_lookup_nonce_identity"
    assert closeout.accepted_evidence_path == MarkerManifest.accepted_evidence_dir()

    assert closeout.accepted_evidence_tree_digest ==
             MarkerManifest.accepted_evidence_tree_digest()

    assert closeout.source_authorization_commit == MarkerManifest.source_authorization_commit()
    assert closeout.ool_integrity.expected_byte_count == "104"
    assert closeout.ool_integrity.expected_sha256 == @payload_sha

    producers =
      MarkerManifest.specs()
      |> Enum.map(& &1.producer)
      |> Enum.uniq()
      |> Enum.sort()

    assert producers == [:donor, :harness, :kernel, :launchd]

    for spec <- MarkerManifest.specs() do
      assert spec.role in MarkerManifest.roles()
      assert spec.producer in MarkerManifest.producers()
    end

    assert MarkerManifest.category_breakdown()[:port_identity] == 3
    assert MarkerManifest.producer_breakdown()[:launchd] >= 5
  end

  test "ASL A2 authority separates launchd donor kernel and harness proof" do
    launchd_keys =
      MarkerManifest.specs()
      |> Enum.filter(&(&1.producer == :launchd))
      |> Enum.map(& &1.key)

    donor_keys =
      MarkerManifest.specs()
      |> Enum.filter(&(&1.producer == :donor))
      |> Enum.map(& &1.key)

    kernel_keys =
      MarkerManifest.specs()
      |> Enum.filter(&(&1.producer == :kernel))
      |> Enum.map(& &1.key)

    assert "ASL_A2_LAUNCH_CHECKIN_REPLY_PRESENT" in launchd_keys
    assert "ASL_A2_SERVER_RECEIVE_RIGHT_USABLE" in launchd_keys
    assert "ASL_A2_DONOR_LOOKUP_FUNCTION" in donor_keys
    assert "ASL_A2_CLIENT_LOOKUP_SUCCESS" in donor_keys
    assert "ASL_A2_SERVER_AUDIT_TRAILER_PRESENT" in kernel_keys
    refute "ASL_A2_PORT_IDENTITY_NONCE_RECEIVED" in donor_keys
    refute "ASL_A2_DONOR_LOOKUP_CALLED" in launchd_keys
  end

  test "ASL A2 no-copy check cross-series isolation and accepted coverage pass" do
    report = AslA2LaunchdHandoff.static_authority_contract_checks(File.cwd!())

    assert report["passed"]
    assert report["no_copy"]["passed"]
    assert report["cross_series"]["passed"]

    seeded =
      ContractCheck.no_copy_check(%{
        "lib/rmx_os_oracle/migration/seeded_copy.ex" =>
          ~s|def copied, do: "ASL_A2_PORT_IDENTITY_NONCE_RECEIVED=1"|
      })

    refute seeded["passed"]

    assert [%{"literal" => "ASL_A2_PORT_IDENTITY_NONCE_RECEIVED=1"}] =
             Enum.filter(seeded["matches"], &(&1["type"] == "literal"))

    coverage = ContractCheck.accepted_serial_coverage(@valid_serial)

    assert coverage["passed"]
    assert coverage["unmapped_serial_keys"] == []
    assert coverage["authority_keys_missing_from_serial"] == []
  end

  test "ASL A2 generator guard binds value and expression emission anchors" do
    probe = File.read!(Path.join(File.cwd!(), MarkerManifest.probe_path()))
    report = ContractCheck.generator_guard(probe)

    assert report["passed"]
    assert report["missing_anchors"] == []

    service_value_drift =
      probe
      |> String.replace(
        ~s|#define ASL_A2_SERVICE_NAME "com.apple.system.logger"|,
        ~s|#define ASL_A2_SERVICE_NAME "com.example.logger"|
      )
      |> ContractCheck.generator_guard()

    refute service_value_drift["passed"]
    assert missing_emission_anchor?(service_value_drift, "ASL_A2_SERVICE_NAME")

    terminal_value_drift =
      probe
      |> String.replace(
        ~s|emit_kv("ASL_A2_DONE", rc == 0 ? "1" : "0")|,
        ~s|emit_kv("ASL_A2_DONE", rc == 0 ? "10" : "0")|
      )
      |> ContractCheck.generator_guard()

    refute terminal_value_drift["passed"]
    assert missing_emission_anchor?(terminal_value_drift, "ASL_A2_DONE")

    nonce_value_drift =
      probe
      |> String.replace(
        ~s|#define ASL_A2_NONCE "rmxos-asl-a2-nonce-v1"|,
        ~s|#define ASL_A2_NONCE "wrong-nonce"|
      )
      |> ContractCheck.generator_guard()

    refute nonce_value_drift["passed"]
    assert missing_emission_anchor?(nonce_value_drift, "ASL_A2_NONCE")

    ool_expression_drift =
      probe
      |> String.replace(
        ~s|ool_len = (mach_msg_type_number_t)sizeof(ASL_A2_PAYLOAD);|,
        ~s|ool_len = (mach_msg_type_number_t)strlen(ASL_A2_PAYLOAD);|
      )
      |> ContractCheck.generator_guard()

    refute ool_expression_drift["passed"]
    assert missing_emission_anchor?(ool_expression_drift, "ASL_A2_EXPECTED_OOL_BYTE_COUNT")
  end

  test "A2 validation requires authority OOL constants and dynamic port policies" do
    wrong_hash =
      @valid_serial
      |> String.replace(@payload_sha, String.duplicate("0", 64))
      |> AslA2LaunchdHandoff.validate_serial()

    wrong_count =
      @valid_serial
      |> String.replace(
        "ASL_A2_EXPECTED_OOL_BYTE_COUNT=104",
        "ASL_A2_EXPECTED_OOL_BYTE_COUNT=105"
      )
      |> String.replace(
        "ASL_A2_RECEIVED_OOL_BYTE_COUNT=104",
        "ASL_A2_RECEIVED_OOL_BYTE_COUNT=105"
      )
      |> AslA2LaunchdHandoff.validate_serial()

    invalid_port =
      @valid_serial
      |> String.replace(
        "ASL_A2_SERVER_CHECKIN_RECEIVE_PORT=112",
        "ASL_A2_SERVER_CHECKIN_RECEIVE_PORT=0"
      )
      |> AslA2LaunchdHandoff.validate_serial()

    refute wrong_hash["passed"]
    refute wrong_count["passed"]
    refute invalid_port["passed"]
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

  defp missing_emission_anchor?(report, key) do
    Enum.any?(report["missing_emission_anchors"], &(&1.key == key))
  end
end
