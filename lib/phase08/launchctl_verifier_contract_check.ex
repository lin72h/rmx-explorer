defmodule Phase08.LaunchctlVerifierContractCheck do
  @moduledoc """
  Static ownership checks for the Oracle D19 launchctl order contract.

  The source-side script scanned sibling verifier files. Oracle keeps the
  shared order as data and checks that downstream consumers refer to that data
  instead of carrying copied ordered marker lists. The production check scans
  Oracle `lib/**/*.ex` text only; it does not read source-side `scripts/launchd`
  as live authority.
  """

  alias Phase08.LaunchctlVerifierCommon

  @shared_ref :d19_shared_order
  @owner_path "lib/phase08/launchctl_verifier_common.ex"
  @expected_consumers MapSet.new([:d19, :d20, :d21, :d22])
  @not_applicable_consumers MapSet.new([:d23])

  def check_oracle_layout do
    check_layout(%{
      owner_markers: LaunchctlVerifierCommon.d19_order_markers(),
      consumers: LaunchctlVerifierCommon.d19_downstream_consumers(),
      not_applicable_consumers: LaunchctlVerifierCommon.d19_not_applicable_consumers(),
      source_texts: oracle_source_texts()
    })
  end

  def check_oracle_layout! do
    case check_oracle_layout() do
      :ok -> :ok
      {:error, issues} -> raise ArgumentError, format_issues(issues)
    end
  end

  def check_layout(%{owner_markers: owner_markers, consumers: consumers} = layout) do
    not_applicable_consumers = Map.get(layout, :not_applicable_consumers, [])
    source_texts = Map.get(layout, :source_texts, [])

    issues =
      []
      |> check_owner_set(owner_markers)
      |> check_consumer_set(consumers)
      |> check_not_applicable_consumers(not_applicable_consumers)
      |> check_consumer_refs(consumers)
      |> check_source_texts(owner_markers, source_texts)
      |> Enum.reverse()

    if issues == [], do: :ok, else: {:error, issues}
  end

  def seeded_copied_order_source_text do
    %{
      path: "lib/phase08/seeded_bad_consumer.ex",
      text: """
      defmodule Phase08.SeededBadConsumer do
        @copied_d19_order [
          #{quoted_marker_lines(LaunchctlVerifierCommon.d19_order_markers())}
        ]
      end
      """
    }
  end

  def owner_source_text do
    path = Path.join(File.cwd!(), @owner_path)
    %{path: @owner_path, text: File.read!(path)}
  end

  defp check_owner_set(issues, owner_markers) do
    cond do
      owner_markers == [] ->
        [%{reason: :missing_owner_order_contract} | issues]

      length(owner_markers) != length(Enum.uniq(owner_markers)) ->
        [%{reason: :duplicate_owner_order_marker} | issues]

      true ->
        issues
    end
  end

  defp check_consumer_set(issues, consumers) do
    actual = consumers |> Enum.map(&Map.fetch!(&1, :id)) |> MapSet.new()

    issues
    |> add_missing_consumers(MapSet.difference(@expected_consumers, actual))
    |> add_unknown_consumers(MapSet.difference(actual, @expected_consumers))
  end

  defp check_not_applicable_consumers(issues, consumers) do
    actual = consumers |> Enum.map(&Map.fetch!(&1, :id)) |> MapSet.new()
    missing = MapSet.difference(@not_applicable_consumers, actual)

    missing_reason =
      consumers
      |> Enum.filter(&(Map.get(&1, :status) != :not_applicable or blank?(Map.get(&1, :reason))))
      |> Enum.map(&Map.fetch!(&1, :id))
      |> MapSet.new()

    issues
    |> maybe_add_issue(missing, :missing_not_applicable_consumer)
    |> maybe_add_issue(missing_reason, :invalid_not_applicable_consumer)
  end

  defp add_missing_consumers(issues, missing) do
    if MapSet.size(missing) == 0 do
      issues
    else
      [%{reason: :missing_d19_order_consumers, consumers: Enum.sort(missing)} | issues]
    end
  end

  defp add_unknown_consumers(issues, unknown) do
    if MapSet.size(unknown) == 0 do
      issues
    else
      [%{reason: :unknown_d19_order_consumers, consumers: Enum.sort(unknown)} | issues]
    end
  end

  defp check_consumer_refs(issues, consumers) do
    missing_refs =
      consumers
      |> Enum.reject(&(Map.get(&1, :order_ref) == @shared_ref))
      |> Enum.map(&Map.fetch!(&1, :id))

    if missing_refs == [] do
      issues
    else
      [%{reason: :missing_shared_order_ref, consumers: Enum.sort(missing_refs)} | issues]
    end
  end

  defp check_source_texts(issues, _owner_markers, []), do: issues

  defp check_source_texts(issues, owner_markers, source_texts) do
    owner_text =
      Enum.find(source_texts, &(normalize_path(&1.path) == @owner_path))

    issues
    |> check_owner_text(owner_markers, owner_text)
    |> check_non_owner_copies(owner_markers, source_texts)
  end

  defp check_owner_text(issues, _owner_markers, nil) do
    [%{reason: :missing_owner_source_text, owner_path: @owner_path} | issues]
  end

  defp check_owner_text(issues, owner_markers, owner_text) do
    if contains_ordered_marker_set?(owner_text.text, owner_markers) do
      issues
    else
      [%{reason: :owner_source_missing_order_contract, owner_path: @owner_path} | issues]
    end
  end

  defp check_non_owner_copies(issues, owner_markers, source_texts) do
    copied =
      source_texts
      |> Enum.reject(&(normalize_path(&1.path) == @owner_path))
      |> Enum.flat_map(fn source ->
        if contains_ordered_marker_set?(source.text, owner_markers) do
          [
            %{
              reason: :copied_d19_order_contract,
              path: source.path,
              marker_count: length(owner_markers)
            }
          ]
        else
          []
        end
      end)

    copied ++ issues
  end

  defp contains_ordered_marker_set?(text, markers) do
    markers
    |> Enum.reduce_while(-1, fn marker, last_idx ->
      case :binary.match(text, marker) do
        {idx, _length} when idx > last_idx -> {:cont, idx}
        _ -> {:halt, false}
      end
    end)
    |> is_integer()
  end

  defp oracle_source_texts do
    File.cwd!()
    |> Path.join("lib/**/*.ex")
    |> Path.wildcard()
    |> Enum.map(fn path ->
      %{path: Path.relative_to(path, File.cwd!()), text: File.read!(path)}
    end)
  end

  defp normalize_path(path), do: Path.relative_to(path, File.cwd!())

  defp maybe_add_issue(issues, values, reason) do
    if MapSet.size(values) == 0 do
      issues
    else
      [%{reason: reason, consumers: Enum.sort(values)} | issues]
    end
  end

  defp quoted_marker_lines(markers) do
    markers
    |> Enum.map_join(",\n      ", &inspect/1)
  end

  defp blank?(value), do: is_nil(value) or value == ""

  defp format_issues(issues) do
    issues
    |> Enum.map(&inspect/1)
    |> Enum.join("\n")
  end
end
