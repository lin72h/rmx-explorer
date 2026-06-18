defmodule RmxOSOracleEnvTest do
  use ExUnit.Case

  alias RmxOSOracle.Env

  @workspace_root "/Users/me/wip-mach"
  @candidate_src "/Users/me/wip-mach/wip-gpt/wip-rmxos"
  @releng_src "/Users/me/wip-mach/wip-gpt/wip-rmxos"
  @invalid_src "/Users/me/wip-mach"
  @releng_objdir "/Users/me/wip-mach/build/releng151-mach-obj"
  @releng_rc1_objdir "/Users/me/wip-mach/build/releng151-rc1-mach-obj"
  @candidate_objdir "/Users/me/wip-mach/build/wip-rmxos-alpha-obj"
  @candidate_commit "a0c2a8fb822e"
  @lane_env_keys %{
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

  test "absent profile defaults to stable15-active source pin on every lane" do
    for {lane, lane_key} <- @lane_env_keys do
      report =
        check_with_env(
          %{
            "NXPLATFORM_WORKSPACE_ROOT" => @workspace_root,
            "NXPLATFORM_FREEBSD_SRC" => @candidate_src,
            lane_key => @candidate_objdir
          },
          lane
        )

      assert report["status"] == "pass"
      assert report["accepted_source_profile"] == "stable15-active"
      assert report["source_pin_id"] == "stable15-active"
      assert report["freebsd_src"] == @candidate_src
      assert report["freebsd_src_commit"] == @candidate_commit
      assert report["expected_freebsd_src_commit"] == @candidate_commit
      assert report["kernel_objdirprefix"] == @candidate_objdir
    end
  end

  test "explicit releng151-current source pin passes" do
    report =
      check_with_env(%{
        "NXPLATFORM_BASE_PROFILE" => " releng151-current ",
        "NXPLATFORM_WORKSPACE_ROOT" => @workspace_root,
        "NXPLATFORM_FREEBSD_SRC" => @releng_src,
        "NXPLATFORM_KERNEL_OBJDIRPREFIX_LAUNCHD" => @releng_objdir
      })

    assert report["status"] == "pass"
    assert report["accepted_source_profile"] == "releng151-current"
    assert report["source_pin_id"] == "releng151-current"
    assert report["freebsd_src"] == @releng_src
    assert report["expected_freebsd_src_commit"] == nil
  end

  test "explicit stable15-active source pin requires exact source, commit, and objdir" do
    report =
      check_with_env(%{
        "NXPLATFORM_BASE_PROFILE" => " stable15-active ",
        "NXPLATFORM_WORKSPACE_ROOT" => @workspace_root,
        "NXPLATFORM_FREEBSD_SRC" => @candidate_src,
        "NXPLATFORM_KERNEL_OBJDIRPREFIX_LAUNCHD" => @candidate_objdir
      })

    assert_stable15_report(report, "stable15-active")
  end

  test "official stable15 candidate alias shares stable15-active source, commit, and objdir" do
    report =
      check_with_env(%{
        "NXPLATFORM_BASE_PROFILE" => "official-stable15-candidate",
        "NXPLATFORM_WORKSPACE_ROOT" => @workspace_root,
        "NXPLATFORM_FREEBSD_SRC" => @candidate_src,
        "NXPLATFORM_KERNEL_OBJDIRPREFIX_LAUNCHD" => @candidate_objdir
      })

    assert_stable15_report(report, "official-stable15-candidate")
  end

  test "default profile with noncanonical source fails closed" do
    report =
      check_with_env(%{
        "NXPLATFORM_WORKSPACE_ROOT" => @workspace_root,
        "NXPLATFORM_FREEBSD_SRC" => @invalid_src,
        "NXPLATFORM_KERNEL_OBJDIRPREFIX_LAUNCHD" => @candidate_objdir
      })

    assert_failed_with(report, "NXPLATFORM_FREEBSD_SRC must match accepted source pin")
  end

  test "unknown source profile fails explicitly" do
    report =
      check_with_env(%{
        "NXPLATFORM_BASE_PROFILE" => "stable15-surprise",
        "NXPLATFORM_WORKSPACE_ROOT" => @workspace_root,
        "NXPLATFORM_FREEBSD_SRC" => @releng_src,
        "NXPLATFORM_KERNEL_OBJDIRPREFIX_LAUNCHD" => @releng_objdir
      })

    assert_failed_with(report, "unknown NXPLATFORM_BASE_PROFILE: stable15-surprise")
  end

  test "unknown absolute source path fails active source pin validation" do
    report =
      check_with_env(%{
        "NXPLATFORM_WORKSPACE_ROOT" => @workspace_root,
        "NXPLATFORM_FREEBSD_SRC" => @workspace_root,
        "NXPLATFORM_KERNEL_OBJDIRPREFIX_LAUNCHD" => @releng_objdir
      })

    assert_failed_with(report, "NXPLATFORM_FREEBSD_SRC must match accepted source pin")
  end

  test "default stable15-active rejects releng and default objdir prefixes" do
    for objdir <- [@releng_objdir, @releng_rc1_objdir, "/usr/obj"] do
      report =
        check_with_env(%{
          "NXPLATFORM_WORKSPACE_ROOT" => @workspace_root,
          "NXPLATFORM_FREEBSD_SRC" => @candidate_src,
          "NXPLATFORM_KERNEL_OBJDIRPREFIX_LAUNCHD" => objdir
        })

      assert_failed_with(
        report,
        "NXPLATFORM_KERNEL_OBJDIRPREFIX for stable15-active must be #{@candidate_objdir}"
      )
    end
  end

  test "stable15-active rejects releng and default objdir prefixes" do
    for objdir <- [@releng_objdir, @releng_rc1_objdir, "/usr/obj"] do
      report =
        check_with_env(%{
          "NXPLATFORM_BASE_PROFILE" => "stable15-active",
          "NXPLATFORM_WORKSPACE_ROOT" => @workspace_root,
          "NXPLATFORM_FREEBSD_SRC" => @candidate_src,
          "NXPLATFORM_KERNEL_OBJDIRPREFIX_LAUNCHD" => objdir
        })

      assert_failed_with(
        report,
        "NXPLATFORM_KERNEL_OBJDIRPREFIX for stable15-active must be #{@candidate_objdir}"
      )
    end
  end

  test "official stable15 candidate alias rejects releng and default objdir prefixes" do
    for objdir <- [@releng_objdir, @releng_rc1_objdir, "/usr/obj"] do
      report =
        check_with_env(%{
          "NXPLATFORM_BASE_PROFILE" => "official-stable15-candidate",
          "NXPLATFORM_WORKSPACE_ROOT" => @workspace_root,
          "NXPLATFORM_FREEBSD_SRC" => @candidate_src,
          "NXPLATFORM_KERNEL_OBJDIRPREFIX_LAUNCHD" => objdir
        })

      assert_failed_with(
        report,
        "NXPLATFORM_KERNEL_OBJDIRPREFIX for official-stable15-candidate must be #{@candidate_objdir}"
      )
    end
  end

  test "stable15-active rejects noncanonical source" do
    report =
      check_with_env(%{
        "NXPLATFORM_BASE_PROFILE" => "stable15-active",
        "NXPLATFORM_WORKSPACE_ROOT" => @workspace_root,
        "NXPLATFORM_FREEBSD_SRC" => @invalid_src,
        "NXPLATFORM_KERNEL_OBJDIRPREFIX_LAUNCHD" => @candidate_objdir
      })

    assert_failed_with(report, "NXPLATFORM_FREEBSD_SRC must match accepted source pin")
  end

  defp check_with_env(env, lane \\ "launchd") do
    with_clean_nx_env(fn ->
      env_path = write_env_file!(env)
      Env.check(lane, env_path: env_path)
    end)
  end

  defp assert_stable15_report(report, expected_profile) do
    assert report["status"] == "pass"
    assert report["accepted_source_profile"] == expected_profile
    assert report["source_pin_id"] == expected_profile
    assert report["freebsd_src"] == @candidate_src
    assert report["freebsd_src_commit"] == @candidate_commit
    assert report["expected_freebsd_src_commit"] == @candidate_commit
    assert report["kernel_objdirprefix"] == @candidate_objdir
  end

  defp write_env_file!(env) do
    dir = Path.join(System.tmp_dir!(), "rmxos-oracle-env-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    path = Path.join(dir, "env.local")

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

  defp assert_failed_with(report, expected) do
    assert report["status"] == "fail"
    assert Enum.any?(report["errors"], &String.contains?(&1, expected))
  end
end
