defmodule RmxOSOracleUIExportTest do
  use ExUnit.Case

  alias RmxOSOracle.UI.Export

  defmodule FakeModel do
    def overview(_opts) do
      %{
        "source_refs" => [],
        "warnings" => [],
        "data" => %{
          "phase" => %{},
          "m1_acceptance" => %{},
          "source_freeze" => %{},
          "m0_manifest" => %{},
          "checks" => [],
          "hard_stops" => []
        }
      }
    end

    def migration(_opts) do
      %{
        "source_refs" => [],
        "warnings" => [],
        "data" => %{
          "milestones" => %{"m0" => %{}, "m1" => %{}},
          "imported_files" => [],
          "manifest_drift" => %{"changed_entries" => []},
          "dependency_audit" => %{"blocked_edges" => [], "allowed_edges" => []},
          "fixture_import_status" => %{"imported" => [], "skipped" => [], "blocked" => []}
        }
      }
    end

    def canonicalization(_opts) do
      %{
        "source_refs" => [],
        "warnings" => [],
        "data" => %{
          "status_semantics" => "status semantics",
          "summary" => [],
          "actions" =>
            Map.new(
              ~w(keep_elixir keep_fixture port_to_elixir port_to_zig retain_c_reference_until_zig_parity relocate_zig evaluate_c_support keep_c_support),
              fn action ->
                {action,
                 %{
                   "action" => action,
                   "label" => action,
                   "status" => "not_applicable",
                   "status_meaning" => "manifest_classification_readiness",
                   "entry_count" => 0,
                   "entries" => [],
                   "source_refs" => []
                 }}
              end
            ),
          "other_actions" => [],
          "blocked_dependency_edges" => [],
          "dependency_audit" => %{"blocked_edge_count" => 0}
        }
      }
    end

    def platforms(_opts) do
      %{
        "source_refs" => [],
        "warnings" => [],
        "data" => %{
          "status_semantics" => "platform status semantics",
          "canonical_platforms" =>
            Enum.map(~w(rx-x64 rx-a64 mx-x64 mx-a64 nx-r64), fn id ->
              %{
                "id" => id,
                "label" => id,
                "arch" => String.split(id, "-") |> List.last(),
                "status" => "pass",
                "status_meaning" => "static_identity_metadata_only",
                "evidence_status" => "parser_missing",
                "evidence_levels" => [],
                "runner_ids" => [],
                "source_refs" => ["docs/migration-m2-authority-design.md"]
              }
            end),
          "historical_runner_ids" => [
            historical_runner("mx-a64z", "mx-a64"),
            historical_runner("mx-x64z", "mx-x64"),
            historical_runner("nx-v64z", "nx-r64")
          ],
          "runner_mapping_audit" => %{
            "status" => "parser_missing",
            "status_meaning" => "historical_runner_mapping_audit_not_implemented",
            "summary" => "parser missing",
            "source_refs" => ["docs/migration-m2-authority-design.md"]
          },
          "artifact_availability" => [
            %{
              "id" => "mx_a64z_runner_dir",
              "path" => "mx-a64z",
              "kind" => "historical_runner_dir",
              "exists" => true,
              "status" => "pass",
              "status_meaning" => "presence_only_not_evidence",
              "source_refs" => ["mx-a64z"]
            }
          ]
        }
      }
    end

    def evidence_ladder(_opts) do
      %{
        "source_refs" => [],
        "warnings" => [],
        "data" => %{
          "status_semantics" => "evidence status semantics",
          "classifier_status" => %{
            "status" => "parser_missing",
            "status_meaning" => "artifact_to_evidence_layer_classifier_not_implemented",
            "source_refs" => ["lib/rmx_os_oracle/evidence.ex"]
          },
          "levels" =>
            Enum.map(~w(L0 L1 L2 L3 L4), fn id ->
              level = %{
                "id" => id,
                "label" => id,
                "layer" => "layer_#{id}",
                "status" => "parser_missing",
                "status_meaning" => "evidence_classifier_missing",
                "scaffold_status" => "pass",
                "artifact_refs" => [],
                "source_refs" => ["lib/rmx_os_oracle/evidence.ex"]
              }

              if id == "L3", do: Map.put(level, "mismatch_categories", []), else: level
            end),
          "harness_note" => %{
            "severity" => "warning",
            "text" => "ExUnit green is harness evidence only, not platform evidence.",
            "source_refs" => ["lib/rmx_os_oracle/evidence.ex"]
          }
        }
      }
    end

    def repo_status(_repo_root) do
      %{"sha" => "abc123", "dirty" => false, "warnings" => []}
    end

    defp historical_runner(id, platform_id) do
      %{
        "id" => id,
        "canonical_platform_id" => platform_id,
        "provenance_only" => true,
        "status" => "pass",
        "status_meaning" => "historical_runner_id_sourced_mapping_not_audited",
        "source_refs" => ["docs/migration-m2-authority-design.md"]
      }
    end
  end

  defmodule WarningModel do
    def overview(_opts) do
      %{
        "source_refs" => [],
        "warnings" => [
          warning("common.source.unavailable"),
          warning("other.source.unavailable")
        ],
        "data" => %{
          "phase" => %{},
          "m1_acceptance" => %{},
          "source_freeze" => %{},
          "m0_manifest" => %{},
          "checks" => [],
          "hard_stops" => []
        }
      }
    end

    def canonicalization(_opts), do: FakeModel.canonicalization([])
    def platforms(_opts), do: FakeModel.platforms([])
    def evidence_ladder(_opts), do: FakeModel.evidence_ladder([])

    def repo_status(_repo_root) do
      %{"sha" => "abc123", "dirty" => false, "warnings" => []}
    end

    defp warning(id) do
      %{"id" => id, "severity" => "warning", "message" => id, "source_refs" => []}
    end
  end

  test "writes validated built-in JSON snapshots inside the designated directory" do
    subdir = "test-#{System.unique_integer([:positive])}"
    output_dir = Path.join([File.cwd!(), Export.snapshot_dir(), subdir])
    on_exit(fn -> File.rm_rf!(output_dir) end)

    report =
      Export.export(
        model: FakeModel,
        pages: ["overview", "migration", "canonicalization", "platforms", "evidence_ladder"],
        snapshot_subdir: subdir,
        generated_at: "2026-06-09T00:00:00Z"
      )

    assert report["status"] == "pass"

    for page <- ["overview", "migration"] do
      snapshot = output_dir |> Path.join("#{page}.json") |> File.read!() |> JSON.decode!()
      assert snapshot["schema"] == "rmxos_oracle.ui.#{page}.v1"
      assert snapshot["repo"]["sha"] == "abc123"
      assert snapshot["ui"]["semantics"] == "a2ui-inspired"
    end

    snapshot = output_dir |> Path.join("canonicalization.json") |> File.read!() |> JSON.decode!()
    assert snapshot["schema"] == "rmxos_oracle.ui.canonicalization.v1"
    assert snapshot["repo"]["sha"] == "abc123"
    assert snapshot["ui"]["surface_id"] == "canonicalization"

    snapshot = output_dir |> Path.join("platforms.json") |> File.read!() |> JSON.decode!()
    assert snapshot["schema"] == "rmxos_oracle.ui.platforms.v1"
    assert snapshot["repo"]["sha"] == "abc123"
    assert snapshot["ui"]["surface_id"] == "platforms"

    snapshot = output_dir |> Path.join("evidence_ladder.json") |> File.read!() |> JSON.decode!()
    assert snapshot["schema"] == "rmxos_oracle.ui.evidence_ladder.v1"
    assert snapshot["repo"]["sha"] == "abc123"
    assert snapshot["ui"]["surface_id"] == "evidence_ladder"
  end

  test "rejects a symlinked output path component" do
    subdir = "test-link-#{System.unique_integer([:positive])}"
    designated = Path.join(File.cwd!(), Export.snapshot_dir())
    link = Path.join(designated, subdir)
    File.mkdir_p!(designated)
    File.ln_s!(System.tmp_dir!(), link)
    on_exit(fn -> File.rm(link) end)

    assert_raise ArgumentError, ~r/symlink component/, fn ->
      Export.export(model: FakeModel, pages: ["overview"], snapshot_subdir: subdir)
    end
  end

  test "rejects lexical traversal outside the designated snapshot directory" do
    assert_raise ArgumentError, ~r/snapshot output escapes/, fn ->
      Export.export(model: FakeModel, pages: ["overview"], snapshot_subdir: "../../escape")
    end
  end

  test "page-prefixing preserves complete warning ids without collisions" do
    snapshot =
      Export.build_snapshot("overview",
        model: WarningModel,
        generated_at: "2026-06-09T00:00:00Z"
      )

    assert Enum.map(snapshot["warnings"], & &1["id"]) == [
             "overview.common.source.unavailable",
             "overview.other.source.unavailable"
           ]
  end
end
