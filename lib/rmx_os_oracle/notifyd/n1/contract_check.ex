defmodule RmxOSOracle.Notifyd.N1.ContractCheck do
  @moduledoc """
  Static authority checks for the notifyd N1 marker contract.

  The notifyd N1 authority module owns the Oracle-side marker contract. Runtime
  marker emitters remain source-owned; Oracle does not read source scripts as a
  live authority for normal tests.
  """

  alias RmxOSOracle.Notifyd.N1.MarkerManifest

  @authority_path "lib/rmx_os_oracle/notifyd/n1/marker_manifest.ex"
  @notifyd_glob "lib/rmx_os_oracle/notifyd/**/*.ex"
  @phase08_glob "lib/phase08/**/*.ex"
  @asl_glob "lib/rmx_os_oracle/asl/**/*.ex"
  @probe_glob "priv/probes/**/*.c"

  def run(repo_root \\ File.cwd!()) do
    sources = production_sources(repo_root)
    no_copy = no_copy_check(sources)
    cross_series = cross_series_check(repo_root)

    %{
      "passed" => no_copy["passed"] and cross_series["passed"],
      "no_copy" => no_copy,
      "cross_series" => cross_series,
      "series_prefix_registry" => series_prefix_registry(),
      "registry_debt" =>
        "prefix registry is local to notifyd N1 ContractCheck; promote to shared registry when the next non-ASL marker family is extracted"
    }
  end

  def production_sources(repo_root) do
    lib_sources =
      repo_root
      |> Path.join("lib/**/*.ex")
      |> Path.wildcard()
      |> Enum.map(fn path -> {Path.relative_to(path, repo_root), File.read!(path)} end)

    probe_sources =
      repo_root
      |> Path.join(@probe_glob)
      |> Path.wildcard()
      |> Enum.map(fn path -> {Path.relative_to(path, repo_root), File.read!(path)} end)

    lib_sources ++ probe_sources
  end

  def no_copy_check(sources) when is_map(sources), do: no_copy_check(Map.to_list(sources))

  def no_copy_check(sources) when is_list(sources) do
    allowed_paths = MapSet.new([@authority_path])
    marker_literals = MarkerManifest.marker_literals()

    matches =
      for {path, source} <- sources,
          not MapSet.member?(allowed_paths, normalize_path(path)),
          literal <- marker_literals,
          String.contains?(source, literal) do
        %{"path" => path, "literal" => literal}
      end
      |> Enum.uniq_by(&{&1["path"], &1["literal"]})

    %{
      "passed" => matches == [],
      "allowed_literal_paths" => MapSet.to_list(allowed_paths),
      "matches" => matches
    }
  end

  def cross_series_check(repo_root \\ File.cwd!()) do
    notifyd_prefix = series_prefix_registry()["notifyd_n1"]
    phase08_prefix = series_prefix_registry()["phase08"]
    asl_a1_prefix = series_prefix_registry()["asl_a1"]
    asl_a2_prefix = series_prefix_registry()["asl_a2"]

    phase08_notifyd =
      repo_root
      |> wildcard(@phase08_glob)
      |> grep_paths(repo_root, notifyd_prefix)

    asl_notifyd =
      repo_root
      |> wildcard(@asl_glob)
      |> grep_paths(repo_root, notifyd_prefix)

    notifyd_phase08 =
      repo_root
      |> wildcard(@notifyd_glob)
      |> grep_paths(repo_root, phase08_prefix)

    notifyd_asl_a1 =
      repo_root
      |> wildcard(@notifyd_glob)
      |> grep_paths(repo_root, asl_a1_prefix)

    notifyd_asl_a2 =
      repo_root
      |> wildcard(@notifyd_glob)
      |> grep_paths(repo_root, asl_a2_prefix)

    %{
      "passed" =>
        Enum.all?(
          [phase08_notifyd, asl_notifyd, notifyd_phase08, notifyd_asl_a1, notifyd_asl_a2],
          &(&1 == [])
        ),
      "phase08_notifyd_n1_matches" => phase08_notifyd,
      "asl_notifyd_n1_matches" => asl_notifyd,
      "notifyd_phase08_matches" => notifyd_phase08,
      "notifyd_asl_a1_matches" => notifyd_asl_a1,
      "notifyd_asl_a2_matches" => notifyd_asl_a2
    }
  end

  def series_prefix_registry do
    %{
      "phase08" => "PHASE" <> "08_",
      "asl_a1" => "ASL_" <> "A1_",
      "asl_a2" => "ASL_" <> "A2_",
      "notifyd_n1" => "NOTIFYD_" <> "N1_"
    }
  end

  defp wildcard(repo_root, glob), do: repo_root |> Path.join(glob) |> Path.wildcard()

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

  defp normalize_path(path) do
    path
    |> Path.relative_to(File.cwd!())
    |> String.trim_leading("./")
  end
end
