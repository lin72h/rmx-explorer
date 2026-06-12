defmodule RmxOSOracle.Notifyd.N2.ContractCheck do
  @moduledoc """
  Static authority checks for the notifyd N2-series marker contract.

  The notifyd N2 authority module owns Oracle-side marker literals. Runtime
  emitters remain source-owned and preserved serials remain evidence; normal
  tests must not treat source scripts or ignored run directories as live marker
  authority.
  """

  alias RmxOSOracle.Notifyd.N2.MarkerManifest

  @authority_path "lib/rmx_os_oracle/notifyd/n2/marker_manifest.ex"
  @phase08_glob "lib/phase08/**/*.ex"
  @asl_glob "lib/rmx_os_oracle/asl/**/*.ex"
  @notifyd_n1_glob "lib/rmx_os_oracle/notifyd/n1/**/*.ex"
  @notifyd_n2_glob "lib/rmx_os_oracle/notifyd/n2/**/*.ex"

  def run(repo_root \\ File.cwd!()) do
    sources = production_sources(repo_root)
    no_copy = no_copy_check(sources)
    cross_series = cross_series_check(repo_root)
    whitelist = phase07_exit_whitelist_check()

    %{
      "passed" => no_copy["passed"] and cross_series["passed"] and whitelist["passed"],
      "no_copy" => no_copy,
      "cross_series" => cross_series,
      "phase07_exit_whitelist" => whitelist,
      "series_prefix_registry" => series_prefix_registry()
    }
  end

  def production_sources(repo_root) do
    repo_root
    |> Path.join("lib/**/*.ex")
    |> Path.wildcard()
    |> Enum.map(fn path -> {Path.relative_to(path, repo_root), File.read!(path)} end)
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
    registry = series_prefix_registry()
    notifyd_n2_prefix = registry["notifyd_n2"]

    phase08_notifyd_n2 =
      repo_root |> wildcard(@phase08_glob) |> grep_paths(repo_root, notifyd_n2_prefix)

    asl_notifyd_n2 =
      repo_root |> wildcard(@asl_glob) |> grep_paths(repo_root, notifyd_n2_prefix)

    notifyd_n1_notifyd_n2 =
      repo_root |> wildcard(@notifyd_n1_glob) |> grep_paths(repo_root, notifyd_n2_prefix)

    notifyd_n2_phase08 =
      repo_root |> wildcard(@notifyd_n2_glob) |> grep_paths(repo_root, registry["phase08"])

    notifyd_n2_asl_a1 =
      repo_root |> wildcard(@notifyd_n2_glob) |> grep_paths(repo_root, registry["asl_a1"])

    notifyd_n2_asl_a2 =
      repo_root |> wildcard(@notifyd_n2_glob) |> grep_paths(repo_root, registry["asl_a2"])

    notifyd_n2_asl_a3 =
      repo_root |> wildcard(@notifyd_n2_glob) |> grep_paths(repo_root, registry["asl_a3"])

    notifyd_n2_notifyd_n1 =
      repo_root |> wildcard(@notifyd_n2_glob) |> grep_paths(repo_root, registry["notifyd_n1"])

    groups = [
      phase08_notifyd_n2,
      asl_notifyd_n2,
      notifyd_n1_notifyd_n2,
      notifyd_n2_phase08,
      notifyd_n2_asl_a1,
      notifyd_n2_asl_a2,
      notifyd_n2_asl_a3,
      notifyd_n2_notifyd_n1
    ]

    %{
      "passed" => Enum.all?(groups, &(&1 == [])),
      "phase08_notifyd_n2_matches" => phase08_notifyd_n2,
      "asl_notifyd_n2_matches" => asl_notifyd_n2,
      "notifyd_n1_notifyd_n2_matches" => notifyd_n1_notifyd_n2,
      "notifyd_n2_phase08_matches" => notifyd_n2_phase08,
      "notifyd_n2_asl_a1_matches" => notifyd_n2_asl_a1,
      "notifyd_n2_asl_a2_matches" => notifyd_n2_asl_a2,
      "notifyd_n2_asl_a3_matches" => notifyd_n2_asl_a3,
      "notifyd_n2_notifyd_n1_matches" => notifyd_n2_notifyd_n1
    }
  end

  def phase07_exit_whitelist_check do
    whitelist = MarkerManifest.phase07_exit_whitelist()

    expected = %{
      "phase07_dispatch_mach_send_exit" => [:mach_send],
      "phase07_mach_dead_name_raw_exit" => [:mach_raw],
      "phase07_mach_direct_kevent_exit" => [:mach_direct],
      "phase07_dispatch_notify_trace_exit" => [
        :dispatch_notify_trace_timeout,
        :dispatch_notify_trace_delivered
      ]
    }

    %{
      "passed" => whitelist == expected,
      "whitelist" => stringify_atom_lists(whitelist)
    }
  end

  def accepted_evidence_hash_check(repo_root \\ File.cwd!()) do
    results =
      MarkerManifest.evidence()
      |> Enum.flat_map(fn {family, evidence} ->
        case Map.fetch(evidence, :path) do
          {:ok, path} ->
            full_path = Path.join(repo_root, path)

            if File.exists?(full_path) do
              sha = full_path |> File.read!() |> sha256()

              [
                %{
                  "family" => Atom.to_string(family),
                  "path" => path,
                  "expected_sha256" => evidence.serial_sha256,
                  "actual_sha256" => sha,
                  "passed" => sha == evidence.serial_sha256
                }
              ]
            else
              [
                %{
                  "family" => Atom.to_string(family),
                  "path" => path,
                  "expected_sha256" => evidence.serial_sha256,
                  "actual_sha256" => nil,
                  "passed" => true,
                  "skipped" => "ignored evidence path absent"
                }
              ]
            end

          :error ->
            []
        end
      end)

    %{"passed" => Enum.all?(results, & &1["passed"]), "results" => results}
  end

  def series_prefix_registry do
    %{
      "phase08" => "PHASE" <> "08_",
      "asl_a1" => "ASL_" <> "A1_",
      "asl_a2" => "ASL_" <> "A2_",
      "asl_a3" => "ASL_" <> "A3_",
      "notifyd_n1" => "NOTIFYD_" <> "N1_",
      "notifyd_n2" => "NOTIFYD_" <> "N2_"
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

  defp stringify_atom_lists(map) do
    Map.new(map, fn {key, values} -> {key, Enum.map(values, &Atom.to_string/1)} end)
  end

  defp sha256(data), do: :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
end
