defmodule RmxOSOracle.Migration.AslA1ServerMessageOolTest do
  use ExUnit.Case, async: true

  alias RmxOSOracle.CanonicalJSON
  alias RmxOSOracle.Migration.AslA1ServerMessageOol

  @payload_sha "a3ff9feadd6c4954712c16fb362ff5fcee0fa45a9a65d9e569fa7a33f7c7f977"

  @valid_serial """
  === ASL A1 server-message-ool start ===
  mach_module=loaded
  ASL_A1_PROBE_START=1
  ASL_A1_MIG_SUBSYSTEM=114
  ASL_A1_MIG_ROUTINE_ID=118
  ASL_A1_CLIENT_PID=123
  ASL_A1_CLIENT_UID=0
  ASL_A1_CLIENT_GID=0
  ASL_A1_ARM_START=positive_decode
  ASL_A1_EXPECTED_OOL_BYTE_COUNT=96
  ASL_A1_EXPECTED_OOL_SHA256=#{@payload_sha}
  ASL_A1_CLIENT_SEND_STARTED=1
  ASL_A1_SERVER_RECEIVE_KR=0
  ASL_A1_SERVER_RECEIVED_MSG_ID=118
  ASL_A1_SERVER_REQUESTED_AUDIT_TRAILER=1
  ASL_A1_SERVER_AUDIT_TRAILER_PRESENT=1
  ASL_A1_GENERATED_DEMUX_CALLED=1
  ASL_A1_DONOR_SERVER_MESSAGE_ENTER=1
  ASL_A1_RECEIVED_OOL_BYTE_COUNT=96
  ASL_A1_RECEIVED_OOL_SHA256=#{@payload_sha}
  ASL_A1_DONOR_OOL_BYTES_INTACT=1
  ASL_A1_DONOR_DECODE_OK=1
  ASL_A1_PROCESS_MESSAGE_STUB_CALLED=1
  ASL_A1_PROCESS_MESSAGE_SOURCE=5
  ASL_A1_PROCESS_MESSAGE_SENDER=oracle_asl_a1_client
  ASL_A1_PROCESS_MESSAGE_FACILITY=com.rmxos.oracle.asl
  ASL_A1_PROCESS_MESSAGE_LEVEL=5
  ASL_A1_PROCESS_MESSAGE_MESSAGE=oracle_asl_a1
  ASL_A1_PROCESS_MESSAGE_UID=0
  ASL_A1_PROCESS_MESSAGE_GID=0
  ASL_A1_PROCESS_MESSAGE_PID=123
  ASL_A1_AUDIT_UID=0
  ASL_A1_AUDIT_GID=0
  ASL_A1_AUDIT_PID=123
  ASL_A1_AUDIT_MATCH=1
  ASL_A1_AUDIT_CLAIM=accepted
  ASL_A1_PROCESS_MESSAGE_PAYLOAD_MATCH=1
  ASL_A1_DONOR_RELEASE_COMPLETED=1
  ASL_A1_GENERATED_DEMUX_HANDLED=1
  ASL_A1_CLIENT_SEND_KR=0
  ASL_A1_POSITIVE_DECODE_AND_STUB_CONFIRMED=1
  ASL_A1_ARM_END=positive_decode
  ASL_A1_ARM_START=malformed_payload
  ASL_A1_CLIENT_SEND_STARTED=1
  ASL_A1_SERVER_RECEIVE_KR=0
  ASL_A1_SERVER_RECEIVED_MSG_ID=118
  ASL_A1_SERVER_REQUESTED_AUDIT_TRAILER=1
  ASL_A1_SERVER_AUDIT_TRAILER_PRESENT=1
  ASL_A1_GENERATED_DEMUX_CALLED=1
  ASL_A1_DONOR_SERVER_MESSAGE_ENTER=1
  ASL_A1_RECEIVED_OOL_BYTE_COUNT=28
  ASL_A1_RECEIVED_OOL_SHA256=03a1bc4f95a8e9a6baafb960a79ff36b42f823ee19b7ff46b196cfe788bb9e05
  ASL_A1_GENERATED_DEMUX_HANDLED=1
  ASL_A1_CLIENT_SEND_KR=0
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

  test "allows normal WITNESS banner and rejects real diagnostics" do
    assert AslA1ServerMessageOol.hard_stop_scan(
             "WARNING: WITNESS option enabled, expect reduced performance.\n"
           )["passed"]

    refute AslA1ServerMessageOol.hard_stop_scan("WITNESS: lock diagnostic\n")["passed"]
    refute AslA1ServerMessageOol.hard_stop_scan("lock order reversal: witness report\n")["passed"]
  end

  test "required falsifiers fail closed" do
    assert AslA1ServerMessageOol.negative_controls(@valid_serial)["passed"]
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
      |> String.replace("ASL_A1_AUDIT_PID=123", "ASL_A1_AUDIT_PID=0")
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
end
