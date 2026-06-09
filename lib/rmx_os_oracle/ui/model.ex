defmodule RmxOSOracle.UI.Model do
  @moduledoc """
  Read-only artifact readers and normalizers for UI snapshot export.

  Returned values use binary keys and JSON-compatible values only.
  """

  alias RmxOSOracle.Dependency
  alias RmxOSOracle.Evidence
  alias RmxOSOracle.Manifest
  alias RmxOSOracle.UI.SourceInventory

  def overview(opts \\ []) do
    repo_root = Keyword.get(opts, :repo_root, File.cwd!())
    source = Keyword.get(opts, :source, Manifest.default_source())
    {manifest, manifest_warnings} = manifest(repo_root, "overview")
    {preflight, preflight_warnings} = manifest_preflight(source, repo_root)
    {dependency, dependency_warnings} = dependency_audit(repo_root)
    {zig, zig_warnings} = zig_scaffold(repo_root)

    %{
      "source_refs" =>
        Enum.uniq(
          SourceInventory.migration_refs() ++
            [
              SourceInventory.manifest_path(),
              SourceInventory.dependency_path(),
              "lib/rmx_os_oracle/evidence.ex",
              "zig/build.zig",
              "zig/README.md"
            ]
        ),
      "warnings" =>
        manifest_warnings ++
          preflight_warnings ++
          dependency_warnings ++
          zig_warnings ++
          status_warnings(
            "overview.m0_manifest_failed",
            manifest,
            "The committed M0 manifest is missing, malformed, or has an unexpected digest.",
            [SourceInventory.manifest_path()]
          ) ++
          status_warnings(
            "overview.manifest_drift_detected",
            preflight,
            "Current source differs from the frozen M0 manifest.",
            [SourceInventory.manifest_path()]
          ) ++
          status_warnings(
            "overview.dependency_audit_failed",
            dependency,
            "The original-M1-scope dependency audit failed.",
            [SourceInventory.dependency_path()]
          ) ++
          [
            warning(
              "overview.env_validation_unavailable",
              "warning",
              "No persisted environment/path validation result exists; live env checks are not run by the UI model.",
              ["priv/env/env.example"]
            ),
            warning(
              "overview.phoenix_in_m1_not_detectable",
              "warning",
              "Phoenix-in-M1 has no producing boundary audit yet.",
              []
            )
          ],
      "data" => %{
        "phase" => %{
          "current" => "post_m1",
          "label" => "Post-M1 UI snapshot export",
          "status" => "pass"
        },
        "m1_acceptance" => SourceInventory.historical_baseline(),
        "source_freeze" => source_freeze(preflight),
        "m0_manifest" => manifest,
        "checks" => [
          check(
            "manifest_preflight",
            "Manifest preflight",
            preflight["status"],
            manifest_preflight_summary(preflight),
            [SourceInventory.manifest_path()]
          ),
          check(
            "env_path_validation",
            "Environment/path validation",
            "not_available",
            "No persisted read-only result is available.",
            ["priv/env/env.example"]
          ),
          check(
            "dependency_edge_audit",
            "Dependency-edge audit",
            dependency["status"],
            "#{dependency["edge_count"] || 0} original-M1-scope edges audited.",
            [SourceInventory.dependency_path()]
          ),
          check(
            "evidence_scaffold",
            "Evidence scaffold",
            "pass",
            "#{map_size(Evidence.layers())} evidence levels are defined; this is scaffold evidence only.",
            ["lib/rmx_os_oracle/evidence.ex"]
          ),
          check(
            "zig_probe_layout",
            "Zig probe layout",
            zig["status"],
            zig["summary"],
            zig["source_refs"]
          )
        ],
        "hard_stops" => [
          %{
            "id" => "phoenix_in_m1",
            "label" => "Phoenix in M1",
            "state" => "not_detectable",
            "detectable" => false,
            "severity" => "hard_stop",
            "message" => "Phoenix must not enter the M1 scaffold; no producing audit exists yet.",
            "source_refs" => []
          }
        ]
      }
    }
  end

  def migration(opts \\ []) do
    repo_root = Keyword.get(opts, :repo_root, File.cwd!())
    source = Keyword.get(opts, :source, Manifest.default_source())
    {manifest, manifest_warnings} = manifest(repo_root, "migration")
    {preflight, preflight_warnings} = manifest_preflight(source, repo_root)
    {dependency, dependency_warnings} = dependency_audit(repo_root)
    {fixtures, fixture_warnings} = fixture_inventory(repo_root)
    {imports, import_warnings} = imported_files(repo_root)

    %{
      "source_refs" =>
        Enum.uniq(
          SourceInventory.migration_refs() ++
            [
              SourceInventory.manifest_path(),
              SourceInventory.dependency_path(),
              "fixtures/launchd/"
            ]
        ),
      "warnings" =>
        manifest_warnings ++
          preflight_warnings ++
          dependency_warnings ++
          fixture_warnings ++
          import_warnings ++
          status_warnings(
            "migration.m0_manifest_failed",
            manifest,
            "The committed M0 manifest is missing, malformed, or has an unexpected digest.",
            [SourceInventory.manifest_path()]
          ) ++
          status_warnings(
            "migration.manifest_drift_detected",
            preflight,
            "Current source differs from the frozen M0 manifest.",
            [SourceInventory.manifest_path()]
          ) ++
          status_warnings(
            "migration.dependency_audit_failed",
            dependency,
            "The original-M1-scope dependency audit failed.",
            [SourceInventory.dependency_path()]
          ) ++
          status_warnings(
            "migration.fixture_inventory_failed",
            fixtures,
            "The launchd fixture inventory check failed.",
            ["fixtures/launchd/"]
          ),
      "data" => %{
        "milestones" => %{
          "m0" => %{
            "status" => manifest["status"],
            "summary" => m0_manifest_summary(manifest),
            "source_refs" => ["docs/migration-m0-inventory.md", SourceInventory.manifest_path()]
          },
          "m1" =>
            SourceInventory.historical_baseline()
            |> Map.put(
              "summary",
              "M1 was historically accepted; current drift is reported separately."
            )
        },
        "imported_files" => imports,
        "manifest_drift" => %{
          "status" => preflight["status"],
          "expected_digest" => preflight["expected_sha"],
          "observed_digest" => preflight["actual_sha"],
          "changed_entries" => preflight["drift"] || [],
          "source_sha" => preflight["source_sha"],
          "expected_source_sha" => SourceInventory.source_freeze_sha()
        },
        "dependency_audit" => %{
          "status" => dependency["status"],
          "scope" => "original_m1_scan_set",
          "edge_count" => dependency["edge_count"] || 0,
          "blocked_edges" => dependency["errors"] || [],
          "allowed_edges" => [],
          "source_refs" => [SourceInventory.dependency_path()]
        },
        "fixture_import_status" => fixtures
      }
    }
  end

  def repo_status(repo_root \\ File.cwd!()) do
    sha = git(repo_root, ["rev-parse", "HEAD"])
    status = git(repo_root, ["status", "--short", "--untracked-files=all"])

    case {sha, status} do
      {{:ok, sha}, {:ok, status}} ->
        %{"sha" => sha, "dirty" => status != "", "warnings" => []}

      _ ->
        %{
          "sha" => nil,
          "dirty" => true,
          "warnings" => [
            warning(
              "common.repo_status_unavailable",
              "error",
              "Repository SHA or dirty status could not be read; dirty defaults to true.",
              []
            )
          ]
        }
    end
  end

  defp manifest(repo_root, page) do
    path = Path.join(repo_root, SourceInventory.manifest_path())

    safe_read("#{page}.manifest_unavailable", [SourceInventory.manifest_path()], fn ->
      loaded = Manifest.load_expected(path)

      %{
        "path" => SourceInventory.manifest_path(),
        "digest" => Manifest.digest(loaded),
        "expected_digest" => Manifest.expected_digest(),
        "digest_algorithm" => "sha256",
        "status" =>
          if(Manifest.digest(loaded) == Manifest.expected_digest(), do: "pass", else: "fail")
      }
    end)
  end

  defp manifest_preflight(source, repo_root) do
    path = Path.join(repo_root, SourceInventory.manifest_path())

    if File.dir?(source) do
      safe_read("common.manifest_preflight_unavailable", [SourceInventory.manifest_path()], fn ->
        Manifest.check(source, path, Manifest.expected_digest(), "committed")
      end)
    else
      {%{
         "status" => "unknown",
         "source" => Path.expand(source),
         "mode" => "committed",
         "expected_sha" => Manifest.expected_digest(),
         "self_test_sha" => nil,
         "actual_sha" => nil,
         "source_sha" => nil,
         "manifest_path" => SourceInventory.manifest_path(),
         "drift" => [],
         "policy_failures" => [],
         "ignored_paths" => [],
         "import_relevant_status" => []
       },
       [
         warning(
           "common.source_repository_unavailable",
           "error",
           "The configured source repository is missing or not a directory: #{Path.expand(source)}",
           [SourceInventory.manifest_path()]
         )
       ]}
    end
  end

  defp dependency_audit(repo_root) do
    path = Path.join(repo_root, SourceInventory.dependency_path())

    safe_read("common.dependency_audit_unavailable", [SourceInventory.dependency_path()], fn ->
      Dependency.audit(path)
    end)
  end

  defp fixture_inventory(repo_root) do
    safe_read("migration.fixture_inventory_unavailable", ["fixtures/launchd/"], fn ->
      files =
        repo_root
        |> Path.join("fixtures/launchd/*.{plist,json}")
        |> Path.wildcard()
        |> Enum.map(&Path.relative_to(&1, repo_root))
        |> Enum.sort()

      %{
        "status" => if(files == [], do: "fail", else: "pass"),
        "scope" => "presence_only",
        "imported" => files,
        "skipped" => [],
        "blocked" => []
      }
    end)
  end

  defp imported_files(repo_root) do
    entries =
      Enum.map(SourceInventory.imports(), fn entry ->
        target_path = entry["target_path"]
        current = File.regular?(Path.join(repo_root, target_path))

        accepted =
          git_object_exists?(repo_root, SourceInventory.accepted_oracle_sha(), target_path)

        status =
          cond do
            current and accepted -> "pass"
            not current -> "fail"
            true -> "unknown"
          end

        entry
        |> Map.put("status", status)
        |> Map.put("current_target_exists", current)
        |> Map.put("accepted_commit_contains_target", accepted)
        |> Map.put("digest", nil)
      end)

    missing = Enum.filter(entries, &(&1["status"] != "pass"))

    warnings =
      if missing == [] do
        []
      else
        [
          warning(
            "migration.import_mapping_incomplete",
            "error",
            "#{length(missing)} selected import mappings could not be confirmed.",
            SourceInventory.migration_refs()
          )
        ]
      end

    {entries, warnings}
  end

  defp zig_scaffold(repo_root) do
    refs = SourceInventory.zig_paths()
    missing = Enum.reject(refs, &File.exists?(Path.join(repo_root, &1)))

    if missing == [] do
      {%{
         "status" => "pass",
         "summary" => "All declared Zig scaffold paths exist.",
         "source_refs" => refs
       }, []}
    else
      {%{
         "status" => "unknown",
         "summary" => "#{length(missing)} declared Zig scaffold paths are absent.",
         "source_refs" => refs,
         "missing" => missing
       },
       [
         warning(
           "overview.zig_scaffold_incomplete",
           "error",
           "Declared Zig scaffold paths are absent: #{Enum.join(missing, ", ")}",
           refs
         )
       ]}
    end
  end

  defp source_freeze(preflight) do
    drift =
      cond do
        preflight["status"] == "unknown" ->
          "unknown"

        same_commit?(preflight["source_sha"], SourceInventory.source_freeze_sha()) and
            preflight["drift"] == [] ->
          "none"

        true ->
          "detected"
      end

    %{
      "sha" => SourceInventory.source_freeze_sha(),
      "status" => if(drift == "none", do: "pass", else: "warning"),
      "drift" => drift,
      "current_source_sha" => preflight["source_sha"],
      "source_ref" => "docs/migration-m0-inventory.md"
    }
  end

  defp manifest_preflight_summary(%{"status" => "unknown"}),
    do: "Manifest preflight could not be read."

  defp manifest_preflight_summary(report) do
    "#{length(report["drift"] || [])} changed entries; current source SHA #{report["source_sha"] || "unknown"}."
  end

  defp m0_manifest_summary(%{"status" => "pass"}), do: "The frozen M0 manifest digest is valid."

  defp m0_manifest_summary(%{"status" => "fail"}),
    do: "The frozen M0 manifest digest does not match the accepted digest."

  defp m0_manifest_summary(_manifest), do: "The frozen M0 manifest could not be read."

  defp check(id, label, status, summary, source_refs) do
    %{
      "id" => id,
      "label" => label,
      "status" => status,
      "severity" => if(status == "pass", do: "info", else: "warning"),
      "summary" => summary,
      "details" => [],
      "source_refs" => source_refs
    }
  end

  defp safe_read(id, refs, fun) do
    {fun.(), []}
  rescue
    error ->
      {%{"status" => "unknown"},
       [
         warning(
           id,
           "error",
           "Artifact read failed: #{Exception.message(error)}",
           refs
         )
       ]}
  end

  defp warning(id, severity, message, refs) do
    %{"id" => id, "severity" => severity, "message" => message, "source_refs" => refs}
  end

  defp status_warnings(id, %{"status" => status}, message, refs)
       when status in ["fail", "blocked", "warning"] do
    [warning(id, "warning", message, refs)]
  end

  defp status_warnings(_id, _report, _message, _refs), do: []

  defp same_commit?(nil, _expected), do: false

  defp same_commit?(observed, expected) do
    String.starts_with?(expected, observed) or String.starts_with?(observed, expected)
  end

  defp git(repo_root, args) do
    case System.cmd("git", ["-C", repo_root | args], stderr_to_stdout: true) do
      {output, 0} -> {:ok, String.trim(output)}
      {output, status} -> {:error, %{"status" => status, "output" => String.trim(output)}}
    end
  end

  defp git_object_exists?(repo_root, sha, path) do
    case System.cmd("git", ["-C", repo_root, "cat-file", "-e", "#{sha}:#{path}"],
           stderr_to_stdout: true
         ) do
      {_output, 0} -> true
      {_output, _status} -> false
    end
  end
end
