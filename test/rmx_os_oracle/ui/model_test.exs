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

  test "canonicalization groups required M0 target actions and blocked edges" do
    result = Model.canonicalization()
    actions = result["data"]["actions"]

    assert Map.keys(actions) |> Enum.sort() ==
             ~w(evaluate_c_support keep_c_support keep_elixir keep_fixture port_to_elixir port_to_zig relocate_zig retain_c_reference_until_zig_parity)

    assert actions["evaluate_c_support"]["entry_count"] == 4
    assert actions["keep_c_support"]["entry_count"] == 2
    assert actions["keep_elixir"]["entry_count"] == 36
    assert actions["keep_fixture"]["entry_count"] == 17
    assert actions["port_to_elixir"]["entry_count"] == 44
    assert actions["port_to_zig"]["status"] == "not_applicable"
    assert actions["retain_c_reference_until_zig_parity"]["entry_count"] == 16
    assert actions["relocate_zig"]["entry_count"] == 2

    assert result["data"]["status_semantics"] =~ "not migrated status"
    assert result["data"]["other_actions"] == []
    assert is_list(result["data"]["blocked_dependency_edges"])
  end
end
