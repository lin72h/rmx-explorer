defmodule RmxOSOracle.Migration.AslA1ServerMessageOolTest do
  use ExUnit.Case, async: true

  alias RmxOSOracle.Asl.A1.{ContractCheck, MarkerManifest}
  alias RmxOSOracle.CanonicalJSON
  alias RmxOSOracle.Migration.AslA1ServerMessageOol

  @payload_sha "a3ff9feadd6c4954712c16fb362ff5fcee0fa45a9a65d9e569fa7a33f7c7f977"
  @malformed_payload_sha "bd153d0688b6c4c77e8587258a87b887f15de6c7b63c36d7ad3790ba820f6f49"

  @valid_serial """
  === ASL A1 server-message-ool start ===
  mach_module=loaded
  ASL_A1_PROBE_START=1
  ASL_A1_MIG_SUBSYSTEM=114
  ASL_A1_MIG_ROUTINE_ID=118
  ASL_A1_CLIENT_PID=1056
  ASL_A1_CLIENT_UID=0
  ASL_A1_CLIENT_GID=0
  ASL_A1_ARM_START=positive_decode
  ASL_A1_EXPECTED_OOL_BYTE_COUNT=96
  ASL_A1_EXPECTED_OOL_SHA256=#{@payload_sha}
  ASL_A1_CLIENT_SEND_STARTED=1
  ASL_A1_CLIENT_SEND_KR=0
  ASL_A1_SERVER_RECEIVE_KR=0
  ASL_A1_SERVER_RECEIVED_MSG_ID=118
  ASL_A1_SERVER_REQUESTED_AUDIT_TRAILER=1
  ASL_A1_SERVER_AUDIT_TRAILER_PRESENT=1
  ASL_A1_GENERATED_DEMUX_CALLED=1
  ASL_A1_DONOR_SERVER_MESSAGE_ENTER=1
  ASL_A1_RECEIVED_OOL_BYTE_COUNT=96
  ASL_A1_RECEIVED_OOL_SHA256=#{@payload_sha}
  ASL_A1_DONOR_OOL_BYTES_INTACT=1
  ASL_A1_TASK_NAME_FOR_PID=fenced_deferred
  ASL_A1_DONOR_DECODE_OK=1
  ASL_A1_PROCESS_MESSAGE_STUB_CALLED=1
  ASL_A1_PROCESS_MESSAGE_SOURCE=5
  ASL_A1_PROCESS_MESSAGE_SENDER=oracle_asl_a1_client
  ASL_A1_PROCESS_MESSAGE_FACILITY=com.rmxos.oracle.asl
  ASL_A1_PROCESS_MESSAGE_LEVEL=5
  ASL_A1_PROCESS_MESSAGE_MESSAGE=oracle_asl_a1
  ASL_A1_PROCESS_MESSAGE_UID=0
  ASL_A1_PROCESS_MESSAGE_GID=0
  ASL_A1_PROCESS_MESSAGE_PID=1056
  ASL_A1_AUDIT_UID=0
  ASL_A1_AUDIT_GID=0
  ASL_A1_AUDIT_PID=1056
  ASL_A1_AUDIT_MATCH=1
  ASL_A1_AUDIT_CLAIM=accepted
  ASL_A1_PROCESS_MESSAGE_PAYLOAD_MATCH=1
  ASL_A1_DONOR_RELEASE_COMPLETED=1
  ASL_A1_GENERATED_DEMUX_HANDLED=1
  ASL_A1_POSITIVE_DECODE_AND_STUB_CONFIRMED=1
  ASL_A1_ARM_END=positive_decode
  ASL_A1_ARM_START=malformed_payload
  ASL_A1_CLIENT_SEND_STARTED=1
  ASL_A1_CLIENT_SEND_KR=0
  ASL_A1_SERVER_RECEIVE_KR=0
  ASL_A1_SERVER_RECEIVED_MSG_ID=118
  ASL_A1_SERVER_REQUESTED_AUDIT_TRAILER=1
  ASL_A1_SERVER_AUDIT_TRAILER_PRESENT=1
  ASL_A1_GENERATED_DEMUX_CALLED=1
  ASL_A1_DONOR_SERVER_MESSAGE_ENTER=1
  ASL_A1_RECEIVED_OOL_BYTE_COUNT=28
  ASL_A1_RECEIVED_OOL_SHA256=#{@malformed_payload_sha}
  ASL_A1_GENERATED_DEMUX_HANDLED=1
  ASL_A1_NEG_MALFORMED_PAYLOAD_REJECTED=1
  ASL_A1_ARM_END=malformed_payload
  ASL_A1_ARM_START=invalid_ool
  ASL_A1_NEG_INVALID_OOL_DESCRIPTOR_REJECTED=1
  ASL_A1_ARM_END=invalid_ool
  ASL_A1_DONE=1
  === ASL A1 server-message-ool end rc=0 ===
  """

  test "validates exact arm-aware donor decode evidence" do
    result = AslA1ServerMessageOol.validate_serial(@valid_serial)

    assert result["passed"]
    assert result["errors"] == []
    assert result["audit_result"]["status"] == "accepted"
    assert result["ool_integrity"]["passed"]
  end

  test "ASL A1 marker authority records accepted closeout and producer model" do
    closeout = MarkerManifest.closeout()

    assert closeout.accepted_claim == "ool_transport_decode_plus_audit_identity"
    assert closeout.accepted_serial_sha256 == MarkerManifest.accepted_serial_sha256()
    assert closeout.authoritative_revalidation == "post_run_revalidation.json"
    assert "parity.json" in closeout.historical_failed_in_run_outputs
    assert MarkerManifest.replacement_runtime_evidence_count() == 1

    producers =
      MarkerManifest.specs()
      |> Enum.map(& &1.producer)
      |> Enum.uniq()
      |> Enum.sort()

    assert producers == [:donor, :harness, :kernel]

    roles =
      MarkerManifest.specs()
      |> Enum.map(& &1.role)
      |> Enum.uniq()

    for role <- roles do
      assert role in MarkerManifest.roles()
    end

    assert MarkerManifest.category_breakdown()[:positive_claim] == 3

    assert MarkerManifest.invariants().summary_marker_not_primary_proof ==
             "ASL_A1_POSITIVE_DECODE_AND_STUB_CONFIRMED"
  end

  test "ASL A1 authority separates demux process-stub audit and donor proof" do
    donor_keys =
      MarkerManifest.specs()
      |> Enum.filter(&(&1.producer == :donor))
      |> Enum.map(& &1.key)

    refute "ASL_A1_GENERATED_DEMUX_CALLED" in donor_keys
    refute "ASL_A1_PROCESS_MESSAGE_STUB_CALLED" in donor_keys
    assert "ASL_A1_DONOR_SERVER_MESSAGE_ENTER" in donor_keys
    assert "ASL_A1_DONOR_DECODE_OK" in donor_keys
    assert "ASL_A1_DONOR_RELEASE_COMPLETED" in donor_keys

    audit_keys =
      MarkerManifest.specs()
      |> Enum.filter(&(&1.role == :audit_identity))
      |> Enum.map(& &1.key)

    assert "ASL_A1_AUDIT_PID" in audit_keys
    refute "ASL_A1_PROCESS_MESSAGE_PID" in audit_keys
  end

  test "ASL A1 no-copy check and cross-series isolation pass and catch seeded copies" do
    report = ContractCheck.run(File.cwd!())

    assert report["passed"]
    assert report["no_copy"]["passed"]
    assert report["cross_series"]["passed"]

    seeded =
      ContractCheck.no_copy_check(%{
        "lib/rmx_os_oracle/migration/seeded_copy.ex" =>
          ~s|def copied, do: "ASL_A1_DONOR_DECODE_OK=1"|
      })

    refute seeded["passed"]

    assert [%{"literal" => "ASL_A1_DONOR_DECODE_OK=1"}] =
             Enum.filter(seeded["matches"], &(&1["type"] == "literal"))
  end

  test "ASL A1 frozen generator guard binds authority entries to probe anchors" do
    probe = File.read!(Path.join(File.cwd!(), MarkerManifest.probe_path()))
    report = ContractCheck.generator_guard(probe)

    assert report["passed"]
    assert report["missing_anchors"] == []

    missing_anchor =
      probe
      |> String.replace("ASL_A1_DONOR_DECODE_OK", "ASL_A1_DONOR_DCODE_OK")
      |> ContractCheck.generator_guard()

    refute missing_anchor["passed"]

    assert Enum.any?(missing_anchor["missing_anchors"], fn anchor ->
             anchor.key == "ASL_A1_DONOR_DECODE_OK"
           end)

    mig_value_drift =
      probe
      |> String.replace(
        ~s|emit_kv("ASL_A1_MIG_SUBSYSTEM", "114")|,
        ~s|emit_kv("ASL_A1_MIG_SUBSYSTEM", "115")|
      )
      |> ContractCheck.generator_guard()

    refute mig_value_drift["passed"]
    assert missing_emission_anchor?(mig_value_drift, "ASL_A1_MIG_SUBSYSTEM")

    terminal_value_drift =
      probe
      |> String.replace(
        ~s|emit_kv("ASL_A1_DONE", rc == 0 ? "1" : "0")|,
        ~s|emit_kv("ASL_A1_DONE", rc == 0 ? "10" : "0")|
      )
      |> ContractCheck.generator_guard()

    refute terminal_value_drift["passed"]
    assert missing_emission_anchor?(terminal_value_drift, "ASL_A1_DONE")

    audit_claim_drift =
      probe
      |> String.replace(
        ~s|emit_kv("ASL_A1_AUDIT_CLAIM", "accepted")|,
        ~s|emit_kv("ASL_A1_AUDIT_CLAIM", "deferred")|
      )
      |> ContractCheck.generator_guard()

    refute audit_claim_drift["passed"]
    assert missing_emission_anchor?(audit_claim_drift, "ASL_A1_AUDIT_CLAIM")

    ool_expression_drift =
      probe
      |> String.replace(
        ~s|emit_u32("ASL_A1_EXPECTED_OOL_BYTE_COUNT", sizeof(ASL_A1_POSITIVE_PAYLOAD))|,
        ~s|emit_u32("ASL_A1_EXPECTED_OOL_BYTE_COUNT", strlen(ASL_A1_POSITIVE_PAYLOAD))|
      )
      |> ContractCheck.generator_guard()

    refute ool_expression_drift["passed"]
    assert missing_emission_anchor?(ool_expression_drift, "ASL_A1_EXPECTED_OOL_BYTE_COUNT")
  end

  test "allows normal WITNESS banner and rejects real diagnostics" do
    assert AslA1ServerMessageOol.hard_stop_scan(
             "WARNING: WITNESS option enabled, expect reduced performance.\n"
           )["passed"]

    refute AslA1ServerMessageOol.hard_stop_scan("WITNESS: lock diagnostic\n")["passed"]
    refute AslA1ServerMessageOol.hard_stop_scan("lock order reversal: witness report\n")["passed"]
  end

  test "required falsifiers fail closed" do
    controls = AslA1ServerMessageOol.negative_controls(@valid_serial)

    assert controls["passed"]
    assert length(controls["controls"]) == 25

    refute Enum.any?(controls["controls"], fn control ->
             control
             |> Map.get("observed_errors", [])
             |> Enum.any?(&String.contains?(&1, "CLIENT_SEND_KR"))
           end)

    assert control_errors(controls, "missing_terminal")
           |> Enum.any?(&String.contains?(&1, "terminal requires exactly one ASL_A1_DONE=1"))

    assert control_errors(controls, "donor_entry_without_decode_ok")
           |> Enum.any?(&String.contains?(&1, "ASL_A1_DONOR_DECODE_OK"))

    assert control_errors(controls, "equal_fake_ool_hashes")
           |> Enum.any?(&String.contains?(&1, "Oracle-pinned payload hash"))

    assert control_errors(controls, "malformed_duplicate_client_send")
           |> Enum.any?(&String.contains?(&1, "ASL_A1_CLIENT_SEND_STARTED"))
  end

  test "CRLF boot marker is accepted by post-run boot identity recomputation" do
    dir = temp_dir!("crlf-boot-identity")

    try do
      File.write!(
        Path.join(dir, "asl_a1_serial.log"),
        String.replace(@valid_serial, "\n", "\r\n")
      )

      CanonicalJSON.write!(Path.join(dir, "boot_identity.json"), boot_identity_fixture(false))

      report = AslA1ServerMessageOol.revalidate_evidence(dir)

      assert report["boot_identity_recomputed"]
      assert report["boot_identity"]["mach_module_loaded_marker"]
      assert report["boot_identity_passed"]
      assert report["marker_validation_passed"]
      refute report["passed"]
      assert report["donor_build_provenance_errors"] != []
    after
      File.rm_rf!(dir)
    end
  end

  test "CLIENT_SEND_KR belongs to client phase and remains required" do
    result = AslA1ServerMessageOol.validate_serial(@valid_serial)

    assert result["passed"]

    missing_client_send_kr =
      replace_in_arm(
        @valid_serial,
        "positive_decode",
        "ASL_A1_CLIENT_SEND_KR=0",
        "ASL_A1_CLIENT_SEND_KR_REMOVED=1"
      )
      |> AslA1ServerMessageOol.validate_serial()

    refute missing_client_send_kr["passed"]

    assert missing_client_send_kr["errors"]
           |> Enum.any?(&String.contains?(&1, "ASL_A1_CLIENT_SEND_KR=0"))
  end

  test "wrong value cannot satisfy exact marker validation" do
    result =
      @valid_serial
      |> String.replace("ASL_A1_DONE=1", "ASL_A1_DONE=10")
      |> AslA1ServerMessageOol.validate_serial()

    refute result["passed"]
  end

  test "terminal marker must be present exactly once" do
    missing =
      @valid_serial
      |> String.replace("ASL_A1_DONE=1", "ASL_A1_DONE_REMOVED=1")
      |> AslA1ServerMessageOol.validate_serial()

    duplicated =
      @valid_serial
      |> String.replace("ASL_A1_DONE=1", "ASL_A1_DONE=1\nASL_A1_DONE=1")
      |> AslA1ServerMessageOol.validate_serial()

    refute missing["passed"]
    refute duplicated["passed"]
  end

  test "positive-only duplicate and contradictory claim fail" do
    duplicate =
      @valid_serial
      |> String.replace(
        "ASL_A1_DONOR_DECODE_OK=1",
        "ASL_A1_DONOR_DECODE_OK=1\nASL_A1_DONOR_DECODE_OK=1"
      )
      |> AslA1ServerMessageOol.validate_serial()

    contradiction =
      @valid_serial
      |> String.replace(
        "ASL_A1_AUDIT_CLAIM=accepted",
        "ASL_A1_AUDIT_CLAIM=accepted\nASL_A1_AUDIT_CLAIM=deferred"
      )
      |> AslA1ServerMessageOol.validate_serial()

    refute duplicate["passed"]
    refute contradiction["passed"]
  end

  test "critical order and donor path are required" do
    invalid_order =
      @valid_serial
      |> String.replace("ASL_A1_GENERATED_DEMUX_CALLED=1", "__SWAP__", global: false)
      |> String.replace(
        "ASL_A1_DONOR_SERVER_MESSAGE_ENTER=1",
        "ASL_A1_GENERATED_DEMUX_CALLED=1",
        global: false
      )
      |> String.replace("__SWAP__", "ASL_A1_DONOR_SERVER_MESSAGE_ENTER=1", global: false)
      |> AslA1ServerMessageOol.validate_serial()

    no_entry =
      @valid_serial
      |> String.replace(
        "ASL_A1_DONOR_SERVER_MESSAGE_ENTER=1",
        "ASL_A1_DONOR_SERVER_MESSAGE_ENTER_REMOVED=1",
        global: false
      )
      |> AslA1ServerMessageOol.validate_serial()

    no_decode =
      @valid_serial
      |> String.replace("ASL_A1_DONOR_DECODE_OK=1", "ASL_A1_DONOR_DECODE_OK_REMOVED=1")
      |> AslA1ServerMessageOol.validate_serial()

    refute invalid_order["passed"]
    refute no_entry["passed"]
    refute no_decode["passed"]
  end

  test "server and donor causal order remains strict" do
    demux_before_receive =
      @valid_serial
      |> swap_first("ASL_A1_SERVER_RECEIVE_KR=0", "ASL_A1_GENERATED_DEMUX_CALLED=1")
      |> AslA1ServerMessageOol.validate_serial()

    release_before_decode =
      @valid_serial
      |> swap_first("ASL_A1_DONOR_DECODE_OK=1", "ASL_A1_DONOR_RELEASE_COMPLETED=1")
      |> AslA1ServerMessageOol.validate_serial()

    refute demux_before_receive["passed"]
    refute release_before_decode["passed"]
  end

  test "OOL counts, hashes, and full equality are independently required" do
    altered =
      @valid_serial
      |> String.replace("ASL_A1_DONOR_OOL_BYTES_INTACT=1", "ASL_A1_DONOR_OOL_BYTES_INTACT=0")
      |> AslA1ServerMessageOol.validate_serial()

    same_length =
      @valid_serial
      |> String.replace(
        "ASL_A1_RECEIVED_OOL_SHA256=#{@payload_sha}",
        "ASL_A1_RECEIVED_OOL_SHA256=#{String.duplicate("0", 64)}"
      )
      |> AslA1ServerMessageOol.validate_serial()

    appended =
      @valid_serial
      |> String.replace("ASL_A1_RECEIVED_OOL_BYTE_COUNT=96", "ASL_A1_RECEIVED_OOL_BYTE_COUNT=97")
      |> AslA1ServerMessageOol.validate_serial()

    refute altered["passed"]
    refute same_length["passed"]
    refute appended["passed"]

    fake = String.duplicate("0", 64)

    equal_fake_hashes =
      @valid_serial
      |> String.replace(@payload_sha, fake)
      |> AslA1ServerMessageOol.validate_serial()

    equal_wrong_counts =
      @valid_serial
      |> String.replace("ASL_A1_EXPECTED_OOL_BYTE_COUNT=96", "ASL_A1_EXPECTED_OOL_BYTE_COUNT=95")
      |> String.replace("ASL_A1_RECEIVED_OOL_BYTE_COUNT=96", "ASL_A1_RECEIVED_OOL_BYTE_COUNT=95")
      |> AslA1ServerMessageOol.validate_serial()

    refute equal_fake_hashes["passed"]
    refute equal_wrong_counts["passed"]
  end

  test "malformed and invalid-OOL arms fail closed on duplicates conflicts and contamination" do
    malformed_conflict =
      replace_in_arm(
        @valid_serial,
        "malformed_payload",
        "ASL_A1_SERVER_RECEIVE_KR=0",
        "ASL_A1_SERVER_RECEIVE_KR=0\nASL_A1_SERVER_RECEIVE_KR=5"
      )

    malformed_duplicate =
      replace_in_arm(
        @valid_serial,
        "malformed_payload",
        "ASL_A1_CLIENT_SEND_STARTED=1",
        "ASL_A1_CLIENT_SEND_STARTED=1\nASL_A1_CLIENT_SEND_STARTED=1"
      )

    malformed_decode =
      replace_in_arm(
        @valid_serial,
        "malformed_payload",
        "ASL_A1_NEG_MALFORMED_PAYLOAD_REJECTED=1",
        "ASL_A1_DONOR_DECODE_OK=1\nASL_A1_NEG_MALFORMED_PAYLOAD_REJECTED=1"
      )

    invalid_conflict =
      replace_in_arm(
        @valid_serial,
        "invalid_ool",
        "ASL_A1_NEG_INVALID_OOL_DESCRIPTOR_REJECTED=1",
        "ASL_A1_NEG_INVALID_OOL_DESCRIPTOR_REJECTED=0\nASL_A1_NEG_INVALID_OOL_DESCRIPTOR_REJECTED=1"
      )

    cross_arm =
      replace_in_arm(
        @valid_serial,
        "invalid_ool",
        "ASL_A1_NEG_INVALID_OOL_DESCRIPTOR_REJECTED=1",
        "ASL_A1_DONOR_DECODE_OK=1\nASL_A1_NEG_INVALID_OOL_DESCRIPTOR_REJECTED=1"
      )

    Enum.each(
      [malformed_conflict, malformed_duplicate, malformed_decode, invalid_conflict, cross_arm],
      fn serial -> refute AslA1ServerMessageOol.validate_serial(serial)["passed"] end
    )
  end

  test "audit mismatch and zeroed claimed identity fail" do
    mismatch =
      @valid_serial
      |> String.replace("ASL_A1_AUDIT_MATCH=1", "ASL_A1_AUDIT_MATCH=0")
      |> AslA1ServerMessageOol.validate_serial()

    zeroed =
      @valid_serial
      |> String.replace("ASL_A1_AUDIT_PID=1056", "ASL_A1_AUDIT_PID=0")
      |> AslA1ServerMessageOol.validate_serial()

    refute mismatch["passed"]
    refute zeroed["passed"]
  end

  test "project probe cannot own donor decoder implementations" do
    assert AslA1ServerMessageOol.static_donor_ownership_check(
             "extern int __asl_server_message(); rmx_asl_a1_donor_msg_release(msg);"
           )[
             "passed"
           ]

    refute AslA1ServerMessageOol.static_donor_ownership_check(
             "void *asl_msg_from_string(const char *x) { return 0; }"
           )["passed"]

    refute AslA1ServerMessageOol.static_donor_ownership_check(
             "void asl_release(void *obj) { (void)obj; } rmx_asl_a1_donor_msg_release(msg);"
           )["passed"]
  end

  test "first-attempt disposition is durable and explicitly supersedes acceptance" do
    disposition =
      CanonicalJSON.decode!(
        Path.join(File.cwd!(), "findings/asl-a1-first-attempt-disposition.json")
      )

    assert disposition["schema"] == "rmxos_oracle.asl_a1.first_attempt_disposition.v1"

    assert disposition["evidence_path"] ==
             "priv/runs/asl-a1/20260609T085402837615Z-asl-server-message-ool"

    assert disposition["evidence_tree_digest"] ==
             "229fd5d1c617a9446c8adae7ca9f98e8bf2ad3c3874fa5fa4e6a419f7c09412f"

    assert disposition["classification"] == "transport_infrastructure_only"
    assert disposition["accepted_claim"] == "not_accepted"
    assert disposition["raw_evidence_copied"] == false
    assert disposition["supersession"]["statement"] =~ "superseded and non-authoritative"
  end

  test "static marker manifest check rejects ASL A1 entries" do
    assert AslA1ServerMessageOol.static_marker_manifest_check("defmodule X do\nend\n")["passed"]
    refute AslA1ServerMessageOol.static_marker_manifest_check("ASL_A1_DONE=1")["passed"]
  end

  test "full revalidation rejects first-attempt shape without donor build provenance" do
    dir = temp_dir!("first-attempt")
    File.write!(Path.join(dir, "asl_a1_serial.log"), @valid_serial)
    CanonicalJSON.write!(Path.join(dir, "boot_identity.json"), %{"passed" => true})

    try do
      report = AslA1ServerMessageOol.revalidate_evidence(dir)

      refute report["passed"]
      assert report["classification"] == "transport_infrastructure_only"
      assert report["accepted_claim"] == "not_accepted"

      assert "missing donor_build_provenance.json; donor decoder build/link provenance absent" in report[
               "donor_build_provenance_errors"
             ]

      refute File.exists?(Path.join(dir, "revalidation.json"))
    after
      File.rm_rf!(dir)
    end
  end

  defp temp_dir!(label) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "rmxos-oracle-asl-a1-#{label}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    dir
  end

  defp replace_in_arm(serial, arm, original, replacement) do
    [before, tail] = String.split(serial, "ASL_A1_ARM_START=#{arm}", parts: 2)
    [body, after_arm] = String.split(tail, "ASL_A1_ARM_END=#{arm}", parts: 2)

    before <>
      "ASL_A1_ARM_START=#{arm}" <>
      String.replace(body, original, replacement, global: false) <>
      "ASL_A1_ARM_END=#{arm}" <> after_arm
  end

  defp swap_first(serial, first, second) do
    token = "__TEST_SWAP__"

    serial
    |> String.replace(first, token, global: false)
    |> String.replace(second, first, global: false)
    |> String.replace(token, second, global: false)
  end

  defp control_errors(controls, id) do
    controls["controls"]
    |> Enum.find(&(&1["id"] == id))
    |> Map.fetch!("observed_errors")
  end

  defp missing_emission_anchor?(report, key) do
    Enum.any?(report["missing_emission_anchors"], &(&1.key == key))
  end

  defp boot_identity_fixture(marker_value) do
    %{
      "schema" => "rmxos_oracle.asl_a1.boot_identity.v1",
      "mach_module_loaded_marker" => marker_value,
      "kernel" => %{"sha256" => String.duplicate("1", 64), "size" => 1},
      "mach_ko" => %{"sha256" => String.duplicate("2", 64), "size" => 1},
      "guest_image" => %{"sha256" => String.duplicate("3", 64), "size" => 1}
    }
  end
end
