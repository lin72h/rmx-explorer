defmodule RmxOSOracle.Asl.A1.ContractCheck do
  @moduledoc """
  Static authority checks for the ASL A1 marker contract.

  The ASL A1 authority module and the A1 probe source are the only production
  files allowed to own ASL_A1 marker literals. Runtime validators consume the
  authority module instead of copying marker lists.
  """

  alias RmxOSOracle.Asl.A1.MarkerManifest

  @authority_path "lib/rmx_os_oracle/asl/a1/marker_manifest.ex"
  @probe_path MarkerManifest.probe_path()
  @phase08_glob "lib/phase08/**/*.ex"
  @asl_authority_glob "lib/rmx_os_oracle/asl/**/*.ex"

  @probe_constant_keys MapSet.new([
                         "ASL_A1_SOURCE_ASL_MESSAGE",
                         "ASL_A1_EXPECTED_MESSAGE",
                         "ASL_A1_EXPECTED_SENDER",
                         "ASL_A1_EXPECTED_FACILITY",
                         "ASL_A1_EXPECTED_LEVEL",
                         "ASL_A1_POSITIVE_PAYLOAD"
                       ])

  @nonaccepted_probe_keys MapSet.new([
                            "ASL_A1_AUDIT_DEFER_REASON",
                            "ASL_A1_SESSION_TRACKING"
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
      ~r/ASL_A1_[A-Z0-9_]+/
      |> Regex.scan(probe_source)
      |> List.flatten()
      |> MapSet.new()

    allowed_keys =
      manifest_keys
      |> MapSet.union(@probe_constant_keys)
      |> MapSet.union(@nonaccepted_probe_keys)

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
      "unmapped_probe_keys" => unmapped_probe_keys,
      "nonaccepted_probe_keys" => MapSet.to_list(@nonaccepted_probe_keys)
    }
  end

  def cross_series_check(repo_root \\ File.cwd!()) do
    phase08_matches =
      repo_root
      |> Path.join(@phase08_glob)
      |> Path.wildcard()
      |> grep_paths(repo_root, "ASL_A1_")

    asl_authority_matches =
      repo_root
      |> Path.join(@asl_authority_glob)
      |> Path.wildcard()
      |> Enum.reject(&(Path.relative_to(&1, repo_root) == @authority_path))
      |> grep_paths(repo_root, "PHASE" <> "08_")

    %{
      "passed" => phase08_matches == [] and asl_authority_matches == [],
      "phase08_asl_a1_matches" => phase08_matches,
      "asl_phase08_matches" => asl_authority_matches
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
