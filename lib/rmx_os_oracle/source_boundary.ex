defmodule RmxOSOracle.SourceBoundary do
  @moduledoc """
  Read-only checks for the source/Oracle responsibility boundary.

  The source worktree fingerprint supports before/after comparison. Producing
  it does not require a clean source worktree and does not write to the source
  repository.
  """

  alias RmxOSOracle.CanonicalJSON

  @default_source "/Users/me/wip-mach/wip-gpt"
  @source_policy_commit "e6dfa40c1823adc73b5962e6503a904472a85f52"

  @documentation_requirements %{
    "docs/source-oracle-responsibility-boundary.md" => [
      "Oracle has read-only access to `/Users/me/wip-mach/wip-gpt`.",
      "Oracle must never create, modify, delete, move, stage, or commit files",
      "Report the smallest falsifiable source requirement.",
      "Oracle test probes, fixtures, stubs, and validators must never substitute",
      "Oracle may validate only committed source pins."
    ],
    "docs/migration-m1-design.md" => [
      "source-oracle-responsibility-boundary.md",
      "Oracle may validate only committed source"
    ],
    "docs/migration-m0-inventory.md" => [
      "Oracle may validate only committed source pins."
    ],
    "docs/migration-m2-authority-design.md" => [
      "source-oracle-responsibility-boundary.md"
    ],
    "docs/launchctl-test-authority-migration-status.md" => [
      "source-oracle-responsibility-boundary.md"
    ],
    "docs/asl-a2-design.md" => [
      "source-oracle-responsibility-boundary.md",
      "source_staging_capability_missing"
    ]
  }

  def default_source, do: @default_source
  def source_policy_commit, do: @source_policy_commit
  def documentation_requirements, do: @documentation_requirements

  def check(opts \\ []) do
    source = opts |> Keyword.get(:source, @default_source) |> Path.expand()
    oracle_root = opts |> Keyword.get(:oracle_root, File.cwd!()) |> Path.expand()
    pin = Keyword.get(opts, :pin, @source_policy_commit)

    {resolved_pin, pin_errors} = resolve_committed_pin(source, pin)
    {policy_commit, policy_errors} = resolve_committed_pin(source, @source_policy_commit)
    history_errors = policy_history_errors(source)
    documentation = documentation_check(oracle_root)
    fingerprint = worktree_fingerprint(source)

    errors =
      pin_errors ++
        policy_errors ++
        history_errors ++
        documentation["errors"] ++
        fingerprint["errors"]

    %{
      "schema" => "rmxos_oracle.source_boundary_check.v1",
      "status" => if(errors == [], do: "pass", else: "fail"),
      "source" => source,
      "requested_pin" => pin,
      "resolved_pin" => resolved_pin,
      "source_policy_commit" => policy_commit,
      "documentation" => documentation,
      "source_worktree" => fingerprint,
      "errors" => errors
    }
  end

  def documentation_check(oracle_root \\ File.cwd!()) do
    results =
      Enum.map(@documentation_requirements, fn {path, required_text} ->
        absolute = Path.join(oracle_root, path)

        case File.read(absolute) do
          {:ok, text} ->
            check_document(path, text, required_text)

          {:error, reason} ->
            %{"path" => path, "status" => "fail", "errors" => ["missing: #{reason}"]}
        end
      end)
      |> Enum.sort_by(& &1["path"])

    errors =
      Enum.flat_map(results, fn result ->
        Enum.map(result["errors"], &"#{result["path"]}: #{&1}")
      end)

    %{
      "status" => if(errors == [], do: "pass", else: "fail"),
      "documents" => results,
      "errors" => errors
    }
  end

  def check_document(path, text, required_text) do
    missing = Enum.reject(required_text, &String.contains?(text, &1))

    %{
      "path" => path,
      "status" => if(missing == [], do: "pass", else: "fail"),
      "errors" => Enum.map(missing, &"missing required boundary text: #{inspect(&1)}")
    }
  end

  def resolve_committed_pin(source, pin) do
    case git(source, ["rev-parse", "--verify", "#{pin}^{commit}"]) do
      {resolved, 0} ->
        {String.trim(resolved), []}

      {output, _status} ->
        {nil, ["source pin is not a committed git object: #{pin}: #{String.trim(output)}"]}
    end
  end

  def worktree_fingerprint(source) do
    with {head, 0} <- git(source, ["rev-parse", "HEAD"]),
         {status, 0} <- git(source, ["status", "--porcelain=v1", "--untracked-files=all"]),
         {unstaged, 0} <- git(source, ["diff", "--binary", "--no-ext-diff"]),
         {staged, 0} <- git(source, ["diff", "--cached", "--binary", "--no-ext-diff"]),
         {untracked, 0} <- git(source, ["ls-files", "--others", "--exclude-standard", "-z"]) do
      untracked_files = untracked_identities(source, untracked)

      state = %{
        "head" => String.trim(head),
        "status_sha256" => sha256(status),
        "unstaged_diff_sha256" => sha256(unstaged),
        "staged_diff_sha256" => sha256(staged),
        "untracked_files" => untracked_files
      }

      Map.merge(state, %{
        "workspace_sha256" => CanonicalJSON.sha256(state),
        "errors" => []
      })
    else
      {output, _status} ->
        %{
          "head" => nil,
          "workspace_sha256" => nil,
          "errors" => ["cannot fingerprint source worktree: #{String.trim(output)}"]
        }
    end
  end

  def unchanged?(before_fingerprint, after_fingerprint) do
    before_fingerprint["workspace_sha256"] != nil and
      before_fingerprint["workspace_sha256"] == after_fingerprint["workspace_sha256"]
  end

  defp policy_history_errors(source) do
    case git(source, ["merge-base", "--is-ancestor", @source_policy_commit, "HEAD"]) do
      {_output, 0} -> []
      {_output, _status} -> ["source policy commit is not an ancestor of source HEAD"]
    end
  end

  defp untracked_identities(source, output) do
    output
    |> String.split(<<0>>, trim: true)
    |> Enum.sort()
    |> Enum.map(fn path ->
      absolute = Path.join(source, path)

      %{
        "path" => path,
        "sha256" =>
          if(File.regular?(absolute), do: absolute |> File.read!() |> sha256(), else: nil)
      }
    end)
  end

  defp git(source, args) do
    System.cmd("git", ["-C", source | args],
      stderr_to_stdout: true,
      env: [{"GIT_OPTIONAL_LOCKS", "0"}]
    )
  end

  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end
