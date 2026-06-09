defmodule RmxOSOracleUISourceInventoryTest do
  use ExUnit.Case, async: true

  alias RmxOSOracle.UI.SourceInventory

  test "records the historical M1 baseline separately from live worktree state" do
    assert SourceInventory.historical_baseline() == %{
             "status" => "pass",
             "acceptance" => "accepted",
             "oracle_sha" => "389e6eb96215b732108832527efe169f7b1ef915",
             "source_freeze_sha" => "a30ef3f4fff278d6dc7594543f364a880d4b36a4",
             "source_refs" => [
               "docs/migration-m0-inventory.md",
               "docs/migration-m1-design.md"
             ]
           }
  end

  test "defines selected import mappings and producer scope" do
    inventory = SourceInventory.inventory()
    imports = inventory["imports"]

    assert inventory["schema"] == "rmxos_oracle.ui.source_inventory.v1"
    assert length(imports) == 21
    assert Enum.all?(imports, &is_binary(&1["source_path"]))
    assert Enum.all?(imports, &is_binary(&1["target_path"]))

    assert inventory["producer_scopes"]["dependency_audit"]["scope"] ==
             "original_m1_scan_set"
  end
end
