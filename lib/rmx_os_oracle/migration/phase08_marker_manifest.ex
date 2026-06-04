defmodule RmxOSOracle.Migration.Phase08MarkerManifest do
  @moduledoc """
  Parity runner for the `Phase08.MarkerManifest` host-only migration slice.

  The runner executes legacy code from materialized `oracle-parity-a30ef3f`
  bytes in a separate BEAM process, executes the oracle module separately, and
  compares normalized behavior output. It writes raw ignored evidence only.
  """

  alias RmxOSOracle.CanonicalJSON

  @slice_id "phase08.marker_manifest"
  @expected_legacy_commit "a30ef3f"
  @default_legacy_repo "/Users/me/wip-mach/wip-gpt"
  @default_legacy_ref "oracle-parity-a30ef3f"
  @default_oracle_repo "/Users/me/wip-mach/wip-gpt-oracle"
  @legacy_files [
    "scripts/launchd/phase08_marker_manifest.exs"
  ]
  @oracle_files [
    "lib/phase08/marker_manifest.ex",
    "test/phase08/marker_manifest_test.exs"
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
        Path.join(oracle_repo, "lib/phase08/marker_manifest.ex"),
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
        "id" => "phase08.marker_manifest.behavior_outputs.v1",
        "description" =>
          "Compare normalized marker inventory, lookup, C-emission, log-validation, and negative behavior cases."
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
      "oracle_focused_test" => oracle_test,
      "negative_controls" => %{
        "direct_api" => negative_api,
        "mix_test_runner" => negative_mix_test
      },
      "evidence_files" => evidence_files(evidence_dir),
      "limitations" => [
        "No committed parity record is written.",
        "No marker_manifest migrated ledger entry is emitted.",
        "No guest behavior or certification claim is made.",
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
        "#{legacy_commit}:scripts/launchd/phase08_marker_manifest.exs"
      ])

    path = Path.join([evidence_dir, "legacy_materialized", "phase08_marker_manifest.exs"])
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

        raise "#{kind} marker manifest behavior process failed with exit #{status}; see #{log_path}"
    end
  end

  defp behavior_code(source_path, behavior_kind) do
    source_path = inspect(source_path)
    behavior_kind = inspect(behavior_kind)

    """
    Code.require_file(#{source_path})

    defmodule RmxOSOracleMarkerManifestBehavior do
      alias Phase08.MarkerManifest

      @lookup_ids [
        :d23_inert_reload_accepted,
        :d22_running_deferred_enter_count,
        :d22_running_donor_sent_signal
      ]
      @arm_cases [
        {:d22, :running},
        {:d22, :keepalive},
        {:d23, :inert},
        {:d23, :keepalive}
      ]

      def run(kind) do
        markers = MarkerManifest.markers()

        %{
          "schema" => "rmxos_oracle.migration.phase08_marker_manifest.behavior.v1",
          "kind" => kind,
          "inventory" => inventory(markers),
          "markers" => Enum.map(markers, &normalize/1),
          "for_gate" => %{
            "d22" => marker_ids(MarkerManifest.for_gate(:d22)),
            "d23" => marker_ids(MarkerManifest.for_gate(:d23))
          },
          "for_arm" => for_arm_results(),
          "lookups" => lookup_results(),
          "emit_c" => emit_c_results(),
          "escaping" => escaping_results(),
          "marker_values" => marker_values_result(),
          "validate_log_positive" => validate_log_positive_results(),
          "negative_behavior" => negative_behavior_results()
        }
      end

      defp inventory(markers) do
        ids = Enum.map(markers, &Atom.to_string(&1.id))
        keys = Enum.map(markers, & &1.key)

        %{
          "count" => length(markers),
          "sorted_ids" => Enum.sort(ids),
          "sorted_keys" => Enum.sort(keys),
          "ids_unique" => ids_unique?(ids),
          "keys_unique" => ids_unique?(keys),
          "duplicate_ids" => duplicates(ids),
          "duplicate_keys" => duplicates(keys)
        }
      end

      defp ids_unique?(values), do: length(values) == length(Enum.uniq(values))

      defp duplicates(values) do
        values
        |> Enum.frequencies()
        |> Enum.filter(fn {_value, count} -> count > 1 end)
        |> Enum.map(&elem(&1, 0))
        |> Enum.sort()
      end

      defp for_arm_results do
        Map.new(@arm_cases, fn {gate, arm} ->
          {"\#{gate}:\#{arm}", marker_ids(MarkerManifest.for_arm(gate, arm))}
        end)
      end

      defp lookup_results do
        Map.new(@lookup_ids, fn id ->
          {Atom.to_string(id),
           %{
             "key" => MarkerManifest.key!(id),
             "c_key" => MarkerManifest.c_key!(id),
             "spec" => normalize(MarkerManifest.spec!(id))
           }}
        end)
      end

      defp emit_c_results do
        %{
          "emit_c_3" =>
            MarkerManifest.emit_c(:d23_inert_reload_accepted, "accepted ? 1 : 0", "%d"),
          "emit_c_4_opts" =>
            MarkerManifest.emit_c(:d23_inert_reload_accepted, "1", fmt: "%d", value: "1"),
          "static_must_equal" =>
            MarkerManifest.emit_c(:d23_inert_reload_accepted, "1", fmt: "%d", value: "1"),
          "static_must_include" =>
            MarkerManifest.emit_c(:d22_running_deferred_enter_count, "2",
              fmt: "%d",
              value: "2"
            ),
          "static_must_be_one_of" =>
            MarkerManifest.emit_c(:d22_running_donor_sent_signal, "SIGTERM",
              fmt: "%s",
              value: "SIGTERM"
            )
        }
      end

      defp escaping_results do
        %{
          "c_string_literal" =>
            MarkerManifest.c_string_literal("quote\\" slash\\\\ newline\\n tab\\t percent%")
        }
      end

      defp marker_values_result do
        key = MarkerManifest.key!(:d22_running_deferred_enter_count)
        log = "\#{key}=1\\n\#{key}=2\\nOTHER=ignored\\n"

        %{
          "key" => key,
          "values" => MarkerManifest.marker_values(log, key)
        }
      end

      defp validate_log_positive_results do
        Map.new([:d22, :d23], fn gate ->
          log = synthetic_log(gate)
          MarkerManifest.validate_log!(log, gate)

          {Atom.to_string(gate),
           %{
             "status" => "ok",
             "line_count" => log |> String.split("\\n", trim: true) |> length()
           }}
        end)
      end

      defp negative_behavior_results do
        %{
          "unknown_marker_id" =>
            capture(fn -> MarkerManifest.key!(:missing_marker) end),
          "nil_value_expression" =>
            capture(fn -> MarkerManifest.emit_c(:d23_inert_reload_accepted, nil, "%d") end),
          "empty_value_expression" =>
            capture(fn -> MarkerManifest.emit_c(:d23_inert_reload_accepted, "", "%d") end),
          "invalid_static_value" =>
            capture(fn ->
              MarkerManifest.emit_c(:d23_inert_reload_accepted, "0", fmt: "%d", value: "0")
            end),
          "missing_required_log_marker" =>
            capture(fn -> MarkerManifest.validate_log!(synthetic_log(:d23, %{}, [:d23_requested]), :d23) end),
          "wrong_marker_value" =>
            capture(fn ->
              MarkerManifest.validate_log!(
                synthetic_log(:d23, %{d23_requested: "0"}),
                :d23
              )
            end)
        }
      end

      defp capture(fun) do
        %{
          "status" => "unexpected_success",
          "value" => normalize(fun.())
        }
      rescue
        exception in ArgumentError ->
          %{
            "status" => "raised",
            "exception" => inspect(exception.__struct__),
            "message" => Exception.message(exception)
          }
      end

      defp synthetic_log(gate, overrides \\\\ %{}, skip_ids \\\\ []) do
        gate
        |> MarkerManifest.for_gate()
        |> Enum.reject(&(&1.id in skip_ids))
        |> Enum.map_join("", fn spec ->
          value = Map.get(overrides, spec.id, policy_value(spec.policy))
          "\#{spec.key}=\#{value}\\n"
        end)
      end

      defp policy_value({:must_equal, expected}), do: to_string(expected)
      defp policy_value({:must_include, expected}), do: to_string(expected)
      defp policy_value({:must_be_one_of, [expected | _rest]}), do: to_string(expected)

      defp marker_ids(markers) do
        markers
        |> Enum.map(&Atom.to_string(&1.id))
        |> Enum.sort()
      end

      defp normalize(value) when is_map(value) do
        value
        |> Enum.map(fn {key, nested} -> {to_string(key), normalize(nested)} end)
        |> Map.new()
      end

      defp normalize(value) when is_list(value), do: Enum.map(value, &normalize/1)

      defp normalize(value) when is_tuple(value) do
        value
        |> Tuple.to_list()
        |> Enum.map(&normalize/1)
      end

      defp normalize(value) when is_atom(value), do: Atom.to_string(value)
      defp normalize(value), do: value
    end

    IO.write(JSON.encode!(RmxOSOracleMarkerManifestBehavior.run(#{behavior_kind})))
    """
  end

  defp normalize_behavior(data), do: Map.drop(data, ["kind"])

  defp run_oracle_focused_test!(oracle_repo, evidence_dir) do
    log_path = Path.join(evidence_dir, "oracle_test_output.log")

    {out, status} =
      System.cmd("mix", ["test", "test/phase08/marker_manifest_test.exs"],
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
        Phase08.MarkerManifest.emit_c(:d23_inert_reload_accepted, "0", fmt: "%d", value: "0")
        {"unexpected_success", "negative API control unexpectedly succeeded"}
      rescue
        exception in ArgumentError ->
          message = Exception.message(exception)

          if String.contains?(message, "emit_c value") do
            {"expected_failure", message}
          else
            {"wrong_failure", message}
          end
      end

    {status, message} = result
    log = "status=#{status}\nmessage=#{message}\n"
    File.write!(log_path, log)

    %{
      "control" => "direct_api_invalid_static_marker_value",
      "status" => status,
      "passed" => status == "expected_failure",
      "log_path" => Path.basename(log_path),
      "sha256" => sha256(log)
    }
  end

  defp run_negative_mix_test_control!(oracle_repo, evidence_dir) do
    test_path = Path.join(evidence_dir, "negative_marker_manifest_failure_test.exs")
    log_path = Path.join(evidence_dir, "negative_mix_test.log")

    File.write!(test_path, negative_mix_test_source())

    {out, status} =
      System.cmd("mix", ["test", test_path],
        cd: oracle_repo,
        stderr_to_stdout: true
      )

    File.write!(log_path, out)

    %{
      "control" => "mix_test_intentional_wrong_marker_key",
      "exit_status" => status,
      "passed" => status != 0,
      "test_path" => Path.basename(test_path),
      "log_path" => Path.basename(log_path),
      "sha256" => sha256(out)
    }
  end

  defp negative_mix_test_source do
    """
    defmodule RmxOSOracleNegativeMarkerManifestFailureTest do
      use ExUnit.Case, async: true

      test "intentional wrong marker manifest expectation" do
        assert Phase08.MarkerManifest.key!(:d23_inert_reload_accepted) ==
                 "INTENTIONALLY_WRONG_MARKER_KEY"
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

    Path.join(out_root, "#{timestamp}-phase08-marker-manifest")
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
