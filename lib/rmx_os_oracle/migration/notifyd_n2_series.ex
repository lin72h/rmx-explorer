defmodule RmxOSOracle.Migration.NotifydN2Series do
  @moduledoc false

  alias RmxOSOracle.Notifyd.N2.{ContractCheck, MarkerManifest}

  @schema_prefix "rmxos_oracle.notifyd_n2_series"

  def validate_serial(family, serial, opts \\ [])
      when family in [
             :mach_send,
             :mach_raw,
             :mach_direct,
             :dispatch_notify_trace_timeout,
             :concurrency
           ] and
             is_binary(serial) do
    run_guest_rc = Keyword.get(opts, :run_guest_rc)
    parsed = parse_serial(serial)

    errors =
      field_record_errors(family, parsed) ++
        exact_line_errors(family, serial) ++
        order_errors(family, parsed, serial) ++
        terminal_errors(family, parsed, serial, run_guest_rc) ++
        Enum.map(hard_stop_matches(serial), &"hard stop matched #{&1["match"]}")

    %{
      "schema" => @schema_prefix <> ".marker_validation.v1",
      "family" => Atom.to_string(family),
      "passed" => errors == [],
      "errors" => errors,
      "ordered_marker_count" => ordered_marker_count(family),
      "field_record_count" => length(MarkerManifest.specs(family)),
      "terminal_contract" => terminal_report(family, parsed, serial, run_guest_rc),
      "hard_stop_matches" => hard_stop_matches(serial)
    }
  end

  def marker_coverage(family, serial) when is_binary(serial) do
    parsed = parse_serial(serial)

    serial_keys =
      parsed
      |> Enum.map(& &1.key)
      |> MapSet.new()

    authority_keys =
      family
      |> MarkerManifest.specs()
      |> Enum.map(& &1.key)
      |> MapSet.new()

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
      family
      |> MarkerManifest.specs()
      |> Enum.reject(&find_record(parsed, &1))
      |> Enum.map(&Atom.to_string(&1.id))

    %{
      "schema" => @schema_prefix <> ".marker_coverage.v1",
      "family" => Atom.to_string(family),
      "passed" =>
        unmapped_serial_keys == [] and missing_authority_keys == [] and missing_specs == [],
      "serial_sha256" => sha256(serial),
      "authority_spec_count" => length(MarkerManifest.specs(family)),
      "unmapped_serial_keys" => unmapped_serial_keys,
      "authority_keys_missing_from_serial" => missing_authority_keys,
      "authority_specs_missing_from_serial" => missing_specs
    }
  end

  def hard_stop_scan(serial) when is_binary(serial) do
    matches = hard_stop_matches(serial)

    %{
      "schema" => @schema_prefix <> ".hard_stop_scan.v1",
      "passed" => matches == [],
      "normal_witness_boot_banner_allowed" => true,
      "patterns" => Enum.map(MarkerManifest.hard_stop_patterns(), &Regex.source/1),
      "matches" => matches
    }
  end

  def negative_controls(family, serial, run_guest_rc \\ "1") when is_binary(serial) do
    controls =
      MarkerManifest.negative_control_contracts()
      |> Enum.map(&run_control(family, serial, run_guest_rc, &1))

    %{
      "schema" => @schema_prefix <> ".negative_controls.v1",
      "family" => Atom.to_string(family),
      "passed" => Enum.all?(controls, & &1["passed"]),
      "controls" => controls
    }
  end

  def revalidate_accepted_family(family, repo_root \\ File.cwd!()) do
    evidence = MarkerManifest.evidence(family)
    serial = evidence.path |> Path.expand(repo_root) |> File.read!()
    rc = Map.get(evidence, :raw_run_guest_rc, "1")
    validation = validate_serial(family, serial, run_guest_rc: rc)
    hard_stop = hard_stop_scan(serial)
    coverage = marker_coverage(family, serial)
    negatives = negative_controls(family, serial, rc)
    serial_sha = sha256(serial)

    %{
      "schema" => @schema_prefix <> ".post_run_revalidation.v1",
      "family" => Atom.to_string(family),
      "passed" =>
        serial_sha == evidence.serial_sha256 and validation["passed"] and hard_stop["passed"] and
          coverage["passed"] and negatives["passed"],
      "accepted_claim" => accepted_claim(family),
      "serial_sha256" => serial_sha,
      "expected_serial_sha256" => evidence.serial_sha256,
      "marker_validation_passed" => validation["passed"],
      "hard_stop_scan_passed" => hard_stop["passed"],
      "marker_coverage_passed" => coverage["passed"],
      "negative_controls_passed" => negatives["passed"],
      "raw_evidence_mutated" => false
    }
  end

  def static_authority_contract_checks(repo_root \\ File.cwd!()), do: ContractCheck.run(repo_root)

  def parse_serial(serial) do
    keys = MapSet.new(MarkerManifest.marker_keys())

    serial
    |> normalize_lines()
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_no} ->
      case parse_marker_line(line, keys) do
        nil -> []
        record -> [%{record | line: line, line_no: line_no}]
      end
    end)
  end

  defp field_record_errors(family, parsed) do
    family
    |> MarkerManifest.specs()
    |> Enum.flat_map(fn spec ->
      matching = Enum.filter(parsed, &matches_spec?(&1, spec))
      expected_count = Map.get(spec, :count, 1)
      count_policy = Map.get(spec, :count_policy, :exact)

      cond do
        count_policy == :exact and length(matching) == expected_count ->
          []

        count_policy == :minimum and length(matching) >= expected_count ->
          []

        count_policy == :exact and length(matching) > expected_count ->
          ["duplicate field record #{spec.id}"]

        length(matching) > 0 and length(matching) < expected_count ->
          ["missing field record #{spec.id}"]

        true ->
          same_key = Enum.find(parsed, &(&1.key == spec.key))

          if same_key do
            field_errors(spec, same_key)
          else
            ["missing field record #{spec.id}"]
          end
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

        not policy_matches?(actual, policy) ->
          ["wrong field #{spec.id}.#{field}: expected #{format_policy(policy)}, got #{actual}"]

        true ->
          []
      end
    end)
  end

  defp exact_line_errors(family, serial) do
    lines = normalize_lines(serial)

    family
    |> MarkerManifest.required_lines()
    |> Enum.flat_map(fn spec ->
      count = Enum.count(lines, &(&1 == spec.line))

      cond do
        count == 1 -> []
        count == 0 -> ["missing exact line #{spec.id}"]
        true -> ["duplicate exact line #{spec.id}"]
      end
    end)
  end

  defp order_errors(family, parsed, serial) do
    ordered =
      (MarkerManifest.required_lines(family) ++ MarkerManifest.ordered_specs(family))
      |> Enum.sort_by(& &1.order)

    lines = normalize_lines(serial) |> Enum.with_index(1)

    {_offset, errors} =
      Enum.reduce(ordered, {0, []}, fn spec, {offset, errors} ->
        case find_after(spec, parsed, lines, offset) do
          nil -> {offset, errors ++ ["order violation missing #{spec.id} after line #{offset}"]}
          line_no -> {line_no, errors}
        end
      end)

    errors
  end

  defp terminal_errors(family, parsed, serial, run_guest_rc) do
    terminal = MarkerManifest.terminal_contract(family).terminal_spec
    terminal_count = Enum.count(parsed, &matches_spec?(&1, terminal))
    phase_exit_line = MarkerManifest.terminal_contract(family).phase_exit_line
    phase_exit_count = Enum.count(normalize_lines(serial), &(&1 == phase_exit_line))

    []
    |> append_if(terminal_count == 0, "missing terminal")
    |> append_if(terminal_count > 1, "duplicate terminal")
    |> append_if(phase_exit_count == 0, "missing phase07 exit marker")
    |> append_if(phase_exit_count > 1, "duplicate phase07 exit marker")
    |> append_if(
      run_guest_rc == "1" and not (terminal_count == 1 and phase_exit_count == 1),
      "rc normalization failed for run-guest.rc=1"
    )
    |> append_if(
      is_binary(run_guest_rc) and run_guest_rc not in ["0", "1"],
      "unexpected run-guest.rc=#{run_guest_rc}"
    )
  end

  defp terminal_report(family, parsed, serial, run_guest_rc) do
    terminal = MarkerManifest.terminal_contract(family).terminal_spec
    terminal_count = Enum.count(parsed, &matches_spec?(&1, terminal))
    phase_exit_line = MarkerManifest.terminal_contract(family).phase_exit_line
    phase_exit_count = Enum.count(normalize_lines(serial), &(&1 == phase_exit_line))

    %{
      "run_guest_rc" => run_guest_rc,
      "terminal_count" => terminal_count,
      "phase_exit_count" => phase_exit_count,
      "run_guest_rc_accepted" =>
        run_guest_rc in [nil, "0"] or
          (run_guest_rc == "1" and terminal_count == 1 and phase_exit_count == 1)
    }
  end

  defp hard_stop_matches(serial) do
    serial
    |> normalize_lines()
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_no} ->
      Enum.flat_map(MarkerManifest.hard_stop_patterns(), fn pattern ->
        if Regex.match?(pattern, line) do
          [%{"line" => line_no, "match" => line, "pattern" => Regex.source(pattern)}]
        else
          []
        end
      end)
    end)
  end

  defp run_control(family, serial, rc, %{id: id, expected_error: expected} = contract) do
    {mutated_serial, mutated_rc} = mutate_control(family, serial, rc, id)
    result = validate_serial(family, mutated_serial, run_guest_rc: mutated_rc)

    %{
      "id" => id,
      "class" => Atom.to_string(contract.class),
      "passed" =>
        not result["passed"] and Enum.any?(result["errors"], &String.contains?(&1, expected)),
      "expected_error" => expected,
      "errors" => result["errors"]
    }
  end

  defp mutate_control(family, serial, rc, "missing_terminal"),
    do: {remove_first_matching_line(serial, terminal_id(family)), rc}

  defp mutate_control(family, serial, rc, "duplicate_terminal"),
    do: {duplicate_first_matching_line(serial, terminal_id(family)), rc}

  defp mutate_control(family, serial, rc, "invalid_order"),
    do: {move_matching_line_before(serial, receipt_id(family), start_id(family)), rc}

  defp mutate_control(family, serial, rc, "wrong_value"),
    do:
      {replace_first_matching_line(
         serial,
         terminal_id(family),
         &String.replace(&1, "status=0", "status=10")
       ), rc}

  defp mutate_control(family, serial, rc, "missing_receipt"),
    do: {remove_first_matching_line(serial, receipt_id(family)), rc}

  defp mutate_control(family, serial, _rc, "rc_one_without_terminal"),
    do: {remove_first_matching_line(serial, terminal_id(family)), "1"}

  defp mutate_control(_family, serial, rc, "hard_stop"), do: {serial <> "\nKASSERT(fake)\n", rc}

  defp terminal_id(:mach_send), do: :mach_send_terminal
  defp terminal_id(:mach_raw), do: :mach_raw_terminal
  defp terminal_id(:mach_direct), do: :mach_direct_terminal
  defp terminal_id(:dispatch_notify_trace_timeout), do: :trace_terminal
  defp terminal_id(:concurrency), do: :concurrency_terminal

  defp receipt_id(:mach_send), do: :mach_send_dead_event
  defp receipt_id(:mach_raw), do: :mach_raw_notification_receive
  defp receipt_id(:mach_direct), do: :mach_direct_kevent_receive
  defp receipt_id(:dispatch_notify_trace_timeout), do: :trace_private_merge_find_zero
  defp receipt_id(:concurrency), do: :concurrency_mach_send_source_create

  defp start_id(:mach_send), do: :mach_send_start
  defp start_id(:mach_raw), do: :mach_raw_start
  defp start_id(:mach_direct), do: :mach_direct_start
  defp start_id(:dispatch_notify_trace_timeout), do: :trace_start
  defp start_id(:concurrency), do: :concurrency_start

  defp remove_first_matching_line(serial, spec_id) do
    {_removed?, lines} =
      serial
      |> split_lines()
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
      |> split_lines()
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
      |> split_lines()
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
    lines = split_lines(serial)
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
    spec = MarkerManifest.spec!(spec_id)
    keys = MapSet.new(MarkerManifest.marker_keys())

    case parse_marker_line(normalize_line(line), keys) do
      nil -> false
      record -> matches_spec?(record, spec)
    end
  end

  defp find_record(parsed, spec), do: Enum.find(parsed, &matches_spec?(&1, spec))

  defp find_after(%{kind: :exact_line} = spec, _parsed, lines, offset) do
    Enum.find_value(lines, fn {line, line_no} ->
      if line_no > offset and line == spec.line, do: line_no
    end)
  end

  defp find_after(%{kind: :field_record} = spec, parsed, _lines, offset) do
    Enum.find_value(parsed, fn record ->
      if record.line_no > offset and matches_spec?(record, spec), do: record.line_no
    end)
  end

  defp matches_spec?(record, spec) do
    record.key == spec.key and
      Enum.all?(spec.fields, fn {field, policy} ->
        record.fields |> Map.get(field) |> policy_matches?(policy)
      end)
  end

  defp policy_matches?(nil, _policy), do: false
  defp policy_matches?(actual, {:eq, expected}), do: actual == expected
  defp policy_matches?(actual, {:one_of, values}), do: actual in values
  defp policy_matches?(actual, :positive_integer), do: integer_policy?(actual, &(&1 > 0))
  defp policy_matches?(actual, :nonnegative_integer), do: integer_policy?(actual, &(&1 >= 0))
  defp policy_matches?(actual, :integer), do: integer_policy?(actual, fn _ -> true end)

  defp integer_policy?(actual, fun) do
    case Integer.parse(actual) do
      {integer, ""} -> fun.(integer)
      _ -> false
    end
  end

  defp format_policy({:eq, expected}), do: expected
  defp format_policy({:one_of, values}), do: Enum.join(values, " | ")
  defp format_policy(:positive_integer), do: "positive integer"
  defp format_policy(:nonnegative_integer), do: "nonnegative integer"
  defp format_policy(:integer), do: "integer"

  defp parse_marker_line(line, keys) do
    [key | fields] = String.split(line, " ")

    if MapSet.member?(keys, key) do
      %{
        key: key,
        fields:
          fields
          |> Enum.map(&String.split(&1, "=", parts: 2))
          |> Enum.filter(&(length(&1) == 2))
          |> Enum.flat_map(fn [field, value] ->
            case existing_atom(field) do
              nil -> []
              atom -> [{atom, value}]
            end
          end)
          |> Map.new(),
        line: nil,
        line_no: nil
      }
    end
  end

  defp existing_atom(field) do
    String.to_existing_atom(field)
  rescue
    ArgumentError -> nil
  end

  defp ordered_marker_count(family),
    do:
      length(MarkerManifest.ordered_specs(family)) + length(MarkerManifest.required_lines(family))

  defp split_lines(serial), do: normalize_lines(serial)

  defp normalize_lines(serial) do
    serial
    |> String.replace("\r\n", "\n")
    |> String.replace("\r", "\n")
    |> String.split("\n", trim: true)
  end

  defp normalize_line(line), do: line |> String.replace("\r", "") |> String.trim_trailing("\n")

  defp append_if(errors, true, error), do: errors ++ [error]
  defp append_if(errors, false, _error), do: errors

  defp accepted_claim(:mach_send), do: MarkerManifest.accepted_claim()
  defp accepted_claim(:concurrency), do: MarkerManifest.narrowed_concurrency_claim()
  defp accepted_claim(_family), do: "supporting_split_evidence"

  defp sha256(data), do: :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
end
