defmodule RmxOSOracle.Asl.A1.MarkerManifest do
  @moduledoc """
  Oracle-owned ASL A1 marker authority extracted from accepted runtime evidence.

  Closeout/provenance:

  * accepted claim: `ool_transport_decode_plus_audit_identity`
  * non-claims: no launchd handoff, no storage/query/syslog/aslmanager behavior,
    no certification claim, no ASL A2 behavior
  * accepted evidence:
    `priv/runs/asl-a1/20260609T112655558626Z-asl-server-message-ool/post_run_revalidation.json`
  * accepted serial SHA256:
    `a784bba7149d98858d7067d4f4e8f2a633d9b4e503a0719ca3d37b41b67aa467`
  * original failed attempt disposition:
    `findings/asl-a1-first-attempt-disposition.json`
  * raw `parity.json` and `marker_validation.json` from the replacement run are
    historical failed in-run outputs; `post_run_revalidation.json` is the
    accepted host-only revalidation over unchanged raw evidence
  * replacement runtime evidence count: `n=1`

  The manifest owns marker keys, exact value policies, arm membership, ordering
  contracts, OOL integrity constants, terminal contract, and audit identity
  policy. The ASL verifier consumes this module instead of maintaining an
  independent marker list.
  """

  @accepted_claim "ool_transport_decode_plus_audit_identity"
  @accepted_evidence_dir "priv/runs/asl-a1/20260609T112655558626Z-asl-server-message-ool"
  @post_run_revalidation_path Path.join(@accepted_evidence_dir, "post_run_revalidation.json")
  @accepted_serial_sha256 "a784bba7149d98858d7067d4f4e8f2a633d9b4e503a0719ca3d37b41b67aa467"
  @donor_commit "8be0f2507b69906d068bed31ffc58cdfafadaef3"
  @source_authorization_commit "2444504cc7727b1c8e957b4929b7233c9187f1a1"
  @failed_attempt_disposition "findings/asl-a1-first-attempt-disposition.json"
  @replacement_runtime_evidence_count 1

  @probe_path "priv/probes/asl/a1_server_message_ool.c"
  @start_marker "=== ASL A1 server-message-ool start ==="
  @success_marker "=== ASL A1 server-message-ool end rc=0 ==="
  @expected_ool_byte_count "96"
  @expected_ool_sha256 "a3ff9feadd6c4954712c16fb362ff5fcee0fa45a9a65d9e569fa7a33f7c7f977"
  @malformed_ool_byte_count "28"
  @malformed_ool_sha256 "bd153d0688b6c4c77e8587258a87b887f15de6c7b63c36d7ad3790ba820f6f49"

  @roles [
    :positive_claim,
    :negative_arm,
    :terminal,
    :arm_boundary,
    :infrastructure,
    :audit_identity,
    :ool_integrity,
    :process_stub,
    :summary,
    :fenced
  ]

  @producers [:donor, :kernel, :harness]

  def accepted_claim, do: @accepted_claim
  def accepted_evidence_dir, do: @accepted_evidence_dir
  def post_run_revalidation_path, do: @post_run_revalidation_path
  def accepted_serial_sha256, do: @accepted_serial_sha256
  def donor_commit, do: @donor_commit
  def source_authorization_commit, do: @source_authorization_commit
  def failed_attempt_disposition_path, do: @failed_attempt_disposition
  def replacement_runtime_evidence_count, do: @replacement_runtime_evidence_count
  def probe_path, do: @probe_path
  def start_marker, do: @start_marker
  def success_marker, do: @success_marker
  def expected_ool_byte_count, do: @expected_ool_byte_count
  def expected_ool_sha256, do: @expected_ool_sha256
  def malformed_ool_byte_count, do: @malformed_ool_byte_count
  def malformed_ool_sha256, do: @malformed_ool_sha256
  def roles, do: @roles
  def producers, do: @producers

  def closeout do
    %{
      accepted_claim: @accepted_claim,
      non_claims: [
        "no_launchd_handoff",
        "no_storage_query_syslog_aslmanager_behavior",
        "no_certification_claim",
        "no_asl_a2_behavior"
      ],
      accepted_evidence_path: @post_run_revalidation_path,
      accepted_serial_sha256: @accepted_serial_sha256,
      original_failed_attempt_disposition: @failed_attempt_disposition,
      historical_failed_in_run_outputs: ["parity.json", "marker_validation.json"],
      authoritative_revalidation: "post_run_revalidation.json",
      raw_evidence_mutated: false,
      replacement_runtime_evidence_count: @replacement_runtime_evidence_count,
      donor_commit: @donor_commit,
      source_authorization_commit: @source_authorization_commit
    }
  end

  def specs do
    global_specs() ++
      positive_decode_specs() ++
      malformed_payload_specs() ++
      invalid_ool_specs() ++
      terminal_specs()
  end

  def marker_keys do
    specs()
    |> Enum.map(& &1.key)
    |> Enum.uniq()
  end

  def spec!(id) when is_atom(id) do
    Enum.find(specs(), &(&1.id == id)) ||
      raise ArgumentError, "unknown ASL A1 marker id: #{inspect(id)}"
  end

  def key!(id), do: spec!(id).key
  def value!(id), do: spec!(id).value
  def marker!(id), do: {key!(id), value!(id)}
  def line!(id), do: "#{key!(id)}=#{value!(id)}"

  def line_with_value!(id, value) do
    "#{key!(id)}=#{value}"
  end

  def arm_start_line(arm), do: line_with_value!(:positive_arm_start, arm)
  def arm_end_line(arm), do: line_with_value!(:positive_arm_end, arm)

  def nonaccepted_probe_key!(:audit_defer_reason), do: "ASL_A1_AUDIT_DEFER_REASON"
  def nonaccepted_probe_key!(:session_tracking), do: "ASL_A1_SESSION_TRACKING"

  def marker_literals do
    specs()
    |> Enum.filter(&(&1.value_policy == :must_equal))
    |> Enum.map(&"#{&1.key}=#{&1.value}")
    |> Enum.uniq()
  end

  def global_markers do
    specs_for_arm(:global) |> exact_pairs()
  end

  def terminal_markers do
    specs_for_arm(:terminal) |> exact_pairs()
  end

  def transport_infrastructure_markers do
    [
      {"ASL_A1_CLIENT_SEND_STARTED", "1"},
      {"ASL_A1_CLIENT_SEND_KR", "0"},
      {"ASL_A1_SERVER_RECEIVE_KR", "0"},
      {"ASL_A1_SERVER_RECEIVED_MSG_ID", "118"},
      {"ASL_A1_SERVER_REQUESTED_AUDIT_TRAILER", "1"},
      {"ASL_A1_SERVER_AUDIT_TRAILER_PRESENT", "1"},
      {"ASL_A1_GENERATED_DEMUX_CALLED", "1"},
      {"ASL_A1_GENERATED_DEMUX_HANDLED", "1"},
      {"ASL_A1_DONE", "1"}
    ]
  end

  def arm_contracts do
    %{
      "positive_decode" => specs_for_arm(:positive_decode) |> exact_pairs(),
      "malformed_payload" => specs_for_arm(:malformed_payload) |> exact_pairs(),
      "invalid_ool" => specs_for_arm(:invalid_ool) |> exact_pairs()
    }
  end

  def critical_positive_order do
    [
      {"ASL_A1_ARM_START", "positive_decode"},
      {"ASL_A1_CLIENT_SEND_STARTED", "1"},
      {"ASL_A1_CLIENT_SEND_KR", "0"},
      {"ASL_A1_SERVER_RECEIVE_KR", "0"},
      {"ASL_A1_GENERATED_DEMUX_CALLED", "1"},
      {"ASL_A1_DONOR_SERVER_MESSAGE_ENTER", "1"},
      {"ASL_A1_DONOR_DECODE_OK", "1"},
      {"ASL_A1_PROCESS_MESSAGE_PAYLOAD_MATCH", "1"},
      {"ASL_A1_DONOR_RELEASE_COMPLETED", "1"},
      {"ASL_A1_GENERATED_DEMUX_HANDLED", "1"},
      {"ASL_A1_POSITIVE_DECODE_AND_STUB_CONFIRMED", "1"},
      {"ASL_A1_ARM_END", "positive_decode"}
    ]
  end

  def arm_order_contracts do
    %{
      "positive_decode" => critical_positive_order(),
      "malformed_payload" => [
        {"ASL_A1_ARM_START", "malformed_payload"},
        {"ASL_A1_CLIENT_SEND_STARTED", "1"},
        {"ASL_A1_CLIENT_SEND_KR", "0"},
        {"ASL_A1_SERVER_RECEIVE_KR", "0"},
        {"ASL_A1_GENERATED_DEMUX_CALLED", "1"},
        {"ASL_A1_DONOR_SERVER_MESSAGE_ENTER", "1"},
        {"ASL_A1_GENERATED_DEMUX_HANDLED", "1"},
        {"ASL_A1_NEG_MALFORMED_PAYLOAD_REJECTED", "1"},
        {"ASL_A1_ARM_END", "malformed_payload"}
      ],
      "invalid_ool" => [
        {"ASL_A1_ARM_START", "invalid_ool"},
        {"ASL_A1_NEG_INVALID_OOL_DESCRIPTOR_REJECTED", "1"},
        {"ASL_A1_ARM_END", "invalid_ool"}
      ]
    }
  end

  def arm_exclusive_keys do
    arm_keys =
      [:positive_decode, :malformed_payload, :invalid_ool]
      |> Map.new(fn arm ->
        keys =
          specs_for_arm(arm)
          |> Enum.map(& &1.key)
          |> Enum.reject(&(&1 in ["ASL_A1_ARM_START", "ASL_A1_ARM_END"]))
          |> MapSet.new()

        {arm, keys}
      end)

    Enum.into(arm_keys, %{}, fn {arm, keys} ->
      other_keys =
        arm_keys
        |> Enum.reject(fn {other, _} -> other == arm end)
        |> Enum.reduce(MapSet.new(), fn {_, other_keys}, acc -> MapSet.union(acc, other_keys) end)

      {Atom.to_string(arm), keys |> MapSet.difference(other_keys) |> MapSet.to_list()}
    end)
  end

  def positive_singleton_keys do
    specs_for_arm(:positive_decode)
    |> Enum.map(& &1.key)
    |> Enum.reject(&(&1 in ["ASL_A1_ARM_START", "ASL_A1_ARM_END"]))
    |> Enum.uniq()
  end

  def claim_singleton_keys do
    [
      "ASL_A1_AUDIT_UID",
      "ASL_A1_AUDIT_GID",
      "ASL_A1_AUDIT_PID",
      "ASL_A1_AUDIT_MATCH",
      "ASL_A1_AUDIT_CLAIM",
      "ASL_A1_DONOR_DECODE_OK",
      "ASL_A1_DONOR_RELEASE_COMPLETED",
      "ASL_A1_PROCESS_MESSAGE_PAYLOAD_MATCH",
      "ASL_A1_POSITIVE_DECODE_AND_STUB_CONFIRMED",
      "ASL_A1_DONE"
    ]
  end

  def ool_policy do
    %{
      expected_byte_count: @expected_ool_byte_count,
      expected_sha256: @expected_ool_sha256,
      exact_count_required: true,
      exact_sha256_required: true,
      full_equality_marker: {"ASL_A1_DONOR_OOL_BYTES_INTACT", "1"}
    }
  end

  def audit_policy do
    %{
      claim: "accepted",
      load_bearing: true,
      identity_fields: [
        "ASL_A1_CLIENT_UID",
        "ASL_A1_CLIENT_GID",
        "ASL_A1_CLIENT_PID",
        "ASL_A1_PROCESS_MESSAGE_UID",
        "ASL_A1_PROCESS_MESSAGE_GID",
        "ASL_A1_PROCESS_MESSAGE_PID",
        "ASL_A1_AUDIT_UID",
        "ASL_A1_AUDIT_GID",
        "ASL_A1_AUDIT_PID"
      ]
    }
  end

  def terminal_contract do
    %{
      start_line: @start_marker,
      success_line: @success_marker,
      terminal_marker: {"ASL_A1_DONE", "1"},
      exactly_one_success_line: true,
      exactly_one_terminal_marker: true
    }
  end

  def invariants do
    %{
      generated_demux_not_donor_decode: true,
      process_stub_not_donor_decode: true,
      audit_identity_separate_from_process_message_identity: true,
      donor_behavior_requires_donor_markers: [
        "ASL_A1_DONOR_SERVER_MESSAGE_ENTER",
        "ASL_A1_DONOR_DECODE_OK",
        "ASL_A1_DONOR_RELEASE_COMPLETED"
      ],
      summary_marker_not_primary_proof: "ASL_A1_POSITIVE_DECODE_AND_STUB_CONFIRMED",
      task_name_for_pid_fenced_sentinel: {"ASL_A1_TASK_NAME_FOR_PID", "fenced_deferred"}
    }
  end

  def specs_for_arm(arm) when is_atom(arm) do
    Enum.filter(specs(), &(&1.arm == arm))
  end

  def category_breakdown do
    specs()
    |> Enum.frequencies_by(& &1.role)
    |> Map.new(fn {role, count} -> {role, count} end)
  end

  def producer_breakdown do
    specs()
    |> Enum.frequencies_by(& &1.producer)
    |> Map.new(fn {producer, count} -> {producer, count} end)
  end

  defp exact_pairs(specs) do
    specs
    |> Enum.filter(&(&1.value_policy == :must_equal and &1.required))
    |> Enum.map(&{&1.key, &1.value})
  end

  defp global_specs do
    [
      spec(
        :probe_start,
        "ASL_A1_PROBE_START",
        "1",
        :infrastructure,
        :global,
        :harness,
        :orchestration
      ),
      spec(
        :mig_subsystem,
        "ASL_A1_MIG_SUBSYSTEM",
        "114",
        :infrastructure,
        :global,
        :harness,
        :generated_mig
      ),
      spec(
        :mig_routine_id,
        "ASL_A1_MIG_ROUTINE_ID",
        "118",
        :infrastructure,
        :global,
        :harness,
        :generated_mig
      ),
      spec(
        :client_pid,
        "ASL_A1_CLIENT_PID",
        "1056",
        :infrastructure,
        :global,
        :harness,
        :client_probe
      ),
      spec(
        :client_uid,
        "ASL_A1_CLIENT_UID",
        "0",
        :infrastructure,
        :global,
        :harness,
        :client_probe
      ),
      spec(
        :client_gid,
        "ASL_A1_CLIENT_GID",
        "0",
        :infrastructure,
        :global,
        :harness,
        :client_probe
      )
    ]
  end

  defp positive_decode_specs do
    [
      spec(
        :positive_arm_start,
        "ASL_A1_ARM_START",
        "positive_decode",
        :arm_boundary,
        :positive_decode,
        :harness,
        :orchestration
      ),
      spec(
        :expected_ool_count,
        "ASL_A1_EXPECTED_OOL_BYTE_COUNT",
        @expected_ool_byte_count,
        :ool_integrity,
        :positive_decode,
        :harness,
        :ool_integrity
      ),
      spec(
        :expected_ool_sha,
        "ASL_A1_EXPECTED_OOL_SHA256",
        @expected_ool_sha256,
        :ool_integrity,
        :positive_decode,
        :harness,
        :ool_integrity
      ),
      spec(
        :positive_client_send_started,
        "ASL_A1_CLIENT_SEND_STARTED",
        "1",
        :infrastructure,
        :positive_decode,
        :harness,
        :client_probe
      ),
      spec(
        :positive_client_send_kr,
        "ASL_A1_CLIENT_SEND_KR",
        "0",
        :infrastructure,
        :positive_decode,
        :harness,
        :client_probe
      ),
      spec(
        :positive_server_receive_kr,
        "ASL_A1_SERVER_RECEIVE_KR",
        "0",
        :infrastructure,
        :positive_decode,
        :harness,
        :server_probe
      ),
      spec(
        :positive_server_msg_id,
        "ASL_A1_SERVER_RECEIVED_MSG_ID",
        "118",
        :infrastructure,
        :positive_decode,
        :harness,
        :server_probe
      ),
      spec(
        :positive_audit_requested,
        "ASL_A1_SERVER_REQUESTED_AUDIT_TRAILER",
        "1",
        :infrastructure,
        :positive_decode,
        :harness,
        :server_probe
      ),
      spec(
        :positive_audit_present,
        "ASL_A1_SERVER_AUDIT_TRAILER_PRESENT",
        "1",
        :infrastructure,
        :positive_decode,
        :kernel,
        :audit_trailer
      ),
      spec(
        :positive_demux_called,
        "ASL_A1_GENERATED_DEMUX_CALLED",
        "1",
        :infrastructure,
        :positive_decode,
        :harness,
        :generated_mig
      ),
      spec(
        :positive_donor_enter,
        "ASL_A1_DONOR_SERVER_MESSAGE_ENTER",
        "1",
        :positive_claim,
        :positive_decode,
        :donor,
        :donor_decode
      ),
      spec(
        :positive_received_ool_count,
        "ASL_A1_RECEIVED_OOL_BYTE_COUNT",
        @expected_ool_byte_count,
        :ool_integrity,
        :positive_decode,
        :harness,
        :ool_integrity
      ),
      spec(
        :positive_received_ool_sha,
        "ASL_A1_RECEIVED_OOL_SHA256",
        @expected_ool_sha256,
        :ool_integrity,
        :positive_decode,
        :harness,
        :ool_integrity
      ),
      spec(
        :positive_ool_intact,
        "ASL_A1_DONOR_OOL_BYTES_INTACT",
        "1",
        :ool_integrity,
        :positive_decode,
        :harness,
        :ool_integrity
      ),
      spec(
        :positive_task_name_fenced,
        "ASL_A1_TASK_NAME_FOR_PID",
        "fenced_deferred",
        :fenced,
        :positive_decode,
        :harness,
        :fenced_deferred
      ),
      spec(
        :positive_donor_decode_ok,
        "ASL_A1_DONOR_DECODE_OK",
        "1",
        :positive_claim,
        :positive_decode,
        :donor,
        :donor_decode
      ),
      spec(
        :positive_process_stub_called,
        "ASL_A1_PROCESS_MESSAGE_STUB_CALLED",
        "1",
        :process_stub,
        :positive_decode,
        :harness,
        :process_stub
      ),
      spec(
        :positive_process_source,
        "ASL_A1_PROCESS_MESSAGE_SOURCE",
        "5",
        :process_stub,
        :positive_decode,
        :harness,
        :process_stub
      ),
      spec(
        :positive_process_sender,
        "ASL_A1_PROCESS_MESSAGE_SENDER",
        "oracle_asl_a1_client",
        :process_stub,
        :positive_decode,
        :harness,
        :process_stub
      ),
      spec(
        :positive_process_facility,
        "ASL_A1_PROCESS_MESSAGE_FACILITY",
        "com.rmxos.oracle.asl",
        :process_stub,
        :positive_decode,
        :harness,
        :process_stub
      ),
      spec(
        :positive_process_level,
        "ASL_A1_PROCESS_MESSAGE_LEVEL",
        "5",
        :process_stub,
        :positive_decode,
        :harness,
        :process_stub
      ),
      spec(
        :positive_process_message,
        "ASL_A1_PROCESS_MESSAGE_MESSAGE",
        "oracle_asl_a1",
        :process_stub,
        :positive_decode,
        :harness,
        :process_stub
      ),
      spec(
        :positive_process_uid,
        "ASL_A1_PROCESS_MESSAGE_UID",
        "0",
        :process_stub,
        :positive_decode,
        :harness,
        :process_stub
      ),
      spec(
        :positive_process_gid,
        "ASL_A1_PROCESS_MESSAGE_GID",
        "0",
        :process_stub,
        :positive_decode,
        :harness,
        :process_stub
      ),
      spec(
        :positive_process_pid,
        "ASL_A1_PROCESS_MESSAGE_PID",
        "1056",
        :process_stub,
        :positive_decode,
        :harness,
        :process_stub
      ),
      spec(
        :positive_audit_uid,
        "ASL_A1_AUDIT_UID",
        "0",
        :audit_identity,
        :positive_decode,
        :kernel,
        :audit_trailer
      ),
      spec(
        :positive_audit_gid,
        "ASL_A1_AUDIT_GID",
        "0",
        :audit_identity,
        :positive_decode,
        :kernel,
        :audit_trailer
      ),
      spec(
        :positive_audit_pid,
        "ASL_A1_AUDIT_PID",
        "1056",
        :audit_identity,
        :positive_decode,
        :kernel,
        :audit_trailer
      ),
      spec(
        :positive_audit_match,
        "ASL_A1_AUDIT_MATCH",
        "1",
        :audit_identity,
        :positive_decode,
        :kernel,
        :audit_trailer
      ),
      spec(
        :positive_audit_claim,
        "ASL_A1_AUDIT_CLAIM",
        "accepted",
        :audit_identity,
        :positive_decode,
        :kernel,
        :audit_trailer
      ),
      spec(
        :positive_payload_match,
        "ASL_A1_PROCESS_MESSAGE_PAYLOAD_MATCH",
        "1",
        :process_stub,
        :positive_decode,
        :harness,
        :process_stub
      ),
      spec(
        :positive_donor_release,
        "ASL_A1_DONOR_RELEASE_COMPLETED",
        "1",
        :positive_claim,
        :positive_decode,
        :donor,
        :donor_release
      ),
      spec(
        :positive_demux_handled,
        "ASL_A1_GENERATED_DEMUX_HANDLED",
        "1",
        :infrastructure,
        :positive_decode,
        :harness,
        :generated_mig
      ),
      spec(
        :positive_summary,
        "ASL_A1_POSITIVE_DECODE_AND_STUB_CONFIRMED",
        "1",
        :summary,
        :positive_decode,
        :harness,
        :orchestration
      ),
      spec(
        :positive_arm_end,
        "ASL_A1_ARM_END",
        "positive_decode",
        :arm_boundary,
        :positive_decode,
        :harness,
        :orchestration
      )
    ]
  end

  defp malformed_payload_specs do
    [
      spec(
        :malformed_arm_start,
        "ASL_A1_ARM_START",
        "malformed_payload",
        :arm_boundary,
        :malformed_payload,
        :harness,
        :negative_control
      ),
      spec(
        :malformed_client_send_started,
        "ASL_A1_CLIENT_SEND_STARTED",
        "1",
        :negative_arm,
        :malformed_payload,
        :harness,
        :client_probe
      ),
      spec(
        :malformed_client_send_kr,
        "ASL_A1_CLIENT_SEND_KR",
        "0",
        :negative_arm,
        :malformed_payload,
        :harness,
        :client_probe
      ),
      spec(
        :malformed_server_receive_kr,
        "ASL_A1_SERVER_RECEIVE_KR",
        "0",
        :negative_arm,
        :malformed_payload,
        :harness,
        :server_probe
      ),
      spec(
        :malformed_server_msg_id,
        "ASL_A1_SERVER_RECEIVED_MSG_ID",
        "118",
        :negative_arm,
        :malformed_payload,
        :harness,
        :server_probe
      ),
      spec(
        :malformed_audit_requested,
        "ASL_A1_SERVER_REQUESTED_AUDIT_TRAILER",
        "1",
        :negative_arm,
        :malformed_payload,
        :harness,
        :server_probe
      ),
      spec(
        :malformed_audit_present,
        "ASL_A1_SERVER_AUDIT_TRAILER_PRESENT",
        "1",
        :negative_arm,
        :malformed_payload,
        :kernel,
        :audit_trailer
      ),
      spec(
        :malformed_demux_called,
        "ASL_A1_GENERATED_DEMUX_CALLED",
        "1",
        :negative_arm,
        :malformed_payload,
        :harness,
        :generated_mig
      ),
      spec(
        :malformed_donor_enter,
        "ASL_A1_DONOR_SERVER_MESSAGE_ENTER",
        "1",
        :negative_arm,
        :malformed_payload,
        :donor,
        :donor_decode
      ),
      spec(
        :malformed_received_ool_count,
        "ASL_A1_RECEIVED_OOL_BYTE_COUNT",
        @malformed_ool_byte_count,
        :negative_arm,
        :malformed_payload,
        :harness,
        :ool_integrity
      ),
      spec(
        :malformed_received_ool_sha,
        "ASL_A1_RECEIVED_OOL_SHA256",
        @malformed_ool_sha256,
        :negative_arm,
        :malformed_payload,
        :harness,
        :ool_integrity
      ),
      spec(
        :malformed_demux_handled,
        "ASL_A1_GENERATED_DEMUX_HANDLED",
        "1",
        :negative_arm,
        :malformed_payload,
        :harness,
        :generated_mig
      ),
      spec(
        :malformed_rejected,
        "ASL_A1_NEG_MALFORMED_PAYLOAD_REJECTED",
        "1",
        :negative_arm,
        :malformed_payload,
        :harness,
        :negative_control
      ),
      spec(
        :malformed_arm_end,
        "ASL_A1_ARM_END",
        "malformed_payload",
        :arm_boundary,
        :malformed_payload,
        :harness,
        :negative_control
      )
    ]
  end

  defp invalid_ool_specs do
    [
      spec(
        :invalid_ool_arm_start,
        "ASL_A1_ARM_START",
        "invalid_ool",
        :arm_boundary,
        :invalid_ool,
        :harness,
        :negative_control
      ),
      spec(
        :invalid_ool_rejected,
        "ASL_A1_NEG_INVALID_OOL_DESCRIPTOR_REJECTED",
        "1",
        :negative_arm,
        :invalid_ool,
        :harness,
        :negative_control
      ),
      spec(
        :invalid_ool_arm_end,
        "ASL_A1_ARM_END",
        "invalid_ool",
        :arm_boundary,
        :invalid_ool,
        :harness,
        :negative_control
      )
    ]
  end

  defp terminal_specs do
    [
      spec(:terminal_done, "ASL_A1_DONE", "1", :terminal, :terminal, :harness, :orchestration)
    ]
  end

  defp spec(id, key, value, role, arm, producer, producer_detail, opts \\ []) do
    %{
      id: id,
      key: key,
      value: value,
      value_policy: Keyword.get(opts, :value_policy, :must_equal),
      role: role,
      arm: arm,
      producer: producer,
      producer_detail: producer_detail,
      required: Keyword.get(opts, :required, true),
      load_bearing:
        Keyword.get(
          opts,
          :load_bearing,
          role in [:positive_claim, :audit_identity, :ool_integrity, :process_stub, :negative_arm]
        ),
      anchor: Keyword.get(opts, :anchor, key),
      emission_anchors: Keyword.get(opts, :emission_anchors, emission_anchors_for(id, key, value))
    }
  end

  defp emission_anchors_for(:client_pid, key, _value), do: [~s|emit_i32("#{key}", getpid())|]
  defp emission_anchors_for(:client_uid, key, _value), do: [~s|emit_i32("#{key}", geteuid())|]
  defp emission_anchors_for(:client_gid, key, _value), do: [~s|emit_i32("#{key}", getegid())|]

  defp emission_anchors_for(:expected_ool_count, key, _value),
    do: [~s|emit_u32("#{key}", sizeof(ASL_A1_POSITIVE_PAYLOAD))|]

  defp emission_anchors_for(:expected_ool_sha, key, _value),
    do: [
      ~s|emit_sha256("#{key}", ASL_A1_POSITIVE_PAYLOAD,|,
      "sizeof(ASL_A1_POSITIVE_PAYLOAD))"
    ]

  defp emission_anchors_for(id, key, _value)
       when id in [:positive_client_send_kr, :malformed_client_send_kr],
       do: [~s|emit_i32("#{key}", kr)|]

  defp emission_anchors_for(id, key, _value)
       when id in [:positive_server_receive_kr, :malformed_server_receive_kr],
       do: [~s|emit_i32("#{key}", state->receive_kr)|]

  defp emission_anchors_for(id, key, _value)
       when id in [:positive_server_msg_id, :malformed_server_msg_id],
       do: [~s|emit_u32("#{key}", (uint32_t)request.head.msgh_id)|]

  defp emission_anchors_for(id, key, _value)
       when id in [:positive_audit_present, :malformed_audit_present],
       do: [
         ~s|emit_kv("#{key}",|,
         ~s|state->audit_trailer_present ? "1" : "0"|
       ]

  defp emission_anchors_for(id, key, _value)
       when id in [:positive_received_ool_count, :malformed_received_ool_count],
       do: [~s|emit_u32("#{key}", (uint32_t)(len + 1))|]

  defp emission_anchors_for(id, key, _value)
       when id in [:positive_received_ool_sha, :malformed_received_ool_sha],
       do: [~s|emit_sha256("#{key}", payload, len + 1)|]

  defp emission_anchors_for(:positive_process_source, key, _value),
    do: [~s|emit_u32("#{key}", source)|]

  defp emission_anchors_for(:positive_process_sender, key, _value),
    do: [~s|emit_kv("#{key}", sender)|]

  defp emission_anchors_for(:positive_process_facility, key, _value),
    do: [~s|emit_kv("#{key}", facility)|]

  defp emission_anchors_for(:positive_process_level, key, _value),
    do: [~s|emit_kv("#{key}", level)|]

  defp emission_anchors_for(:positive_process_message, key, _value),
    do: [~s|emit_kv("#{key}", message)|]

  defp emission_anchors_for(:positive_process_uid, key, _value),
    do: [~s|emit_kv("#{key}", uid)|]

  defp emission_anchors_for(:positive_process_gid, key, _value),
    do: [~s|emit_kv("#{key}", gid)|]

  defp emission_anchors_for(:positive_process_pid, key, _value),
    do: [~s|emit_kv("#{key}", pid)|]

  defp emission_anchors_for(:positive_audit_uid, key, _value),
    do: [~s|emit_kv("#{key}", uid)|]

  defp emission_anchors_for(:positive_audit_gid, key, _value),
    do: [~s|emit_kv("#{key}", gid)|]

  defp emission_anchors_for(:positive_audit_pid, key, _value),
    do: [~s|emit_kv("#{key}", pid)|]

  defp emission_anchors_for(id, key, _value)
       when id in [:positive_demux_handled, :malformed_demux_handled],
       do: [~s|emit_kv("#{key}", state->demux_handled ? "1" : "0")|]

  defp emission_anchors_for(:terminal_done, key, _value),
    do: [~s|emit_kv("#{key}", rc == 0 ? "1" : "0")|]

  defp emission_anchors_for(_id, key, value), do: [~s|emit_kv("#{key}", "#{value}")|]
end
