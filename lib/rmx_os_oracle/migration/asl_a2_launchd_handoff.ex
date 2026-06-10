defmodule RmxOSOracle.Migration.AslA2LaunchdHandoff do
  @moduledoc false

  alias RmxOSOracle.Asl.A2.{ContractCheck, MarkerManifest}
  alias RmxOSOracle.{CanonicalJSON, Env}

  @slice_id "asl.a2.launchd_handoff"
  @schema "rmxos_oracle.asl_a2.raw_evidence.v1"
  @donor_root "/Users/me/wip-mach/nx/NextBSD"
  @donor_commit "8be0f2507b69906d068bed31ffc58cdfafadaef3"
  @source_repo "/Users/me/wip-mach/wip-gpt"
  @source_authorization_commit "cc2d081ab028c6bef902d1d1b0af9cdd91790334"
  @oracle_a2_design_commit "ee6c680abbf9365d06e8a7ff2e991583d724382b"
  @a1_authority_commit "ab92a5b9dfd2d9ecbd54002bae72db08a4a9c201"
  @defs_rel "lib/libasl/asl_ipc.defs"
  @donor_asl_core_rel "lib/libasl/asl_core.c"
  @donor_asl_core_h_rel "lib/libasl/asl_core.h"
  @donor_syslogd_rel "usr.sbin/asl/syslogd.c"
  @fixture_rel "fixtures/launchd/org.rmxos.asl.a2.system-logger.plist"
  @probe_rel "priv/probes/asl/a2_system_logger_handoff.c"
  @stage_tool "scripts/bhyve/stage-phase1-launchd-harness-guest.sh"
  @run_tool "scripts/bhyve/run-guest.sh"
  @link_harness_tool "scripts/launchd/link-launchd-harness.sh"
  @build_minibootstrap_tool "scripts/bhyve/build-phase1-minibootstrap.sh"
  @build_donor_tests_tool "scripts/launchd/build-bootstrap-donor-tests.sh"
  @kernel_conf_default "MACHDEBUGDEBUG"

  @donor_paths [
    @defs_rel,
    @donor_asl_core_rel,
    @donor_asl_core_h_rel,
    @donor_syslogd_rel,
    "lib/liblaunch/bootstrap.h",
    "lib/liblaunch/bootstrap_priv.h",
    "lib/liblaunch/launch.h",
    "lib/liblaunch/launch_internal.h",
    "include/servers/bootstrap.h"
  ]

  @hard_stop_patterns [
    ~r/panic/i,
    ~r/Fatal trap/i,
    ~r/KASSERT/i,
    ~r/WITNESS:|WITNESS.*lock order|lock order reversal/i,
    ~r/SIGSYS/i,
    ~r/Bad system call/i,
    ~r/UNKNOWN FreeBSD SYSCALL/i,
    ~r/nosys [0-9]+/i,
    ~r/Enter full pathname of shell/i,
    ~r/Consoles:\s+Dual \(Video primary\)/i
  ]

  def run(opts) do
    oracle_repo = Keyword.fetch!(opts, :oracle_repo)
    out_root = Keyword.get(opts, :out_root, Path.join(oracle_repo, "priv/runs/asl-a2"))
    lane = Keyword.get(opts, :lane, "launchd")
    host_only? = Keyword.get(opts, :host_only, false)
    evidence_dir = Path.join(out_root, "#{timestamp()}-system-logger-handoff")
    File.mkdir_p!(evidence_dir)

    ctx =
      opts
      |> Map.new()
      |> Map.merge(%{
        oracle_repo: oracle_repo,
        out_root: out_root,
        lane: lane,
        evidence_dir: evidence_dir
      })

    report =
      ctx
      |> materialize_and_build()
      |> maybe_run_guest(host_only?)

    CanonicalJSON.write!(Path.join(evidence_dir, "parity.json"), report)
    report
  end

  def validate_serial(serial) when is_binary(serial) do
    parsed = parse_serial(serial)
    hard_stops = hard_stop_matches(serial)
    exact = exact_errors(parsed, MarkerManifest.required_exact())
    policies = policy_errors(parsed, MarkerManifest.policy_specs())
    order = order_errors(parsed, MarkerManifest.required_order())
    duplicates = duplicate_errors(parsed)
    terminal = terminal_errors(parsed)
    subclaims = subclaim_report(parsed)

    errors =
      exact ++
        policies ++
        order ++
        duplicates ++
        terminal ++
        subclaims["errors"] ++
        Enum.map(hard_stops, &"hard stop matched #{&1["match"]}")

    %{
      "schema" => "rmxos_oracle.asl_a2.marker_validation.v1",
      "passed" => errors == [],
      "errors" => errors,
      "subclaim_a_passed" => subclaims["subclaim_a_passed"],
      "subclaim_b_passed" => subclaims["subclaim_b_passed"],
      "port_identity_passed" => subclaims["port_identity_passed"],
      "hard_stop_matches" => hard_stops,
      "expected_payload" => %{
        "byte_count" => MarkerManifest.payload_byte_count(),
        "sha256" => MarkerManifest.payload_sha256()
      }
    }
  end

  def hard_stop_scan(serial) do
    matches = hard_stop_matches(serial)

    %{
      "schema" => "rmxos_oracle.asl_a2.hard_stop_scan.v1",
      "passed" => matches == [],
      "patterns" => Enum.map(@hard_stop_patterns, &Regex.source/1),
      "matches" => matches
    }
  end

  def revalidate_evidence(evidence_dir) when is_binary(evidence_dir) do
    serial_path = Path.join(evidence_dir, "asl_a2_serial.log")
    serial = File.read!(serial_path)
    boot_identity = read_json_if_present(Path.join(evidence_dir, "boot_identity.json"))
    validation = validate_serial(serial)
    hard_stop_scan = hard_stop_scan(serial)
    negatives = negative_controls(serial)

    passed =
      boot_identity["passed"] == true and validation["passed"] and hard_stop_scan["passed"] and
        negatives["passed"] and validation["subclaim_a_passed"] and
        validation["subclaim_b_passed"] and validation["port_identity_passed"]

    %{
      "schema" => "rmxos_oracle.asl_a2.authority_revalidation.v1",
      "passed" => passed,
      "accepted_claim" => if(passed, do: MarkerManifest.accepted_claim(), else: "not_accepted"),
      "accepted_evidence_path" => MarkerManifest.accepted_evidence_dir(),
      "accepted_evidence_tree_digest" => MarkerManifest.accepted_evidence_tree_digest(),
      "serial_sha256" => sha256(serial),
      "raw_evidence_mutated" => false,
      "boot_identity_passed" => boot_identity["passed"] == true,
      "marker_validation_passed" => validation["passed"],
      "hard_stop_scan_passed" => hard_stop_scan["passed"],
      "negative_controls_passed" => negatives["passed"],
      "subclaim_a_passed" => validation["subclaim_a_passed"],
      "subclaim_b_passed" => validation["subclaim_b_passed"],
      "port_identity_passed" => validation["port_identity_passed"]
    }
  end

  def negative_controls(serial) do
    controls = Enum.map(MarkerManifest.negative_control_contracts(), &falsifier(serial, &1))

    %{
      "schema" => "rmxos_oracle.asl_a2.negative_controls.v1",
      "passed" => Enum.all?(controls, & &1["passed"]),
      "controls" => controls,
      "limitations" => [
        "negative controls mutate serial evidence and prove validator red paths, not extra guest behavior",
        "ResetAtClose falsifier is deferred because the first A2 fixture does not use ResetAtClose"
      ]
    }
  end

  def static_authority_contract_checks(repo_root \\ File.cwd!()) do
    ContractCheck.run(repo_root)
  end

  def fixture_shape(path) do
    text = File.read!(path)

    forbidden =
      Enum.filter(
        ["Sockets", "KeepAlive", "LaunchEvents", "XPC", "EnvironmentVariables"],
        fn key ->
          String.contains?(text, "<key>#{key}</key>")
        end
      )

    checks = %{
      "has_machservices" => String.contains?(text, "<key>MachServices</key>"),
      "has_service_name" => String.contains?(text, "<key>#{MarkerManifest.service_name()}</key>"),
      "has_project_label" => String.contains?(text, "org.rmxos.asl.a2.system-logger"),
      "forbidden_product_keys" => forbidden
    }

    %{
      "schema" => "rmxos_oracle.asl_a2.fixture_shape.v1",
      "path" => path,
      "sha256" => sha256_file(path),
      "checks" => checks,
      "passed" =>
        checks["has_machservices"] and checks["has_service_name"] and
          checks["has_project_label"] and forbidden == []
    }
  end

  def staging_capability(source_text) when is_binary(source_text) do
    fixture_variable = String.contains?(source_text, "NXPLATFORM_PHASE1_LAUNCHD_HARNESS_FIXTURE")

    donor_bootstrap_fixture_install? = donor_bootstrap_fixture_install?(source_text)

    %{
      "schema" => "rmxos_oracle.asl_a2.source_staging_capability.v1",
      "passed" => fixture_variable and donor_bootstrap_fixture_install?,
      "fixture_variable_present" => fixture_variable,
      "donor_bootstrap_installs_fixture" => donor_bootstrap_fixture_install?,
      "required_runtime_fixture" => @fixture_rel,
      "reason" =>
        if(donor_bootstrap_fixture_install?,
          do: "source staging can install the A2 MachServices fixture for donor-bootstrap mode",
          else:
            "current source staging script only installs NXPLATFORM_PHASE1_LAUNCHD_HARNESS_FIXTURE for import/bootstrap modes; A2 donor-bootstrap staging cannot prove the MachServices fixture is consumed at runtime without a source-side staging change"
        )
    }
  end

  defp donor_bootstrap_fixture_install?(source_text) do
    lines = String.split(source_text, "\n")

    lines
    |> Enum.with_index()
    |> Enum.filter(fn {line, _index} ->
      String.contains?(line, ~s|doas install -m 644 "$fixture"|)
    end)
    |> Enum.any?(fn {_line, index} ->
      start = max(index - 8, 0)

      lines
      |> Enum.slice(start, index - start + 1)
      |> Enum.join("\n")
      |> String.contains?("donor-bootstrap")
    end)
  end

  def staged_root_guard(guest_root) when is_binary(guest_root) do
    stale_paths =
      [
        "etc/rc.d/nxplatform_asl_a1",
        "root/nxplatform/asl/asl-a1-server-message-ool"
      ]
      |> Enum.map(&Path.join(guest_root, &1))
      |> Enum.filter(&File.exists?/1)
      |> Enum.map(&Path.relative_to(&1, guest_root))

    rc_conf = Path.join(guest_root, "etc/rc.conf")
    enabled_rc_lines = enabled_a1_rc_lines(rc_conf)
    a1_text_matches = asl_a1_text_matches(guest_root)

    %{
      "schema" => "rmxos_oracle.asl_a2.staged_root_guard.v1",
      "passed" => stale_paths == [] and enabled_rc_lines == [] and a1_text_matches == [],
      "guest_root" => guest_root,
      "stale_a1_paths" => stale_paths,
      "enabled_a1_rc_lines" => enabled_rc_lines,
      "asl_a1_text_matches" => a1_text_matches,
      "rule" =>
        "A2 staging must not leave nxplatform_asl_a1 rc state, A1 probe binaries, or ASL_A1 marker/service text in executable guest paths"
    }
  end

  def first_staging_failure_disposition(
        path \\ "findings/asl-a2-first-staging-failure-disposition.json"
      ) do
    path
    |> File.read!()
    |> JSON.decode!()
  end

  defp materialize_and_build(ctx) do
    evidence_dir = ctx.evidence_dir
    oracle_repo = ctx.oracle_repo
    env_report = Env.check(ctx.lane, env_path: Map.get(ctx, :env_path, "priv/env/env.local"))
    source_commit = git!(@source_repo, ["rev-parse", "HEAD"])
    oracle_commit = git!(oracle_repo, ["rev-parse", "HEAD"])
    donor_resolved = git!(@donor_root, ["rev-parse", "#{@donor_commit}^{commit}"])
    parity_tag = git!(@source_repo, ["rev-parse", "oracle-parity-a30ef3f^{commit}"])

    fail_unless(donor_resolved == @donor_commit, "donor commit mismatch")

    fail_unless(
      source_commit == @source_authorization_commit,
      "source authorization commit mismatch: #{source_commit}"
    )

    fail_unless(
      env_report["status"] == "pass",
      "ASL A2 env check failed: #{inspect(env_report["errors"])}"
    )

    host_dir = Path.join(evidence_dir, "host")
    donor_dir = Path.join(host_dir, "donor")
    generated_dir = Path.join(host_dir, "generated")
    build_dir = Path.join(host_dir, "build")
    log_dir = Path.join(evidence_dir, "logs")
    Enum.each([donor_dir, generated_dir, build_dir, log_dir], &File.mkdir_p!/1)

    archive = Path.join(host_dir, "donor-a2.tar")

    run_cmd!(
      "donor archive",
      "git",
      ["-C", @donor_root, "archive", "--format=tar", "--output=#{archive}", @donor_commit, "--"] ++
        @donor_paths,
      Path.join(log_dir, "donor_archive.log")
    )

    run_cmd!(
      "donor extract",
      "tar",
      ["-xf", archive, "-C", donor_dir],
      Path.join(log_dir, "donor_extract.log")
    )

    donor_hashes = donor_hashes(donor_dir)
    CanonicalJSON.write!(Path.join(evidence_dir, "donor_hashes.json"), donor_hashes)

    workspace_root = env_report["workspace_root"] || "/Users/me/wip-mach"
    m7a_workdir = Path.join(workspace_root, "build/m7a-libmach-work")
    m7a_prefix = Path.join(workspace_root, "build/m7a-libmach-prefix")
    mig = Path.join(m7a_workdir, "tools/bin/mig")
    freebsd_src = env_report["freebsd_src"]

    fail_unless(File.regular?(mig), "missing MIG tool: #{mig}")
    fail_unless(File.dir?(m7a_prefix), "missing libmach prefix: #{m7a_prefix}")

    run_cmd!(
      "generate ASL MIG",
      mig,
      [
        "-I#{freebsd_src}/sys",
        "-I#{m7a_prefix}/include",
        "-user",
        Path.join(generated_dir, "asl_ipc_user.c"),
        "-server",
        Path.join(generated_dir, "asl_ipc_server.c"),
        "-header",
        Path.join(generated_dir, "asl_ipc.h"),
        "-sheader",
        Path.join(generated_dir, "asl_ipc_server.h"),
        Path.join(donor_dir, @defs_rel)
      ],
      Path.join(log_dir, "mig-asl-ipc.log")
    )

    extraction = extract_asl_core_lookup!(donor_dir, generated_dir)
    fixture = fixture_shape(Path.join(oracle_repo, @fixture_rel))
    CanonicalJSON.write!(Path.join(evidence_dir, "fixture_shape.json"), fixture)

    probe_source = Path.join(oracle_repo, @probe_rel)
    probe_copy = Path.join(build_dir, "a2_system_logger_handoff.c")
    File.cp!(probe_source, probe_copy)

    static_checks = %{
      "schema" => "rmxos_oracle.asl_a2.static_checks.v1",
      "authority_contract" => static_authority_contract_checks(oracle_repo),
      "fixture_shape" => fixture,
      "source_staging_capability" =>
        staging_capability(File.read!(Map.fetch!(source_tools(), @stage_tool))),
      "source_status_before" => git_status(@source_repo),
      "oracle_parity_tag_commit" => parity_tag
    }

    CanonicalJSON.write!(Path.join(evidence_dir, "static_checks.json"), static_checks)

    build =
      build_binaries(
        ctx,
        donor_dir,
        generated_dir,
        build_dir,
        log_dir,
        m7a_prefix,
        freebsd_src,
        extraction
      )

    CanonicalJSON.write!(
      Path.join(evidence_dir, "generated_mig_hashes.json"),
      generated_hashes(generated_dir, build_dir)
    )

    CanonicalJSON.write!(
      Path.join(evidence_dir, "probe_hashes.json"),
      probe_hashes(probe_source, probe_copy, build)
    )

    CanonicalJSON.write!(
      Path.join(evidence_dir, "donor_lookup_build_provenance.json"),
      donor_lookup_provenance(donor_dir, build_dir, extraction, build)
    )

    host_checks = %{
      "schema" => "rmxos_oracle.asl_a2.host_checks.v1",
      "status" =>
        if(
          env_report["status"] == "pass" and static_checks["authority_contract"]["passed"] and
            static_checks["fixture_shape"]["passed"] and
            static_checks["source_staging_capability"]["passed"] and
            build["passed"],
          do: "pass",
          else: "fail"
        ),
      "env_check_passed" => env_report["status"] == "pass",
      "source_authorization_commit" => @source_authorization_commit,
      "oracle_a2_design_commit" => @oracle_a2_design_commit,
      "a1_authority_commit" => @a1_authority_commit,
      "donor_lookup_extraction_exact" => extraction.exact,
      "fixture_shape_passed" => fixture["passed"],
      "source_staging_capability_passed" => static_checks["source_staging_capability"]["passed"],
      "authority_contract_passed" => static_checks["authority_contract"]["passed"],
      "build_passed" => build["passed"],
      "runtime_fixture_consumed_by_existing_harness" =>
        static_checks["source_staging_capability"]["passed"],
      "runtime_fixture_limitation" => static_checks["source_staging_capability"]["reason"]
    }

    CanonicalJSON.write!(Path.join(evidence_dir, "host_checks.json"), host_checks)
    CanonicalJSON.write!(Path.join(evidence_dir, "env_resolved.json"), env_report)

    Map.merge(ctx, %{
      env_report: env_report,
      oracle_commit: oracle_commit,
      source_commit: source_commit,
      parity_tag_commit: parity_tag,
      donor_hashes: donor_hashes,
      host_checks: host_checks,
      static_checks: static_checks,
      build: build,
      server_binary: build["server_binary"],
      client_binary: build["client_binary"]
    })
  end

  defp maybe_run_guest(%{host_checks: %{"status" => status}} = ctx, _host_only)
       when status != "pass" do
    base_report(ctx, "host_checks_failed")
    |> Map.merge(%{
      "host_only" => true,
      "host_checks_passed" => false,
      "source_staging_capability_passed" => ctx.host_checks["source_staging_capability_passed"],
      "authorized_first_guest_attempt_consumed" => false,
      "parity_passed" => false,
      "behavior_passed" => false,
      "claim" => "not_accepted",
      "failure_class" => "source_staging_capability_missing",
      "failure_reason" => ctx.host_checks["runtime_fixture_limitation"],
      "guest_run_performed" => false
    })
  end

  defp maybe_run_guest(ctx, true) do
    base_report(ctx, "host_checks_passed")
    |> Map.merge(%{
      "host_only" => true,
      "host_checks_passed" => true,
      "parity_passed" => false,
      "behavior_passed" => false,
      "claim" => "host_checks_only_no_guest_evidence"
    })
  end

  defp maybe_run_guest(ctx, false) do
    evidence_dir = ctx.evidence_dir
    env = guest_env(ctx)

    case stage_and_prepare_guest(ctx, env) do
      {:ok, staging_guard} ->
        run_guest(ctx, env, staging_guard)
        validate_guest_run(ctx, env, staging_guard)

      {:error, report} ->
        CanonicalJSON.write!(Path.join(evidence_dir, "staging_setup_failure.json"), report)

        base_report(ctx, "runner_staging_setup_failure")
        |> Map.merge(%{
          "host_only" => false,
          "authorized_first_guest_attempt_consumed" => false,
          "parity_passed" => false,
          "behavior_passed" => false,
          "boot_identity_passed" => nil,
          "marker_comparison_passed" => false,
          "hard_stop_scan_passed" => nil,
          "negative_control_passed" => nil,
          "subclaim_a_passed" => false,
          "subclaim_b_passed" => false,
          "port_identity_passed" => false,
          "claim" => "not_accepted",
          "staging_setup_failure_ref" => "staging_setup_failure.json",
          "failure_class" => "runner_staging_setup_failure",
          "limitations" => [
            "no guest runtime evidence was accepted",
            "authorized attempt is not consumed unless ASL_A2 runtime markers are emitted",
            "A2 staging must prove MachServices fixture consumption and absence of stale A1 rc state before run-guest"
          ]
        })
    end
  end

  defp validate_guest_run(ctx, env, _staging_guard) do
    evidence_dir = ctx.evidence_dir
    serial_path = env["NXPLATFORM_SERIAL_LOG"]
    serial = File.read!(serial_path)
    File.cp!(serial_path, Path.join(evidence_dir, "asl_a2_serial.log"))

    boot_identity = boot_identity(ctx, env, serial)
    validation = validate_serial(serial)
    hard_stop_scan = hard_stop_scan(serial)
    negatives = negative_controls(serial)
    post = post_run_revalidation(ctx, serial)

    CanonicalJSON.write!(Path.join(evidence_dir, "boot_identity.json"), boot_identity)
    CanonicalJSON.write!(Path.join(evidence_dir, "marker_validation.json"), validation)
    CanonicalJSON.write!(Path.join(evidence_dir, "hard_stop_scan.json"), hard_stop_scan)
    CanonicalJSON.write!(Path.join(evidence_dir, "negative_controls.json"), negatives)
    CanonicalJSON.write!(Path.join(evidence_dir, "post_run_revalidation.json"), post)

    passed =
      boot_identity["passed"] and validation["passed"] and hard_stop_scan["passed"] and
        negatives["passed"] and validation["subclaim_a_passed"] and
        validation["subclaim_b_passed"] and validation["port_identity_passed"]

    base_report(ctx, if(passed, do: "parity_passed", else: "parity_failed"))
    |> Map.merge(%{
      "host_only" => false,
      "authorized_first_guest_attempt_consumed" => a2_runtime_markers?(serial),
      "staging_guard_ref" => "staged_root_guard.json",
      "parity_passed" => passed,
      "behavior_passed" => validation["passed"],
      "boot_identity_passed" => boot_identity["passed"],
      "marker_comparison_passed" => validation["passed"],
      "hard_stop_scan_passed" => hard_stop_scan["passed"],
      "negative_control_passed" => negatives["passed"],
      "subclaim_a_passed" => validation["subclaim_a_passed"],
      "subclaim_b_passed" => validation["subclaim_b_passed"],
      "port_identity_passed" => validation["port_identity_passed"],
      "claim" => if(passed, do: MarkerManifest.accepted_claim(), else: "not_accepted"),
      "serial_log" => "asl_a2_serial.log",
      "limitations" => [
        "no certification claim",
        "no generic Phase 0.85 authority module",
        "no D22/D23 launchctl migration",
        "no libnotify/notifyd, storage/query, syslog socket, XPC, or aslmanager claim",
        "ASL A2 marker manifest entries are intentionally not authored before accepted evidence"
      ]
    })
  end

  defp base_report(ctx, status) do
    %{
      "schema" => @schema,
      "slice_id" => @slice_id,
      "status" => status,
      "evidence_dir" => ctx.evidence_dir,
      "comparison_axis" => "oracle_runtime_claim",
      "observation_basis" =>
        if(status in ["host_checks_passed", "host_checks_failed"],
          do: "host_build_probe",
          else: "L2_guest_integration"
        ),
      "oracle_commit" => ctx.oracle_commit,
      "source_authorization_commit" => @source_authorization_commit,
      "source_repo_commit" => ctx.source_commit,
      "oracle_a2_design_commit" => @oracle_a2_design_commit,
      "a1_authority_commit" => @a1_authority_commit,
      "donor_asl_source" => %{"path" => @donor_root, "commit" => @donor_commit},
      "legacy_commit" => @donor_commit,
      "legacy_test_commit" => nil,
      "service_name" => MarkerManifest.service_name(),
      "nonce" => MarkerManifest.nonce(),
      "host_checks_ref" => "host_checks.json",
      "donor_hashes_ref" => "donor_hashes.json",
      "donor_lookup_build_provenance_ref" => "donor_lookup_build_provenance.json",
      "generated_mig_hashes_ref" => "generated_mig_hashes.json",
      "probe_hashes_ref" => "probe_hashes.json",
      "fixture_shape_ref" => "fixture_shape.json",
      "negative_api_passed" => nil,
      "negative_mix_test_passed" => nil
    }
  end

  defp build_binaries(
         _ctx,
         donor_dir,
         generated_dir,
         build_dir,
         log_dir,
         m7a_prefix,
         freebsd_src,
         extraction
       ) do
    cc = System.get_env("CC") || "cc"
    workspace_root = "/Users/me/wip-mach"
    liblaunch_obj = "#{workspace_root}/build/phase1-minibootstrap/obj/liblaunch.o"
    libbootstrap_obj = "#{workspace_root}/build/phase1-minibootstrap/obj/libbootstrap.o"
    job_user_obj = "#{workspace_root}/build/phase1-minibootstrap/obj/jobUser.o"

    cflags = [
      "-O2",
      "-Wall",
      "-Wextra",
      "-I#{generated_dir}",
      "-I#{m7a_prefix}/include",
      "-I#{m7a_prefix}/include/apple",
      "-I#{donor_dir}/lib/liblaunch",
      "-I#{donor_dir}/lib/libasl",
      "-I#{freebsd_src}/sys",
      "-idirafter",
      "#{donor_dir}/include",
      "-D__APPLE__",
      "-DPRIVATE",
      "-D__MigTypeCheck=1"
    ]

    compile_object(
      cc,
      cflags,
      Path.join(generated_dir, "asl_ipc_user.c"),
      Path.join(build_dir, "asl_ipc_user.o"),
      log_dir
    )

    compile_object(
      cc,
      cflags,
      extraction.wrapper_path,
      Path.join(build_dir, "donor_asl_core_lookup.o"),
      log_dir
    )

    compile_object(
      cc,
      cflags ++ ["-DASL_A2_ROLE_SERVER=1"],
      Path.join(build_dir, "a2_system_logger_handoff.c"),
      Path.join(build_dir, "a2_server.o"),
      log_dir
    )

    compile_object(
      cc,
      cflags ++ ["-DASL_A2_ROLE_CLIENT=1"],
      Path.join(build_dir, "a2_system_logger_handoff.c"),
      Path.join(build_dir, "a2_client.o"),
      log_dir
    )

    server_binary = Path.join(build_dir, "asl-a2-launchd-server")
    client_binary = Path.join(build_dir, "asl-a2-launchd-client")

    run_cmd!(
      "link ASL A2 server",
      cc,
      [
        Path.join(build_dir, "a2_server.o"),
        liblaunch_obj,
        libbootstrap_obj,
        job_user_obj,
        "-L#{m7a_prefix}/lib",
        "-lmach",
        "-lmach-traps",
        "-lmd",
        "-lutil",
        "-o",
        server_binary
      ],
      Path.join(log_dir, "a2-server-link.log")
    )

    run_cmd!(
      "link ASL A2 client",
      cc,
      [
        Path.join(build_dir, "a2_client.o"),
        Path.join(build_dir, "asl_ipc_user.o"),
        Path.join(build_dir, "donor_asl_core_lookup.o"),
        libbootstrap_obj,
        job_user_obj,
        "-L#{m7a_prefix}/lib",
        "-lmach",
        "-lmach-traps",
        "-lmd",
        "-lutil",
        "-o",
        client_binary
      ],
      Path.join(log_dir, "a2-client-link.log")
    )

    %{
      "schema" => "rmxos_oracle.asl_a2.build.v1",
      "passed" => File.regular?(server_binary) and File.regular?(client_binary),
      "server_binary" => server_binary,
      "client_binary" => client_binary,
      "cc" => cc,
      "cflags" => cflags
    }
  end

  defp stage_and_prepare_guest(ctx, env) do
    evidence_dir = ctx.evidence_dir
    source_tools = source_tools()
    host_log = Path.join(evidence_dir, "oracle_host.log")
    File.write!(host_log, "")

    commands = [
      {"build minibootstrap support objects", Map.fetch!(source_tools, @build_minibootstrap_tool),
       []},
      {"build donor bootstrap tests", Map.fetch!(source_tools, @build_donor_tests_tool), []},
      {"link donor bootstrap harness", Map.fetch!(source_tools, @link_harness_tool), [],
       [{"NXPLATFORM_LAUNCHD_HARNESS_MODE", "donor-bootstrap"}]},
      {"stage ASL A2 launchd handoff guest", Map.fetch!(source_tools, @stage_tool), [],
       [
         {"NXPLATFORM_PHASE1_LAUNCHD_HARNESS_MODE", "donor-bootstrap"},
         {"NXPLATFORM_PHASE1_BOOTSTRAP_SERVER_BINARY", ctx.server_binary},
         {"NXPLATFORM_PHASE1_BOOTSTRAP_CLIENT_BINARY", ctx.client_binary},
         {"NXPLATFORM_PHASE1_LAUNCHD_HARNESS_FIXTURE", Path.join(ctx.oracle_repo, @fixture_rel)},
         {"NXPLATFORM_PHASE1_LAUNCHD_HARNESS_TIMEOUT", "120"},
         {"NXPLATFORM_INSTALL_MACH_MODULE", "1"}
       ]},
      {"remove stale A1 rc state", "sh", ["-c", cleanup_a1_script()], []}
    ]

    records =
      Enum.map(commands, fn command ->
        run_command(command, env, host_log)
      end)

    staging_guard = mounted_guest_root_check(env, evidence_dir, host_log)

    CanonicalJSON.write!(Path.join(evidence_dir, "guest_execution.json"), %{
      "schema" => "rmxos_oracle.asl_a2.guest_execution.v1",
      "commands" => records,
      "host_log_path" => "oracle_host.log",
      "staged_root_guard_ref" => "staged_root_guard.json",
      "transitional_shell_tools" => true
    })

    if staging_guard["passed"] do
      {:ok, staging_guard}
    else
      {:error,
       %{
         "schema" => "rmxos_oracle.asl_a2.runner_staging_setup_failure.v1",
         "classification" => "runner_staging_setup_failure",
         "attempt_consumed" => false,
         "reason" => "staged guest would still run or expose stale ASL A1 service path",
         "staged_root_guard" => staging_guard,
         "guest_execution_ref" => "guest_execution.json"
       }}
    end
  end

  defp cleanup_a1_script do
    """
    set -eu

    find_root_partition()
    {
      doas gpart list "$1" | awk '
        $2 == "Name:" { name = $3 }
        $1 == "type:" && $2 == "freebsd-ufs" { print "/dev/" name; exit }
      '
    }

    set_rcconf_value()
    {
      target=$1
      key=$2
      value=$3
      tmp=$(mktemp)

      if doas test -f "$target"; then
        doas awk -v key="$key" 'index($0, key "=") != 1 { print }' "$target" > "$tmp"
      fi
      printf '%s="%s"\\n' "$key" "$value" >> "$tmp"
      doas install -m 644 "$tmp" "$target"
      rm -f "$tmp"
    }

    vm_image=${NXPLATFORM_VM_IMAGE:?}
    guest_root=${NXPLATFORM_GUEST_ROOT:?}
    mddev=

    cleanup()
    {
      if doas mount | awk '{print $3}' | grep -Fxq "$guest_root"; then
        doas umount "$guest_root" || true
      fi
      if [ -n "$mddev" ]; then
        doas mdconfig -d -u "${mddev#md}" || true
      fi
    }
    trap cleanup EXIT INT TERM

    doas mkdir -p "$guest_root"
    guest_root=$(CDPATH= cd -- "$guest_root" && pwd)
    mddev=$(doas mdconfig -a -t vnode -f "$vm_image")
    root_part=$(find_root_partition "$mddev")
    [ -n "$root_part" ] || {
      echo "unable to locate guest root partition" >&2
      exit 65
    }

    doas fsck -p "$root_part" || true
    doas mount -o rw -t ufs "$root_part" "$guest_root"
    doas rm -f "$guest_root/etc/rc.d/nxplatform_asl_a1"
    doas rm -f "$guest_root/root/nxplatform/asl/asl-a1-server-message-ool"
    set_rcconf_value "$guest_root/etc/rc.conf" nxplatform_asl_a1_enable NO
    """
  end

  defp mounted_guest_root_check(env, evidence_dir, host_log) do
    result =
      with_mounted_guest_root(env, host_log, fn guest_root ->
        staged_root_guard(guest_root)
      end)

    CanonicalJSON.write!(Path.join(evidence_dir, "staged_root_guard.json"), result)
    result
  end

  defp with_mounted_guest_root(env, log, fun) do
    vm_image = Map.fetch!(env, "NXPLATFORM_VM_IMAGE")
    guest_root = Map.fetch!(env, "NXPLATFORM_GUEST_ROOT")
    File.mkdir_p!(guest_root)

    mddev =
      run_cmd!(
        "mdconfig attach for guard",
        "doas",
        ["mdconfig", "-a", "-t", "vnode", "-f", vm_image],
        log
      ).out
      |> String.trim()

    try do
      root_part =
        run_cmd!("gpart list for guard", "doas", ["gpart", "list", mddev], log)
        |> Map.fetch!(:out)
        |> root_partition!()

      run_cmd("fsck guest for guard", "doas", ["fsck", "-p", root_part], log)

      run_cmd!(
        "mount guest for guard",
        "doas",
        ["mount", "-o", "ro", "-t", "ufs", root_part, guest_root],
        log
      )

      fun.(guest_root)
    after
      run_cmd("umount guest after guard", "doas", ["umount", guest_root], log)

      run_cmd(
        "mdconfig detach after guard",
        "doas",
        ["mdconfig", "-d", "-u", String.replace_prefix(mddev, "md", "")],
        log
      )
    end
  end

  defp enabled_a1_rc_lines(rc_conf) do
    if File.regular?(rc_conf) do
      rc_conf
      |> File.read!()
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
      |> Enum.filter(&Regex.match?(~r/^nxplatform_asl_a1_enable\s*=\s*"?YES"?$/i, &1))
    else
      []
    end
  end

  defp asl_a1_text_matches(guest_root) do
    [
      Path.join(guest_root, "etc/rc.d"),
      Path.join(guest_root, "usr/local/etc/rc.d"),
      Path.join(guest_root, "root/nxplatform")
    ]
    |> Enum.flat_map(fn dir ->
      if File.dir?(dir), do: Path.wildcard(Path.join(dir, "**/*")), else: []
    end)
    |> Enum.filter(&File.regular?/1)
    |> Enum.flat_map(fn path ->
      case File.read(path) do
        {:ok, text} ->
          if String.contains?(text, "ASL_A1_") or
               String.contains?(text, "nxplatform_asl_a1") or
               String.contains?(text, "asl-a1-server-message-ool") do
            [Path.relative_to(path, guest_root)]
          else
            []
          end

        {:error, _reason} ->
          []
      end
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp run_guest(ctx, env, _staging_guard) do
    source_tools = source_tools()
    host_log = Path.join(ctx.evidence_dir, "oracle_host.log")

    command =
      {"run guest stdin isolated", "sh",
       [
         "-c",
         "exec \"$1\" < /dev/null",
         "oracle-asl-a2-runner",
         Map.fetch!(source_tools, @run_tool)
       ]}

    record = run_command(command, env, host_log)

    CanonicalJSON.write!(Path.join(ctx.evidence_dir, "run_guest_command.json"), %{
      "schema" => "rmxos_oracle.asl_a2.run_guest_command.v1",
      "command" => record,
      "stdin_isolated" => true
    })
  end

  defp guest_env(ctx) do
    env_report = ctx.env_report
    workspace_root = env_report["workspace_root"]
    kernel_conf = System.get_env("NXPLATFORM_KERNEL_CONF") || @kernel_conf_default
    vm_name = System.get_env("NXPLATFORM_VM_NAME") || "nxplatform-dev"

    %{
      "NXPLATFORM_WORKSPACE_ROOT" => workspace_root,
      "NXPLATFORM_FREEBSD_SRC" => env_report["freebsd_src"],
      "NXPLATFORM_KERNEL_OBJDIRPREFIX" => env_report["kernel_objdirprefix"],
      "MAKEOBJDIRPREFIX" => env_report["kernel_objdirprefix"],
      "NXPLATFORM_KERNEL_CONF" => kernel_conf,
      "NXPLATFORM_BASE_PROFILE" => env_report["accepted_source_profile"],
      "NXPLATFORM_VM_NAME" => vm_name,
      "NXPLATFORM_VM_IMAGE" =>
        System.get_env("NXPLATFORM_VM_IMAGE") ||
          Path.join(workspace_root, "vm/runs/#{vm_name}.img"),
      "NXPLATFORM_GUEST_ROOT" =>
        System.get_env("NXPLATFORM_GUEST_ROOT") ||
          Path.join(workspace_root, "vm/runs/#{vm_name}.root"),
      "NXPLATFORM_SERIAL_LOG" => Path.join(ctx.evidence_dir, "asl_a2_serial.raw.log"),
      "NXPLATFORM_GUEST_SUCCESS_MARKER" => MarkerManifest.success_marker(),
      "NXPLATFORM_EXPECT_KERNEL" => kernel_conf
    }
  end

  defp boot_identity(ctx, env, serial) do
    freebsd_src = env["NXPLATFORM_FREEBSD_SRC"]
    objdir = env["NXPLATFORM_KERNEL_OBJDIRPREFIX"]
    kernel_conf = env["NXPLATFORM_KERNEL_CONF"]
    kernel_path = "#{objdir}#{freebsd_src}/amd64.amd64/sys/#{kernel_conf}/kernel"
    mach_ko_path = "#{objdir}#{freebsd_src}/amd64.amd64/sys/modules/mach/mach.ko"
    guest_image = env["NXPLATFORM_VM_IMAGE"]

    fields = %{
      "schema" => "rmxos_oracle.asl_a2.boot_identity.v1",
      "source_profile" => ctx.env_report["accepted_source_profile"],
      "freebsd_src" => freebsd_src,
      "freebsd_src_commit" => ctx.env_report["freebsd_src_commit"],
      "expected_freebsd_src_commit" => ctx.env_report["expected_freebsd_src_commit"],
      "kernel_objdirprefix" => objdir,
      "kernel_conf" => kernel_conf,
      "kernel" => file_identity(kernel_path),
      "mach_ko" => file_identity(mach_ko_path),
      "guest_image" => file_identity(guest_image),
      "mach_module_loaded_marker" =>
        parse_serial(serial).lines |> Enum.any?(&(&1 == "mach_module=loaded"))
    }

    Map.put(
      fields,
      "passed",
      fields["mach_module_loaded_marker"] and present_hash?(fields["kernel"]) and
        present_hash?(fields["mach_ko"]) and present_hash?(fields["guest_image"])
    )
  end

  defp post_run_revalidation(ctx, serial) do
    validation = validate_serial(serial)

    %{
      "schema" => "rmxos_oracle.asl_a2.post_run_revalidation.v1",
      "passed" => validation["passed"],
      "accepted_claim" =>
        if(validation["passed"],
          do: MarkerManifest.accepted_claim(),
          else: "not_accepted"
        ),
      "raw_evidence_mutated" => false,
      "serial_sha256" => sha256(serial),
      "oracle_commit" => ctx.oracle_commit
    }
  end

  defp parse_serial(serial) do
    lines = serial |> String.split("\n") |> Enum.map(&String.trim_trailing(&1, "\r"))

    entries =
      lines
      |> Enum.with_index()
      |> Enum.flat_map(fn {line, index} ->
        case Regex.run(~r/^([A-Za-z0-9_]+)=(.*)$/, line, capture: :all_but_first) do
          [key, value] -> [%{key: key, value: value, line: line, index: index}]
          _ -> []
        end
      end)

    %{lines: lines, entries: entries}
  end

  defp exact_errors(parsed, required) do
    Enum.flat_map(required, fn {key, value} ->
      required_count = required_marker_count(key, value)

      case Enum.count(parsed.entries, &(&1.key == key and &1.value == value)) do
        0 ->
          ["missing exact marker #{key}=#{value}"]

        ^required_count ->
          []

        count ->
          ["marker #{key}=#{value} must occur #{required_count} time(s), got #{count}"]
      end
    end)
  end

  defp required_marker_count(key, value), do: MarkerManifest.required_marker_count(key, value)

  defp policy_errors(parsed, specs) do
    Enum.flat_map(specs, fn spec ->
      entries = Enum.filter(parsed.entries, &(&1.key == spec.key))

      case {spec.value_policy, entries} do
        {:must_be_positive_integer, [entry]} ->
          case Integer.parse(entry.value) do
            {value, ""} when value > 0 -> []
            _ -> ["marker #{spec.key} must be a positive integer, got #{inspect(entry.value)}"]
          end

        {:must_be_positive_integer, []} ->
          ["missing policy marker #{spec.key}=<positive_integer>"]

        {:must_be_positive_integer, entries} ->
          ["marker #{spec.key} must occur 1 time(s), got #{length(entries)}"]
      end
    end)
  end

  defp order_errors(parsed, required) do
    {_last, errors} =
      Enum.reduce(required, {-1, []}, fn {key, value}, {last, errors} ->
        indices =
          parsed.entries
          |> Enum.filter(&(&1.key == key and &1.value == value))
          |> Enum.map(& &1.index)

        case indices do
          [index] when index > last -> {index, errors}
          [index] -> {last, errors ++ ["marker out of order #{key}=#{value} at #{index}"]}
          _ -> {last, errors ++ ["order marker missing #{key}=#{value}"]}
        end
      end)

    errors
  end

  defp duplicate_errors(parsed) do
    parsed.entries
    |> Enum.filter(&(&1.key in MarkerManifest.singleton_keys()))
    |> Enum.group_by(& &1.key)
    |> Enum.flat_map(fn {key, entries} ->
      if length(entries) > 1, do: ["duplicate singleton marker #{key}"], else: []
    end)
  end

  defp terminal_errors(parsed) do
    {key, value} = MarkerManifest.terminal_marker()

    case Enum.count(parsed.entries, &(&1.key == key and &1.value == value)) do
      1 -> []
      count -> ["terminal requires exactly one #{key}=#{value}, got #{count}"]
    end
  end

  defp subclaim_report(parsed) do
    has? = fn key, value -> Enum.any?(parsed.entries, &(&1.key == key and &1.value == value)) end

    a? = Enum.all?(MarkerManifest.subclaim_a_markers(), fn {key, value} -> has?.(key, value) end)
    b? = Enum.all?(MarkerManifest.subclaim_b_markers(), fn {key, value} -> has?.(key, value) end)

    port? =
      Enum.all?(MarkerManifest.port_identity_markers(), fn {key, value} -> has?.(key, value) end)

    errors =
      []
      |> maybe_error(a?, "Subclaim A launchd check-in did not pass")
      |> maybe_error(b?, "Subclaim B donor lookup/send/receipt did not pass")
      |> maybe_error(port?, "port identity nonce proof did not pass")

    %{
      "subclaim_a_passed" => a?,
      "subclaim_b_passed" => b?,
      "port_identity_passed" => port?,
      "errors" => errors
    }
  end

  defp maybe_error(errors, true, _message), do: errors
  defp maybe_error(errors, false, message), do: errors ++ [message]

  defp hard_stop_matches(serial) do
    Enum.flat_map(@hard_stop_patterns, fn pattern ->
      Regex.scan(pattern, serial)
      |> Enum.map(fn [match | _] -> %{"pattern" => Regex.source(pattern), "match" => match} end)
    end)
  end

  defp falsifier(serial, contract) do
    mutated =
      String.replace(serial, contract.from, contract.to,
        global: Map.get(contract, :global, false)
      )

    result = validate_serial(mutated)

    %{
      "id" => contract.id,
      "passed" => result["passed"] == false,
      "validator_passed" => result["passed"],
      "observed_errors" => result["errors"]
    }
  end

  defp extract_asl_core_lookup!(donor_dir, generated_dir) do
    source_path = Path.join(donor_dir, @donor_asl_core_rel)
    source = File.read!(source_path)

    [_, body] =
      Regex.run(~r/(mach_port_t\s+asl_core_get_service_port\s*\(int reset\)\s*\{.*?^})/ms, source)

    wrapper = Path.join(generated_dir, "donor_asl_core_get_service_port.c")

    File.write!(wrapper, """
    #include <mach/mach.h>
    #include <bootstrap.h>
    #include <bootstrap_priv.h>
    #include <stdlib.h>
    #include <string.h>
    #include <stdint.h>
    #define ASL_SERVICE_NAME "#{MarkerManifest.service_name()}"
    #define OSAtomicCompareAndSwap32Barrier(old_value, new_value, ptr) __sync_bool_compare_and_swap((ptr), (old_value), (new_value))

    #{body}
    """)

    %{
      wrapper_path: wrapper,
      donor_source_path: @donor_asl_core_rel,
      source_slice_sha256: sha256(body),
      wrapper_sha256: sha256_file(wrapper),
      exact: String.contains?(body, "bootstrap_look_up2(bootstrap_port, ASL_SERVICE_NAME")
    }
  end

  defp donor_hashes(donor_dir) do
    %{
      "schema" => "rmxos_oracle.asl_a2.donor_hashes.v1",
      "donor_root" => @donor_root,
      "donor_commit" => @donor_commit,
      "files" =>
        Enum.map(@donor_paths, fn path ->
          full = Path.join(donor_dir, path)
          %{"path" => path, "sha256" => sha256_file(full), "size" => File.stat!(full).size}
        end)
    }
  end

  defp donor_lookup_provenance(donor_dir, build_dir, extraction, build) do
    link_map = %{
      "server_binary" => file_identity(build["server_binary"]),
      "client_binary" => file_identity(build["client_binary"]),
      "donor_lookup_object" => file_identity(Path.join(build_dir, "donor_asl_core_lookup.o")),
      "source_slice_sha256" => extraction.source_slice_sha256,
      "wrapper_sha256" => extraction.wrapper_sha256
    }

    %{
      "schema" => "rmxos_oracle.asl_a2.donor_lookup_build_provenance.v1",
      "passed" => extraction.exact and present_hash?(link_map["client_binary"]),
      "donor_commit" => @donor_commit,
      "donor_source" => %{
        "path" => @donor_asl_core_rel,
        "sha256" => sha256_file(Path.join(donor_dir, @donor_asl_core_rel))
      },
      "extraction" =>
        Map.take(extraction, [:donor_source_path, :source_slice_sha256, :wrapper_sha256, :exact]),
      "build" => link_map
    }
  end

  defp generated_hashes(generated_dir, build_dir) do
    %{
      "schema" => "rmxos_oracle.asl_a2.generated_mig_hashes.v1",
      "files" =>
        Enum.map(~w(asl_ipc_user.c asl_ipc_server.c asl_ipc.h asl_ipc_server.h), fn path ->
          full = Path.join(generated_dir, path)

          %{
            "path" => "host/generated/#{path}",
            "sha256" => sha256_file(full),
            "size" => File.stat!(full).size
          }
        end) ++
          Enum.map(~w(asl_ipc_user.o), fn path ->
            full = Path.join(build_dir, path)

            %{
              "path" => "host/build/#{path}",
              "sha256" => sha256_file(full),
              "size" => File.stat!(full).size
            }
          end)
    }
  end

  defp probe_hashes(probe_source, probe_copy, build) do
    %{
      "schema" => "rmxos_oracle.asl_a2.probe_hashes.v1",
      "probe_source" => file_identity(probe_source),
      "materialized_probe_source" => file_identity(probe_copy),
      "server_binary" => file_identity(build["server_binary"]),
      "client_binary" => file_identity(build["client_binary"])
    }
  end

  defp source_tools do
    [
      @build_minibootstrap_tool,
      @build_donor_tests_tool,
      @link_harness_tool,
      @stage_tool,
      @run_tool
    ]
    |> Map.new(fn rel -> {rel, Path.join(@source_repo, rel)} end)
  end

  defp run_command(command, env, host_log) do
    {label, cmd, args, extra_env} =
      case command do
        {label, cmd, args} -> {label, cmd, args, []}
        {label, cmd, args, extra_env} -> {label, cmd, args, extra_env}
      end

    File.write!(host_log, "\n==> #{label}\n$ #{cmd} #{Enum.join(args, " ")}\n", [:append])

    {out, status} =
      System.cmd(cmd, args, env: command_env(env, extra_env), stderr_to_stdout: true)

    File.write!(host_log, out, [:append])

    %{
      "label" => label,
      "cmd" => cmd,
      "args" => args,
      "exit_status" => status,
      "output_sha256" => sha256(out)
    }
  end

  defp command_env(env, extra_env) do
    env
    |> Enum.map(fn {key, value} -> {key, value} end)
    |> Kernel.++(extra_env)
  end

  defp compile_object(cc, cflags, source, object, log_dir) do
    run_cmd!(
      "compile #{Path.basename(source)}",
      cc,
      cflags ++ ["-c", source, "-o", object],
      Path.join(log_dir, "#{Path.basename(object)}.compile.log")
    )
  end

  defp run_cmd(label, cmd, args, log, opts \\ []) do
    {out, status} = System.cmd(cmd, args, Keyword.merge([stderr_to_stdout: true], opts))
    File.write!(log, "$ #{cmd} #{Enum.join(args, " ")}\n#{out}", [:append])
    %{label: label, out: out, status: status}
  end

  defp run_cmd!(label, cmd, args, log, opts \\ []) do
    {out, status} = System.cmd(cmd, args, Keyword.merge([stderr_to_stdout: true], opts))
    File.write!(log, "$ #{cmd} #{Enum.join(args, " ")}\n#{out}", [:append])
    fail_unless(status == 0, "#{label} failed with status #{status}; see #{log}")
    %{out: out, status: status}
  end

  defp fail_unless(true, _message), do: :ok
  defp fail_unless(false, message), do: raise(message)

  defp file_identity(path) when is_binary(path) do
    if File.regular?(path) do
      stat = File.stat!(path)
      %{"path" => path, "sha256" => sha256_file(path), "size" => stat.size}
    else
      %{"path" => path, "sha256" => nil, "missing_reason" => "file not found"}
    end
  end

  defp read_json_if_present(path) do
    if File.regular?(path), do: CanonicalJSON.decode!(path), else: %{}
  end

  defp present_hash?(%{"sha256" => sha}) when is_binary(sha) and sha != "", do: true
  defp present_hash?(_), do: false

  defp a2_runtime_markers?(serial) do
    Enum.any?(MarkerManifest.marker_keys(), &String.contains?(serial, &1))
  end

  defp sha256_file(path), do: path |> File.read!() |> sha256()
  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

  defp git!(repo, args), do: repo |> git_bytes!(args) |> String.trim()

  defp git_bytes!(repo, args) do
    {out, status} = System.cmd("git", ["-C", repo | args], stderr_to_stdout: true)
    fail_unless(status == 0, "git -C #{repo} #{Enum.join(args, " ")} failed: #{out}")
    out
  end

  defp git_status(repo) do
    {out, 0} = System.cmd("git", ["-C", repo, "status", "--short"], stderr_to_stdout: true)
    String.split(out, "\n", trim: true)
  end

  defp root_partition!(gpart_output) do
    {_name, root_part} =
      gpart_output
      |> String.split("\n")
      |> Enum.reduce({nil, nil}, fn line, {name, found} ->
        cond do
          Regex.match?(~r/\bName:\s+\S+/, line) ->
            [_, value] = Regex.run(~r/\bName:\s+(\S+)/, line)
            {value, found}

          String.trim(line) == "type: freebsd-ufs" and is_binary(name) ->
            {name, "/dev/#{name}"}

          true ->
            {name, found}
        end
      end)

    case root_part do
      nil -> raise "unable to locate freebsd-ufs root partition"
      path -> path
    end
  end

  defp timestamp do
    Calendar.strftime(DateTime.utc_now(), "%Y%m%dT%H%M%S") <>
      "#{System.unique_integer([:positive])}Z"
  end
end
