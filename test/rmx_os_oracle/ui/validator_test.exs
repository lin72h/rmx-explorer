defmodule RmxOSOracleUIValidatorTest do
  use ExUnit.Case, async: true

  alias RmxOSOracle.UI.Export
  alias RmxOSOracle.UI.Validator

  defmodule FakeModel do
    def overview(_opts), do: page_model("checks", [])
    def migration(_opts), do: page_model("imported_files", [])

    def repo_status(_repo_root) do
      %{"sha" => "abc123", "dirty" => false, "warnings" => []}
    end

    defp page_model(key, value) do
      data =
        case key do
          "checks" ->
            %{
              "phase" => %{},
              "m1_acceptance" => %{},
              "source_freeze" => %{},
              "m0_manifest" => %{},
              "checks" => value,
              "hard_stops" => []
            }

          "imported_files" ->
            %{
              "milestones" => %{"m0" => %{}, "m1" => %{}},
              "imported_files" => value,
              "manifest_drift" => %{"changed_entries" => []},
              "dependency_audit" => %{"blocked_edges" => [], "allowed_edges" => []},
              "fixture_import_status" => %{"imported" => [], "skipped" => [], "blocked" => []}
            }
        end

      %{"source_refs" => [], "warnings" => [], "data" => data}
    end
  end

  test "accepts a complete overview snapshot" do
    assert :ok =
             "overview"
             |> snapshot()
             |> Validator.validate()
  end

  test "rejects non-binary keys before JSON encoding" do
    invalid = Map.put(snapshot("overview"), :atom_key, "not allowed")

    assert {:error, errors} = Validator.validate(invalid)
    assert Enum.any?(errors, &String.contains?(&1, "non-binary map key"))
  end

  test "rejects dangling children and unresolved RFC 6901 bindings" do
    invalid =
      update_in(snapshot("overview"), ["ui", "components"], fn components ->
        Enum.map(components, fn
          %{"id" => "root"} = root -> Map.put(root, "children", ["missing"])
          %{"id" => "checks"} = checks -> put_in(checks, ["bind", "items"], "/data/nope")
          component -> component
        end)
      end)

    assert {:error, errors} = Validator.validate(invalid)
    assert Enum.any?(errors, &String.contains?(&1, "dangling id"))
    assert Enum.any?(errors, &String.contains?(&1, "does not resolve"))
  end

  test "rejects invalid envelope provenance and duplicate warning ids" do
    warning = %{
      "id" => "overview.duplicate",
      "severity" => "warning",
      "message" => "duplicate",
      "source_refs" => []
    }

    invalid =
      snapshot("overview")
      |> Map.put("generated_at", "not-a-time")
      |> Map.put("source_refs", [123])
      |> Map.put("warnings", [warning, warning])
      |> put_in(["ui", "surface_id"], "migration")

    assert {:error, errors} = Validator.validate(invalid)
    assert Enum.any?(errors, &String.contains?(&1, "UTC ISO-8601"))
    assert Enum.any?(errors, &String.contains?(&1, "duplicate ids"))
    assert Enum.any?(errors, &String.contains?(&1, "surface_id"))
  end

  defp snapshot(page) do
    Export.build_snapshot(page,
      model: FakeModel,
      generated_at: "2026-06-09T00:00:00Z"
    )
  end
end
