defmodule Mix.Tasks.Oracle.Migration.Parity do
  use Mix.Task

  alias RmxOSOracle.Migration.Phase08SourceTransform

  @shortdoc "Run migration parity checks for approved slices"

  @impl Mix.Task
  def run(args) do
    {opts, rest, _invalid} =
      OptionParser.parse(args,
        strict: [
          legacy_repo: :string,
          legacy_ref: :string,
          oracle_repo: :string,
          out_root: :string
        ]
      )

    case rest do
      ["phase08.source_transform"] ->
        report =
          Phase08SourceTransform.run(
            legacy_repo: Keyword.get(opts, :legacy_repo, "/Users/me/wip-mach/wip-gpt"),
            legacy_ref: Keyword.get(opts, :legacy_ref, "oracle-parity-a30ef3f"),
            oracle_repo: Keyword.get(opts, :oracle_repo, File.cwd!()),
            out_root:
              Keyword.get(opts, :out_root, Path.join(File.cwd!(), "priv/runs/migration-parity"))
          )

        Mix.shell().info("oracle.migration.parity phase08.source_transform: #{report["status"]}")
        Mix.shell().info("  evidence_dir: #{report["evidence_dir"]}")
        Mix.shell().info("  legacy_commit: #{report["legacy_commit"]}")
        Mix.shell().info("  oracle_commit: #{report["oracle_commit"]}")
        Mix.shell().info("  behavior_passed: #{report["behavior_passed"]}")
        Mix.shell().info("  negative_api_passed: #{report["negative_api_passed"]}")
        Mix.shell().info("  negative_mix_test_passed: #{report["negative_mix_test_passed"]}")

        if report["parity_passed"] do
          :ok
        else
          exit({:shutdown, 1})
        end

      [] ->
        Mix.shell().error("missing slice id; expected phase08.source_transform")
        exit({:shutdown, 1})

      [slice | _] ->
        Mix.shell().error("unsupported migration parity slice: #{slice}")
        exit({:shutdown, 1})
    end
  end
end
