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

    def repo_status(_repo_root) do
      %{"sha" => "abc123", "dirty" => false, "warnings" => []}
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
        pages: ["overview", "migration"],
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
