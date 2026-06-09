defmodule Phase08.LaunchctlVerifierContractCheck do
  @moduledoc """
  Static ownership checks for Oracle launchctl order contracts.

  The source-side script scanned sibling verifier files. Oracle keeps shared
  order as data and checks that downstream consumers refer to that data instead
  of carrying copied ordered marker lists. The production check scans Oracle
  `lib/**/*.ex` text only; it does not read source-side `scripts/launchd` as
  live authority.
  """

  alias Phase08.LaunchctlVerifierCommon

  @owner_path "lib/phase08/launchctl_verifier_common.ex"

  @contracts [
    %{
      name: :d19,
      shared_ref: :d19_shared_order,
      copied_reason: :copied_d19_order_contract,
      missing_consumers_reason: :missing_d19_order_consumers,
      unknown_consumers_reason: :unknown_d19_order_consumers,
      markers: {LaunchctlVerifierCommon, :d19_order_markers, []},
      consumers: {LaunchctlVerifierCommon, :d19_downstream_consumers, []},
      not_applicable_consumers: {LaunchctlVerifierCommon, :d19_not_applicable_consumers, []},
      expected_consumers: MapSet.new([:d19, :d20, :d21, :d22]),
      not_applicable_expected: MapSet.new([:d23])
    },
    %{
      name: :d20,
      shared_ref: :d20_successful_exit_order,
      copied_reason: :copied_d20_order_contract,
      missing_consumers_reason: :missing_d20_order_consumers,
      unknown_consumers_reason: :unknown_d20_order_consumers,
      markers: {LaunchctlVerifierCommon, :d20_order_markers, []},
      consumers: {LaunchctlVerifierCommon, :d20_downstream_consumers, []},
      not_applicable_consumers: {LaunchctlVerifierCommon, :d20_not_applicable_consumers, []},
      expected_consumers: MapSet.new([:d20, :d21, :d22]),
      not_applicable_expected: MapSet.new([:d23])
    }
  ]

  def check_oracle_layout do
    check_layout(%{
      contracts: runtime_contracts(),
      source_texts: oracle_source_texts()
    })
  end

  def check_oracle_layout! do
    case check_oracle_layout() do
      :ok -> :ok
      {:error, issues} -> raise ArgumentError, format_issues(issues)
    end
  end

  def check_layout(%{contracts: contracts} = layout) do
    source_texts = Map.get(layout, :source_texts, [])

    issues =
      contracts
      |> Enum.reduce([], fn contract, issues ->
        issues
        |> check_owner_set(contract)
        |> check_consumer_set(contract)
        |> check_not_applicable_consumers(contract)
        |> check_consumer_refs(contract)
        |> check_source_texts(contract, source_texts)
      end)
      |> Enum.reverse()

    if issues == [], do: :ok, else: {:error, issues}
  end

  def check_layout(%{owner_markers: owner_markers, consumers: consumers} = layout) do
    check_layout(%{
      contracts: [
        %{
          name: :d19,
          shared_ref: :d19_shared_order,
          copied_reason: :copied_d19_order_contract,
          missing_consumers_reason: :missing_d19_order_consumers,
          unknown_consumers_reason: :unknown_d19_order_consumers,
          markers: owner_markers,
          consumers: consumers,
          not_applicable_consumers: Map.get(layout, :not_applicable_consumers, []),
          expected_consumers: MapSet.new([:d19, :d20, :d21, :d22]),
          not_applicable_expected: MapSet.new([:d23])
        }
      ],
      source_texts: Map.get(layout, :source_texts, [])
    })
  end

  def runtime_contracts do
    Enum.map(@contracts, fn contract ->
      contract
      |> Map.update!(:markers, &apply_tuple/1)
      |> Map.update!(:consumers, &apply_tuple/1)
      |> Map.update!(:not_applicable_consumers, &apply_tuple/1)
    end)
  end

  def seeded_copied_order_source_text(contract \\ :d19) do
    markers =
      case contract do
        :d19 -> LaunchctlVerifierCommon.d19_order_markers()
        :d20 -> LaunchctlVerifierCommon.d20_order_markers()
      end

    %{
      path: "lib/phase08/seeded_bad_#{contract}_consumer.ex",
      text: """
      defmodule Phase08.SeededBad#{String.upcase(to_string(contract))}Consumer do
        @copied_#{contract}_order [
          #{quoted_marker_lines(markers)}
        ]
      end
      """
    }
  end

  def owner_source_text do
    path = Path.join(File.cwd!(), @owner_path)
    %{path: @owner_path, text: File.read!(path)}
  end

  defp check_owner_set(issues, %{markers: markers, name: name}) do
    cond do
      markers == [] ->
        [%{reason: :missing_owner_order_contract, contract: name} | issues]

      length(markers) != length(Enum.uniq(markers)) ->
        [%{reason: :duplicate_owner_order_marker, contract: name} | issues]

      true ->
        issues
    end
  end

  defp check_consumer_set(issues, contract) do
    actual = contract.consumers |> Enum.map(&Map.fetch!(&1, :id)) |> MapSet.new()

    issues
    |> add_missing_consumers(MapSet.difference(contract.expected_consumers, actual), contract)
    |> add_unknown_consumers(MapSet.difference(actual, contract.expected_consumers), contract)
  end

  defp check_not_applicable_consumers(issues, contract) do
    actual = contract.not_applicable_consumers |> Enum.map(&Map.fetch!(&1, :id)) |> MapSet.new()
    missing = MapSet.difference(contract.not_applicable_expected, actual)

    missing_reason =
      contract.not_applicable_consumers
      |> Enum.filter(&(Map.get(&1, :status) != :not_applicable or blank?(Map.get(&1, :reason))))
      |> Enum.map(&Map.fetch!(&1, :id))
      |> MapSet.new()

    issues
    |> maybe_add_issue(missing, :missing_not_applicable_consumer, contract.name)
    |> maybe_add_issue(missing_reason, :invalid_not_applicable_consumer, contract.name)
  end

  defp add_missing_consumers(issues, missing, contract) do
    if MapSet.size(missing) == 0 do
      issues
    else
      [
        %{
          reason: contract.missing_consumers_reason,
          contract: contract.name,
          consumers: Enum.sort(missing)
        }
        | issues
      ]
    end
  end

  defp add_unknown_consumers(issues, unknown, contract) do
    if MapSet.size(unknown) == 0 do
      issues
    else
      [
        %{
          reason: contract.unknown_consumers_reason,
          contract: contract.name,
          consumers: Enum.sort(unknown)
        }
        | issues
      ]
    end
  end

  defp check_consumer_refs(issues, contract) do
    missing_refs =
      contract.consumers
      |> Enum.reject(&(Map.get(&1, :order_ref) == contract.shared_ref))
      |> Enum.map(&Map.fetch!(&1, :id))

    if missing_refs == [] do
      issues
    else
      [
        %{
          reason: :missing_shared_order_ref,
          contract: contract.name,
          shared_ref: contract.shared_ref,
          consumers: Enum.sort(missing_refs)
        }
        | issues
      ]
    end
  end

  defp check_source_texts(issues, _contract, []), do: issues

  defp check_source_texts(issues, contract, source_texts) do
    owner_text =
      Enum.find(source_texts, &(normalize_path(&1.path) == @owner_path))

    issues
    |> check_owner_text(contract, owner_text)
    |> check_non_owner_copies(contract, source_texts)
  end

  defp check_owner_text(issues, contract, nil) do
    [
      %{reason: :missing_owner_source_text, contract: contract.name, owner_path: @owner_path}
      | issues
    ]
  end

  defp check_owner_text(issues, contract, owner_text) do
    if contains_ordered_marker_set?(owner_text.text, contract.markers) do
      issues
    else
      [
        %{
          reason: :owner_source_missing_order_contract,
          contract: contract.name,
          owner_path: @owner_path
        }
        | issues
      ]
    end
  end

  defp check_non_owner_copies(issues, contract, source_texts) do
    copied =
      source_texts
      |> Enum.reject(&(normalize_path(&1.path) == @owner_path))
      |> Enum.flat_map(fn source ->
        if contains_ordered_marker_set?(source.text, contract.markers) do
          [
            %{
              reason: contract.copied_reason,
              contract: contract.name,
              path: source.path,
              marker_count: length(contract.markers)
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

  defp maybe_add_issue(issues, values, reason, contract) do
    if MapSet.size(values) == 0 do
      issues
    else
      [%{reason: reason, contract: contract, consumers: Enum.sort(values)} | issues]
    end
  end

  defp quoted_marker_lines(markers) do
    markers
    |> Enum.map_join(",\n      ", &inspect/1)
  end

  defp apply_tuple({module, function, args}), do: apply(module, function, args)
  defp apply_tuple(value), do: value

  defp blank?(value), do: is_nil(value) or value == ""

  defp format_issues(issues) do
    issues
    |> Enum.map(&inspect/1)
    |> Enum.join("\n")
  end
end
