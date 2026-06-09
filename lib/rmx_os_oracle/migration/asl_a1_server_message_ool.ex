defmodule RmxOSOracle.Migration.AslA1ServerMessageOol do
  @moduledoc false

  alias RmxOSOracle.{CanonicalJSON, Env}

  @slice_id "asl.a1.server_message_ool"
  @evidence_schema "rmxos_oracle.asl_a1.raw_evidence.v1"
  @donor_root "/Users/me/wip-mach/nx/NextBSD"
  @donor_commit "8be0f2507b69906d068bed31ffc58cdfafadaef3"
  @source_repo "/Users/me/wip-mach/wip-gpt"
  @source_authorization_commit "79aa456d4264bd2fe6f0ee007178e699735fae78"
  @oracle_a0_commit "e80dbb37ebe752353c75438718f5ac3e4d188e9c"
  @oracle_a1_design_commit "a61e50df3819645c56130593afa5c8a69ac57edb"
  @defs_rel "lib/libasl/asl_ipc.defs"
  @donor_dbserver_rel "usr.sbin/asl/dbserver.c"
  @donor_codec_rel "lib/libasl/asl_msg.c"
  @donor_object_rel "lib/libasl/asl_object.c"
  @donor_decode_refs [@donor_dbserver_rel, @donor_codec_rel, @donor_object_rel]
  @pinned_donor_hashes %{
    @defs_rel => "f99ec7346c10a43d5d35d6b62e5dfbb3d353a27cfb55f4d682dc54ca915924e7",
    @donor_dbserver_rel => "01baf337b7c75d0a06b47c84c05f1e60424a3e76bfa548d9b30f1466653a62dc",
    @donor_codec_rel => "6f80ea731ca3d696b29e9bf335ff5c08411a31368b1bfe5ed865a4b0c4f91651",
    @donor_object_rel => "2f315a139de6cdfbcf2be46c3b639cc0cb2e79a1e8a15175d549b0a255434e4c"
  }
  @donor_symbol_origins %{
    "__asl_server_message" => "donor_asl_server_message.o",
    "asl_msg_from_string" => "donor_asl_msg.o",
    "asl_release" => "donor_asl_release.o",
    "rmx_asl_a1_donor_msg_release" => "donor_asl_release.o"
  }
  @donor_archive_paths [
    @defs_rel,
    @donor_dbserver_rel,
    "lib/libasl",
    "lib/libnotify/notify.h",
    "lib/libdispatch/os",
    "lib/libosxsupport/atomic_compat.h",
    "include/TargetConditionals.h",
    "include/Availability.h",
    "include/AvailabilityInternal.h",
    "include/AvailabilityMacros.h",
    "include/os",
    "contrib/openbsm/bsm/libbsm.h"
  ]
  @probe_rel "priv/probes/asl/a1_server_message_ool.c"
  @stage_tool "scripts/bhyve/stage-guest.sh"
  @run_tool "scripts/bhyve/run-guest.sh"
  @source_tool_files [
    @stage_tool,
    @run_tool,
    "scripts/bhyve/nxplatform-mach-probe.c"
  ]
  @mig_subsystem 114
  @mig_routine_id 118
  @default_kernel_conf "MACHDEBUGDEBUG"
  @start_marker "=== ASL A1 server-message-ool start ==="
  @success_marker "=== ASL A1 server-message-ool end rc=0 ==="
  @expected_ool_byte_count "96"
  @expected_ool_sha256 "a3ff9feadd6c4954712c16fb362ff5fcee0fa45a9a65d9e569fa7a33f7c7f977"

  @positive_exact [
    {"ASL_A1_ARM_START", "positive_decode"},
    {"ASL_A1_EXPECTED_OOL_BYTE_COUNT", @expected_ool_byte_count},
    {"ASL_A1_CLIENT_SEND_STARTED", "1"},
    {"ASL_A1_SERVER_RECEIVE_KR", "0"},
    {"ASL_A1_SERVER_REQUESTED_AUDIT_TRAILER", "1"},
    {"ASL_A1_SERVER_AUDIT_TRAILER_PRESENT", "1"},
    {"ASL_A1_GENERATED_DEMUX_CALLED", "1"},
    {"ASL_A1_DONOR_SERVER_MESSAGE_ENTER", "1"},
    {"ASL_A1_RECEIVED_OOL_BYTE_COUNT", @expected_ool_byte_count},
    {"ASL_A1_DONOR_OOL_BYTES_INTACT", "1"},
    {"ASL_A1_DONOR_DECODE_OK", "1"},
    {"ASL_A1_PROCESS_MESSAGE_STUB_CALLED", "1"},
    {"ASL_A1_PROCESS_MESSAGE_SOURCE", "5"},
    {"ASL_A1_PROCESS_MESSAGE_SENDER", "oracle_asl_a1_client"},
    {"ASL_A1_PROCESS_MESSAGE_FACILITY", "com.rmxos.oracle.asl"},
    {"ASL_A1_PROCESS_MESSAGE_LEVEL", "5"},
    {"ASL_A1_PROCESS_MESSAGE_MESSAGE", "oracle_asl_a1"},
    {"ASL_A1_PROCESS_MESSAGE_PAYLOAD_MATCH", "1"},
    {"ASL_A1_DONOR_RELEASE_COMPLETED", "1"},
    {"ASL_A1_GENERATED_DEMUX_HANDLED", "1"},
    {"ASL_A1_CLIENT_SEND_KR", "0"},
    {"ASL_A1_POSITIVE_DECODE_AND_STUB_CONFIRMED", "1"},
    {"ASL_A1_ARM_END", "positive_decode"}
  ]
  @malformed_exact [
    {"ASL_A1_ARM_START", "malformed_payload"},
    {"ASL_A1_CLIENT_SEND_STARTED", "1"},
    {"ASL_A1_SERVER_RECEIVE_KR", "0"},
    {"ASL_A1_GENERATED_DEMUX_CALLED", "1"},
    {"ASL_A1_DONOR_SERVER_MESSAGE_ENTER", "1"},
    {"ASL_A1_GENERATED_DEMUX_HANDLED", "1"},
    {"ASL_A1_CLIENT_SEND_KR", "0"},
    {"ASL_A1_NEG_MALFORMED_PAYLOAD_REJECTED", "1"},
    {"ASL_A1_ARM_END", "malformed_payload"}
  ]
  @invalid_ool_exact [
    {"ASL_A1_ARM_START", "invalid_ool"},
    {"ASL_A1_NEG_INVALID_OOL_DESCRIPTOR_REJECTED", "1"},
    {"ASL_A1_ARM_END", "invalid_ool"}
  ]
  @global_exact [
    {"mach_module", "loaded"},
    {"ASL_A1_PROBE_START", "1"},
    {"ASL_A1_MIG_SUBSYSTEM", "114"},
    {"ASL_A1_MIG_ROUTINE_ID", "118"}
  ]
  @terminal_exact [
    {"ASL_A1_DONE", "1"}
  ]
  @critical_positive_order [
    {"ASL_A1_CLIENT_SEND_STARTED", "1"},
    {"ASL_A1_SERVER_RECEIVE_KR", "0"},
    {"ASL_A1_GENERATED_DEMUX_CALLED", "1"},
    {"ASL_A1_DONOR_SERVER_MESSAGE_ENTER", "1"},
    {"ASL_A1_DONOR_DECODE_OK", "1"},
    {"ASL_A1_PROCESS_MESSAGE_PAYLOAD_MATCH", "1"},
    {"ASL_A1_DONOR_RELEASE_COMPLETED", "1"},
    {"ASL_A1_POSITIVE_DECODE_AND_STUB_CONFIRMED", "1"},
    {"ASL_A1_ARM_END", "positive_decode"}
  ]
  @arm_contracts %{
    "positive_decode" => @positive_exact,
    "malformed_payload" => @malformed_exact,
    "invalid_ool" => @invalid_ool_exact
  }
  @arm_exclusive_keys %{
    "positive_decode" =>
      ~w(ASL_A1_EXPECTED_OOL_BYTE_COUNT ASL_A1_EXPECTED_OOL_SHA256 ASL_A1_DONOR_OOL_BYTES_INTACT ASL_A1_DONOR_DECODE_OK ASL_A1_PROCESS_MESSAGE_STUB_CALLED ASL_A1_PROCESS_MESSAGE_PAYLOAD_MATCH ASL_A1_DONOR_RELEASE_COMPLETED ASL_A1_POSITIVE_DECODE_AND_STUB_CONFIRMED),
    "malformed_payload" => ~w(ASL_A1_NEG_MALFORMED_PAYLOAD_REJECTED),
    "invalid_ool" => ~w(ASL_A1_NEG_INVALID_OOL_DESCRIPTOR_REJECTED)
  }
  @positive_singleton_keys Enum.map(@positive_exact, &elem(&1, 0)) ++
                             ~w(ASL_A1_EXPECTED_OOL_SHA256 ASL_A1_RECEIVED_OOL_SHA256)
  @claim_singleton_keys ~w(
    ASL_A1_AUDIT_CLAIM
    ASL_A1_AUDIT_MATCH
    ASL_A1_AUDIT_UID
    ASL_A1_AUDIT_GID
    ASL_A1_AUDIT_PID
    ASL_A1_DONE
  )
  @transport_infrastructure_exact [
    {"mach_module", "loaded"},
    {"ASL_A1_PROBE_START", "1"},
    {"ASL_A1_MIG_SUBSYSTEM", "114"},
    {"ASL_A1_MIG_ROUTINE_ID", "118"},
    {"ASL_A1_SERVER_RECEIVE_KR", "0"},
    {"ASL_A1_GENERATED_DEMUX_CALLED", "1"},
    {"ASL_A1_GENERATED_DEMUX_HANDLED", "1"},
    {"ASL_A1_NEG_INVALID_OOL_DESCRIPTOR_REJECTED", "1"},
    {"ASL_A1_DONE", "1"}
  ]

  @hard_stop_patterns [
    ~r/panic/i,
    ~r/Fatal trap/i,
    ~r/KASSERT/i,
    ~r/WITNESS:|WITNESS.*lock order|lock order reversal/i,
    ~r/SIGSYS/i,
    ~r/Bad system call/i,
    ~r/UNKNOWN FreeBSD SYSCALL/i,
    ~r/nosys 468/i,
    ~r/signal 12/i,
    ~r/Enter full pathname of shell/i,
    ~r/Consoles:\s+Dual \(Video primary\)/i
  ]

  def run(opts) do
    oracle_repo = Keyword.fetch!(opts, :oracle_repo)
    lane = Keyword.get(opts, :lane, "current-tree")
    host_only? = Keyword.get(opts, :host_only, false)

    out_root =
      Keyword.get(opts, :out_root, Path.join(oracle_repo, "priv/runs/asl-a1"))

    evidence_dir = Path.join(out_root, "#{timestamp()}-asl-server-message-ool")
    File.mkdir_p!(evidence_dir)

    report =
      opts
      |> Map.new()
      |> Map.merge(%{oracle_repo: oracle_repo, lane: lane, evidence_dir: evidence_dir})
      |> materialize_and_build()
      |> maybe_run_guest(host_only?)

    CanonicalJSON.write!(Path.join(evidence_dir, "parity.json"), report)
    report
  end

  def validate_serial(serial) do
    parsed = parse_serial(serial)
    hard_stops = hard_stop_matches(serial)
    global = validate_exact_set(parsed, :global, @global_exact)
    positive = validate_arm(parsed, "positive_decode", @arm_contracts["positive_decode"])
    malformed = validate_arm(parsed, "malformed_payload", @arm_contracts["malformed_payload"])
    invalid_ool = validate_arm(parsed, "invalid_ool", @arm_contracts["invalid_ool"])
    terminal = validate_terminal(parsed)
    duplicates = duplicate_errors(parsed)
    contradictions = contradiction_errors(parsed)
    order_errors = order_errors(parsed)
    ool = validate_ool_integrity(parsed)
    audit = audit_result(parsed)

    errors =
      global.errors ++
        positive.errors ++
        malformed.errors ++
        invalid_ool.errors ++
        terminal.errors ++
        duplicates ++
        contradictions ++
        order_errors ++
        ool.errors ++
        audit_errors(audit) ++ hard_stop_error(hard_stops)

    %{
      "schema" => "rmxos_oracle.asl_a1.marker_validation.v2",
      "passed" => errors == [],
      "errors" => errors,
      "arms" => %{
        "positive_decode" => positive.report,
        "malformed_payload" => malformed.report,
        "invalid_ool" => invalid_ool.report,
        "terminal" => terminal.report
      },
      "ool_integrity" => ool.report,
      "hard_stop_matches" => hard_stops,
      "audit_result" => audit
    }
  end

  def validate_transport_serial(serial) do
    parsed = parse_serial(serial)
    validation = validate_exact_set(parsed, :all, @transport_infrastructure_exact)

    %{
      "schema" => "rmxos_oracle.asl_a1.transport_infrastructure_validation.v1",
      "passed" => validation.errors == [] and hard_stop_matches(serial) == [],
      "classification" => "transport_infrastructure_only",
      "errors" => validation.errors,
      "accepted_claim" => "not_accepted"
    }
  end

  def hard_stop_scan(serial) when is_binary(serial) do
    matches = hard_stop_matches(serial)

    %{
      "schema" => "rmxos_oracle.asl_a1.hard_stop_scan.v1",
      "passed" => matches == [],
      "patterns" => Enum.map(@hard_stop_patterns, &Regex.source/1),
      "matches" => matches
    }
  end

  def revalidate_evidence(evidence_dir) do
    serial_path = Path.join(evidence_dir, "asl_a1_serial.log")
    boot_identity_path = Path.join(evidence_dir, "boot_identity.json")
    serial = File.read!(serial_path)
    boot_identity = CanonicalJSON.decode!(boot_identity_path)
    marker_validation = validate_serial(serial)
    hard_stop_scan = hard_stop_scan(serial)
    negative_controls = negative_controls(serial)
    donor_provenance = verify_build_provenance(evidence_dir)
    transport = validate_transport_serial(serial)

    passed =
      boot_identity["passed"] and marker_validation["passed"] and hard_stop_scan["passed"] and
        negative_controls["passed"] and donor_provenance["passed"]

    claim =
      if passed and marker_validation["audit_result"]["status"] == "accepted" do
        "ool_transport_decode_plus_audit_identity"
      else
        "not_accepted"
      end

    %{
      "schema" => "rmxos_oracle.asl_a1.revalidation.v2",
      "status" => if(passed, do: "pass", else: "fail"),
      "passed" => passed,
      "classification" =>
        if(passed, do: "accepted_a1_evidence", else: "transport_infrastructure_only"),
      "evidence_dir" => evidence_dir,
      "serial_path" => "asl_a1_serial.log",
      "serial_sha256" => sha256_file(serial_path),
      "boot_identity_ref" => "boot_identity.json",
      "boot_identity_passed" => boot_identity["passed"],
      "marker_validation_passed" => marker_validation["passed"],
      "marker_validation_errors" => marker_validation["errors"],
      "hard_stop_scan_passed" => hard_stop_scan["passed"],
      "hard_stop_matches" => hard_stop_scan["matches"],
      "negative_controls_passed" => negative_controls["passed"],
      "donor_build_provenance_passed" => donor_provenance["passed"],
      "donor_build_provenance_errors" => donor_provenance["errors"],
      "transport_infrastructure_validation" => transport,
      "audit_result" => marker_validation["audit_result"],
      "accepted_claim" => claim,
      "guest_run_performed" => false,
      "raw_evidence_mutated" => false
    }
  end

  def negative_controls(serial) do
    controls = [
      falsifier(serial, "wrong_required_value", "ASL_A1_DONE=1", "ASL_A1_DONE=10"),
      falsifier(serial, "missing_terminal", "ASL_A1_DONE=1", "ASL_A1_DONE_REMOVED=1"),
      falsifier(serial, "duplicated_terminal", "ASL_A1_DONE=1", "ASL_A1_DONE=1\nASL_A1_DONE=1"),
      falsifier(
        serial,
        "duplicated_positive_only_marker",
        "ASL_A1_DONOR_DECODE_OK=1",
        "ASL_A1_DONOR_DECODE_OK=1\nASL_A1_DONOR_DECODE_OK=1"
      ),
      falsifier(
        serial,
        "contradictory_claim_marker",
        "ASL_A1_AUDIT_CLAIM=accepted",
        "ASL_A1_AUDIT_CLAIM=accepted\nASL_A1_AUDIT_CLAIM=deferred"
      ),
      invalid_order_falsifier(serial),
      terminal_order_falsifier(serial),
      falsifier(
        serial,
        "demux_without_donor_entry",
        "ASL_A1_DONOR_SERVER_MESSAGE_ENTER=1",
        "ASL_A1_DONOR_SERVER_MESSAGE_ENTER_REMOVED=1"
      ),
      falsifier(
        serial,
        "donor_entry_without_decode_ok",
        "ASL_A1_DONOR_DECODE_OK=1",
        "ASL_A1_DONOR_DECODE_OK_REMOVED=1"
      ),
      falsifier(
        serial,
        "toy_receiver_without_donor_decode",
        "ASL_A1_DONOR_SERVER_MESSAGE_ENTER=1",
        "ASL_A1_TOY_RECEIVER_ONLY=1"
      ),
      audit_mismatch(serial),
      audit_zeroed(serial),
      altered_payload_falsifier(serial),
      same_length_payload_falsifier(serial),
      appended_payload_falsifier(serial),
      equal_fake_hashes_falsifier(serial),
      equal_wrong_counts_falsifier(serial),
      malformed_receive_conflict_falsifier(serial),
      malformed_duplicate_send_falsifier(serial),
      malformed_missing_donor_falsifier(serial),
      malformed_unexpected_decode_falsifier(serial),
      invalid_ool_conflict_falsifier(serial),
      invalid_ool_duplicate_falsifier(serial),
      cross_arm_contamination_falsifier(serial),
      conflicting_boundary_falsifier(serial)
    ]

    %{
      "schema" => "rmxos_oracle.asl_a1.negative_controls.v1",
      "passed" => Enum.all?(controls, & &1["passed"]),
      "controls" => controls,
      "limitations" => [
        "negative controls mutate or synthesize serial evidence; they prove verifier red-path behavior, not additional guest behavior"
      ]
    }
  end

  def static_marker_manifest_check(source) do
    matches =
      Regex.scan(~r/(ASL_A\d+_|:asl_a\d+|asl_a\d+)/, source)
      |> Enum.map(&List.first/1)
      |> Enum.uniq()

    %{
      "schema" => "rmxos_oracle.asl_a1.static_marker_manifest_check.v1",
      "passed" => matches == [],
      "forbidden_matches" => matches,
      "rule" => "ASL A1 must not add marker manifest entries before accepted evidence review"
    }
  end

  def static_donor_ownership_check(probe_source) do
    forbidden = [
      ~r/\basl_msg_from_string\s*\([^;]*\)\s*\{/s,
      ~r/\b__asl_server_message\s*\([^;]*\)\s*\{/s,
      ~r/\basl_release\s*\([^;]*\)\s*\{/s
    ]

    matches =
      Enum.flat_map(forbidden, fn pattern ->
        Regex.scan(pattern, probe_source) |> Enum.map(&List.first/1)
      end)

    %{
      "schema" => "rmxos_oracle.asl_a1.static_donor_ownership_check.v1",
      "passed" =>
        matches == [] and
          String.contains?(probe_source, "rmx_asl_a1_donor_msg_release(msg);"),
      "forbidden_project_owned_implementations" => matches,
      "rule" =>
        "project probe must not implement donor decoder/release functions and must call donor-derived bounded release"
    }
  end

  defp materialize_and_build(ctx) do
    evidence_dir = ctx.evidence_dir
    oracle_repo = ctx.oracle_repo
    env_report = Env.check(ctx.lane, env_path: Map.get(ctx, :env_path, "priv/env/env.local"))
    host_dir = Path.join(evidence_dir, "host")
    donor_dir = Path.join(host_dir, "donor")
    generated_dir = Path.join(host_dir, "generated")
    build_dir = Path.join(host_dir, "build")
    log_dir = Path.join(evidence_dir, "logs")
    File.mkdir_p!(log_dir)
    File.mkdir_p!(donor_dir)
    File.mkdir_p!(generated_dir)
    File.mkdir_p!(build_dir)

    oracle_commit = git!(oracle_repo, ["rev-parse", "HEAD"])
    source_commit = git!(@source_repo, ["rev-parse", "HEAD"])
    donor_resolved = git!(@donor_root, ["rev-parse", "#{@donor_commit}^{commit}"])

    fail_unless(
      donor_resolved == @donor_commit,
      "donor commit mismatch: #{donor_resolved} != #{@donor_commit}"
    )

    fail_unless(
      source_commit == @source_authorization_commit,
      "source authorization commit mismatch: #{source_commit} != #{@source_authorization_commit}"
    )

    archive = Path.join(host_dir, "donor-asl.tar")

    run_cmd!(
      "donor archive",
      "git",
      ["-C", @donor_root, "archive", "--format=tar", "--output=#{archive}", @donor_commit, "--"] ++
        @donor_archive_paths,
      Path.join(log_dir, "donor_archive.log")
    )

    run_cmd!(
      "donor extract",
      "tar",
      ["-xf", archive, "-C", donor_dir],
      Path.join(log_dir, "donor_extract.log")
    )

    defs_path = Path.join(donor_dir, @defs_rel)
    donor_hashes = donor_hashes(donor_dir, [@defs_rel | @donor_decode_refs])
    CanonicalJSON.write!(Path.join(evidence_dir, "donor_hashes.json"), donor_hashes)

    m7a_workdir =
      Path.join(env_report["workspace_root"] || "/Users/me/wip-mach", "build/m7a-libmach-work")

    m7a_prefix =
      Path.join(env_report["workspace_root"] || "/Users/me/wip-mach", "build/m7a-libmach-prefix")

    mig = Path.join(m7a_workdir, "tools/bin/mig")
    freebsd_src = env_report["freebsd_src"]

    fail_unless(File.regular?(mig), "missing MIG tool: #{mig}")
    fail_unless(File.dir?(m7a_prefix), "missing libmach prefix: #{m7a_prefix}")

    mig_log = Path.join(log_dir, "mig-asl-ipc.log")

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
        defs_path
      ],
      mig_log
    )

    probe_source = Path.join(oracle_repo, @probe_rel)
    probe_copy = Path.join(build_dir, "a1_server_message_ool.c")
    File.cp!(probe_source, probe_copy)
    extraction = extract_donor_server_message!(donor_dir, generated_dir)
    release_extraction = extract_donor_release!(donor_dir, generated_dir)

    cc = System.get_env("CC") || "cc"

    cflags = [
      "-O2",
      "-Wall",
      "-Wextra",
      "-ffunction-sections",
      "-fdata-sections",
      "-pthread",
      "-I#{generated_dir}",
      "-I#{m7a_prefix}/include",
      "-I#{m7a_prefix}/include/apple",
      "-I#{donor_dir}/lib/libasl",
      "-I#{donor_dir}/lib/libnotify",
      "-I#{donor_dir}/lib/libosxsupport",
      "-I#{donor_dir}/lib/libdispatch",
      "-I#{donor_dir}/contrib/openbsm",
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
      Path.join(donor_dir, @donor_codec_rel),
      Path.join(build_dir, "donor_asl_msg.o"),
      log_dir
    )

    compile_object(
      cc,
      cflags,
      extraction.wrapper_path,
      Path.join(build_dir, "donor_asl_server_message.o"),
      log_dir
    )

    compile_object(
      cc,
      cflags,
      release_extraction.wrapper_path,
      Path.join(build_dir, "donor_asl_release.o"),
      log_dir
    )

    compile_object(
      cc,
      cflags,
      Path.join(generated_dir, "asl_ipc_server.c"),
      Path.join(build_dir, "asl_ipc_server.o"),
      log_dir
    )

    compile_object(
      cc,
      cflags,
      probe_copy,
      Path.join(build_dir, "a1_server_message_ool.o"),
      log_dir
    )

    probe_binary = Path.join(build_dir, "asl-a1-server-message-ool")
    link_map = Path.join(build_dir, "asl-a1-server-message-ool.map")

    run_cmd!(
      "link ASL A1 probe",
      cc,
      [
        Path.join(build_dir, "a1_server_message_ool.o"),
        Path.join(build_dir, "asl_ipc_user.o"),
        Path.join(build_dir, "asl_ipc_server.o"),
        Path.join(build_dir, "donor_asl_msg.o"),
        Path.join(build_dir, "donor_asl_server_message.o"),
        Path.join(build_dir, "donor_asl_release.o"),
        "-Wl,--gc-sections",
        "-Wl,-Map,#{link_map}",
        "-L#{m7a_prefix}/lib",
        "-lmach",
        "-lmach-traps",
        "-lbsm",
        "-lmd",
        "-pthread",
        "-o",
        probe_binary
      ],
      Path.join(log_dir, "probe-link.log")
    )

    generated_hashes =
      generated_hashes(generated_dir, build_dir, probe_source, probe_copy, probe_binary)

    CanonicalJSON.write!(Path.join(evidence_dir, "generated_mig_hashes.json"), generated_hashes)
    CanonicalJSON.write!(Path.join(evidence_dir, "probe_hashes.json"), generated_hashes["probe"])

    donor_build_provenance =
      donor_build_provenance(
        donor_dir,
        build_dir,
        probe_binary,
        link_map,
        cc,
        cflags,
        extraction,
        release_extraction
      )

    CanonicalJSON.write!(
      Path.join(evidence_dir, "donor_build_provenance.json"),
      donor_build_provenance
    )

    provenance_verification = verify_build_provenance(evidence_dir)
    provenance_falsifiers = provenance_falsifiers(evidence_dir)

    CanonicalJSON.write!(
      Path.join(evidence_dir, "provenance_verification.json"),
      provenance_verification
    )

    CanonicalJSON.write!(
      Path.join(evidence_dir, "provenance_negative_controls.json"),
      provenance_falsifiers
    )

    static_report =
      oracle_repo
      |> Path.join("lib/phase08/marker_manifest.ex")
      |> File.read!()
      |> static_marker_manifest_check()

    donor_ownership_report = static_donor_ownership_check(File.read!(probe_source))

    CanonicalJSON.write!(Path.join(evidence_dir, "static_checks.json"), %{
      "schema" => "rmxos_oracle.asl_a1.static_checks.v1",
      "marker_manifest" => static_report,
      "donor_ownership" => donor_ownership_report
    })

    host_report = %{
      "schema" => "rmxos_oracle.asl_a1.host_checks.v1",
      "status" =>
        if(
          env_report["status"] == "pass" and static_report["passed"] and
            donor_ownership_report["passed"] and donor_build_provenance["passed"] and
            provenance_verification["passed"] and provenance_falsifiers["passed"],
          do: "pass",
          else: "fail"
        ),
      "mig_regeneration_passed" => true,
      "generated_stub_compile_passed" => true,
      "donor_decoder_compile_link_passed" => donor_build_provenance["passed"],
      "cryptographic_provenance_verification_passed" => provenance_verification["passed"],
      "cryptographic_provenance_falsifiers_passed" => provenance_falsifiers["passed"],
      "donor_extraction_exact" => extraction.exact,
      "donor_release_extraction_exact" => release_extraction.exact,
      "static_marker_manifest_check_passed" => static_report["passed"],
      "static_donor_ownership_check_passed" => donor_ownership_report["passed"],
      "env_check_passed" => env_report["status"] == "pass",
      "env_errors" => env_report["errors"],
      "mig_subsystem" => @mig_subsystem,
      "mig_routine_id" => @mig_routine_id,
      "donor_build_provenance_ref" => "donor_build_provenance.json"
    }

    CanonicalJSON.write!(Path.join(evidence_dir, "host_checks.json"), host_report)
    CanonicalJSON.write!(Path.join(evidence_dir, "env_resolved.json"), env_report)

    fail_unless(host_report["status"] == "pass", "ASL A1 host checks failed")

    Map.merge(ctx, %{
      env_report: env_report,
      oracle_commit: oracle_commit,
      source_commit: source_commit,
      donor_hashes: donor_hashes,
      donor_build_provenance: donor_build_provenance,
      provenance_verification: provenance_verification,
      generated_hashes: generated_hashes,
      host_report: host_report,
      probe_binary: probe_binary
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
    serial_log = env["NXPLATFORM_SERIAL_LOG"]
    ctx = Map.put(ctx, :source_tools, materialize_source_tools!(evidence_dir))

    stage_guest(ctx, env)
    install_asl_probe(ctx, env)

    run_guest(ctx, env)
    serial = File.read!(serial_log)
    File.cp!(serial_log, Path.join(evidence_dir, "asl_a1_serial.log"))

    boot_identity = boot_identity(ctx, env, serial)
    marker_validation = validate_serial(serial)
    hard_stop_scan = hard_stop_scan(serial)
    negatives = negative_controls(serial)

    CanonicalJSON.write!(Path.join(evidence_dir, "boot_identity.json"), boot_identity)
    CanonicalJSON.write!(Path.join(evidence_dir, "marker_validation.json"), marker_validation)
    CanonicalJSON.write!(Path.join(evidence_dir, "hard_stop_scan.json"), hard_stop_scan)
    CanonicalJSON.write!(Path.join(evidence_dir, "negative_controls.json"), negatives)

    passed =
      boot_identity["passed"] and marker_validation["passed"] and hard_stop_scan["passed"] and
        negatives["passed"] and ctx.donor_build_provenance["passed"]

    claim = accepted_claim(passed, marker_validation["audit_result"])

    base_report(ctx, if(passed, do: "parity_passed", else: "parity_failed"))
    |> Map.merge(%{
      "host_only" => false,
      "parity_passed" => passed,
      "behavior_passed" => marker_validation["passed"],
      "boot_identity_passed" => boot_identity["passed"],
      "marker_comparison_passed" => marker_validation["passed"],
      "hard_stop_scan_passed" => hard_stop_scan["passed"],
      "negative_control_passed" => negatives["passed"],
      "donor_build_provenance_passed" => ctx.donor_build_provenance["passed"],
      "claim" => claim,
      "audit_result" => marker_validation["audit_result"],
      "serial_log" => "asl_a1_serial.log",
      "environment_ref" => "env_resolved.json",
      "boot_identity_ref" => "boot_identity.json",
      "marker_validation_ref" => "marker_validation.json",
      "hard_stop_scan_ref" => "hard_stop_scan.json",
      "negative_controls_ref" => "negative_controls.json",
      "limitations" => [
        "no certification claim",
        "no launchd MachServices/com.apple.system.logger handoff claim",
        "no storage/query/syslog/aslmanager/XPC claim",
        "audit identity is conditional and deferred unless token UID/GID/PID match sender",
        "ASL marker manifest entries are intentionally not authored in this pass"
      ]
    })
  end

  defp base_report(ctx, status) do
    %{
      "schema" => @evidence_schema,
      "slice_id" => @slice_id,
      "status" => status,
      "evidence_dir" => ctx.evidence_dir,
      "comparison_axis" => "oracle_runtime_claim",
      "observation_basis" =>
        if(status == "host_checks_passed", do: "host_build_probe", else: "L2_guest_integration"),
      "oracle_commit" => ctx.oracle_commit,
      "source_authorization_commit" => @source_authorization_commit,
      "source_repo_commit" => ctx.source_commit,
      "oracle_a0_classification_commit" => @oracle_a0_commit,
      "oracle_a1_design_commit" => @oracle_a1_design_commit,
      "donor_asl_source" => %{
        "path" => @donor_root,
        "commit" => @donor_commit,
        "mig_contract" => @defs_rel,
        "decode_refs" => @donor_decode_refs
      },
      "legacy_commit" => @donor_commit,
      "legacy_test_commit" => nil,
      "mig" => %{
        "subsystem" => @mig_subsystem,
        "routine" => "_asl_server_message",
        "routine_id" => @mig_routine_id
      },
      "donor_hashes_ref" => "donor_hashes.json",
      "donor_build_provenance_ref" => "donor_build_provenance.json",
      "generated_mig_hashes_ref" => "generated_mig_hashes.json",
      "probe_hashes_ref" => "probe_hashes.json",
      "host_checks_ref" => "host_checks.json",
      "negative_api_passed" => nil,
      "negative_mix_test_passed" => nil
    }
  end

  defp compile_object(cc, cflags, source, object, log_dir) do
    run_cmd!(
      "compile #{Path.basename(source)}",
      cc,
      cflags ++ ["-c", source, "-o", object],
      Path.join(log_dir, "#{Path.basename(source)}.compile.log")
    )
  end

  defp stage_guest(ctx, env) do
    log = Path.join(ctx.evidence_dir, "stage_guest.log")
    stage_tool = Map.fetch!(ctx.source_tools, @stage_tool)

    run_cmd!(
      "stage guest",
      stage_tool,
      [],
      log,
      env:
        env_for_cmd(
          Map.merge(env, %{
            "NXPLATFORM_PROBE_MODE" => "asl_a1_boot_identity",
            "NXPLATFORM_PROBE_SHUTDOWN" => "NO",
            "NXPLATFORM_EXPECT_KERNEL" => env["NXPLATFORM_KERNEL_CONF"]
          })
        )
    )
  end

  defp install_asl_probe(ctx, env) do
    evidence_dir = ctx.evidence_dir
    vm_image = env["NXPLATFORM_VM_IMAGE"]
    guest_root = env["NXPLATFORM_GUEST_ROOT"]
    log = Path.join(evidence_dir, "install_asl_probe.log")
    rc_path = Path.join(evidence_dir, "nxplatform_asl_a1.rc")
    File.write!(rc_path, asl_rc_script())

    File.mkdir_p!(guest_root)

    mddev =
      run_cmd!("mdconfig attach", "doas", ["mdconfig", "-a", "-t", "vnode", "-f", vm_image], log).out
      |> String.trim()

    try do
      root_part =
        run_cmd!("gpart list", "doas", ["gpart", "list", mddev], log)
        |> Map.fetch!(:out)
        |> root_partition!()

      run_cmd("fsck guest", "doas", ["fsck", "-p", root_part], log)

      run_cmd!(
        "mount guest",
        "doas",
        ["mount", "-o", "rw", "-t", "ufs", root_part, guest_root],
        log
      )

      run_cmd!(
        "mkdir ASL dir",
        "doas",
        ["install", "-d", "-m", "755", "#{guest_root}/root/nxplatform/asl"],
        log
      )

      run_cmd!(
        "install ASL probe",
        "doas",
        [
          "install",
          "-m",
          "755",
          ctx.probe_binary,
          "#{guest_root}/root/nxplatform/asl/asl-a1-server-message-ool"
        ],
        log
      )

      run_cmd!(
        "install ASL rc",
        "doas",
        ["install", "-m", "755", rc_path, "#{guest_root}/etc/rc.d/nxplatform_asl_a1"],
        log
      )

      append_if_missing("#{guest_root}/etc/rc.conf", "nxplatform_asl_a1_enable=\"YES\"", log)
    after
      run_cmd("umount guest", "doas", ["umount", guest_root], log)

      run_cmd(
        "mdconfig detach",
        "doas",
        ["mdconfig", "-d", "-u", String.replace_prefix(mddev, "md", "")],
        log
      )
    end
  end

  defp run_guest(ctx, env) do
    run_tool = Map.fetch!(ctx.source_tools, @run_tool)
    log = Path.join(ctx.evidence_dir, "run_guest.log")

    run_cmd!(
      "run guest stdin isolated",
      "sh",
      ["-c", "exec \"$1\" < /dev/null", "oracle-asl-a1-runner", run_tool],
      log,
      env: env_for_cmd(env)
    )
  end

  defp guest_env(ctx) do
    env_report = ctx.env_report
    workspace_root = env_report["workspace_root"]
    kernel_conf = System.get_env("NXPLATFORM_KERNEL_CONF") || @default_kernel_conf
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
      "NXPLATFORM_SERIAL_LOG" => Path.join(ctx.evidence_dir, "asl_a1_serial.raw.log"),
      "NXPLATFORM_GUEST_SUCCESS_MARKER" => @success_marker
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
      "schema" => "rmxos_oracle.asl_a1.boot_identity.v1",
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
        serial
        |> String.split("\n")
        |> Enum.any?(&(&1 == "mach_module=loaded"))
    }

    Map.put(
      fields,
      "passed",
      fields["mach_module_loaded_marker"] and present_hash?(fields["kernel"]) and
        present_hash?(fields["mach_ko"]) and present_hash?(fields["guest_image"])
    )
  end

  defp hard_stop_matches(serial) do
    Enum.flat_map(@hard_stop_patterns, fn pattern ->
      Regex.scan(pattern, serial)
      |> Enum.map(fn [match | _] -> %{"pattern" => Regex.source(pattern), "match" => match} end)
    end)
  end

  defp parse_serial(serial) do
    lines =
      serial
      |> String.split("\n")
      |> Enum.map(&String.trim_trailing(&1, "\r"))

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

  defp validate_exact_set(parsed, scope, required) do
    entries = if scope == :all, do: parsed.entries, else: parsed.entries

    errors =
      Enum.flat_map(required, fn {key, value} ->
        case Enum.count(entries, &(&1.key == key and &1.value == value)) do
          0 -> ["missing exact marker #{key}=#{value}"]
          _ -> []
        end
      end)

    %{errors: errors, report: %{"passed" => errors == [], "errors" => errors}}
  end

  defp validate_arm(parsed, arm, required) do
    start_line = "ASL_A1_ARM_START=#{arm}"
    end_line = "ASL_A1_ARM_END=#{arm}"
    starts = exact_line_indices(parsed, start_line)
    ends = exact_line_indices(parsed, end_line)

    {entries, boundary_errors} =
      case {starts, ends} do
        {[start_index], [end_index]} when start_index < end_index ->
          {
            Enum.filter(parsed.entries, &(&1.index >= start_index and &1.index <= end_index)),
            []
          }

        _ ->
          {[],
           [
             "arm #{arm} requires exactly one ordered start/end boundary; starts=#{inspect(starts)} ends=#{inspect(ends)}"
           ]}
      end

    contract_keys = required |> Enum.map(&elem(&1, 0)) |> MapSet.new()

    marker_errors =
      Enum.flat_map(required, fn {key, value} ->
        matching_key = Enum.filter(entries, &(&1.key == key))
        exact_count = Enum.count(matching_key, &(&1.value == value))

        cond do
          exact_count == 1 and length(matching_key) == 1 ->
            []

          matching_key == [] ->
            ["arm #{arm} missing exact marker #{key}=#{value}"]

          true ->
            [
              "arm #{arm} contractual marker #{key} must occur exactly once as #{key}=#{value}; got #{inspect(Enum.map(matching_key, & &1.value))}"
            ]
        end
      end)

    order_errors = arm_order_errors(arm, entries, required)

    contamination_errors =
      @arm_exclusive_keys
      |> Enum.reject(fn {owner, _keys} -> owner == arm end)
      |> Enum.flat_map(fn {owner, keys} ->
        entries
        |> Enum.filter(&(&1.key in keys))
        |> Enum.map(fn entry ->
          "arm #{arm} contains #{owner}-exclusive marker #{entry.line}"
        end)
      end)

    unknown_contract_conflicts =
      entries
      |> Enum.filter(&MapSet.member?(contract_keys, &1.key))
      |> Enum.group_by(& &1.key, & &1.value)
      |> Enum.flat_map(fn {key, values} ->
        if length(Enum.uniq(values)) > 1,
          do: [
            "arm #{arm} has conflicting values for contractual marker #{key}: #{inspect(values)}"
          ],
          else: []
      end)

    errors =
      boundary_errors ++
        marker_errors ++ order_errors ++ contamination_errors ++ unknown_contract_conflicts

    %{errors: errors, report: %{"passed" => errors == [], "errors" => errors}}
  end

  defp arm_order_errors(_arm, [], _required), do: []

  defp arm_order_errors(arm, entries, required) do
    {_last, errors} =
      Enum.reduce(required, {-1, []}, fn {key, value} = marker, {last, errors} ->
        indices =
          entries
          |> Enum.filter(&(&1.key == key and &1.value == value))
          |> Enum.map(& &1.index)

        case indices do
          [index] when index > last ->
            {index, errors}

          [index] ->
            {last,
             errors ++ ["arm #{arm} marker out of order: #{format_marker(marker)} at #{index}"]}

          _ ->
            {last, errors}
        end
      end)

    errors
  end

  defp validate_terminal(parsed) do
    marker_errors =
      Enum.flat_map(@terminal_exact, fn {key, value} ->
        count = Enum.count(parsed.entries, &(&1.key == key and &1.value == value))

        if count == 1,
          do: [],
          else: ["terminal requires exactly one #{key}=#{value}; got #{count}"]
      end)

    start_count = Enum.count(parsed.lines, &(&1 == @start_marker))
    end_count = Enum.count(parsed.lines, &(&1 == @success_marker))
    done_index = exact_marker_index(parsed, {"ASL_A1_DONE", "1"})
    end_indices = exact_line_indices(parsed, @success_marker)

    arm_end_indices =
      Enum.map(~w(positive_decode malformed_payload invalid_ool), fn arm ->
        exact_line_indices(parsed, "ASL_A1_ARM_END=#{arm}")
      end)

    order_errors =
      case {done_index, end_indices, arm_end_indices} do
        {done, [ending], [[positive_end], [malformed_end], [invalid_ool_end]]}
        when is_integer(done) and positive_end < done and malformed_end < done and
               invalid_ool_end < done and done < ending ->
          []

        _ ->
          [
            "terminal ASL_A1_DONE=1 must follow all arm endings and precede exactly one #{@success_marker}"
          ]
      end

    errors =
      marker_errors ++
        count_error(start_count, 1, "start marker") ++
        count_error(end_count, 1, "end rc=0 marker") ++ order_errors

    %{errors: errors, report: %{"passed" => errors == [], "errors" => errors}}
  end

  defp duplicate_errors(parsed) do
    positive_entries = arm_entries(parsed, "positive_decode")

    Enum.flat_map(Enum.uniq(@positive_singleton_keys), fn key ->
      count = Enum.count(positive_entries, &(&1.key == key))
      if count > 1, do: ["unexpected duplicate positive-only marker #{key}: #{count}"], else: []
    end)
  end

  defp contradiction_errors(parsed) do
    Enum.flat_map(@claim_singleton_keys, fn key ->
      values = parsed.entries |> Enum.filter(&(&1.key == key)) |> Enum.map(& &1.value)

      cond do
        length(values) > 1 ->
          ["contradictory or duplicate singleton marker #{key}: #{inspect(values)}"]

        true ->
          []
      end
    end)
  end

  defp order_errors(parsed) do
    positive_entries = arm_entries(parsed, "positive_decode")

    {_last, errors} =
      Enum.reduce(@critical_positive_order, {-1, []}, fn marker, {last, errors} ->
        indices =
          positive_entries
          |> Enum.filter(&(&1.key == elem(marker, 0) and &1.value == elem(marker, 1)))
          |> Enum.map(& &1.index)

        case indices do
          [index] when index > last ->
            {index, errors}

          [index] ->
            {last,
             errors ++ ["critical marker out of order: #{format_marker(marker)} at #{index}"]}

          _ ->
            {last, errors ++ ["critical marker missing or duplicated: #{format_marker(marker)}"]}
        end
      end)

    errors
  end

  defp validate_ool_integrity(parsed) do
    positive = arm_entries(parsed, "positive_decode")
    expected_count = unique_value(positive, "ASL_A1_EXPECTED_OOL_BYTE_COUNT")
    received_count = unique_value(positive, "ASL_A1_RECEIVED_OOL_BYTE_COUNT")
    expected_hash = unique_value(positive, "ASL_A1_EXPECTED_OOL_SHA256")
    received_hash = unique_value(positive, "ASL_A1_RECEIVED_OOL_SHA256")
    intact = unique_value(positive, "ASL_A1_DONOR_OOL_BYTES_INTACT")

    errors =
      []
      |> maybe_add(expected_count == nil, "missing unique expected OOL byte count")
      |> maybe_add(received_count == nil, "missing unique received OOL byte count")
      |> maybe_add(
        expected_count != received_count,
        "expected and received OOL byte counts differ"
      )
      |> maybe_add(
        expected_count != @expected_ool_byte_count,
        "expected OOL byte count does not match Oracle-pinned count #{@expected_ool_byte_count}"
      )
      |> maybe_add(
        received_count != @expected_ool_byte_count,
        "received OOL byte count does not match Oracle-pinned count #{@expected_ool_byte_count}"
      )
      |> maybe_add(
        not valid_sha256?(expected_hash),
        "expected OOL SHA256 is missing or malformed"
      )
      |> maybe_add(
        not valid_sha256?(received_hash),
        "received OOL SHA256 is missing or malformed"
      )
      |> maybe_add(expected_hash != received_hash, "expected and received OOL SHA256 differ")
      |> maybe_add(
        expected_hash != @expected_ool_sha256,
        "expected OOL SHA256 does not match Oracle-pinned payload hash"
      )
      |> maybe_add(
        received_hash != @expected_ool_sha256,
        "received OOL SHA256 does not match Oracle-pinned payload hash"
      )
      |> maybe_add(intact != "1", "full OOL payload equality marker is not 1")

    %{
      errors: errors,
      report: %{
        "passed" => errors == [],
        "expected_byte_count" => expected_count,
        "received_byte_count" => received_count,
        "expected_sha256" => expected_hash,
        "received_sha256" => received_hash,
        "errors" => errors
      }
    }
  end

  defp audit_result(parsed) do
    claim = unique_value(parsed.entries, "ASL_A1_AUDIT_CLAIM")
    match = unique_value(parsed.entries, "ASL_A1_AUDIT_MATCH")
    uid = unique_value(parsed.entries, "ASL_A1_AUDIT_UID")
    gid = unique_value(parsed.entries, "ASL_A1_AUDIT_GID")
    pid = unique_value(parsed.entries, "ASL_A1_AUDIT_PID")
    client_uid = unique_value(parsed.entries, "ASL_A1_CLIENT_UID")
    client_gid = unique_value(parsed.entries, "ASL_A1_CLIENT_GID")
    client_pid = unique_value(parsed.entries, "ASL_A1_CLIENT_PID")

    cond do
      claim == "accepted" and match == "1" and pid not in [nil, "0"] and
          {uid, gid, pid} == {client_uid, client_gid, client_pid} ->
        %{
          "status" => "accepted",
          "uid" => uid,
          "gid" => gid,
          "pid" => pid
        }

      claim == "deferred" ->
        %{
          "status" => "deferred",
          "reason" =>
            unique_value(parsed.entries, "ASL_A1_AUDIT_DEFER_REASON") ||
              "audit_identity_not_claimed"
        }

      true ->
        %{
          "status" => "missing_or_malformed",
          "claim" => claim,
          "match" => match,
          "uid" => uid,
          "gid" => gid,
          "pid" => pid
        }
    end
  end

  defp audit_errors(%{"status" => status}) when status in ["accepted", "deferred"], do: []
  defp audit_errors(audit), do: ["audit identity claim malformed: #{inspect(audit)}"]

  defp hard_stop_error([]), do: []
  defp hard_stop_error(matches), do: ["hard-stop matches present: #{inspect(matches)}"]

  defp falsifier(serial, id, original, replacement) do
    mutated = replace_once(serial, original, replacement)
    result = validate_serial(mutated)

    %{
      "id" => id,
      "passed" =>
        original != replacement and String.contains?(serial, original) and not result["passed"],
      "observed_errors" => result["errors"]
    }
  end

  defp audit_mismatch(serial) do
    if unique_value(parse_serial(serial).entries, "ASL_A1_AUDIT_CLAIM") == "accepted" do
      mutated = replace_once(serial, "ASL_A1_AUDIT_MATCH=1", "ASL_A1_AUDIT_MATCH=0")
      result = validate_serial(mutated)

      %{
        "id" => "audit_identity_mismatch",
        "passed" => not result["passed"],
        "expected_failure" => "accepted audit claim requires ASL_A1_AUDIT_MATCH=1",
        "observed_audit_status" => result["audit_result"]["status"]
      }
    else
      %{
        "id" => "audit_identity_mismatch",
        "passed" => true,
        "not_applicable" => true,
        "reason" => "audit identity was deferred, not claimed"
      }
    end
  end

  defp audit_zeroed(serial) do
    parsed = parse_serial(serial)

    if unique_value(parsed.entries, "ASL_A1_AUDIT_CLAIM") == "accepted" do
      mutated =
        serial
        |> replace_once(
          "ASL_A1_AUDIT_PID=#{unique_value(parsed.entries, "ASL_A1_AUDIT_PID")}",
          "ASL_A1_AUDIT_PID=0"
        )

      result = validate_serial(mutated)

      %{
        "id" => "audit_identity_zeroed",
        "passed" => not result["passed"],
        "observed_errors" => result["errors"]
      }
    else
      %{"id" => "audit_identity_zeroed", "passed" => true, "not_applicable" => true}
    end
  end

  defp invalid_order_falsifier(serial) do
    first = "ASL_A1_GENERATED_DEMUX_CALLED=1"
    second = "ASL_A1_DONOR_SERVER_MESSAGE_ENTER=1"
    mutated = swap_first(serial, first, second)
    result = validate_serial(mutated)

    %{
      "id" => "invalid_critical_path_order",
      "passed" => mutated != serial and not result["passed"],
      "observed_errors" => result["errors"]
    }
  end

  defp terminal_order_falsifier(serial) do
    mutated = swap_first(serial, "ASL_A1_ARM_END=invalid_ool", "ASL_A1_DONE=1")
    result = validate_serial(mutated)

    %{
      "id" => "terminal_before_arm_completion",
      "passed" => mutated != serial and not result["passed"],
      "observed_errors" => result["errors"]
    }
  end

  defp altered_payload_falsifier(serial) do
    falsifier(
      serial,
      "altered_payload_full_equality",
      "ASL_A1_DONOR_OOL_BYTES_INTACT=1",
      "ASL_A1_DONOR_OOL_BYTES_INTACT=0"
    )
  end

  defp same_length_payload_falsifier(serial) do
    parsed = parse_serial(serial)
    hash = unique_value(arm_entries(parsed, "positive_decode"), "ASL_A1_RECEIVED_OOL_SHA256")
    replacement_hash = if valid_sha256?(hash), do: String.duplicate("0", 64), else: "invalid"

    falsifier(
      serial,
      "same_length_payload_hash_mismatch",
      "ASL_A1_RECEIVED_OOL_SHA256=#{hash}",
      "ASL_A1_RECEIVED_OOL_SHA256=#{replacement_hash}"
    )
  end

  defp appended_payload_falsifier(serial) do
    parsed = parse_serial(serial)
    count = unique_value(arm_entries(parsed, "positive_decode"), "ASL_A1_RECEIVED_OOL_BYTE_COUNT")

    replacement =
      case Integer.parse(count || "") do
        {value, ""} -> "ASL_A1_RECEIVED_OOL_BYTE_COUNT=#{value + 1}"
        _ -> "ASL_A1_RECEIVED_OOL_BYTE_COUNT=appended"
      end

    falsifier(
      serial,
      "appended_payload_byte_count",
      "ASL_A1_RECEIVED_OOL_BYTE_COUNT=#{count}",
      replacement
    )
  end

  defp equal_fake_hashes_falsifier(serial) do
    fake = String.duplicate("0", 64)

    mutated =
      serial
      |> String.replace(
        "ASL_A1_EXPECTED_OOL_SHA256=#{@expected_ool_sha256}",
        "ASL_A1_EXPECTED_OOL_SHA256=#{fake}"
      )
      |> String.replace(
        "ASL_A1_RECEIVED_OOL_SHA256=#{@expected_ool_sha256}",
        "ASL_A1_RECEIVED_OOL_SHA256=#{fake}"
      )

    falsifier_result("equal_fake_ool_hashes", serial, mutated)
  end

  defp equal_wrong_counts_falsifier(serial) do
    mutated =
      serial
      |> String.replace(
        "ASL_A1_EXPECTED_OOL_BYTE_COUNT=#{@expected_ool_byte_count}",
        "ASL_A1_EXPECTED_OOL_BYTE_COUNT=95"
      )
      |> String.replace(
        "ASL_A1_RECEIVED_OOL_BYTE_COUNT=#{@expected_ool_byte_count}",
        "ASL_A1_RECEIVED_OOL_BYTE_COUNT=95"
      )

    falsifier_result("equal_wrong_ool_counts", serial, mutated)
  end

  defp malformed_receive_conflict_falsifier(serial) do
    mutate_in_arm(serial, "malformed_payload", fn arm ->
      String.replace(
        arm,
        "ASL_A1_SERVER_RECEIVE_KR=0",
        "ASL_A1_SERVER_RECEIVE_KR=0\nASL_A1_SERVER_RECEIVE_KR=5",
        global: false
      )
    end)
    |> falsifier_result_from_mutation(serial, "malformed_receive_kr_conflict")
  end

  defp malformed_duplicate_send_falsifier(serial) do
    mutate_in_arm(serial, "malformed_payload", fn arm ->
      String.replace(
        arm,
        "ASL_A1_CLIENT_SEND_STARTED=1",
        "ASL_A1_CLIENT_SEND_STARTED=1\nASL_A1_CLIENT_SEND_STARTED=1",
        global: false
      )
    end)
    |> falsifier_result_from_mutation(serial, "malformed_duplicate_client_send")
  end

  defp malformed_missing_donor_falsifier(serial) do
    mutate_in_arm(serial, "malformed_payload", fn arm ->
      String.replace(
        arm,
        "ASL_A1_DONOR_SERVER_MESSAGE_ENTER=1",
        "ASL_A1_DONOR_SERVER_MESSAGE_ENTER_REMOVED=1",
        global: false
      )
    end)
    |> falsifier_result_from_mutation(serial, "malformed_missing_donor_entry")
  end

  defp malformed_unexpected_decode_falsifier(serial) do
    mutate_in_arm(serial, "malformed_payload", fn arm ->
      String.replace(
        arm,
        "ASL_A1_NEG_MALFORMED_PAYLOAD_REJECTED=1",
        "ASL_A1_DONOR_DECODE_OK=1\nASL_A1_NEG_MALFORMED_PAYLOAD_REJECTED=1",
        global: false
      )
    end)
    |> falsifier_result_from_mutation(serial, "malformed_unexpected_donor_decode")
  end

  defp invalid_ool_conflict_falsifier(serial) do
    mutate_in_arm(serial, "invalid_ool", fn arm ->
      String.replace(
        arm,
        "ASL_A1_NEG_INVALID_OOL_DESCRIPTOR_REJECTED=1",
        "ASL_A1_NEG_INVALID_OOL_DESCRIPTOR_REJECTED=0\nASL_A1_NEG_INVALID_OOL_DESCRIPTOR_REJECTED=1",
        global: false
      )
    end)
    |> falsifier_result_from_mutation(serial, "invalid_ool_conflicting_rejection")
  end

  defp invalid_ool_duplicate_falsifier(serial) do
    mutate_in_arm(serial, "invalid_ool", fn arm ->
      String.replace(
        arm,
        "ASL_A1_NEG_INVALID_OOL_DESCRIPTOR_REJECTED=1",
        "ASL_A1_NEG_INVALID_OOL_DESCRIPTOR_REJECTED=1\nASL_A1_NEG_INVALID_OOL_DESCRIPTOR_REJECTED=1",
        global: false
      )
    end)
    |> falsifier_result_from_mutation(serial, "invalid_ool_duplicate_rejection")
  end

  defp cross_arm_contamination_falsifier(serial) do
    mutate_in_arm(serial, "invalid_ool", fn arm ->
      String.replace(
        arm,
        "ASL_A1_ARM_END=invalid_ool",
        "ASL_A1_DONOR_DECODE_OK=1\nASL_A1_ARM_END=invalid_ool",
        global: false
      )
    end)
    |> falsifier_result_from_mutation(serial, "cross_arm_marker_contamination")
  end

  defp conflicting_boundary_falsifier(serial) do
    mutated =
      String.replace(
        serial,
        "ASL_A1_ARM_START=malformed_payload",
        "ASL_A1_ARM_START=malformed_payload\nASL_A1_ARM_START=invalid_ool",
        global: false
      )

    falsifier_result("duplicated_conflicting_arm_boundaries", serial, mutated)
  end

  defp mutate_in_arm(serial, arm, fun) do
    start_marker = "ASL_A1_ARM_START=#{arm}"
    end_marker = "ASL_A1_ARM_END=#{arm}"

    case String.split(serial, start_marker, parts: 2) do
      [before, tail] ->
        case String.split(tail, end_marker, parts: 2) do
          [body, after_arm] -> before <> start_marker <> fun.(body <> end_marker) <> after_arm
          _ -> serial
        end

      _ ->
        serial
    end
  end

  defp falsifier_result_from_mutation(mutated, original, id),
    do: falsifier_result(id, original, mutated)

  defp falsifier_result(id, original, mutated) do
    result = validate_serial(mutated)

    %{
      "id" => id,
      "passed" => mutated != original and not result["passed"],
      "observed_errors" => result["errors"]
    }
  end

  defp arm_entries(parsed, arm) do
    starts = exact_line_indices(parsed, "ASL_A1_ARM_START=#{arm}")
    ends = exact_line_indices(parsed, "ASL_A1_ARM_END=#{arm}")

    case {starts, ends} do
      {[start_index], [end_index]} when start_index < end_index ->
        Enum.filter(parsed.entries, &(&1.index >= start_index and &1.index <= end_index))

      _ ->
        []
    end
  end

  defp exact_line_indices(parsed, line) do
    parsed.lines
    |> Enum.with_index()
    |> Enum.filter(fn {candidate, _index} -> candidate == line end)
    |> Enum.map(&elem(&1, 1))
  end

  defp exact_marker_index(parsed, {key, value}) do
    case Enum.filter(parsed.entries, &(&1.key == key and &1.value == value)) do
      [%{index: index}] -> index
      _ -> nil
    end
  end

  defp unique_value(entries, key) do
    case entries |> Enum.filter(&(&1.key == key)) |> Enum.map(& &1.value) do
      [value] -> value
      _ -> nil
    end
  end

  defp format_marker({key, value}), do: "#{key}=#{value}"
  defp count_error(actual, expected, _label) when actual == expected, do: []

  defp count_error(actual, expected, label),
    do: ["#{label} count must be #{expected}; got #{actual}"]

  defp valid_sha256?(value), do: is_binary(value) and Regex.match?(~r/^[0-9a-f]{64}$/, value)
  defp maybe_add(errors, true, message), do: errors ++ [message]
  defp maybe_add(errors, false, _message), do: errors

  defp replace_once(serial, original, replacement) do
    String.replace(serial, original, replacement, global: false)
  end

  defp swap_first(serial, first, second) do
    token = "__ASL_A1_SWAP_TOKEN__"

    serial
    |> replace_once(first, token)
    |> replace_once(second, first)
    |> replace_once(token, second)
  end

  defp accepted_claim(false, _audit), do: "not_accepted"

  defp accepted_claim(true, %{"status" => "accepted"}),
    do: "ool_transport_decode_plus_audit_identity"

  defp accepted_claim(true, _audit), do: "ool_transport_decode_only_audit_identity_deferred"

  def verify_build_provenance(evidence_dir) do
    required =
      ~w(donor_build_provenance.json donor_hashes.json generated_mig_hashes.json probe_hashes.json)

    missing = Enum.reject(required, &File.regular?(Path.join(evidence_dir, &1)))

    if missing == [] do
      verify_build_provenance_documents(evidence_dir, load_provenance_documents(evidence_dir))
    else
      %{
        "schema" => "rmxos_oracle.asl_a1.cryptographic_provenance_verification.v1",
        "passed" => false,
        "errors" =>
          Enum.map(missing, fn name ->
            "missing #{name}; donor decoder build/link provenance absent"
          end)
      }
    end
  end

  def provenance_falsifiers(evidence_dir) do
    docs = load_provenance_documents(evidence_dir)
    fake = String.duplicate("0", 64)

    cases = [
      {"forged_decoder_object_hash",
       put_in(docs, ["provenance", "decoder_objects", Access.at(0), "sha256"], fake)},
      {"forged_linked_binary_hash",
       put_in(docs, ["provenance", "linked_binary", "sha256"], fake)},
      {"forged_donor_source_hash",
       put_in(docs, ["donor_hashes", "files", Access.at(2), "sha256"], fake)},
      {"forged_extraction_hash",
       put_in(docs, ["provenance", "extraction_diff", "extracted_fragment_sha256"], fake)},
      {"forged_extraction_status",
       put_in(docs, ["provenance", "extraction_diff", "status"], "different")},
      {"forged_symbol_origin_claim",
       put_in(docs, ["provenance", "linked_donor_symbol_origins", "__asl_server_message"], false)},
      {"forged_linked_object_claim",
       put_in(docs, ["provenance", "linked_decoder_objects", "donor_asl_msg.o"], false)},
      {"cross_file_hash_disagreement",
       put_in(docs, ["generated", "probe", "binary_sha256"], fake)}
    ]

    controls =
      Enum.map(cases, fn {id, mutated} ->
        result = verify_build_provenance_documents(evidence_dir, mutated)
        %{"id" => id, "passed" => not result["passed"], "observed_errors" => result["errors"]}
      end)

    %{
      "schema" => "rmxos_oracle.asl_a1.provenance_negative_controls.v1",
      "passed" => Enum.all?(controls, & &1["passed"]),
      "controls" => controls
    }
  end

  defp load_provenance_documents(evidence_dir) do
    %{
      "provenance" =>
        CanonicalJSON.decode!(Path.join(evidence_dir, "donor_build_provenance.json")),
      "donor_hashes" => CanonicalJSON.decode!(Path.join(evidence_dir, "donor_hashes.json")),
      "generated" => CanonicalJSON.decode!(Path.join(evidence_dir, "generated_mig_hashes.json")),
      "probe" => CanonicalJSON.decode!(Path.join(evidence_dir, "probe_hashes.json"))
    }
  end

  defp verify_build_provenance_documents(evidence_dir, docs) do
    provenance = docs["provenance"]
    donor_hashes = docs["donor_hashes"]
    generated = docs["generated"]
    probe = docs["probe"]
    donor_dir = Path.join(evidence_dir, "host/donor")
    generated_dir = Path.join(evidence_dir, "host/generated")
    build_dir = Path.join(evidence_dir, "host/build")
    link_map_path = Path.join(build_dir, "asl-a1-server-message-ool.map")
    binary_path = Path.join(build_dir, "asl-a1-server-message-ool")
    link_map = read_if_regular(link_map_path)

    errors =
      []
      |> maybe_add(
        provenance["donor_commit"] != @donor_commit,
        "donor provenance commit mismatch"
      )
      |> maybe_add(donor_hashes["donor_commit"] != @donor_commit, "donor hashes commit mismatch")
      |> verify_pinned_donor_sources(donor_dir, donor_hashes, provenance)
      |> verify_extraction_files(generated_dir, donor_dir, provenance)
      |> verify_generated_files(generated_dir, build_dir, generated)
      |> verify_probe_files(build_dir, probe, generated)
      |> verify_recorded_identity(link_map_path, provenance["link_map"], "link map")
      |> verify_recorded_identity(binary_path, provenance["linked_binary"], "linked probe binary")
      |> verify_decoder_objects(build_dir, provenance, generated)
      |> verify_source_object_bindings(donor_dir, build_dir, provenance)
      |> verify_link_map_claims(build_dir, link_map, provenance)
      |> verify_cross_file_hashes(provenance, generated, probe)
      |> maybe_add(provenance["passed"] != true, "recorded provenance pass flag is not true")

    %{
      "schema" => "rmxos_oracle.asl_a1.cryptographic_provenance_verification.v1",
      "passed" => errors == [],
      "errors" => errors,
      "checks" => %{
        "pinned_donor_sources_rehashed" => true,
        "extractions_reconstructed" => true,
        "generated_and_object_files_rehashed" => true,
        "link_map_origins_recomputed" => true,
        "cross_file_hashes_checked" => true
      }
    }
  end

  defp verify_pinned_donor_sources(errors, donor_dir, donor_hashes, provenance) do
    recorded = Map.new(donor_hashes["files"] || [], &{&1["path"], &1})

    Enum.reduce(@pinned_donor_hashes, errors, fn {rel, pinned_hash}, acc ->
      path = Path.join(donor_dir, rel)
      actual = hash_if_regular(path)
      record = recorded[rel] || %{}

      acc
      |> maybe_add(actual != pinned_hash, "pinned donor source hash mismatch: #{rel}")
      |> maybe_add(record["sha256"] != pinned_hash, "donor_hashes.json mismatch: #{rel}")
      |> maybe_add(record["size"] != size_if_regular(path), "donor source size mismatch: #{rel}")
    end)
    |> maybe_add(
      provenance["codec_source_sha256"] != @pinned_donor_hashes[@donor_codec_rel],
      "codec source provenance hash mismatch"
    )
    |> maybe_add(
      provenance["server_message_source_sha256"] != @pinned_donor_hashes[@donor_dbserver_rel],
      "server-message source provenance hash mismatch"
    )
    |> maybe_add(
      provenance["release_source_sha256"] != @pinned_donor_hashes[@donor_codec_rel],
      "release source provenance hash mismatch"
    )
    |> maybe_add(
      provenance["release_refcount_source_sha256"] != @pinned_donor_hashes[@donor_object_rel],
      "release refcount source provenance hash mismatch"
    )
  end

  defp verify_extraction_files(errors, generated_dir, donor_dir, provenance) do
    dbserver = read_if_regular(Path.join(donor_dir, @donor_dbserver_rel))
    offset = provenance["extracted_fragment_offset"]
    size = provenance["extracted_fragment_size"]
    source_slice = safe_slice(dbserver, offset, size)
    server_fragment = Path.join(generated_dir, "donor_asl_server_message.fragment.c")
    server_wrapper = Path.join(generated_dir, "donor_asl_server_message.c")
    release_fragment = Path.join(generated_dir, "donor_asl_release.fragments.c")
    release_wrapper = Path.join(generated_dir, "donor_asl_release.c")
    release_wrapper_text = read_if_regular(release_wrapper)

    expected_release_fragment =
      donor_dir
      |> Path.join(@donor_codec_rel)
      |> read_if_regular()
      |> release_source_fragment()

    errors
    |> maybe_add(
      hash_binary(source_slice) != provenance["extracted_fragment_sha256"],
      "server-message pinned source slice hash mismatch"
    )
    |> verify_recorded_hash(
      server_fragment,
      provenance["extracted_fragment_sha256"],
      "server-message extracted fragment"
    )
    |> verify_recorded_hash(
      server_wrapper,
      provenance["generated_wrapper_sha256"],
      "server-message generated wrapper"
    )
    |> verify_recorded_hash(
      release_fragment,
      provenance["release_extracted_fragment_sha256"],
      "release extracted fragments"
    )
    |> verify_recorded_hash(
      release_wrapper,
      provenance["release_generated_wrapper_sha256"],
      "release generated wrapper"
    )
    |> maybe_add(
      get_in(provenance, ["extraction_diff", "status"]) != "identical",
      "server-message extraction status is not identical"
    )
    |> maybe_add(
      get_in(provenance, ["extraction_diff", "source_slice_sha256"]) != hash_binary(source_slice),
      "server-message source-slice cross-check mismatch"
    )
    |> maybe_add(
      get_in(provenance, ["extraction_diff", "extracted_fragment_sha256"]) !=
        hash_if_regular(server_fragment),
      "server-message extraction-diff fragment hash mismatch"
    )
    |> maybe_add(
      provenance["release_extraction_exact"] != true,
      "release extraction is not recorded exact"
    )
    |> maybe_add(
      hash_if_regular(release_fragment) != hash_binary(expected_release_fragment),
      "release extraction does not equal pinned donor cleanup slices"
    )
    |> maybe_add(
      not String.contains?(release_wrapper_text, "_jump_dealloc(obj);"),
      "donor-compatible release wrapper does not call donor-derived deallocator"
    )
    |> maybe_add(
      String.contains?(release_wrapper_text, "(void)obj;"),
      "no-op release implementation detected"
    )
  end

  defp release_source_fragment(source) when is_binary(source) and source != "" do
    [
      exact_slice!(
        source,
        "static const char *\n_asl_msg_slot_val(",
        "\n/*\n * asl_new:",
        "release verify slot val"
      ),
      exact_slice!(
        source,
        "static void\n_asl_msg_free_page(",
        "\nuint32_t\nasl_msg_type(",
        "release verify free page"
      ),
      exact_slice!(
        source,
        "static void\n_jump_dealloc(",
        "\nstatic int\n_jump_set_key_val_op(",
        "release verify jump dealloc"
      )
    ]
    |> Enum.map_join("\n", & &1.bytes)
  end

  defp release_source_fragment(_), do: nil

  defp verify_generated_files(errors, generated_dir, build_dir, generated) do
    errors =
      Enum.reduce(generated["generated"] || [], errors, fn record, acc ->
        verify_recorded_identity(
          acc,
          Path.join(generated_dir, record["path"]),
          record,
          "generated MIG #{record["path"]}"
        )
      end)

    Enum.reduce(generated["objects"] || [], errors, fn record, acc ->
      verify_recorded_identity(
        acc,
        Path.join(build_dir, record["path"]),
        record,
        "generated/object #{record["path"]}"
      )
    end)
  end

  defp verify_probe_files(errors, build_dir, probe, generated) do
    materialized = Path.join(build_dir, "a1_server_message_ool.c")
    binary = Path.join(build_dir, "asl-a1-server-message-ool")
    oracle_source = Path.join(File.cwd!(), @probe_rel)
    generated_probe = generated["probe"] || %{}

    errors
    |> verify_recorded_hash(
      materialized,
      probe["materialized_source_sha256"],
      "materialized probe source"
    )
    |> verify_recorded_hash(oracle_source, probe["source_sha256"], "Oracle probe source")
    |> verify_recorded_hash(binary, probe["binary_sha256"], "probe binary")
    |> maybe_add(
      probe != generated_probe,
      "probe_hashes.json disagrees with generated_mig_hashes.json probe record"
    )
    |> maybe_add(
      probe["source_sha256"] != probe["materialized_source_sha256"],
      "probe source and materialized source hashes disagree"
    )
  end

  defp verify_decoder_objects(errors, build_dir, provenance, generated) do
    generated_objects = Map.new(generated["objects"] || [], &{&1["path"], &1})

    Enum.reduce(provenance["decoder_objects"] || [], errors, fn record, acc ->
      name = Path.basename(record["path"] || "")
      actual_path = Path.join(build_dir, name)

      acc
      |> verify_recorded_identity(actual_path, record, "decoder object #{name}")
      |> maybe_add(
        get_in(generated_objects, [name, "sha256"]) != record["sha256"],
        "decoder object cross-file hash mismatch: #{name}"
      )
    end)
  end

  defp verify_source_object_bindings(errors, donor_dir, build_dir, provenance) do
    Enum.reduce(provenance["source_object_bindings"] || [], errors, fn binding, acc ->
      source_path = Path.join(donor_dir, binding["source_path"] || "")
      object_name = Path.basename(get_in(binding, ["object", "path"]) || "")
      object_path = Path.join(build_dir, object_name)

      acc
      |> verify_recorded_hash(
        source_path,
        binding["source_sha256"],
        "source/object binding source #{binding["source_path"]}"
      )
      |> verify_recorded_identity(
        object_path,
        binding["object"],
        "source/object binding object #{object_name}"
      )
    end)
  end

  defp verify_link_map_claims(errors, build_dir, link_map, provenance) do
    linked_objects =
      Map.new(~w(donor_asl_msg.o donor_asl_server_message.o donor_asl_release.o), fn name ->
        {name, String.contains?(link_map, Path.join(build_dir, name))}
      end)

    origins =
      Map.new(@donor_symbol_origins, fn {symbol, object} ->
        pattern =
          ~r/#{Regex.escape(Path.join(build_dir, object))}:\([^)]+\)\n\s+\S+\s+\S+\s+\S+\s+\S+\s+#{Regex.escape(symbol)}$/m

        {symbol, Regex.match?(pattern, link_map)}
      end)

    errors
    |> maybe_add(
      provenance["linked_decoder_objects"] != linked_objects,
      "linked-object claims disagree with recomputed link map"
    )
    |> maybe_add(
      provenance["linked_donor_symbol_origins"] != origins,
      "symbol-origin claims disagree with recomputed link map"
    )
    |> maybe_add(
      not Enum.all?(linked_objects, &elem(&1, 1)),
      "link map is missing required donor-derived object"
    )
    |> maybe_add(
      not Enum.all?(origins, &elem(&1, 1)),
      "link map is missing required donor symbol origin"
    )
  end

  defp verify_cross_file_hashes(errors, provenance, generated, probe) do
    object_hashes = Map.new(generated["objects"] || [], &{&1["path"], &1["sha256"]})

    errors =
      Enum.reduce(provenance["decoder_objects"] || [], errors, fn record, acc ->
        name = Path.basename(record["path"] || "")

        maybe_add(
          acc,
          object_hashes[name] != record["sha256"],
          "decoder object hash disagrees across provenance files: #{name}"
        )
      end)

    errors
    |> maybe_add(
      get_in(provenance, ["linked_binary", "sha256"]) != probe["binary_sha256"],
      "linked binary hash disagrees with probe_hashes.json"
    )
    |> maybe_add(
      get_in(generated, ["probe", "binary_sha256"]) != probe["binary_sha256"],
      "linked binary hash disagrees with generated_mig_hashes.json"
    )
  end

  defp verify_recorded_identity(errors, path, record, label) do
    errors
    |> verify_recorded_hash(path, record && record["sha256"], label)
    |> maybe_add(size_if_regular(path) != (record && record["size"]), "#{label} size mismatch")
  end

  defp verify_recorded_hash(errors, path, expected, label),
    do:
      maybe_add(
        errors,
        hash_if_regular(path) != expected,
        "#{label} SHA256 mismatch or file missing"
      )

  defp hash_if_regular(path), do: if(File.regular?(path), do: sha256_file(path), else: nil)
  defp size_if_regular(path), do: if(File.regular?(path), do: File.stat!(path).size, else: nil)
  defp read_if_regular(path), do: if(File.regular?(path), do: File.read!(path), else: "")
  defp hash_binary(nil), do: nil
  defp hash_binary(data), do: sha256(data)

  defp safe_slice(data, offset, size)
       when is_binary(data) and is_integer(offset) and is_integer(size) and offset >= 0 and
              size >= 0 and
              offset + size <= byte_size(data),
       do: binary_part(data, offset, size)

  defp safe_slice(_data, _offset, _size), do: nil

  defp extract_donor_server_message!(donor_dir, generated_dir) do
    source_path = Path.join(donor_dir, @donor_dbserver_rel)
    source = File.read!(source_path)
    start_anchor = "kern_return_t\n__asl_server_message\n("
    end_anchor = "\nkern_return_t\n__asl_server_create_aux_link\n("
    {start, _} = unique_binary_match!(source, start_anchor, "donor __asl_server_message start")
    tail = binary_part(source, start, byte_size(source) - start)
    {relative_end, _} = unique_binary_match!(tail, end_anchor, "donor __asl_server_message end")
    fragment = binary_part(source, start, relative_end)

    prelude = """
    #include <asl.h>
    #include <asl_msg.h>
    #include <bsm/libbsm.h>
    #include <mach/mach.h>
    #include <stdio.h>
    #include <sys/types.h>
    #include "asl_ipc.h"

    #define SOURCE_ASL_MESSAGE 5

    int asldebug(const char *, ...);
    void register_session(mach_port_name_t, pid_t);
    void process_message(asl_msg_t *, uint32_t);

    """

    wrapper_path = Path.join(generated_dir, "donor_asl_server_message.c")
    fragment_path = Path.join(generated_dir, "donor_asl_server_message.fragment.c")
    File.write!(fragment_path, fragment)
    File.write!(wrapper_path, prelude <> fragment)

    %{
      exact: binary_part(source, start, byte_size(fragment)) == fragment,
      source_path: source_path,
      source_sha256: sha256(source),
      source_slice_sha256: sha256(binary_part(source, start, byte_size(fragment))),
      fragment_path: fragment_path,
      fragment_sha256: sha256(fragment),
      fragment_offset: start,
      fragment_size: byte_size(fragment),
      wrapper_path: wrapper_path,
      wrapper_sha256: sha256(prelude <> fragment),
      method: "exact_byte_slice_between_pinned_function_anchors"
    }
  end

  defp extract_donor_release!(donor_dir, generated_dir) do
    source_path = Path.join(donor_dir, @donor_codec_rel)
    source = File.read!(source_path)

    fragments = [
      exact_slice!(
        source,
        "static const char *\n_asl_msg_slot_val(",
        "\n/*\n * asl_new:",
        "donor _asl_msg_slot_val"
      ),
      exact_slice!(
        source,
        "static void\n_asl_msg_free_page(",
        "\nuint32_t\nasl_msg_type(",
        "donor _asl_msg_free_page"
      ),
      exact_slice!(
        source,
        "static void\n_jump_dealloc(",
        "\nstatic int\n_jump_set_key_val_op(",
        "donor _jump_dealloc"
      )
    ]

    fragment = Enum.map_join(fragments, "\n", & &1.bytes)

    prelude = """
    #include <asl.h>
    #include <asl_msg.h>
    #include <asl_object.h>
    #include <stdint.h>
    #include <stdlib.h>
    #include <string.h>

    uint32_t notify_post(const char *);

    """

    adapter = """

    void
    rmx_asl_a1_donor_msg_release(asl_msg_t *msg)
    {
      asl_object_private_t *obj = (asl_object_private_t *)msg;

      if (obj == NULL) return;
      if ((obj->asl_type != ASL_TYPE_MSG) && (obj->asl_type != ASL_TYPE_QUERY)) abort();
      if (__sync_sub_and_fetch(&(obj->refcount), 1) != 0) return;
      _jump_dealloc(obj);
    }

    void
    asl_release(asl_object_t obj)
    {
      rmx_asl_a1_donor_msg_release((asl_msg_t *)obj);
    }
    """

    wrapper = prelude <> fragment <> adapter
    wrapper_path = Path.join(generated_dir, "donor_asl_release.c")
    fragment_path = Path.join(generated_dir, "donor_asl_release.fragments.c")
    File.write!(fragment_path, fragment)
    File.write!(wrapper_path, wrapper)

    %{
      exact: Enum.all?(fragments, & &1.exact),
      source_path: source_path,
      source_sha256: sha256(source),
      fragments:
        Enum.map(fragments, fn item ->
          %{
            "label" => item.label,
            "offset" => item.offset,
            "size" => byte_size(item.bytes),
            "sha256" => sha256(item.bytes)
          }
        end),
      fragment_path: fragment_path,
      fragment_sha256: sha256(fragment),
      wrapper_path: wrapper_path,
      wrapper_sha256: sha256(wrapper),
      method: "exact_donor_cleanup_slices_plus_narrow_refcount_adapter"
    }
  end

  defp exact_slice!(source, start_anchor, end_anchor, label) do
    {start, _} = unique_binary_match!(source, start_anchor, "#{label} start")
    tail = binary_part(source, start, byte_size(source) - start)
    {relative_end, _} = unique_binary_match!(tail, end_anchor, "#{label} end")
    bytes = binary_part(source, start, relative_end)

    %{
      label: label,
      offset: start,
      bytes: bytes,
      exact: binary_part(source, start, byte_size(bytes)) == bytes
    }
  end

  defp unique_binary_match!(source, anchor, label) do
    matches = :binary.matches(source, anchor)
    fail_unless(length(matches) == 1, "#{label} must match exactly once; got #{length(matches)}")
    hd(matches)
  end

  defp donor_build_provenance(
         donor_dir,
         build_dir,
         probe_binary,
         link_map,
         cc,
         cflags,
         extraction,
         release_extraction
       ) do
    codec_source = Path.join(donor_dir, @donor_codec_rel)
    codec_object = Path.join(build_dir, "donor_asl_msg.o")
    server_object = Path.join(build_dir, "donor_asl_server_message.o")
    release_object = Path.join(build_dir, "donor_asl_release.o")
    link_map_text = File.read!(link_map)
    {nm_output, nm_rc} = System.cmd("nm", ["-g", probe_binary], stderr_to_stdout: true)
    {cc_version, cc_version_rc} = System.cmd(cc, ["--version"], stderr_to_stdout: true)

    required_symbols = Map.keys(@donor_symbol_origins) ++ ["process_message"]

    symbol_checks =
      Map.new(required_symbols, fn symbol ->
        {symbol, Regex.match?(~r/\b#{Regex.escape(symbol)}$/m, nm_output)}
      end)

    linked_objects = %{
      "donor_asl_msg.o" => String.contains?(link_map_text, codec_object),
      "donor_asl_server_message.o" => String.contains?(link_map_text, server_object),
      "donor_asl_release.o" => String.contains?(link_map_text, release_object)
    }

    linked_symbol_origins =
      Map.new(@donor_symbol_origins, fn {symbol, object} ->
        pattern =
          ~r/#{Regex.escape(Path.join(build_dir, object))}:\([^)]+\)\n\s+\S+\s+\S+\s+\S+\s+\S+\s+#{Regex.escape(symbol)}$/m

        {symbol, Regex.match?(pattern, link_map_text)}
      end)

    source_object_bindings = [
      %{
        "source_path" => @donor_codec_rel,
        "source_sha256" => sha256_file(codec_source),
        "materialization" => "full_pinned_donor_source_file",
        "object" => file_identity(codec_object),
        "compile_log" => "logs/asl_msg.c.compile.log"
      },
      %{
        "source_path" => @donor_dbserver_rel,
        "source_sha256" => extraction.source_sha256,
        "materialization" => extraction.method,
        "source_slice_sha256" => extraction.source_slice_sha256,
        "object" => file_identity(server_object),
        "compile_log" => "logs/donor_asl_server_message.c.compile.log"
      },
      %{
        "source_path" => @donor_codec_rel,
        "source_sha256" => release_extraction.source_sha256,
        "refcount_source_path" => @donor_object_rel,
        "refcount_source_sha256" => sha256_file(Path.join(donor_dir, @donor_object_rel)),
        "materialization" => release_extraction.method,
        "source_slice_hashes" => Enum.map(release_extraction.fragments, & &1["sha256"]),
        "object" => file_identity(release_object),
        "compile_log" => "logs/donor_asl_release.c.compile.log"
      }
    ]

    source_object_bindings_verified =
      Enum.all?(source_object_bindings, fn binding ->
        present_hash?(binding["object"]) and valid_sha256?(binding["source_sha256"])
      end)

    passed =
      extraction.exact and release_extraction.exact and nm_rc == 0 and cc_version_rc == 0 and
        Enum.all?(symbol_checks, fn {_symbol, present} -> present end) and
        Enum.all?(linked_objects, fn {_object, present} -> present end) and
        Enum.all?(linked_symbol_origins, fn {_symbol, verified} -> verified end) and
        source_object_bindings_verified

    %{
      "schema" => "rmxos_oracle.asl_a1.donor_build_provenance.v1",
      "passed" => passed,
      "donor_commit" => @donor_commit,
      "codec_source_path" => @donor_codec_rel,
      "codec_source_sha256" => sha256_file(codec_source),
      "codec_compilation_mode" => "full_pinned_donor_source_file",
      "server_message_source_path" => @donor_dbserver_rel,
      "server_message_source_sha256" => extraction.source_sha256,
      "server_message_compilation_mode" => "mechanical_exact_extraction",
      "full_dbserver_block_reason" =>
        "full donor dbserver.c pulls storage/query/notify/session/daemon behavior outside bounded A1",
      "extraction_method" => extraction.method,
      "extraction_exact" => extraction.exact,
      "extraction_diff" => %{
        "status" => if(extraction.exact, do: "identical", else: "different"),
        "source_slice_sha256" => extraction.source_slice_sha256,
        "extracted_fragment_sha256" => extraction.fragment_sha256
      },
      "extracted_fragment_sha256" => extraction.fragment_sha256,
      "extracted_fragment_offset" => extraction.fragment_offset,
      "extracted_fragment_size" => extraction.fragment_size,
      "generated_wrapper_sha256" => extraction.wrapper_sha256,
      "release_source_path" => @donor_codec_rel,
      "release_source_sha256" => release_extraction.source_sha256,
      "release_refcount_source_path" => @donor_object_rel,
      "release_refcount_source_sha256" => sha256_file(Path.join(donor_dir, @donor_object_rel)),
      "release_extraction_method" => release_extraction.method,
      "release_extraction_exact" => release_extraction.exact,
      "release_extraction_fragments" => release_extraction.fragments,
      "release_extracted_fragment_sha256" => release_extraction.fragment_sha256,
      "release_generated_wrapper_sha256" => release_extraction.wrapper_sha256,
      "compiler" => cc,
      "compiler_version" => String.trim(cc_version),
      "compiler_flags" => cflags,
      "decoder_objects" => [
        file_identity(codec_object),
        file_identity(server_object),
        file_identity(release_object)
      ],
      "source_object_bindings" => source_object_bindings,
      "source_object_bindings_verified" => source_object_bindings_verified,
      "support_boundaries" => [
        %{
          "symbol" => "audit_token_to_au32",
          "owner" => "oracle_compatibility_support",
          "reason" => "bounded audit-token field extraction support"
        },
        %{
          "symbol" => "task_name_for_pid",
          "owner" => "oracle_fenced_deferred_support",
          "reason" => "session tracking is outside A1"
        },
        %{
          "symbol" => "notify_post",
          "owner" => "oracle_fenced_side_effect_support",
          "reason" =>
            "donor message-page cleanup is preserved; free-note notification side effects are outside A1"
        }
      ],
      "link_map" => file_identity(link_map),
      "linked_decoder_objects" => linked_objects,
      "linked_decoder_objects_verified" =>
        Enum.all?(linked_objects, fn {_object, present} -> present end),
      "linked_donor_symbol_origins" => linked_symbol_origins,
      "linked_donor_symbol_origins_verified" =>
        Enum.all?(linked_symbol_origins, fn {_symbol, verified} -> verified end),
      "linked_binary" => file_identity(probe_binary),
      "required_linked_symbols" => symbol_checks
    }
  end

  defp donor_hashes(donor_dir, paths) do
    %{
      "schema" => "rmxos_oracle.asl_a1.donor_hashes.v1",
      "donor_root" => @donor_root,
      "donor_commit" => @donor_commit,
      "files" =>
        Enum.map(paths, fn rel ->
          path = Path.join(donor_dir, rel)
          %{"path" => rel, "sha256" => sha256_file(path), "size" => File.stat!(path).size}
        end)
    }
  end

  defp generated_hashes(generated_dir, build_dir, probe_source, probe_copy, probe_binary) do
    generated_files = ~w(asl_ipc.h asl_ipc_server.h asl_ipc_user.c asl_ipc_server.c)

    %{
      "schema" => "rmxos_oracle.asl_a1.generated_mig_hashes.v1",
      "generated" =>
        Enum.map(generated_files, fn rel ->
          path = Path.join(generated_dir, rel)
          %{"path" => rel, "sha256" => sha256_file(path), "size" => File.stat!(path).size}
        end),
      "objects" =>
        Enum.map(
          ~w(asl_ipc_user.o asl_ipc_server.o donor_asl_msg.o donor_asl_server_message.o donor_asl_release.o a1_server_message_ool.o),
          fn rel ->
            path = Path.join(build_dir, rel)
            %{"path" => rel, "sha256" => sha256_file(path), "size" => File.stat!(path).size}
          end
        ),
      "probe" => %{
        "source_path" => @probe_rel,
        "source_sha256" => sha256_file(probe_source),
        "materialized_source_path" => "host/build/a1_server_message_ool.c",
        "materialized_source_sha256" => sha256_file(probe_copy),
        "binary_path" => "host/build/asl-a1-server-message-ool",
        "binary_sha256" => sha256_file(probe_binary),
        "binary_size" => File.stat!(probe_binary).size
      }
    }
  end

  defp materialize_source_tools!(evidence_dir) do
    tools_root = Path.join(evidence_dir, "source-tools")

    files =
      Enum.map(@source_tool_files, fn rel ->
        data = git_blob!(@source_repo, "#{@source_authorization_commit}:#{rel}")
        path = Path.join(tools_root, rel)
        File.mkdir_p!(Path.dirname(path))
        File.write!(path, data)

        if String.ends_with?(rel, ".sh") do
          File.chmod!(path, 0o755)
        end

        %{
          "path" => rel,
          "materialized_path" => path,
          "mode" => "materialized_from_source_authorization_commit",
          "source_commit" => @source_authorization_commit,
          "sha256" => sha256(data),
          "size" => byte_size(data)
        }
      end)

    CanonicalJSON.write!(Path.join(evidence_dir, "transitional_tool_hashes.json"), %{
      "schema" => "rmxos_oracle.asl_a1.transitional_tool_hashes.v1",
      "files" => files
    })

    Map.new(files, &{&1["path"], &1["materialized_path"]})
  end

  defp asl_rc_script do
    """
    #!/bin/sh
    #
    # PROVIDE: nxplatform_asl_a1
    # REQUIRE: nxplatform_probe
    # KEYWORD: nojail

    . /etc/rc.subr

    name=nxplatform_asl_a1
    rcvar=nxplatform_asl_a1_enable
    start_cmd=nxplatform_asl_a1_start
    stop_cmd=:

    nxplatform_asl_a1_start()
    {
      probe_rc=0
      timeout_bin=/usr/bin/timeout
      if [ ! -x "$timeout_bin" ]; then
        timeout_bin=timeout
      fi

      echo "=== ASL A1 server-message-ool start ==="
      if kldstat -q -m mach; then
        echo "mach_module=loaded"
      else
        echo "mach_module=missing"
      fi
      "$timeout_bin" 45 /root/nxplatform/asl/asl-a1-server-message-ool 2>&1 || probe_rc=$?
      echo "=== ASL A1 server-message-ool end rc=${probe_rc} ==="

      shutdown -p now
      return "$probe_rc"
    }

    load_rc_config $name
    : ${nxplatform_asl_a1_enable:=YES}
    run_rc_command "$1"
    """
  end

  defp root_partition!(gpart_output) do
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
    |> elem(1)
    |> case do
      nil -> raise "unable to find freebsd-ufs partition"
      path -> path
    end
  end

  defp append_if_missing(path, line, log) do
    case System.cmd("doas", ["grep", "-Fqx", line, path], stderr_to_stdout: true) do
      {_out, 0} ->
        :ok

      _ ->
        run_cmd!(
          "append #{Path.basename(path)}",
          "doas",
          ["sh", "-c", "printf '%s\\n' \"$1\" >> \"$2\"", "append", line, path],
          log
        )
    end
  end

  defp file_identity(path) do
    if File.regular?(path) do
      %{"path" => path, "sha256" => sha256_file(path), "size" => File.stat!(path).size}
    else
      %{"path" => path, "sha256" => nil, "size" => nil, "missing" => true}
    end
  end

  defp present_hash?(%{"sha256" => hash}) when is_binary(hash) and byte_size(hash) == 64, do: true
  defp present_hash?(_), do: false

  defp run_cmd!(label, cmd, args, log_path, opts \\ []) do
    result = run_cmd(label, cmd, args, log_path, opts)
    fail_unless(result.rc == 0, "#{label} failed with rc=#{result.rc}; see #{log_path}")
    result
  end

  defp run_cmd(label, cmd, args, log_path, opts \\ []) do
    File.mkdir_p!(Path.dirname(log_path))
    {out, rc} = System.cmd(cmd, args, Keyword.merge([stderr_to_stdout: true], opts))

    File.write!(
      log_path,
      [
        "$ #{Enum.join([cmd | args], " ")}\n",
        "label=#{label}\n",
        "rc=#{rc}\n",
        out
      ],
      [:append]
    )

    %{label: label, cmd: cmd, args: args, rc: rc, out: out}
  end

  defp git!(repo, args),
    do: elem(System.cmd("git", ["-C", repo] ++ args, stderr_to_stdout: true), 0) |> String.trim()

  defp git_blob!(repo, object) do
    case System.cmd("git", ["-C", repo, "show", object], stderr_to_stdout: true) do
      {data, 0} -> data
      {out, rc} -> raise "git show #{object} failed in #{repo} with rc=#{rc}: #{out}"
    end
  end

  defp sha256_file(path), do: path |> File.read!() |> sha256()
  defp sha256(data), do: :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)

  defp env_for_cmd(env), do: Enum.map(env, fn {key, value} -> {key, to_string(value)} end)

  defp fail_unless(true, _message), do: :ok
  defp fail_unless(false, message), do: raise(message)

  defp timestamp do
    DateTime.utc_now()
    |> DateTime.to_iso8601(:extended)
    |> String.replace(["-", ":", "."], "")
  end
end
