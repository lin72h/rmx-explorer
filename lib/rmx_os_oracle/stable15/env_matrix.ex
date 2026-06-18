defmodule RmxOSOracle.Stable15.EnvMatrix do
  @moduledoc """
  Post-activation stable/15 env-check matrix.

  This is host-only validation. It does not fetch sources, build kernels, stage
  guests, run guests, or write evidence under `priv/runs/`.
  """

  alias RmxOSOracle.Env

  @workspace_root "/Users/me/wip-mach"
  @stable15_src "/Users/me/wip-mach/wip-gpt/wip-rmxos"
  @stable15_objdir "/Users/me/wip-mach/build/wip-rmxos-alpha-obj"
  @releng_src "/Users/me/wip-mach/wip-gpt/wip-rmxos"
  @releng_objdir "/Users/me/wip-mach/build/releng151-mach-obj"
  @releng_rc1_objdir "/Users/me/wip-mach/build/releng151-rc1-mach-obj"
  @all_lanes %{
    "current-tree" => "NXPLATFORM_KERNEL_OBJDIRPREFIX_CURRENT_TREE",
    "launchd" => "NXPLATFORM_KERNEL_OBJDIRPREFIX_LAUNCHD",
    "dispatch" => "NXPLATFORM_KERNEL_OBJDIRPREFIX_DISPATCH",
    "libthr" => "NXPLATFORM_KERNEL_OBJDIRPREFIX_LIBTHR"
  }

  @nx_env_keys ~w(
    NXPLATFORM_BASE_PROFILE
    NXPLATFORM_WORKSPACE_ROOT
    NXPLATFORM_FREEBSD_SRC
    NXPLATFORM_KERNEL_OBJDIRPREFIX_CURRENT_TREE
    NXPLATFORM_KERNEL_OBJDIRPREFIX_LAUNCHD
    NXPLATFORM_KERNEL_OBJDIRPREFIX_DISPATCH
    NXPLATFORM_KERNEL_OBJDIRPREFIX_LIBTHR
  )

  def run(opts \\ []) do
    tmp_root =
      Keyword.get_lazy(opts, :tmp_root, fn ->
        Path.join(
          System.tmp_dir!(),
          "rmxos-oracle-stable15-matrix-#{System.unique_integer([:positive])}"
        )
      end)

    File.rm_rf!(tmp_root)
    File.mkdir_p!(tmp_root)

    try do
      cases()
      |> Enum.map(&run_case(&1, tmp_root))
      |> report()
    after
      File.rm_rf!(tmp_root)
    end
  end

  defp cases do
    default_lane_cases =
      Enum.map(@all_lanes, fn {lane, lane_key} ->
        %{
          id: "default_stable15_active_#{lane}",
          lane: lane,
          expect: "pass",
          env:
            stable_env(%{
              lane_key => @stable15_objdir
            }),
          required: %{
            "accepted_source_profile" => "stable15-active",
            "source_pin_id" => "stable15-active",
            "freebsd_src" => @stable15_src,
            "expected_freebsd_src_commit" => "a0c2a8fb822e",
            "kernel_objdirprefix" => @stable15_objdir
          }
        }
      end)

    default_lane_cases ++
      [
        %{
          id: "explicit_stable15_active",
          lane: "launchd",
          expect: "pass",
          env: stable_env(%{"NXPLATFORM_BASE_PROFILE" => "stable15-active"}),
          required: stable_required("stable15-active")
        },
        %{
          id: "official_stable15_candidate_alias",
          lane: "launchd",
          expect: "pass",
          env: stable_env(%{"NXPLATFORM_BASE_PROFILE" => "official-stable15-candidate"}),
          required: stable_required("official-stable15-candidate")
        },
        %{
          id: "explicit_releng151_current",
          lane: "launchd",
          expect: "pass",
          env:
            base_env(%{
              "NXPLATFORM_BASE_PROFILE" => "releng151-current",
              "NXPLATFORM_FREEBSD_SRC" => @releng_src,
              "NXPLATFORM_KERNEL_OBJDIRPREFIX_LAUNCHD" => @releng_objdir
            }),
          required: %{
            "accepted_source_profile" => "releng151-current",
            "source_pin_id" => "releng151-current",
            "freebsd_src" => @releng_src,
            "kernel_objdirprefix" => @releng_objdir
          }
        },
        fail_case(
          "default_profile_releng151_objdir",
          stable_env(%{"NXPLATFORM_KERNEL_OBJDIRPREFIX_LAUNCHD" => @releng_objdir}),
          "NXPLATFORM_KERNEL_OBJDIRPREFIX for stable15-active"
        ),
        fail_case(
          "default_profile_releng151_rc1_objdir",
          stable_env(%{"NXPLATFORM_KERNEL_OBJDIRPREFIX_LAUNCHD" => @releng_rc1_objdir}),
          "NXPLATFORM_KERNEL_OBJDIRPREFIX for stable15-active"
        ),
        fail_case(
          "default_profile_usrobj",
          stable_env(%{"NXPLATFORM_KERNEL_OBJDIRPREFIX_LAUNCHD" => "/usr/obj"}),
          "NXPLATFORM_KERNEL_OBJDIRPREFIX for stable15-active"
        ),
        fail_case(
          "stable15_active_workspace_source",
          base_env(%{
            "NXPLATFORM_BASE_PROFILE" => "stable15-active",
            "NXPLATFORM_FREEBSD_SRC" => @workspace_root,
            "NXPLATFORM_KERNEL_OBJDIRPREFIX_LAUNCHD" => @stable15_objdir
          }),
          "NXPLATFORM_FREEBSD_SRC must match accepted source pin"
        ),
        fail_case(
          "stable15_active_releng_objdir",
          stable_env(%{
            "NXPLATFORM_BASE_PROFILE" => "stable15-active",
            "NXPLATFORM_KERNEL_OBJDIRPREFIX_LAUNCHD" => @releng_objdir
          }),
          "NXPLATFORM_KERNEL_OBJDIRPREFIX for stable15-active"
        ),
        fail_case(
          "candidate_alias_releng_objdir",
          stable_env(%{
            "NXPLATFORM_BASE_PROFILE" => "official-stable15-candidate",
            "NXPLATFORM_KERNEL_OBJDIRPREFIX_LAUNCHD" => @releng_objdir
          }),
          "NXPLATFORM_KERNEL_OBJDIRPREFIX for official-stable15-candidate"
        ),
        fail_case(
          "unknown_profile",
          stable_env(%{"NXPLATFORM_BASE_PROFILE" => "stable15-surprise"}),
          "unknown NXPLATFORM_BASE_PROFILE"
        )
      ]
  end

  defp run_case(case_def, tmp_root) do
    with_clean_nx_env(fn ->
      env_path = write_env!(tmp_root, case_def.id, case_def.env)
      env_report = Env.check(case_def.lane, env_path: env_path)
      actual = env_report["status"]

      passed? =
        actual == case_def.expect and
          required_fields_match?(env_report, Map.get(case_def, :required, %{})) and
          expected_error_present?(env_report, Map.get(case_def, :expected_error))

      %{
        "id" => case_def.id,
        "lane" => case_def.lane,
        "expected_status" => case_def.expect,
        "actual_status" => actual,
        "passed" => passed?,
        "required" => Map.get(case_def, :required, %{}),
        "expected_error" => Map.get(case_def, :expected_error),
        "errors" => env_report["errors"],
        "observed" => observed(env_report)
      }
    end)
  end

  defp report(case_reports) do
    %{
      "schema" => "rmxos_oracle.stable15.env_matrix.v1",
      "status" => if(Enum.all?(case_reports, & &1["passed"]), do: "pass", else: "fail"),
      "case_count" => length(case_reports),
      "cases" => case_reports,
      "guest_run_performed" => false,
      "certification_claim" => false
    }
  end

  defp observed(env_report) do
    Map.take(
      env_report,
      ~w(accepted_source_profile source_pin_id freebsd_src freebsd_src_commit expected_freebsd_src_commit kernel_objdirprefix)
    )
  end

  defp stable_required(profile) do
    %{
      "accepted_source_profile" => profile,
      "source_pin_id" => profile,
      "freebsd_src" => @stable15_src,
      "expected_freebsd_src_commit" => "a0c2a8fb822e",
      "kernel_objdirprefix" => @stable15_objdir
    }
  end

  defp stable_env(extra) do
    base_env(
      Map.merge(
        %{
          "NXPLATFORM_FREEBSD_SRC" => @stable15_src,
          "NXPLATFORM_KERNEL_OBJDIRPREFIX_LAUNCHD" => @stable15_objdir
        },
        extra
      )
    )
  end

  defp base_env(extra) do
    Map.merge(%{"NXPLATFORM_WORKSPACE_ROOT" => @workspace_root}, extra)
  end

  defp fail_case(id, env, expected_error) do
    %{
      id: id,
      lane: "launchd",
      expect: "fail",
      env: env,
      expected_error: expected_error
    }
  end

  defp required_fields_match?(env_report, required) do
    Enum.all?(required, fn {key, expected} -> env_report[key] == expected end)
  end

  defp expected_error_present?(_env_report, nil), do: true

  defp expected_error_present?(env_report, expected_error) do
    Enum.any?(env_report["errors"], &String.contains?(&1, expected_error))
  end

  defp write_env!(tmp_root, id, env) do
    path = Path.join(tmp_root, "#{id}.env")

    body =
      env
      |> Enum.sort()
      |> Enum.map_join("\n", fn {key, value} -> "#{key}=#{value}" end)

    File.write!(path, body <> "\n")
    path
  end

  defp with_clean_nx_env(fun) do
    saved = Map.new(@nx_env_keys, &{&1, System.get_env(&1)})
    Enum.each(@nx_env_keys, &System.delete_env/1)

    try do
      fun.()
    after
      Enum.each(saved, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)
    end
  end
end
