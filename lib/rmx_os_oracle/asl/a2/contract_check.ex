defmodule RmxOSOracle.Asl.A2.ContractCheck do
  @moduledoc """
  Static authority checks for the ASL A2 marker contract.

  The ASL A2 authority module and A2 probe source are the only production files
  allowed to own ASL_A2 marker literals. Runtime validators consume the
  authority module instead of copying marker lists.
  """

  alias RmxOSOracle.Asl.A2.MarkerManifest

  @authority_path "lib/rmx_os_oracle/asl/a2/marker_manifest.ex"
  @probe_path MarkerManifest.probe_path()
  @phase08_glob "lib/phase08/**/*.ex"
  @a1_authority_glob "lib/rmx_os_oracle/asl/a1/**/*.ex"
  @a2_authority_glob "lib/rmx_os_oracle/asl/a2/**/*.ex"

  @probe_constant_keys MapSet.new([
                         "ASL_A2_PAYLOAD",
                         "ASL_A2_ROLE_SERVER",
                         "ASL_A2_ROLE_CLIENT",
                         "ASL_A2_BUILD_ROLE_MISSING"
                       ])

  def run(repo_root \\ File.cwd!()) do
    sources = production_sources(repo_root)
    no_copy = no_copy_check(sources)
    cross_series = cross_series_check(repo_root)
    generator_guard = generator_guard(read_repo_file(repo_root, @probe_path))

    %{
      "passed" => no_copy["passed"] and cross_series["passed"] and generator_guard["passed"],
      "no_copy" => no_copy,
      "cross_series" => cross_series,
      "generator_guard" => generator_guard
    }
  end

  def production_sources(repo_root) do
    lib_sources =
      repo_root
      |> Path.join("lib/**/*.ex")
      |> Path.wildcard()
      |> Enum.map(fn path -> {Path.relative_to(path, repo_root), File.read!(path)} end)

    probe_path = Path.join(repo_root, @probe_path)
    [{@probe_path, File.read!(probe_path)} | lib_sources]
  end

  def no_copy_check(sources) when is_map(sources) do
    no_copy_check(Map.to_list(sources))
  end

  def no_copy_check(sources) when is_list(sources) do
    allowed_paths = MapSet.new([@authority_path, @probe_path])
    marker_literals = MarkerManifest.marker_literals()
    marker_keys = MarkerManifest.marker_keys()

    literal_matches =
      for {path, source} <- sources,
          not MapSet.member?(allowed_paths, normalize_path(path)),
          literal <- marker_literals,
          String.contains?(source, literal) do
        %{"path" => path, "literal" => literal, "type" => "literal"}
      end

    key_matches =
      for {path, source} <- sources,
          not MapSet.member?(allowed_paths, normalize_path(path)),
          key <- marker_keys,
          String.contains?(source, key) do
        %{"path" => path, "literal" => key, "type" => "key"}
      end

    matches =
      Enum.uniq_by(literal_matches ++ key_matches, &{&1["path"], &1["literal"], &1["type"]})

    %{
      "passed" => matches == [],
      "allowed_literal_paths" => MapSet.to_list(allowed_paths),
      "matches" => matches
    }
  end

  def generator_guard(probe_source) when is_binary(probe_source) do
    manifest_keys = MapSet.new(MarkerManifest.marker_keys())

    missing_key_anchors =
      MarkerManifest.specs()
      |> Enum.reject(fn spec -> String.contains?(probe_source, spec.anchor) end)
      |> Enum.map(fn spec -> %{id: spec.id, key: spec.key, anchor: spec.anchor} end)

    missing_emission_anchors =
      MarkerManifest.specs()
      |> Enum.flat_map(fn spec ->
        spec.emission_anchors
        |> Enum.reject(&String.contains?(probe_source, &1))
        |> Enum.map(fn anchor -> %{id: spec.id, key: spec.key, anchor: anchor} end)
      end)

    probe_keys =
      ~r/ASL_A2_[A-Z0-9_]+/
      |> Regex.scan(probe_source)
      |> List.flatten()
      |> MapSet.new()

    allowed_keys = MapSet.union(manifest_keys, @probe_constant_keys)

    unmapped_probe_keys =
      probe_keys
      |> MapSet.difference(allowed_keys)
      |> MapSet.to_list()
      |> Enum.sort()

    %{
      "passed" =>
        missing_key_anchors == [] and missing_emission_anchors == [] and
          unmapped_probe_keys == [],
      "checked_manifest_entries" => length(MarkerManifest.specs()),
      "missing_anchors" => missing_key_anchors ++ missing_emission_anchors,
      "missing_key_anchors" => missing_key_anchors,
      "missing_emission_anchors" => missing_emission_anchors,
      "unmapped_probe_keys" => unmapped_probe_keys
    }
  end

  def accepted_serial_coverage(serial) when is_binary(serial) do
    serial_keys =
      ~r/^ASL_A2_[A-Z0-9_]+=/m
      |> Regex.scan(serial)
      |> List.flatten()
      |> Enum.map(&String.trim_trailing(&1, "="))
      |> MapSet.new()

    authority_keys = MapSet.new(MarkerManifest.marker_keys())

    unmapped_serial_keys =
      serial_keys
      |> MapSet.difference(authority_keys)
      |> MapSet.to_list()
      |> Enum.sort()

    missing_from_serial =
      authority_keys
      |> MapSet.difference(serial_keys)
      |> MapSet.to_list()
      |> Enum.sort()

    %{
      "passed" => unmapped_serial_keys == [] and missing_from_serial == [],
      "unmapped_serial_keys" => unmapped_serial_keys,
      "authority_keys_missing_from_serial" => missing_from_serial
    }
  end

  def cross_series_check(repo_root \\ File.cwd!()) do
    phase08_matches =
      repo_root
      |> Path.join(@phase08_glob)
      |> Path.wildcard()
      |> grep_paths(repo_root, "ASL_A2_")

    a1_matches =
      repo_root
      |> Path.join(@a1_authority_glob)
      |> Path.wildcard()
      |> grep_paths(repo_root, "ASL_A2_")

    a2_authority_matches =
      repo_root
      |> Path.join(@a2_authority_glob)
      |> Path.wildcard()
      |> grep_paths(repo_root, "ASL_" <> "A1_")

    %{
      "passed" => phase08_matches == [] and a1_matches == [] and a2_authority_matches == [],
      "phase08_asl_a2_matches" => phase08_matches,
      "a1_asl_a2_matches" => a1_matches,
      "a2_asl_a1_matches" => a2_authority_matches
    }
  end

  defp grep_paths(paths, repo_root, needle) do
    paths
    |> Enum.flat_map(fn path ->
      source = File.read!(path)

      if String.contains?(source, needle) do
        [Path.relative_to(path, repo_root)]
      else
        []
      end
    end)
    |> Enum.sort()
  end

  defp read_repo_file(repo_root, relative_path) do
    repo_root
    |> Path.join(relative_path)
    |> File.read!()
  end

  defp normalize_path(path) do
    path
    |> Path.relative_to(File.cwd!())
    |> String.trim_leading("./")
  end
end
