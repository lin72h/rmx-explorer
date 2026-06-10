defmodule Mix.Tasks.Oracle.Source.Boundary.Check do
  use Mix.Task

  alias RmxOSOracle.CanonicalJSON
  alias RmxOSOracle.SourceBoundary

  @shortdoc "Validate the read-only source/Oracle responsibility boundary"

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [source: :string, pin: :string, format: :string]
      )

    report =
      SourceBoundary.check(
        source: Keyword.get(opts, :source, SourceBoundary.default_source()),
        pin: Keyword.get(opts, :pin, SourceBoundary.source_policy_commit())
      )

    if Keyword.get(opts, :format, "text") == "json" do
      Mix.shell().info(CanonicalJSON.encode!(report))
    else
      Mix.shell().info("oracle.source.boundary.check: #{report["status"]}")
      Mix.shell().info("  source: #{report["source"]}")
      Mix.shell().info("  committed pin: #{report["resolved_pin"] || "unresolved"}")
      Mix.shell().info("  source policy: #{report["source_policy_commit"] || "unresolved"}")
      Mix.shell().info("  docs: #{report["documentation"]["status"]}")

      Mix.shell().info(
        "  source workspace: #{report["source_worktree"]["workspace_sha256"] || "unavailable"}"
      )

      Enum.each(report["errors"], &Mix.shell().error("  failure: #{&1}"))
    end

    if report["status"] != "pass", do: exit({:shutdown, 1})
  end
end
