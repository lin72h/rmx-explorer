defmodule RmxOSOracleUIModelTest do
  use ExUnit.Case

  alias RmxOSOracle.UI.Model

  test "keeps historical M1 acceptance separate from current manifest drift" do
    result = Model.migration()

    assert result["data"]["milestones"]["m1"]["acceptance"] == "accepted"

    assert result["data"]["milestones"]["m1"]["oracle_sha"] ==
             "389e6eb96215b732108832527efe169f7b1ef915"

    assert result["data"]["manifest_drift"]["expected_source_sha"] ==
             "a30ef3f4fff278d6dc7594543f364a880d4b36a4"

    assert length(result["data"]["imported_files"]) == 21
  end

  test "overview does not synthesize persisted env or Phoenix-boundary audit results" do
    result = Model.overview()
    checks = Map.new(result["data"]["checks"], &{&1["id"], &1})
    [hard_stop] = result["data"]["hard_stops"]

    assert checks["env_path_validation"]["status"] == "not_available"
    assert hard_stop["state"] == "not_detectable"
    assert hard_stop["detectable"] == false
  end

  test "missing source repository is unknown rather than ordinary manifest drift" do
    missing =
      Path.join(
        System.tmp_dir!(),
        "rmxos-oracle-missing-source-#{System.unique_integer([:positive])}"
      )

    result = Model.migration(source: missing)

    assert result["data"]["manifest_drift"]["status"] == "unknown"
    assert result["data"]["manifest_drift"]["changed_entries"] == []

    assert Enum.any?(result["warnings"], fn warning ->
             warning["id"] == "common.source_repository_unavailable" and
               warning["severity"] == "error"
           end)
  end

  test "missing committed manifest does not render M0 as passed" do
    repo_root =
      Path.join(
        System.tmp_dir!(),
        "rmxos-oracle-empty-repo-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(repo_root)
    on_exit(fn -> File.rm_rf!(repo_root) end)

    result = Model.migration(repo_root: repo_root, source: repo_root)

    assert result["data"]["milestones"]["m0"]["status"] == "unknown"

    assert Enum.any?(result["warnings"], fn warning ->
             warning["id"] == "migration.manifest_unavailable" and
               warning["severity"] == "error"
           end)
  end
end
