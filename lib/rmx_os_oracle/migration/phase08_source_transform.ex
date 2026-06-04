defmodule RmxOSOracle.Migration.Phase08SourceTransform do
  @moduledoc """
  Parity runner for the first M3 migration slice.

  This module writes raw evidence only under `priv/runs/`. It does not create a
  committed parity record and does not mark `Phase08.MarkerManifest` migrated.
  """

  alias RmxOSOracle.CanonicalJSON

  @slice_id "phase08.source_transform"
  @expected_legacy_commit "a30ef3f"
  @default_legacy_repo "/Users/me/wip-mach/wip-gpt"
  @default_legacy_ref "oracle-parity-a30ef3f"
  @default_oracle_repo "/Users/me/wip-mach/wip-gpt-oracle"
  @legacy_files [
    "scripts/launchd/phase08_source_transform.exs",
    "test/phase08_source_transform_test.exs"
  ]
  @oracle_files [
    "lib/phase08/source_transform.ex",
    "test/phase08/source_transform_test.exs"
  ]

  def run(opts \\ []) do
    legacy_repo = Keyword.get(opts, :legacy_repo, @default_legacy_repo)
    legacy_ref = Keyword.get(opts, :legacy_ref, @default_legacy_ref)
    oracle_repo = Keyword.get(opts, :oracle_repo, @default_oracle_repo)
    out_root = Keyword.get(opts, :out_root, Path.join(oracle_repo, "priv/runs/migration-parity"))

    evidence_dir = Keyword.get_lazy(opts, :evidence_dir, fn -> default_evidence_dir(out_root) end)
    File.mkdir_p!(evidence_dir)

    legacy_commit = resolve_legacy_commit!(legacy_repo, legacy_ref)
    oracle_commit = git!(oracle_repo, ["rev-parse", "--short", "HEAD"])

    legacy_hashes = hash_legacy_files!(legacy_repo, legacy_commit)
    oracle_hashes = hash_oracle_files!(oracle_repo)
    legacy_source_path = materialize_legacy_source!(legacy_repo, legacy_commit, evidence_dir)

    legacy_behavior =
      run_behavior_process!(
        :legacy,
        legacy_source_path,
        Path.join(evidence_dir, "legacy_behavior.json")
      )

    oracle_behavior =
      run_behavior_process!(
        :oracle,
        Path.join(oracle_repo, "lib/phase08/source_transform.ex"),
        Path.join(evidence_dir, "oracle_behavior.json")
      )

    behavior_passed = normalize_behavior(legacy_behavior) == normalize_behavior(oracle_behavior)

    oracle_test = run_oracle_focused_test!(oracle_repo, evidence_dir)
    negative_api = run_negative_api_control!(evidence_dir)
    negative_mix_test = run_negative_mix_test_control!(oracle_repo, evidence_dir)

    CanonicalJSON.write!(Path.join(evidence_dir, "legacy_hashes.json"), %{
      "schema" => "rmxos_oracle.migration.legacy_hashes.v1",
      "legacy_repo" => legacy_repo,
      "legacy_ref" => legacy_ref,
      "dereferenced_commit" => legacy_commit,
      "files" => legacy_hashes
    })

    CanonicalJSON.write!(Path.join(evidence_dir, "oracle_hashes.json"), %{
      "schema" => "rmxos_oracle.migration.oracle_hashes.v1",
      "oracle_repo" => oracle_repo,
      "oracle_commit" => oracle_commit,
      "files" => oracle_hashes
    })

    result =
      if behavior_passed and oracle_test["exit_status"] == 0 and negative_api["passed"] and
           negative_mix_test["passed"] do
        "parity_passed"
      else
        "parity_failed"
      end

    parity = %{
      "schema" => "rmxos_oracle.migration.parity.raw_evidence.v1",
      "slice_id" => @slice_id,
      "result" => result,
      "comparison_axis" => "legacy_vs_oracle",
      "observation_basis" => "L1_host_semantic_probe",
      "normalization_rule" => %{
        "id" => "phase08.source_transform.behavior_outputs.v1",
        "description" =>
          "Compare generated output and normalized reports for shared source-transform input cases."
      },
      "legacy" => %{
        "repo" => legacy_repo,
        "ref" => legacy_ref,
        "dereferenced_commit" => legacy_commit,
        "expected_dereferenced_commit" => @expected_legacy_commit,
        "file_hashes" => legacy_hashes
      },
      "oracle" => %{
        "repo" => oracle_repo,
        "commit" => oracle_commit,
        "file_hashes" => oracle_hashes
      },
      "behavior_comparison" => %{
        "passed" => behavior_passed,
        "legacy_behavior_path" => "legacy_behavior.json",
        "oracle_behavior_path" => "oracle_behavior.json"
      },
      "negative_controls" => %{
        "direct_api" => negative_api,
        "mix_test_runner" => negative_mix_test
      },
      "evidence_files" => evidence_files(evidence_dir),
      "limitations" => [
        "No marker_manifest migrated status is emitted.",
        "No committed parity record is written by this first implementation.",
        "Legacy behavior is executed from materialized oracle-parity-a30ef3f^{commit} bytes, not from the mutable source working tree."
      ]
    }

    CanonicalJSON.write!(Path.join(evidence_dir, "parity.json"), parity)

    %{
      "status" => result,
      "parity_passed" => result == "parity_passed",
      "evidence_dir" => evidence_dir,
      "legacy_commit" => legacy_commit,
      "oracle_commit" => oracle_commit,
      "behavior_passed" => behavior_passed,
      "negative_api_passed" => negative_api["passed"],
      "negative_mix_test_passed" => negative_mix_test["passed"]
    }
  end

  def slice_id, do: @slice_id

  defp resolve_legacy_commit!(legacy_repo, legacy_ref) do
    commit = git!(legacy_repo, ["rev-parse", "--short", "#{legacy_ref}^{commit}"])

    unless commit == @expected_legacy_commit do
      raise "legacy ref #{legacy_ref}^{commit} resolved to #{commit}, expected #{@expected_legacy_commit}"
    end

    commit
  end

  defp hash_legacy_files!(legacy_repo, legacy_commit) do
    Enum.map(@legacy_files, fn path ->
      bytes = git_bytes!(legacy_repo, ["show", "#{legacy_commit}:#{path}"])
      hash_entry(path, bytes)
    end)
  end

  defp hash_oracle_files!(oracle_repo) do
    Enum.map(@oracle_files, fn path ->
      bytes = File.read!(Path.join(oracle_repo, path))
      hash_entry(path, bytes)
    end)
  end

  defp materialize_legacy_source!(legacy_repo, legacy_commit, evidence_dir) do
    bytes =
      git_bytes!(legacy_repo, [
        "show",
        "#{legacy_commit}:scripts/launchd/phase08_source_transform.exs"
      ])

    path = Path.join([evidence_dir, "legacy_materialized", "phase08_source_transform.exs"])
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, bytes)
    path
  end

  defp run_behavior_process!(kind, source_path, output_path) do
    code = behavior_code(source_path, Atom.to_string(kind))

    case System.cmd("elixir", ["-e", code], stderr_to_stdout: true) do
      {out, 0} ->
        data = CanonicalJSON.decode!(out)
        CanonicalJSON.write!(output_path, data)
        data

      {out, status} ->
        log_path = Path.rootname(output_path) <> ".log"
        File.write!(log_path, out)
        raise "#{kind} behavior process failed with exit #{status}; see #{log_path}"
    end
  end

  defp behavior_code(source_path, behavior_kind) do
    cases = inspect(behavior_cases(), limit: :infinity, printable_limit: :infinity)
    source_path = inspect(source_path)
    behavior_kind = inspect(behavior_kind)

    """
    Code.require_file(#{source_path})
    cases = #{cases}

    normalize_report = fn report ->
      report
      |> Enum.map(fn {key, value} ->
        value =
          case value do
            value when is_atom(value) -> Atom.to_string(value)
            value -> value
          end

        {Atom.to_string(key), value}
      end)
      |> Map.new()
    end

    build_transform = fn transform ->
      id = String.to_atom(transform["id"])

      opts =
        transform
        |> Map.take(["anchor", "context", "context_before", "context_after", "insert"])
        |> Enum.reject(fn {_key, value} -> is_nil(value) end)
        |> Enum.map(fn {key, value} ->
          value =
            if key == "context" and value == "none" do
              :none
            else
              value
            end

          {String.to_atom(key), value}
        end)

      case transform["kind"] do
        "insert_before" ->
          Phase08.Transform.insert_before(id, opts)

        "insert_after" ->
          Phase08.Transform.insert_after(id, opts)

        "legacy_map" ->
          %{
            id: id,
            anchor: transform["anchor"],
            position: String.to_atom(transform["position"]),
            insert: transform["insert"]
          }
      end
    end

    results =
      Enum.map(cases, fn test_case ->
        transforms = Enum.map(test_case["transforms"], build_transform)
        {generated, reports} = Phase08.SourceTransform.apply_transforms(test_case["source"], transforms)

        %{
          "case_id" => test_case["case_id"],
          "generated" => generated,
          "reports" => Enum.map(reports, normalize_report)
        }
      end)

    IO.write(
      JSON.encode!(%{
        "schema" => "rmxos_oracle.migration.phase08_source_transform.behavior.v1",
        "kind" => #{behavior_kind},
        "cases" => results
      })
    )
    """
  end

  defp behavior_cases do
    [
      %{
        "case_id" => "insert_before_with_context",
        "source" => "before\nanchor\nsince\n",
        "transforms" => [
          %{
            "kind" => "insert_before",
            "id" => "unit_before",
            "anchor" => "anchor\n",
            "context_before" => "before\n",
            "context_after" => "since\n",
            "insert" => "inserted\n"
          }
        ]
      },
      %{
        "case_id" => "insert_after_no_context",
        "source" => "before\nanchor\nsince\n",
        "transforms" => [
          %{
            "kind" => "insert_after",
            "id" => "unit_after",
            "anchor" => "anchor\n",
            "context" => "none",
            "insert" => "inserted\n"
          }
        ]
      },
      %{
        "case_id" => "legacy_map_transform",
        "source" => "a\nb\n",
        "transforms" => [
          %{
            "kind" => "legacy_map",
            "id" => "legacy_map",
            "anchor" => "a\n",
            "position" => "after",
            "insert" => "x\n"
          }
        ]
      },
      %{
        "case_id" => "multiple_transforms",
        "source" => "start\none\ntwo\nend\n",
        "transforms" => [
          %{
            "kind" => "insert_after",
            "id" => "after_one",
            "anchor" => "one\n",
            "context_before" => "start\n",
            "context_after" => "two\n",
            "insert" => "one-point-five\n"
          },
          %{
            "kind" => "insert_before",
            "id" => "before_end",
            "anchor" => "end\n",
            "context_before" => "two\n",
            "insert" => "almost-end\n"
          }
        ]
      }
    ]
  end

  defp normalize_behavior(data) do
    data
    |> Map.fetch!("cases")
    |> Enum.sort_by(& &1["case_id"])
  end

  defp run_oracle_focused_test!(oracle_repo, evidence_dir) do
    log_path = Path.join(evidence_dir, "oracle_test_output.log")

    {out, status} =
      System.cmd("mix", ["test", "test/phase08/source_transform_test.exs"],
        cd: oracle_repo,
        stderr_to_stdout: true
      )

    File.write!(log_path, out)

    %{
      "exit_status" => status,
      "passed" => status == 0,
      "log_path" => Path.basename(log_path),
      "sha256" => sha256(out)
    }
  end

  defp run_negative_api_control!(evidence_dir) do
    log_path = Path.join(evidence_dir, "negative_api.log")

    result =
      try do
        transform =
          Phase08.Transform.insert_after(:negative_missing_context,
            anchor: "anchor\n",
            context_before: "expected-before\n",
            insert: "x"
          )

        Phase08.SourceTransform.apply_transforms("actual-before\nanchor\n", [transform])
        {"unexpected_success", "negative API control unexpectedly succeeded"}
      rescue
        exception in ArgumentError ->
          {"expected_failure", Exception.message(exception)}
      end

    {status, message} = result
    log = "status=#{status}\nmessage=#{message}\n"
    File.write!(log_path, log)

    %{
      "control" => "direct_api_missing_context",
      "status" => status,
      "passed" => status == "expected_failure",
      "log_path" => Path.basename(log_path),
      "sha256" => sha256(log)
    }
  end

  defp run_negative_mix_test_control!(oracle_repo, evidence_dir) do
    test_path = Path.join(evidence_dir, "negative_source_transform_failure_test.exs")
    log_path = Path.join(evidence_dir, "negative_mix_test.log")

    File.write!(test_path, negative_mix_test_source())

    {out, status} =
      System.cmd("mix", ["test", test_path],
        cd: oracle_repo,
        stderr_to_stdout: true
      )

    File.write!(log_path, out)

    %{
      "control" => "mix_test_intentional_wrong_output",
      "exit_status" => status,
      "passed" => status != 0,
      "test_path" => Path.basename(test_path),
      "log_path" => Path.basename(log_path),
      "sha256" => sha256(out)
    }
  end

  defp negative_mix_test_source do
    """
    defmodule RmxOSOracleNegativeSourceTransformFailureTest do
      use ExUnit.Case, async: true

      test "intentional wrong source transform expectation" do
        transform =
          Phase08.Transform.insert_after(:negative_runner,
            anchor: "anchor\\n",
            context: :none,
            insert: "inserted\\n"
          )

        {generated, _reports} =
          Phase08.SourceTransform.apply_transforms("before\\nanchor\\nafter\\n", [transform])

        assert generated == "this intentionally cannot match\\n"
      end
    end
    """
  end

  defp evidence_files(evidence_dir) do
    evidence_dir
    |> Path.join("**/*")
    |> Path.wildcard()
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&Path.relative_to(&1, evidence_dir))
    |> Kernel.++(["parity.json"])
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp default_evidence_dir(out_root) do
    timestamp =
      DateTime.utc_now()
      |> DateTime.to_iso8601(:basic)
      |> String.replace("Z", "Z")

    Path.join(out_root, "#{timestamp}-phase08-source-transform")
  end

  defp hash_entry(path, bytes) do
    %{
      "path" => path,
      "sha256" => sha256(bytes),
      "size" => byte_size(bytes)
    }
  end

  defp git!(repo, args) do
    repo
    |> git_bytes!(args)
    |> String.trim()
  end

  defp git_bytes!(repo, args) do
    case System.cmd("git", ["-C", repo | args], stderr_to_stdout: true) do
      {out, 0} ->
        out

      {out, status} ->
        raise "git -C #{repo} #{Enum.join(args, " ")} failed with #{status}: #{out}"
    end
  end

  defp sha256(bytes), do: bytes |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
end
