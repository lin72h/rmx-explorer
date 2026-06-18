defmodule RmxOSOracle.Env do
  @moduledoc """
  Pure Elixir environment and lane path validation.

  Lane-specific objdir prefixes are explicit configuration inputs. The selected
  lane value is projected to `NXPLATFORM_KERNEL_OBJDIRPREFIX` for legacy verifier
  invocation; M1 does not run those legacy verifiers.
  """

  alias RmxOSOracle.Paths

  @default_env_local "priv/env/env.local"
  @releng151_current "releng151-current"
  @stable15_active "stable15-active"
  @official_stable15_candidate "official-stable15-candidate"
  @canonical_freebsd_src "/Users/me/wip-mach/wip-gpt/wip-rmxos"
  @stable15_src "/Users/me/wip-mach/wip-gpt/wip-rmxos"
  @stable15_commit "a0c2a8fb822e"
  @stable15_objdir "/Users/me/wip-mach/build/wip-rmxos-alpha-obj"
  @stable15_profiles [@stable15_active, @official_stable15_candidate]
  @lanes %{
    "current-tree" => "NXPLATFORM_KERNEL_OBJDIRPREFIX_CURRENT_TREE",
    "launchd" => "NXPLATFORM_KERNEL_OBJDIRPREFIX_LAUNCHD",
    "dispatch" => "NXPLATFORM_KERNEL_OBJDIRPREFIX_DISPATCH",
    "libthr" => "NXPLATFORM_KERNEL_OBJDIRPREFIX_LIBTHR"
  }

  def lanes, do: Map.keys(@lanes) |> Enum.sort()

  def check(lane, opts \\ []) do
    env_path = Keyword.get(opts, :env_path, @default_env_local)
    env = load(env_path)
    raw_base_profile = Map.get(env, "NXPLATFORM_BASE_PROFILE")
    {source_profile, profile_errors} = source_profile(raw_base_profile)
    workspace_root = Map.get(env, "NXPLATFORM_WORKSPACE_ROOT")
    freebsd_src = Map.get(env, "NXPLATFORM_FREEBSD_SRC")
    lane_key = Map.get(@lanes, lane)
    configured_prefix = if lane_key, do: Map.get(env, lane_key)

    resolved_prefix =
      if configured_prefix do
        Paths.expand_config_path(configured_prefix, env)
      end

    freebsd_src_commit = git_short_sha(freebsd_src)
    expected_freebsd_src_commit = expected_freebsd_src_commit(source_profile)

    errors =
      profile_errors
      |> require_lane(lane, lane_key)
      |> require_path("NXPLATFORM_WORKSPACE_ROOT", workspace_root)
      |> require_dir("NXPLATFORM_WORKSPACE_ROOT", workspace_root)
      |> require_path("NXPLATFORM_FREEBSD_SRC", freebsd_src)
      |> require_dir("NXPLATFORM_FREEBSD_SRC", freebsd_src)
      |> reject_symlink("NXPLATFORM_FREEBSD_SRC", freebsd_src)
      |> reject_oracle_source_default(freebsd_src)
      |> require_profile_freebsd_src(freebsd_src, source_profile)
      |> require_expected_freebsd_src_commit(
        freebsd_src_commit,
        expected_freebsd_src_commit,
        source_profile
      )
      |> require_configured_prefix(lane_key, configured_prefix)
      |> reject_unresolved_prefix(lane_key, configured_prefix, resolved_prefix)
      |> require_absolute_prefix(lane_key, resolved_prefix)
      |> require_existing_prefix(lane_key, resolved_prefix)
      |> require_profile_objdirprefix(resolved_prefix, source_profile)

    %{
      "schema" => "rmxos_oracle.env_check.v1",
      "status" => if(errors == [], do: "pass", else: "fail"),
      "lane" => lane,
      "configured_base_profile" => raw_base_profile,
      "accepted_source_profile" => source_profile,
      "source_pin_id" => source_profile,
      "workspace_root" => workspace_root,
      "freebsd_src" => freebsd_src,
      "freebsd_src_commit" => freebsd_src_commit,
      "expected_freebsd_src_commit" => expected_freebsd_src_commit,
      "freebsd_src_is_symlink" =>
        if(is_binary(freebsd_src), do: Paths.symlink?(freebsd_src), else: nil),
      "lane_objdir_env_key" => lane_key,
      "configured_lane_objdirprefix" => configured_prefix,
      "kernel_objdirprefix" => resolved_prefix,
      "kernel_objdirprefix_exists" =>
        if(is_binary(resolved_prefix), do: File.dir?(resolved_prefix), else: nil),
      "projected_env" => %{
        "NXPLATFORM_KERNEL_OBJDIRPREFIX" => resolved_prefix
      },
      "base_profile" => source_profile,
      "rmxos_source_commit" => freebsd_src_commit,
      "donor_roots" => donor_roots(env),
      "errors" => errors
    }
  end

  def load(env_path \\ @default_env_local) do
    env_path
    |> load_local()
    |> Map.merge(System.get_env())
  end

  defp load_local(env_path) do
    if File.regular?(env_path) do
      env_path
      |> File.read!()
      |> String.split("\n")
      |> Enum.reduce(%{}, fn line, acc ->
        line = line |> String.trim() |> String.replace_prefix("export ", "")

        cond do
          line == "" or String.starts_with?(line, "#") ->
            acc

          String.contains?(line, "=") ->
            [key, value] = String.split(line, "=", parts: 2)
            Map.put(acc, String.trim(key), strip_quotes(String.trim(value)))

          true ->
            acc
        end
      end)
    else
      %{}
    end
  end

  defp strip_quotes(value) do
    value
    |> String.trim_leading("\"")
    |> String.trim_trailing("\"")
    |> String.trim_leading("'")
    |> String.trim_trailing("'")
  end

  defp donor_roots(env) do
    env
    |> Map.take(
      ~w(NXPLATFORM_DONOR_MACH_TESTS_ROOT NXPLATFORM_DONOR_LIBMACH_TEST_ROOT NXPLATFORM_DONOR_XPC_TESTS_ROOT)
    )
    |> Enum.map(fn {key, path} ->
      {key,
       %{
         "path" => path,
         "exists" => File.exists?(path),
         "absolute" => Paths.absolute?(path),
         "symlink" => Paths.symlink?(path)
       }}
    end)
    |> Map.new()
  end

  defp require_lane(errors, _lane, lane_key) when is_binary(lane_key), do: errors
  defp require_lane(errors, lane, _lane_key), do: errors ++ ["unsupported lane: #{inspect(lane)}"]

  defp require_path(errors, key, path) do
    cond do
      not is_binary(path) or path == "" -> errors ++ ["missing #{key}"]
      not Paths.absolute?(path) -> errors ++ ["#{key} must be absolute: #{path}"]
      true -> errors
    end
  end

  defp require_dir(errors, key, path) do
    if is_binary(path) and Paths.absolute?(path) and not Paths.exists_dir?(path) do
      errors ++ ["#{key} does not exist: #{path}"]
    else
      errors
    end
  end

  defp reject_symlink(errors, key, path) do
    if is_binary(path) and Paths.symlink?(path),
      do: errors ++ ["#{key} must not be a symlink: #{path}"],
      else: errors
  end

  defp reject_oracle_source_default(errors, freebsd_src) do
    oracle_default = Path.join(Paths.oracle_root(), "wip-rmxos")

    if is_binary(freebsd_src) and Path.expand(freebsd_src) == Path.expand(oracle_default) do
      errors ++ ["NXPLATFORM_FREEBSD_SRC must not default to oracle-root/wip-rmxos"]
    else
      errors
    end
  end

  defp source_profile(nil), do: {@stable15_active, []}

  defp source_profile(value) when is_binary(value) do
    case String.trim(value) do
      "" -> {@stable15_active, []}
      @releng151_current -> {@releng151_current, []}
      @stable15_active -> {@stable15_active, []}
      @official_stable15_candidate -> {@official_stable15_candidate, []}
      other -> {nil, ["unknown NXPLATFORM_BASE_PROFILE: #{other}"]}
    end
  end

  defp source_profile(value),
    do: {nil, ["NXPLATFORM_BASE_PROFILE must be a string: #{inspect(value)}"]}

  defp expected_freebsd_src_commit(source_profile) when source_profile in @stable15_profiles,
    do: @stable15_commit

  defp expected_freebsd_src_commit(_source_profile), do: nil

  defp require_profile_freebsd_src(errors, freebsd_src, base_profile) do
    expected = profile_freebsd_src(base_profile)

    cond do
      not is_binary(expected) ->
        errors

      is_binary(freebsd_src) and Path.expand(freebsd_src) != expected ->
        errors ++
          [
            "NXPLATFORM_FREEBSD_SRC must match accepted source pin for #{base_profile || "default"}: #{expected}"
          ]

      true ->
        errors
    end
  end

  defp profile_freebsd_src(source_profile) when source_profile in @stable15_profiles,
    do: @stable15_src

  defp profile_freebsd_src(@releng151_current), do: @canonical_freebsd_src
  defp profile_freebsd_src(_source_profile), do: nil

  defp require_expected_freebsd_src_commit(
         errors,
         freebsd_src_commit,
         expected_freebsd_src_commit,
         source_profile
       ) do
    cond do
      not is_binary(expected_freebsd_src_commit) ->
        errors

      freebsd_src_commit == expected_freebsd_src_commit ->
        errors

      true ->
        errors ++
          [
            "NXPLATFORM_FREEBSD_SRC commit for #{source_profile} must be #{expected_freebsd_src_commit}, got #{freebsd_src_commit || "unknown"}"
          ]
    end
  end

  defp require_configured_prefix(errors, lane_key, configured_prefix) do
    if is_binary(lane_key) and (not is_binary(configured_prefix) or configured_prefix == "") do
      errors ++ ["missing explicit lane objdir prefix #{lane_key}"]
    else
      errors
    end
  end

  defp require_absolute_prefix(errors, lane_key, resolved_prefix) do
    if is_binary(lane_key) and is_binary(resolved_prefix) and not Paths.absolute?(resolved_prefix) do
      errors ++ ["#{lane_key} must resolve to an absolute path: #{resolved_prefix}"]
    else
      errors
    end
  end

  defp reject_unresolved_prefix(errors, lane_key, configured_prefix, resolved_prefix) do
    unresolved? =
      Enum.any?([configured_prefix, resolved_prefix], fn value ->
        is_binary(value) and Regex.match?(~r/\$\{[^}]+\}/, value)
      end)

    if is_binary(lane_key) and unresolved? do
      errors ++
        ["#{lane_key} contains unresolved placeholder after expansion: #{configured_prefix}"]
    else
      errors
    end
  end

  defp require_existing_prefix(errors, lane_key, resolved_prefix) do
    if is_binary(lane_key) and is_binary(resolved_prefix) and Paths.absolute?(resolved_prefix) and
         not File.dir?(resolved_prefix) do
      errors ++ ["#{lane_key} resolved objdir prefix does not exist: #{resolved_prefix}"]
    else
      errors
    end
  end

  defp require_profile_objdirprefix(errors, resolved_prefix, source_profile)
       when source_profile in @stable15_profiles do
    cond do
      not is_binary(resolved_prefix) ->
        errors

      Path.expand(resolved_prefix) == @stable15_objdir ->
        errors

      true ->
        errors ++
          [
            "NXPLATFORM_KERNEL_OBJDIRPREFIX for #{source_profile} must be #{@stable15_objdir}, got #{resolved_prefix}"
          ]
    end
  end

  defp require_profile_objdirprefix(errors, _resolved_prefix, _source_profile), do: errors

  defp git_short_sha(path) do
    cond do
      is_binary(path) and File.dir?(path) ->
        case System.cmd("git", ["-C", path, "rev-parse", "--short=12", "HEAD"],
               stderr_to_stdout: true
             ) do
          {out, 0} -> String.trim(out)
          _ -> nil
        end

      true ->
        nil
    end
  end
end
