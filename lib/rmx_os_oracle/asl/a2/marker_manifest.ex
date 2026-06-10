defmodule RmxOSOracle.Asl.A2.MarkerManifest do
  @moduledoc """
  Oracle-owned ASL A2 marker authority extracted from accepted runtime evidence.

  Closeout/provenance:

  * accepted claim: `launchd_handoff_plus_donor_lookup_nonce_identity`
  * non-claims: no ASL decode/storage/query/syslog/aslmanager/XPC/libnotify
    claim, no generic Phase 0.85 authority, no D22/D23 launchctl migration, and
    no certification claim
  * accepted evidence:
    `priv/runs/asl-a2/20260610T0407195Z-system-logger-handoff`
  * accepted evidence tree digest:
    `0442e4be9ce977d8992b5bbe97a2e654b3d54309cc19b805d8ad43ad721e0dad`
  * source authorization pin:
    `cc2d081ab028c6bef902d1d1b0af9cdd91790334`
  * raw runtime evidence count: `n=1`

  The manifest owns marker keys, exact value policies, critical order, OOL
  integrity constants, port-identity nonce proof, terminal contract, and the
  accepted negative-control contracts. The A2 verifier consumes this module
  instead of maintaining independent marker literals.
  """

  @accepted_claim "launchd_handoff_plus_donor_lookup_nonce_identity"
  @accepted_evidence_dir "priv/runs/asl-a2/20260610T0407195Z-system-logger-handoff"
  @accepted_evidence_tree_digest "0442e4be9ce977d8992b5bbe97a2e654b3d54309cc19b805d8ad43ad721e0dad"
  @accepted_serial_sha256 "dd8763f70b6d0db4758a8867b9b9bd8ab7c699cdc8d5679ab30d9343e883fc93"
  @oracle_pin_commit "347c377789e7505508757ec47241752f3bc4a097"
  @source_authorization_commit "cc2d081ab028c6bef902d1d1b0af9cdd91790334"
  @donor_commit "8be0f2507b69906d068bed31ffc58cdfafadaef3"
  @bootstrap_harness_sha256 "a2089fa8f5551ecf1572fc790e1f33e4f6719151b3e3778e2dac4268c54e583c"
  @bootstrap_harness_path "/Users/me/wip-mach/build/phase1-launchd-harness-link/launchd-donor-bootstrap-harness"
  @fixture_path "fixtures/launchd/org.rmxos.asl.a2.system-logger.plist"
  @fixture_sha256 "db5026532947fa2913d7e7560e674ef2f92dcce649b8e8e4bfe28c366dca9922"
  @probe_path "priv/probes/asl/a2_system_logger_handoff.c"
  @service_name "com.apple.system.logger"
  @nonce "rmxos-asl-a2-nonce-v1"
  @payload_byte_count "104"
  @payload_sha256 "fab284180de734bdd4374aea271ca34a96c759f3053ccb14a22945a1f50c373b"
  @mig_routine_id "118"

  @roles [
    :launchd_handoff,
    :donor_lookup,
    :port_identity,
    :terminal,
    :infrastructure,
    :ool_integrity,
    :audit_trailer,
    :summary
  ]

  @producers [:launchd, :donor, :kernel, :harness]

  def accepted_claim, do: @accepted_claim
  def accepted_evidence_dir, do: @accepted_evidence_dir
  def accepted_evidence_tree_digest, do: @accepted_evidence_tree_digest
  def accepted_serial_sha256, do: @accepted_serial_sha256
  def oracle_pin_commit, do: @oracle_pin_commit
  def source_authorization_commit, do: @source_authorization_commit
  def donor_commit, do: @donor_commit
  def bootstrap_harness_sha256, do: @bootstrap_harness_sha256
  def bootstrap_harness_path, do: @bootstrap_harness_path
  def fixture_path, do: @fixture_path
  def fixture_sha256, do: @fixture_sha256
  def probe_path, do: @probe_path
  def service_name, do: @service_name
  def nonce, do: @nonce
  def payload_byte_count, do: @payload_byte_count
  def payload_sha256, do: @payload_sha256
  def mig_routine_id, do: @mig_routine_id
  def roles, do: @roles
  def producers, do: @producers

  def closeout do
    %{
      accepted_claim: @accepted_claim,
      non_claims: [
        "no_asl_decode_storage_query_syslog_aslmanager_xpc_libnotify_claim",
        "no_generic_phase_085_authority",
        "no_d22_d23_launchctl_migration",
        "no_certification_claim"
      ],
      accepted_evidence_path: @accepted_evidence_dir,
      accepted_evidence_tree_digest: @accepted_evidence_tree_digest,
      accepted_serial_sha256: @accepted_serial_sha256,
      source_authorization_commit: @source_authorization_commit,
      oracle_pin_commit: @oracle_pin_commit,
      donor_commit: @donor_commit,
      bootstrap_fixture: %{
        path: @fixture_path,
        sha256: @fixture_sha256
      },
      bootstrap_harness: %{
        path: @bootstrap_harness_path,
        sha256: @bootstrap_harness_sha256
      },
      ool_integrity: ool_policy(),
      raw_evidence_mutated: false,
      runtime_evidence_count: 1
    }
  end

  def specs do
    subclaim_a_specs() ++ subclaim_b_specs() ++ terminal_specs()
  end

  def marker_keys do
    specs()
    |> Enum.map(& &1.key)
    |> Enum.uniq()
  end

  def marker_literals do
    specs()
    |> Enum.filter(&(&1.value_policy == :must_equal))
    |> Enum.map(&"#{&1.key}=#{&1.value}")
    |> Enum.uniq()
  end

  def spec!(id) when is_atom(id) do
    Enum.find(specs(), &(&1.id == id)) ||
      raise ArgumentError, "unknown ASL A2 marker id: #{inspect(id)}"
  end

  def key!(id), do: spec!(id).key
  def value!(id), do: spec!(id).value
  def marker!(id), do: {key!(id), value!(id)}
  def line!(id), do: "#{key!(id)}=#{value!(id)}"
  def line_with_value!(id, value), do: "#{key!(id)}=#{value}"

  def required_exact do
    specs()
    |> Enum.filter(&(&1.required and &1.value_policy == :must_equal))
    |> Enum.map(&{&1.key, &1.value})
  end

  def policy_specs do
    specs()
    |> Enum.filter(&(&1.required and &1.value_policy != :must_equal))
  end

  def singleton_keys do
    specs()
    |> Enum.filter(& &1.required)
    |> Enum.map(& &1.key)
    |> Enum.reject(&(&1 == key!(:server_service_name)))
    |> Enum.uniq()
  end

  def required_marker_count(key, value) do
    specs()
    |> Enum.count(&(&1.required and &1.key == key and &1.value == value))
    |> case do
      0 -> 1
      count -> count
    end
  end

  def required_order do
    [
      marker!(:launch_checkin_called),
      marker!(:launch_checkin_reply_present),
      marker!(:machservices_dict_present),
      marker!(:service_entry_present),
      marker!(:server_receive_right_usable),
      marker!(:subclaim_a_passed),
      marker!(:donor_lookup_called),
      marker!(:client_lookup_success),
      marker!(:client_send_started),
      marker!(:client_send_kr),
      marker!(:server_receive_kr),
      marker!(:port_identity_nonce_received),
      marker!(:subclaim_b_server_receipt),
      marker!(:done)
    ]
  end

  def subclaim_a_markers do
    [
      marker!(:launch_checkin_reply_present),
      marker!(:server_receive_right_usable),
      marker!(:subclaim_a_passed)
    ]
  end

  def subclaim_b_markers do
    [
      marker!(:client_lookup_success),
      marker!(:subclaim_b_client_send),
      marker!(:subclaim_b_server_receipt)
    ]
  end

  def port_identity_markers do
    [
      marker!(:port_identity_nonce_received),
      marker!(:nonce_match),
      marker!(:received_ool_sha)
    ]
  end

  def terminal_marker, do: marker!(:done)
  def success_marker, do: line!(:done)

  def ool_policy do
    %{
      expected_byte_count: @payload_byte_count,
      expected_sha256: @payload_sha256,
      exact_count_required: true,
      exact_sha256_required: true,
      nonce: @nonce
    }
  end

  def invariants do
    %{
      subclaim_a_only_not_accepted: true,
      lookup_non_null_not_sufficient: true,
      port_identity_requires_nonce_receipt: true,
      launchd_handoff_markers_do_not_prove_asl_decode: true,
      donor_lookup_markers_do_not_prove_launchd_handoff: true,
      summary_markers_not_primary_proof: [
        key!(:subclaim_a_passed),
        key!(:subclaim_b_client_send),
        key!(:subclaim_b_server_receipt),
        key!(:done)
      ]
    }
  end

  def negative_control_contracts do
    [
      %{
        id: "missing_machservices_key",
        from: line!(:machservices_dict_present),
        to: ""
      },
      %{
        id: "wrong_service_name",
        from: line!(:server_service_name),
        to: line_with_value!(:server_service_name, "com.example.wrong"),
        global: true
      },
      %{
        id: "checkin_without_usable_port",
        from: line!(:server_receive_right_usable),
        to: line_with_value!(:server_receive_right_usable, "0")
      },
      %{
        id: "lookup_before_checkin",
        from: line!(:donor_lookup_called),
        to: line!(:donor_lookup_called) <> "\n" <> line!(:launch_checkin_called)
      },
      %{
        id: "wrong_receive_right",
        from: line!(:port_identity_nonce_received),
        to: line_with_value!(:port_identity_nonce_received, "0")
      },
      %{
        id: "harness_injected_port",
        from: line!(:donor_lookup_function),
        to: line_with_value!(:donor_lookup_function, "harness_injected")
      },
      %{
        id: "handoff_without_receipt",
        from: line!(:subclaim_b_server_receipt),
        to: ""
      },
      %{
        id: "receipt_without_handoff",
        from: line!(:subclaim_a_passed),
        to: ""
      },
      %{id: "missing_terminal", from: line!(:done), to: ""},
      %{id: "duplicate_terminal", from: line!(:done), to: line!(:done) <> "\n" <> line!(:done)},
      %{id: "wrong_value", from: line!(:done), to: line_with_value!(:done, "10")},
      %{id: "truncated_serial", from: line!(:done), to: "ASL_A2_TRUNCATED=1"}
    ]
  end

  def category_breakdown do
    specs()
    |> Enum.frequencies_by(& &1.role)
    |> Map.new()
  end

  def producer_breakdown do
    specs()
    |> Enum.frequencies_by(& &1.producer)
    |> Map.new()
  end

  defp subclaim_a_specs do
    [
      spec(
        :server_start,
        "ASL_A2_SERVER_START",
        "1",
        :infrastructure,
        :subclaim_a,
        :harness,
        :server_probe
      ),
      spec(
        :server_service_name,
        "ASL_A2_SERVICE_NAME",
        @service_name,
        :infrastructure,
        :subclaim_a,
        :harness,
        :orchestration
      ),
      spec(
        :launch_checkin_called,
        "ASL_A2_LAUNCH_CHECKIN_CALLED",
        "1",
        :launchd_handoff,
        :subclaim_a,
        :harness,
        :launchd_checkin_request
      ),
      spec(
        :launch_checkin_key,
        "ASL_A2_LAUNCH_CHECKIN_KEY",
        "CheckIn",
        :launchd_handoff,
        :subclaim_a,
        :harness,
        :launchd_checkin_request
      ),
      spec(
        :launch_checkin_reply_present,
        "ASL_A2_LAUNCH_CHECKIN_REPLY_PRESENT",
        "1",
        :launchd_handoff,
        :subclaim_a,
        :launchd,
        :checkin_reply
      ),
      spec(
        :machservices_dict_present,
        "ASL_A2_MACHSERVICES_DICT_PRESENT",
        "1",
        :launchd_handoff,
        :subclaim_a,
        :launchd,
        :machservices_dictionary
      ),
      spec(
        :service_entry_present,
        "ASL_A2_SERVICE_ENTRY_PRESENT",
        "1",
        :launchd_handoff,
        :subclaim_a,
        :launchd,
        :machservice_entry
      ),
      spec(
        :server_checkin_receive_port,
        "ASL_A2_SERVER_CHECKIN_RECEIVE_PORT",
        nil,
        :launchd_handoff,
        :subclaim_a,
        :launchd,
        :machservice_receive_right,
        value_policy: :must_be_positive_integer
      ),
      spec(
        :server_receive_right_usable,
        "ASL_A2_SERVER_RECEIVE_RIGHT_USABLE",
        "1",
        :launchd_handoff,
        :subclaim_a,
        :launchd,
        :machservice_receive_right
      ),
      spec(
        :subclaim_a_passed,
        "ASL_A2_SUBCLAIM_A_PASSED",
        "1",
        :summary,
        :subclaim_a,
        :harness,
        :orchestration
      )
    ]
  end

  defp subclaim_b_specs do
    [
      spec(
        :client_start,
        "ASL_A2_CLIENT_START",
        "1",
        :infrastructure,
        :subclaim_b,
        :harness,
        :client_probe
      ),
      spec(
        :client_service_name,
        "ASL_A2_SERVICE_NAME",
        @service_name,
        :infrastructure,
        :subclaim_b,
        :harness,
        :orchestration
      ),
      spec(
        :donor_lookup_function,
        "ASL_A2_DONOR_LOOKUP_FUNCTION",
        "asl_core_get_service_port",
        :donor_lookup,
        :subclaim_b,
        :donor,
        :asl_core_lookup
      ),
      spec(
        :donor_lookup_called,
        "ASL_A2_DONOR_LOOKUP_CALLED",
        "1",
        :donor_lookup,
        :subclaim_b,
        :donor,
        :asl_core_lookup
      ),
      spec(
        :client_lookup_send_right,
        "ASL_A2_CLIENT_LOOKUP_SEND_RIGHT",
        nil,
        :donor_lookup,
        :subclaim_b,
        :donor,
        :asl_core_lookup,
        value_policy: :must_be_positive_integer
      ),
      spec(
        :client_lookup_success,
        "ASL_A2_CLIENT_LOOKUP_SUCCESS",
        "1",
        :donor_lookup,
        :subclaim_b,
        :donor,
        :asl_core_lookup
      ),
      spec(
        :expected_ool_count,
        "ASL_A2_EXPECTED_OOL_BYTE_COUNT",
        @payload_byte_count,
        :ool_integrity,
        :subclaim_b,
        :harness,
        :ool_integrity
      ),
      spec(
        :expected_ool_sha,
        "ASL_A2_EXPECTED_OOL_SHA256",
        @payload_sha256,
        :ool_integrity,
        :subclaim_b,
        :harness,
        :ool_integrity
      ),
      spec(
        :nonce,
        "ASL_A2_NONCE",
        @nonce,
        :port_identity,
        :subclaim_b,
        :harness,
        :port_identity_nonce
      ),
      spec(
        :client_vm_allocate_kr,
        "ASL_A2_CLIENT_VM_ALLOCATE_KR",
        "0",
        :infrastructure,
        :subclaim_b,
        :harness,
        :client_probe
      ),
      spec(
        :client_send_started,
        "ASL_A2_CLIENT_SEND_STARTED",
        "1",
        :infrastructure,
        :subclaim_b,
        :harness,
        :client_probe
      ),
      spec(
        :client_send_kr,
        "ASL_A2_CLIENT_SEND_KR",
        "0",
        :infrastructure,
        :subclaim_b,
        :harness,
        :client_probe
      ),
      spec(
        :subclaim_b_client_send,
        "ASL_A2_SUBCLAIM_B_CLIENT_SEND",
        "1",
        :summary,
        :subclaim_b,
        :harness,
        :client_probe
      ),
      spec(
        :server_receive_kr,
        "ASL_A2_SERVER_RECEIVE_KR",
        "0",
        :infrastructure,
        :subclaim_b,
        :harness,
        :server_probe
      ),
      spec(
        :server_received_msg_id,
        "ASL_A2_SERVER_RECEIVED_MSG_ID",
        @mig_routine_id,
        :infrastructure,
        :subclaim_b,
        :harness,
        :server_probe
      ),
      spec(
        :server_received_complex,
        "ASL_A2_SERVER_RECEIVED_COMPLEX",
        "1",
        :infrastructure,
        :subclaim_b,
        :harness,
        :server_probe
      ),
      spec(
        :server_descriptor_count,
        "ASL_A2_SERVER_DESCRIPTOR_COUNT",
        "1",
        :infrastructure,
        :subclaim_b,
        :harness,
        :server_probe
      ),
      spec(
        :received_ool_count,
        "ASL_A2_RECEIVED_OOL_BYTE_COUNT",
        @payload_byte_count,
        :ool_integrity,
        :subclaim_b,
        :harness,
        :ool_integrity
      ),
      spec(
        :server_requested_audit_trailer,
        "ASL_A2_SERVER_REQUESTED_AUDIT_TRAILER",
        "1",
        :audit_trailer,
        :subclaim_b,
        :harness,
        :server_probe
      ),
      spec(
        :server_audit_trailer_present,
        "ASL_A2_SERVER_AUDIT_TRAILER_PRESENT",
        "1",
        :audit_trailer,
        :subclaim_b,
        :kernel,
        :audit_trailer
      ),
      spec(
        :received_ool_sha,
        "ASL_A2_RECEIVED_OOL_SHA256",
        @payload_sha256,
        :ool_integrity,
        :subclaim_b,
        :harness,
        :ool_integrity
      ),
      spec(
        :nonce_match,
        "ASL_A2_NONCE_MATCH",
        "1",
        :port_identity,
        :subclaim_b,
        :harness,
        :port_identity_nonce
      ),
      spec(
        :port_identity_nonce_received,
        "ASL_A2_PORT_IDENTITY_NONCE_RECEIVED",
        "1",
        :port_identity,
        :subclaim_b,
        :harness,
        :server_probe
      ),
      spec(
        :subclaim_b_server_receipt,
        "ASL_A2_SUBCLAIM_B_SERVER_RECEIPT",
        "1",
        :summary,
        :subclaim_b,
        :harness,
        :server_probe
      )
    ]
  end

  defp terminal_specs do
    [
      spec(:done, "ASL_A2_DONE", "1", :terminal, :terminal, :harness, :orchestration)
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
          role in [:launchd_handoff, :donor_lookup, :port_identity, :ool_integrity]
        ),
      anchor: Keyword.get(opts, :anchor, key),
      emission_anchors: Keyword.get(opts, :emission_anchors, emission_anchors_for(id, key, value))
    }
  end

  defp emission_anchors_for(:server_service_name, key, _value),
    do: [
      ~s|#define ASL_A2_SERVICE_NAME "#{@service_name}"|,
      ~s|emit_kv("#{key}", ASL_A2_SERVICE_NAME)|
    ]

  defp emission_anchors_for(:client_service_name, key, _value),
    do: [
      ~s|#define ASL_A2_SERVICE_NAME "#{@service_name}"|,
      ~s|emit_kv("#{key}", ASL_A2_SERVICE_NAME)|
    ]

  defp emission_anchors_for(:launch_checkin_key, key, _value),
    do: [~s|#define LAUNCH_KEY_CHECKIN "CheckIn"|, ~s|emit_kv("#{key}", LAUNCH_KEY_CHECKIN)|]

  defp emission_anchors_for(:launch_checkin_reply_present, key, _value),
    do: [~s|emit_kv("#{key}", reply != NULL ? "1" : "0")|]

  defp emission_anchors_for(:machservices_dict_present, key, _value),
    do: [~s|emit_kv("#{key}", machservices != NULL ? "1" : "0")|]

  defp emission_anchors_for(:service_entry_present, key, _value),
    do: [~s|emit_kv("#{key}", service != NULL ? "1" : "0")|]

  defp emission_anchors_for(:server_checkin_receive_port, key, _value),
    do: [~s|emit_u32("#{key}", receive_port)|]

  defp emission_anchors_for(:server_receive_right_usable, key, _value),
    do: [~s|emit_kv("#{key}",|, ~s|receive_port != MACH_PORT_NULL ? "1" : "0"|]

  defp emission_anchors_for(:client_lookup_send_right, key, _value),
    do: [~s|emit_u32("#{key}", service_port)|]

  defp emission_anchors_for(:client_lookup_success, key, _value),
    do: [~s|emit_kv("#{key}",|, ~s|service_port != MACH_PORT_NULL ? "1" : "0"|]

  defp emission_anchors_for(:expected_ool_count, key, _value),
    do: [
      ~s|ool_len = (mach_msg_type_number_t)sizeof(ASL_A2_PAYLOAD);|,
      ~s|emit_u32("#{key}", ool_len)|
    ]

  defp emission_anchors_for(:expected_ool_sha, key, _value),
    do: [~s|emit_sha256("#{key}", ASL_A2_PAYLOAD, ool_len)|]

  defp emission_anchors_for(:nonce, key, _value),
    do: [~s|#define ASL_A2_NONCE "#{@nonce}"|, ~s|emit_kv("#{key}", ASL_A2_NONCE)|]

  defp emission_anchors_for(id, key, _value)
       when id in [:client_vm_allocate_kr, :client_send_kr],
       do: [~s|emit_i32("#{key}", kr)|]

  defp emission_anchors_for(:subclaim_b_client_send, key, _value),
    do: [~s|emit_kv("#{key}", kr == KERN_SUCCESS ? "1" : "0")|]

  defp emission_anchors_for(:server_receive_kr, key, _value),
    do: [~s|emit_i32("#{key}", kr)|]

  defp emission_anchors_for(:server_received_msg_id, key, _value),
    do: [~s|emit_u32("#{key}", (uint32_t)message.request.Head.msgh_id)|]

  defp emission_anchors_for(:server_received_complex, key, _value),
    do: [~s|emit_kv("#{key}",|, "message.request.Head.msgh_bits & MACH_MSGH_BITS_COMPLEX"]

  defp emission_anchors_for(:server_descriptor_count, key, _value),
    do: [~s|emit_u32("#{key}",|, "message.request.msgh_body.msgh_descriptor_count"]

  defp emission_anchors_for(:received_ool_count, key, _value),
    do: [~s|emit_u32("#{key}", message.request.message.size)|]

  defp emission_anchors_for(:server_audit_trailer_present, key, _value),
    do: [~s|emit_kv("#{key}",|, "trailer != NULL && trailer->msgh_trailer_size"]

  defp emission_anchors_for(:received_ool_sha, key, _value),
    do: [~s|emit_sha256("#{key}", payload, payload_size)|]

  defp emission_anchors_for(:nonce_match, key, _value),
    do: [
      ~s|emit_kv("#{key}",|,
      "payload_size == sizeof(ASL_A2_PAYLOAD)",
      "memcmp(payload, ASL_A2_PAYLOAD"
    ]

  defp emission_anchors_for(:done, key, _value),
    do: [~s|emit_kv("#{key}", rc == 0 ? "1" : "0")|]

  defp emission_anchors_for(_id, key, value) when is_binary(value),
    do: [~s|emit_kv("#{key}", "#{value}")|]

  defp emission_anchors_for(_id, key, _value), do: [key]
end
