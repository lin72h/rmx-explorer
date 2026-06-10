defmodule RmxOSOracle.Migration.NotifydN1NotificationCenter do
  @moduledoc false

  alias RmxOSOracle.CanonicalJSON
  alias RmxOSOracle.Notifyd.N1.{ContractCheck, MarkerManifest}

  @schema_prefix "rmxos_oracle.notifyd_n1"

  @hard_stop_patterns [
    ~r/panic/i,
    ~r/Fatal trap/i,
    ~r/KASSERT/i,
    ~r/WITNESS:|WITNESS.*lock order|lock order reversal/i,
    ~r/SIGSYS/i,
    ~r/Bad system call/i,
    ~r/UNKNOWN FreeBSD SYSCALL/i,
    ~r/nosys [0-9]+/i,
    ~r/Enter full pathname of shell/i,
    ~r/Consoles:\s+Dual \(Video primary\)/i
  ]

  def validate_serial(serial, opts \\ []) when is_binary(serial) do
    run_guest_rc = Keyword.get(opts, :run_guest_rc)
    parsed = parse_serial(serial)
    field_record_errors = field_record_errors(parsed)
    order_errors = order_errors(parsed)
    indirect_errors = indirect_attestation_errors(serial)
    terminal_errors = terminal_errors(parsed, serial, run_guest_rc)
    hard_stops = hard_stop_matches(serial)

    errors =
      field_record_errors ++
        order_errors ++
        indirect_errors ++
        terminal_errors ++ Enum.map(hard_stops, &"hard stop matched #{&1["match"]}")

    %{
      "schema" => @schema_prefix <> ".marker_validation.v1",
      "passed" => errors == [],
      "errors" => errors,
      "ordered_marker_count" => length(MarkerManifest.required_order()),
      "field_record_count" => length(MarkerManifest.specs()),
      "indirect_handoff_attestation" => indirect_attestation_report(serial),
      "terminal_contract" => terminal_report(parsed, serial, run_guest_rc),
      "hard_stop_matches" => hard_stops
    }
  end

  def marker_coverage(serial) when is_binary(serial) do
    parsed = parse_serial(serial)

    serial_keys =
      parsed
      |> Enum.map(& &1.key)
      |> MapSet.new()

    authority_keys = MapSet.new(MarkerManifest.marker_keys())

    unmapped_serial_keys =
      serial_keys
      |> MapSet.difference(authority_keys)
      |> MapSet.to_list()
      |> Enum.sort()

    missing_authority_keys =
      authority_keys
      |> MapSet.difference(serial_keys)
      |> MapSet.to_list()
      |> Enum.sort()

    missing_specs =
      MarkerManifest.specs()
      |> Enum.reject(&find_record(parsed, &1))
      |> Enum.map(&Atom.to_string(&1.id))

    %{
      "schema" => @schema_prefix <> ".marker_coverage.v1",
      "passed" =>
        unmapped_serial_keys == [] and missing_authority_keys == [] and missing_specs == [],
      "serial_sha256" => sha256(serial),
      "authority_spec_count" => length(MarkerManifest.specs()),
      "authority_key_count" => MapSet.size(authority_keys),
      "unmapped_serial_keys" => unmapped_serial_keys,
      "authority_keys_missing_from_serial" => missing_authority_keys,
      "authority_specs_missing_from_serial" => missing_specs,
      "role_breakdown" => stringify_keys(MarkerManifest.role_breakdown()),
      "producer_breakdown" => stringify_keys(MarkerManifest.producer_breakdown())
    }
  end

  def hard_stop_scan(serial) when is_binary(serial) do
    matches = hard_stop_matches(serial)

    %{
      "schema" => @schema_prefix <> ".hard_stop_scan.v1",
      "passed" => matches == [],
      "normal_witness_boot_banner_allowed" => true,
      "patterns" => Enum.map(@hard_stop_patterns, &Regex.source/1),
      "matches" => matches
    }
  end

  def negative_controls(serial, run_guest_rc \\ "1") when is_binary(serial) do
    controls =
      MarkerManifest.negative_control_contracts()
      |> Enum.map(&run_control(serial, run_guest_rc, &1))

    %{
      "schema" => @schema_prefix <> ".negative_controls.v1",
      "passed" => Enum.all?(controls, & &1["passed"]),
      "controls" => controls,
      "limitations" => [
        "negative controls mutate serial evidence and run-guest rc to prove validator red paths",
        "negative controls do not add guest runtime behavior"
      ]
    }
  end

  def post_run_revalidation(evidence_dir \\ MarkerManifest.accepted_evidence_dir()) do
    serial = read_evidence!(evidence_dir, "serial.log")
    rc = read_evidence!(evidence_dir, "run-guest.rc") |> String.trim()
    validation = validate_serial(serial, run_guest_rc: rc)
    hard_stop = hard_stop_scan(serial)
    coverage = marker_coverage(serial)
    negatives = negative_controls(serial, rc)
    raw_digest = raw_evidence_tree_digest(evidence_dir)

    passed =
      sha256(serial) == MarkerManifest.accepted_serial_sha256() and
        raw_digest == MarkerManifest.raw_evidence_tree_digest() and
        validation["passed"] and hard_stop["passed"] and coverage["passed"] and
        negatives["passed"]

    %{
      "schema" => @schema_prefix <> ".post_run_revalidation.v1",
      "passed" => passed,
      "accepted_claim" => if(passed, do: MarkerManifest.accepted_claim(), else: "not_accepted"),
      "accepted_evidence_path" => MarkerManifest.accepted_evidence_dir(),
      "accepted_source_pin" => MarkerManifest.accepted_source_pin(),
      "runtime_scaffold_pin" => MarkerManifest.runtime_scaffold_pin(),
      "source_closeout_pin" => MarkerManifest.source_closeout_pin(),
      "serial_sha256" => sha256(serial),
      "expected_serial_sha256" => MarkerManifest.accepted_serial_sha256(),
      "raw_evidence_tree_digest" => raw_digest,
      "expected_raw_evidence_tree_digest" => MarkerManifest.raw_evidence_tree_digest(),
      "raw_evidence_mutated" => false,
      "runtime_binary_kernel_image_hashes_captured" => false,
      "provenance_limitations" => MarkerManifest.closeout().provenance_limitations,
      "marker_validation_passed" => validation["passed"],
      "hard_stop_scan_passed" => hard_stop["passed"],
      "marker_coverage_passed" => coverage["passed"],
      "negative_controls_passed" => negatives["passed"],
      "rc_normalization" => MarkerManifest.terminal_contract().run_guest_rc_normalization,
      "direct_launchd_or_kernel_facts_absent" => true
    }
  end

  def write_revalidation_artifacts!(evidence_dir \\ MarkerManifest.accepted_evidence_dir()) do
    serial = read_evidence!(evidence_dir, "serial.log")
    rc = read_evidence!(evidence_dir, "run-guest.rc") |> String.trim()

    artifacts = %{
      "hard_stop_scan.json" => hard_stop_scan(serial),
      "marker_coverage.json" => marker_coverage(serial),
      "negative_controls.json" => negative_controls(serial, rc)
    }

    Enum.each(artifacts, fn {name, data} ->
      CanonicalJSON.write!(Path.join(evidence_dir, name), data)
    end)

    post = post_run_revalidation(evidence_dir)
    CanonicalJSON.write!(Path.join(evidence_dir, "post_run_revalidation.json"), post)

    Map.put(artifacts, "post_run_revalidation.json", post)
  end

  def raw_evidence_tree_digest(evidence_dir \\ MarkerManifest.accepted_evidence_dir()) do
    evidence_dir
    |> raw_evidence_manifest()
    |> digest_manifest()
  end

  def full_evidence_tree_digest(evidence_dir \\ MarkerManifest.accepted_evidence_dir()) do
    evidence_dir
    |> all_file_manifest()
    |> digest_manifest()
  end

  def raw_evidence_manifest(evidence_dir) do
    Enum.map(MarkerManifest.raw_evidence_files(), fn name ->
      file_manifest_entry(evidence_dir, name)
    end)
  end

  def all_file_manifest(evidence_dir) do
    evidence_dir
    |> Path.join("*")
    |> Path.wildcard()
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(fn path ->
      file_manifest_entry(evidence_dir, Path.basename(path))
    end)
    |> Enum.sort_by(& &1["path"])
  end

  def static_authority_contract_checks(repo_root \\ File.cwd!()) do
    ContractCheck.run(repo_root)
  end

  def a2_n1_comparison_finding do
    %{
      schema: "rmxos_oracle.finding.notifyd_n1_asl_a2_comparison.v1",
      authority: "non_authoritative_data_only",
      notifyd_n1: %{
        accepted_evidence_path: MarkerManifest.accepted_evidence_dir(),
        accepted_claim: MarkerManifest.accepted_claim(),
        shared_candidates: [
          "donor-bootstrap fixture witness",
          "service-name lookup",
          "donor client lookup success"
        ]
      },
      asl_a2: %{
        relation: "prior accepted ASL handoff evidence",
        note: "A2 direct launchd and kernel facts are not promoted into N1"
      },
      gaps: [
        "N1 has no direct notifyd launchd check-in dictionary marker",
        "N1 has no direct notifyd launchd receive-right marker",
        "N1 has no kernel audit fact"
      ],
      conclusion:
        "N1 and A2 share candidate handoff vocabulary, but N1 authority is notify-specific and indirect for launchd handoff."
    }
  end

  def parse_serial(serial) do
    serial
    |> normalize_lines()
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_no} ->
      case parse_marker_line(line) do
        nil -> []
        record -> [%{record | line: line, line_no: line_no}]
      end
    end)
  end

  defp field_record_errors(parsed) do
    MarkerManifest.specs()
    |> Enum.flat_map(fn spec ->
      case find_record(parsed, spec) do
        nil ->
          case Enum.find(parsed, &(&1.key == spec.key)) do
            nil -> ["missing field record #{spec.id}"]
            record -> field_errors(spec, record)
          end

        record ->
          field_errors(spec, record)
      end
    end)
  end

  defp field_errors(spec, record) do
    spec.fields
    |> Enum.flat_map(fn {field, policy} ->
      actual = record.fields[field]

      cond do
        is_nil(actual) ->
          ["missing field #{spec.id}.#{field}"]

        policy.policy == :must_equal and actual != policy.value ->
          ["wrong field #{spec.id}.#{field}: expected #{policy.value}, got #{actual}"]

        policy.policy == :must_be_positive_integer and not positive_integer?(actual) ->
          ["wrong field #{spec.id}.#{field}: expected positive integer, got #{actual}"]

        true ->
          []
      end
    end)
  end

  defp order_errors(parsed) do
    {_offset, errors} =
      Enum.reduce(MarkerManifest.ordered_specs(), {0, []}, fn spec, {offset, errors} ->
        case find_record_after(parsed, spec, offset) do
          nil -> {offset, errors ++ ["order violation missing #{spec.id} after line #{offset}"]}
          record -> {record.line_no, errors}
        end
      end)

    errors
  end

  defp indirect_attestation_errors(serial) do
    MarkerManifest.indirect_attestation_lines()
    |> Enum.reject(&String.contains?(serial, &1))
    |> Enum.map(&"missing indirect handoff attestation #{&1}")
  end

  defp terminal_errors(parsed, serial, run_guest_rc) do
    terminal_count = Enum.count(parsed, &matches_spec?(&1, MarkerManifest.spec!(:terminal)))
    harness_end? = String.contains?(serial, MarkerManifest.terminal_contract().harness_end_marker)

    []
    |> append_if(terminal_count == 0, "missing field record terminal")
    |> append_if(terminal_count > 1, "duplicate terminal")
    |> append_if(not harness_end?, "missing launchd harness end rc=0 marker")
    |> append_if(
      run_guest_rc == "1" and not (terminal_count == 1 and harness_end?),
      "rc normalization failed for run-guest.rc=1"
    )
    |> append_if(
      is_binary(run_guest_rc) and run_guest_rc not in ["0", "1"],
      "unexpected run-guest.rc=#{run_guest_rc}"
    )
  end

  defp terminal_report(parsed, serial, run_guest_rc) do
    terminal_count = Enum.count(parsed, &matches_spec?(&1, MarkerManifest.spec!(:terminal)))
    harness_end? = String.contains?(serial, MarkerManifest.terminal_contract().harness_end_marker)

    %{
      "run_guest_rc" => run_guest_rc,
      "terminal_count" => terminal_count,
      "harness_end_rc0" => harness_end?,
      "run_guest_rc_accepted" =>
        run_guest_rc in [nil, "0"] or
          (run_guest_rc == "1" and terminal_count == 1 and harness_end?)
    }
  end

  defp indirect_attestation_report(serial) do
    Map.new(MarkerManifest.indirect_attestation_lines(), fn line ->
      {line, String.contains?(serial, line)}
    end)
  end

  defp hard_stop_matches(serial) do
    serial
    |> normalize_lines()
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_no} ->
      Enum.flat_map(@hard_stop_patterns, fn pattern ->
        if Regex.match?(pattern, line) do
          [%{"line" => line_no, "match" => line, "pattern" => Regex.source(pattern)}]
        else
          []
        end
      end)
    end)
  end

  defp run_control(serial, rc, %{id: id, expected_error: expected} = contract) do
    {mutated_serial, mutated_rc} = mutate_control(serial, rc, id)
    result = validate_serial(mutated_serial, run_guest_rc: mutated_rc)

    %{
      "id" => id,
      "class" => Atom.to_string(contract.class),
      "passed" =>
        not result["passed"] and Enum.any?(result["errors"], &String.contains?(&1, expected)),
      "expected_error" => expected,
      "errors" => result["errors"]
    }
  end

  defp mutate_control(serial, rc, "missing_terminal") do
    {remove_first_matching_line(serial, :terminal), rc}
  end

  defp mutate_control(serial, rc, "duplicate_terminal") do
    {duplicate_first_matching_line(serial, :terminal), rc}
  end

  defp mutate_control(serial, rc, "invalid_order") do
    {move_matching_line_before(serial, :poster_post_user_before, :baseline_consumed), rc}
  end

  defp mutate_control(serial, rc, "missing_server_post_entry") do
    {remove_first_matching_line(serial, :server_post_entry), rc}
  end

  defp mutate_control(serial, rc, "server_post_return_wrong_status") do
    {replace_first_matching_line(
       serial,
       :server_post_return,
       &String.replace(&1, "status=0", "status=10")
     ), rc}
  end

  defp mutate_control(serial, rc, "wrong_service_name") do
    {String.replace(serial, MarkerManifest.service_name(), "com.example.notification_center"), rc}
  end

  defp mutate_control(serial, rc, "fresh_observation_missing") do
    {remove_first_matching_line(serial, :fresh_observation), rc}
  end

  defp mutate_control(serial, rc, "token_pairing_drift") do
    {replace_first_matching_line(
       serial,
       :shared_memory_observation,
       &String.replace(&1, "token=0", "token=2")
     ), rc}
  end

  defp mutate_control(serial, _rc, "rc_one_without_terminal") do
    {remove_first_matching_line(serial, :terminal), "1"}
  end

  defp mutate_control(serial, _rc, "rc_one_without_harness_end") do
    {String.replace(serial, MarkerManifest.terminal_contract().harness_end_marker, ""), "1"}
  end

  defp remove_first_matching_line(serial, spec_id) do
    {_removed?, lines} =
      serial
      |> split_preserving_trailing_newline()
      |> Enum.reduce({false, []}, fn line, {removed?, acc} ->
        if not removed? and line_matches_spec?(line, spec_id) do
          {true, acc}
        else
          {removed?, [line | acc]}
        end
      end)

    lines |> Enum.reverse() |> Enum.join("\n")
  end

  defp duplicate_first_matching_line(serial, spec_id) do
    {_duplicated?, lines} =
      serial
      |> split_preserving_trailing_newline()
      |> Enum.reduce({false, []}, fn line, {duplicated?, acc} ->
        if not duplicated? and line_matches_spec?(line, spec_id) do
          {true, [line, line | acc]}
        else
          {duplicated?, [line | acc]}
        end
      end)

    lines |> Enum.reverse() |> Enum.join("\n")
  end

  defp replace_first_matching_line(serial, spec_id, fun) do
    {_replaced?, lines} =
      serial
      |> split_preserving_trailing_newline()
      |> Enum.reduce({false, []}, fn line, {replaced?, acc} ->
        if not replaced? and line_matches_spec?(line, spec_id) do
          {true, [fun.(line) | acc]}
        else
          {replaced?, [line | acc]}
        end
      end)

    lines |> Enum.reverse() |> Enum.join("\n")
  end

  defp move_matching_line_before(serial, moving_spec_id, target_spec_id) do
    lines = split_preserving_trailing_newline(serial)
    {moving_lines, remaining} = Enum.split_with(lines, &line_matches_spec?(&1, moving_spec_id))
    moving_line = List.first(moving_lines)

    if moving_line do
      {_inserted?, result} =
        Enum.reduce(remaining, {false, []}, fn line, {inserted?, acc} ->
          if not inserted? and line_matches_spec?(line, target_spec_id) do
            {true, [line, moving_line | acc]}
          else
            {inserted?, [line | acc]}
          end
        end)

      result |> Enum.reverse() |> Enum.join("\n")
    else
      serial
    end
  end

  defp line_matches_spec?(line, spec_id) do
    case parse_marker_line(line) do
      nil -> false
      record -> matches_spec?(record, MarkerManifest.spec!(spec_id))
    end
  end

  defp split_preserving_trailing_newline(serial) do
    serial
    |> String.replace("\r\n", "\n")
    |> String.replace("\r", "\n")
    |> String.split("\n", trim: true)
  end

  defp find_record(parsed, spec), do: Enum.find(parsed, &matches_spec?(&1, spec))

  defp find_record_after(parsed, spec, offset) do
    Enum.find(parsed, fn record -> record.line_no > offset and matches_spec?(record, spec) end)
  end

  defp matches_spec?(record, spec) do
    record.key == spec.key and
      Enum.all?(spec.fields, fn {field, policy} ->
        actual = record.fields[field]

        case policy.policy do
          :must_equal -> actual == policy.value
          :must_be_positive_integer -> positive_integer?(actual)
        end
      end)
  end

  defp parse_marker_line(line) do
    if String.starts_with?(line, "NOTIFYD_N1_") do
      [key | fields] = String.split(line, " ")

      %{
        key: key,
        fields:
          fields
          |> Enum.map(&String.split(&1, "=", parts: 2))
          |> Enum.filter(&(length(&1) == 2))
          |> Map.new(fn [field, value] -> {field, value} end),
        line: nil,
        line_no: nil
      }
    end
  end

  defp normalize_lines(serial) do
    serial
    |> String.replace("\r\n", "\n")
    |> String.replace("\r", "\n")
    |> String.split("\n", trim: true)
  end

  defp read_evidence!(evidence_dir, filename),
    do: evidence_dir |> Path.join(filename) |> File.read!()

  defp file_manifest_entry(evidence_dir, name) do
    path = Path.join(evidence_dir, name)
    bytes = File.read!(path)

    %{
      "path" => name,
      "size" => byte_size(bytes),
      "sha256" => sha256(bytes)
    }
  end

  defp digest_manifest(entries) do
    input =
      entries
      |> Enum.sort_by(& &1["path"])
      |> Enum.map_join("\n", fn entry ->
        "#{entry["path"]}\t#{entry["size"]}\t#{entry["sha256"]}"
      end)
      |> Kernel.<>("\n")

    sha256(input)
  end

  defp positive_integer?(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int > 0
      _ -> false
    end
  end

  defp positive_integer?(_), do: false

  defp append_if(errors, true, error), do: errors ++ [error]
  defp append_if(errors, false, _error), do: errors

  defp stringify_keys(map) do
    Map.new(map, fn {key, value} -> {Atom.to_string(key), value} end)
  end

  defp sha256(data), do: :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
end
