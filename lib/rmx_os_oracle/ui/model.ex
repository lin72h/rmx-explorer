defmodule RmxOSOracle.UI.Model do
  @moduledoc """
  Read-only artifact readers and normalizers for UI snapshot export.

  Returned values use binary keys and JSON-compatible values only.
  """

  alias RmxOSOracle.Dependency
  alias RmxOSOracle.Evidence
  alias RmxOSOracle.Manifest
  alias RmxOSOracle.UI.SourceInventory

  @canonicalization_actions ~w(
    keep_elixir
    keep_fixture
    port_to_elixir
    port_to_zig
    retain_c_reference_until_zig_parity
    relocate_zig
    evaluate_c_support
    keep_c_support
  )

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
    blocked_edges = blocked_dependency_edges(dependency["errors"])
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
          "blocked_edges" => blocked_edges,
          "allowed_edges" => [],
          "source_refs" => [SourceInventory.dependency_path()]
        },
        "fixture_import_status" => fixtures
      }
    }
  end

  def canonicalization(opts \\ []) do
    repo_root = Keyword.get(opts, :repo_root, File.cwd!())
    {manifest, manifest_warnings} = manifest(repo_root, "canonicalization")
    {manifest_payload, payload_warnings} = manifest_payload(repo_root)
    {dependency, dependency_warnings} = dependency_audit(repo_root)

    files = manifest_payload["files"] || []
    blocked_edges = blocked_dependency_edges(dependency["errors"])
    grouped = Enum.group_by(files, & &1["target_action"])
    manifest_available = manifest["status"] == "pass"

    actions =
      @canonicalization_actions
      |> Enum.map(fn action ->
        entries =
          Enum.map(Map.get(grouped, action, []), &canonicalization_entry(&1, manifest_available))

        {action, canonicalization_action(action, entries, manifest_available)}
      end)
      |> Map.new()

    other_actions =
      grouped
      |> Map.keys()
      |> Enum.reject(&(&1 in @canonicalization_actions))
      |> Enum.sort()
      |> Enum.map(fn action ->
        %{
          "action" => action,
          "entry_count" => length(Map.get(grouped, action, [])),
          "status" => if(manifest_available, do: "pass", else: "unknown"),
          "source_refs" => [SourceInventory.manifest_path()]
        }
      end)

    %{
      "source_refs" =>
        Enum.uniq([
          SourceInventory.manifest_path(),
          SourceInventory.dependency_path(),
          "docs/migration-m0-inventory.md",
          "docs/migration-m1-design.md"
        ]),
      "warnings" =>
        manifest_warnings ++
          payload_warnings ++
          dependency_warnings ++
          status_warnings(
            "canonicalization.m0_manifest_failed",
            manifest,
            "The committed M0 manifest is missing, malformed, or has an unexpected digest.",
            [SourceInventory.manifest_path()]
          ) ++
          status_warnings(
            "canonicalization.dependency_audit_failed",
            dependency,
            "The original-M1-scope dependency audit failed.",
            [SourceInventory.dependency_path()]
          ) ++
          blocked_edge_warnings(blocked_edges),
      "data" => %{
        "status_semantics" =>
          "Action and entry status report whether the M0 manifest classification and dependency audit were readable; they are not migrated status and do not certify completion or platform evidence.",
        "summary" =>
          Enum.map(@canonicalization_actions, fn action ->
            action_summary(Map.fetch!(actions, action))
          end),
        "actions" => actions,
        "other_actions" => other_actions,
        "blocked_dependency_edges" => blocked_edges,
        "dependency_audit" => %{
          "status" => dependency["status"],
          "scope" => "original_m1_scan_set",
          "edge_count" => dependency["edge_count"] || 0,
          "blocked_edge_count" => length(blocked_edges),
          "source_refs" => [SourceInventory.dependency_path()]
        }
      }
    }
  end

  def platforms(opts \\ []) do
    repo_root = Keyword.get(opts, :repo_root, File.cwd!())

    %{
      "source_refs" =>
        Enum.uniq(
          SourceInventory.platform_refs() ++
            SourceInventory.migration_refs() ++
            Enum.map(SourceInventory.platform_artifact_paths(), & &1["path"])
        ),
      "warnings" => [
        warning(
          "platforms.runner_mapping_parser_missing",
          "warning",
          "No runner/platform mapping audit exists yet; historical runner IDs are provenance-only aliases.",
          SourceInventory.platform_refs()
        ),
        warning(
          "platforms.platform_evidence_parser_missing",
          "warning",
          "No platform evidence classifier exists yet; evidence_status remains parser_missing.",
          SourceInventory.platform_refs()
        )
      ],
      "data" => %{
        "status_semantics" =>
          "Platform status reports static identity/provenance inventory readiness only; evidence_status reports that platform evidence classification is unavailable until later parsers/audits exist.",
        "canonical_platforms" =>
          Enum.map(SourceInventory.canonical_platforms(), &platform_item/1),
        "historical_runner_ids" =>
          Enum.map(SourceInventory.historical_runner_ids(), &historical_runner_item/1),
        "runner_mapping_audit" => %{
          "status" => "parser_missing",
          "status_meaning" => "historical_runner_mapping_audit_not_implemented",
          "summary" =>
            "Historical runner IDs are shown as provenance-only aliases until a runner/platform audit exists.",
          "source_refs" => SourceInventory.platform_refs()
        },
        "artifact_availability" =>
          Enum.map(
            SourceInventory.platform_artifact_paths(),
            &artifact_availability(repo_root, &1)
          )
      }
    }
  end

  def evidence_ladder(opts \\ []) do
    repo_root = Keyword.get(opts, :repo_root, File.cwd!())
    levels = Enum.map(evidence_level_specs(), &evidence_level(repo_root, &1))
    missing_refs = levels |> Enum.flat_map(& &1["missing_source_refs"]) |> Enum.uniq()

    %{
      "source_refs" =>
        Enum.uniq(
          SourceInventory.evidence_refs() ++
            SourceInventory.zig_paths() ++ ["findings/nx-v64z"]
        ),
      "warnings" =>
        [
          warning(
            "evidence_ladder.classifier_missing",
            "warning",
            "No artifact-to-evidence-layer classifier exists yet; all evidence level statuses remain parser_missing.",
            SourceInventory.evidence_refs()
          ),
          warning(
            "evidence_ladder.exunit_harness_only",
            "warning",
            "ExUnit green is harness evidence only, not platform evidence.",
            SourceInventory.evidence_refs()
          )
        ] ++ missing_source_ref_warnings(missing_refs),
      "data" => %{
        "status_semantics" =>
          "Level status reports evidence classifier availability only; scaffold_status reports whether declared scaffold/source refs are present. ExUnit green is harness evidence only, not platform evidence.",
        "classifier_status" => %{
          "status" => "parser_missing",
          "status_meaning" => "artifact_to_evidence_layer_classifier_not_implemented",
          "source_refs" => SourceInventory.evidence_refs()
        },
        "levels" => Enum.map(levels, &Map.drop(&1, ["missing_source_refs"])),
        "harness_note" => %{
          "severity" => "warning",
          "text" => "ExUnit green is harness evidence only, not platform evidence.",
          "source_refs" => SourceInventory.evidence_refs()
        }
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

  defp manifest_payload(repo_root) do
    path = Path.join(repo_root, SourceInventory.manifest_path())

    safe_read(
      "canonicalization.manifest_payload_unavailable",
      [SourceInventory.manifest_path()],
      fn ->
        Manifest.load_expected(path)
      end
    )
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

  defp canonicalization_action(action, entries, manifest_available) do
    status =
      cond do
        not manifest_available -> "unknown"
        entries == [] -> "not_applicable"
        true -> "pass"
      end

    %{
      "action" => action,
      "label" => action,
      "status" => status,
      "status_meaning" => "manifest_classification_readiness",
      "entry_count" => length(entries),
      "entries" => entries,
      "source_refs" => [SourceInventory.manifest_path()]
    }
  end

  defp canonicalization_entry(file, manifest_available) do
    %{
      "path" => file["path"],
      "language" => file["language"],
      "role" => file["role"],
      "target_action" => file["target_action"],
      "canonical" => file["canonical"],
      "complexity" => file["complexity"],
      "contains_embedded_awk" => file["contains_embedded_awk"],
      "status" => if(manifest_available, do: "pass", else: "unknown"),
      "status_meaning" => "manifest_classification_present",
      "source_refs" => [SourceInventory.manifest_path()]
    }
  end

  defp blocked_dependency_edges(errors) when is_list(errors) do
    Enum.map(errors, &blocked_dependency_edge/1)
  end

  defp blocked_dependency_edges(_errors), do: []

  defp blocked_dependency_edge(error) when is_binary(error) do
    # Dependency.audit/1 currently reports canonical blockers in this string shape.
    # The fallback keeps the UI honest if that private message format changes.
    case String.split(error, " -> ", parts: 2) do
      ["blocked dependency edge: " <> source, target] ->
        blocked_dependency_edge(String.trim(source), String.trim(target), "blocked", error)

      _ ->
        blocked_dependency_edge("unknown", "unknown", "dependency_audit_error", error)
    end
  end

  defp blocked_dependency_edge(error) when is_map(error) do
    blocked_dependency_edge(
      string_field(error, ~w(source consumer from source_path)),
      string_field(error, ~w(target dependency to target_path)),
      string_field(error, ~w(kind edge_kind type)),
      string_field(error, ~w(reason message error))
    )
  end

  defp blocked_dependency_edge(error) do
    blocked_dependency_edge("unknown", "unknown", "dependency_audit_error", inspect(error))
  end

  defp blocked_dependency_edge(source, target, kind, reason) do
    %{
      "source" => non_empty_string(source, "unknown"),
      "target" => non_empty_string(target, "unknown"),
      "kind" => non_empty_string(kind, "dependency_audit_error"),
      "reason" => non_empty_string(reason, "dependency audit reported a blocked edge"),
      "source_refs" => [SourceInventory.dependency_path()]
    }
  end

  defp string_field(map, keys) do
    Enum.find_value(keys, fn key ->
      case Map.get(map, key) do
        value when is_binary(value) -> value
        _ -> nil
      end
    end)
  end

  defp non_empty_string(value, fallback) when is_binary(value) do
    case String.trim(value) do
      "" -> fallback
      trimmed -> trimmed
    end
  end

  defp non_empty_string(_value, fallback), do: fallback

  defp action_summary(action) do
    %{
      "id" => action["action"],
      "label" => action["label"],
      "status" => action["status"],
      "severity" =>
        if(action["status"] in ["pass", "not_applicable"], do: "info", else: "warning"),
      "summary" => "#{action["entry_count"]} manifest entries classified as #{action["action"]}.",
      "details" => [],
      "source_refs" => action["source_refs"]
    }
  end

  defp platform_item(platform) do
    %{
      "id" => platform["id"],
      "label" => platform["label"],
      "arch" => platform["arch"],
      "status" => "pass",
      "status_meaning" => "static_identity_metadata_only",
      "evidence_status" => "parser_missing",
      "evidence_levels" => [],
      "runner_ids" => platform["runner_ids"],
      "source_refs" => SourceInventory.platform_refs()
    }
  end

  defp historical_runner_item(runner) do
    %{
      "id" => runner["id"],
      "canonical_platform_id" => runner["canonical_platform_id"],
      "provenance_only" => true,
      "status" => "pass",
      "status_meaning" => "historical_runner_id_sourced_mapping_not_audited",
      "source_refs" => runner["source_refs"]
    }
  end

  defp artifact_availability(repo_root, artifact) do
    exists = File.exists?(Path.join(repo_root, artifact["path"]))

    artifact
    |> Map.put("exists", exists)
    |> Map.put("status", if(exists, do: "pass", else: "unknown"))
    |> Map.put("status_meaning", "presence_only_not_evidence")
    |> Map.put("source_refs", [artifact["path"] | SourceInventory.platform_refs()])
  end

  defp evidence_level_specs do
    layer_names = Evidence.layers()

    [
      %{
        "id" => "L0",
        "label" => "ABI/layout",
        "layer" => layer_names["L0"],
        "source_refs" => ["lib/rmx_os_oracle/evidence.ex"]
      },
      %{
        "id" => "L1",
        "label" => "Host semantic probes",
        "layer" => layer_names["L1"],
        "source_refs" => ["lib/rmx_os_oracle/evidence.ex" | SourceInventory.zig_paths()]
      },
      %{
        "id" => "L2",
        "label" => "Guest integration",
        "layer" => layer_names["L2"],
        "source_refs" => ["lib/rmx_os_oracle/evidence.ex", "docs/migration-m1-design.md"]
      },
      %{
        "id" => "L3",
        "label" => "macOS oracle",
        "layer" => layer_names["L3"],
        "source_refs" => [
          "lib/rmx_os_oracle/evidence.ex",
          "docs/migration-m2-authority-design.md",
          "findings/nx-v64z"
        ],
        "mismatch_categories" => []
      },
      %{
        "id" => "L4",
        "label" => "Fuzz/property/soak",
        "layer" => layer_names["L4"],
        "source_refs" => ["lib/rmx_os_oracle/evidence.ex"]
      }
    ]
  end

  defp evidence_level(repo_root, spec) do
    source_refs = spec["source_refs"]
    missing = Enum.reject(source_refs, &File.exists?(Path.join(repo_root, &1)))

    %{
      "id" => spec["id"],
      "label" => spec["label"],
      "layer" => spec["layer"],
      "status" => "parser_missing",
      "status_meaning" => "evidence_classifier_missing",
      "scaffold_status" => if(missing == [], do: "pass", else: "unknown"),
      "artifact_refs" => [],
      "source_refs" => source_refs,
      "missing_source_refs" => missing
    }
    |> maybe_put_map("mismatch_categories", spec["mismatch_categories"])
  end

  defp missing_source_ref_warnings([]), do: []

  defp missing_source_ref_warnings(refs) do
    [
      warning(
        "evidence_ladder.scaffold_refs_missing",
        "warning",
        "Some declared evidence scaffold/source refs are absent: #{Enum.join(refs, ", ")}",
        refs
      )
    ]
  end

  defp maybe_put_map(map, _key, nil), do: map
  defp maybe_put_map(map, key, value), do: Map.put(map, key, value)

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

  defp blocked_edge_warnings([]), do: []

  defp blocked_edge_warnings(blocked_edges) do
    [
      warning(
        "canonicalization.blocked_dependency_edges_present",
        "warning",
        "#{length(blocked_edges)} blocked dependency edges are present in the original-M1-scope audit.",
        [SourceInventory.dependency_path()]
      )
    ]
  end

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
