defmodule RmxOSOracle.SourceBoundaryTest do
  use ExUnit.Case

  alias RmxOSOracle.SourceBoundary

  test "Oracle governance documents state the source responsibility boundary" do
    report = SourceBoundary.documentation_check()

    assert report["status"] == "pass"
    assert report["errors"] == []
  end

  test "documentation check fails when a required boundary clause is missing" do
    report =
      SourceBoundary.check_document(
        "docs/example.md",
        "Oracle has read-only access.",
        ["smallest falsifiable source requirement"]
      )

    assert report["status"] == "fail"
    assert length(report["errors"]) == 1
  end

  test "source policy reference resolves to a committed pin" do
    {resolved, errors} =
      SourceBoundary.resolve_committed_pin(
        SourceBoundary.default_source(),
        SourceBoundary.source_policy_commit()
      )

    assert errors == []
    assert resolved == SourceBoundary.source_policy_commit()
  end

  test "uncommitted or unknown source labels fail closed" do
    {resolved, errors} =
      SourceBoundary.resolve_committed_pin(
        SourceBoundary.default_source(),
        "e6dfa40-dirty"
      )

    assert resolved == nil
    assert length(errors) == 1
  end

  test "worktree fingerprints support read-only before and after comparison" do
    first = SourceBoundary.worktree_fingerprint(SourceBoundary.default_source())
    second = SourceBoundary.worktree_fingerprint(SourceBoundary.default_source())

    assert first["errors"] == []
    assert SourceBoundary.unchanged?(first, second)
  end
end
