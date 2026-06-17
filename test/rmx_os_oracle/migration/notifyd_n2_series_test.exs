defmodule RmxOSOracle.Migration.NotifydN2SeriesTest do
  use ExUnit.Case, async: true

  alias RmxOSOracle.Migration.NotifydN2Series
  alias RmxOSOracle.Notifyd.N2.{ContractCheck, MarkerManifest}

  @mach_send_serial """
  WARNING: WITNESS option enabled, expect reduced performance.
  mach_module=loaded
  === phase07 dispatch_mach_send smoke start ===
  NOTIFYD_N2_MACH_SEND_SMOKE_START status=0
  NOTIFYD_N2_MACH_SEND_REGISTRATION count=1
  NOTIFYD_N2_MACH_SEND_EARLY_EVENT count=0
  NOTIFYD_N2_MACH_SEND_RECEIVE_DESTROY kr=0 owner=same_task
  NOTIFYD_N2_MACH_SEND_DEAD_EVENT count=1 duplicate=0 data=1
  NOTIFYD_N2_MACH_SEND_CANCEL count=1 before_event=0
  NOTIFYD_N2_MACH_SEND_FINAL_COUNTS registration=1 event=1 duplicate=0 cancel=1 cancel_before_event=0
  NOTIFYD_N2_MACH_SEND_TERMINAL status=0
  phase07_dispatch_mach_send_exit=0
  === phase07 dispatch_mach_send smoke end rc=0 ===
  """

  @mach_raw_serial """
  mach_module=loaded
  NOTIFYD_N2_MACH_RAW_SMOKE_START status=0
  NOTIFYD_N2_MACH_RAW_TARGET_ALLOCATE kr=0 port=19
  NOTIFYD_N2_MACH_RAW_TARGET_MAKE_SEND kr=0
  NOTIFYD_N2_MACH_RAW_NOTIFY_ALLOCATE kr=0 port=20
  NOTIFYD_N2_MACH_RAW_REQUEST kr=0 previous=0
  NOTIFYD_N2_MACH_RAW_EARLY_RECEIVE mr=268451843 count=0
  NOTIFYD_N2_MACH_RAW_RECEIVE_DESTROY kr=0 owner=same_task
  NOTIFYD_N2_MACH_RAW_NOTIFICATION_RECEIVE mr=0 id=72 not_port=19 size=36
  NOTIFYD_N2_MACH_RAW_DUPLICATE_RECEIVE mr=268451843 duplicate=0
  NOTIFYD_N2_MACH_RAW_TERMINAL status=0
  phase07_mach_dead_name_raw_exit=0
  """

  @mach_direct_serial """
  mach_module=loaded
  NOTIFYD_N2_MACH_DIRECT_SMOKE_START status=0
  NOTIFYD_N2_MACH_DIRECT_TARGET_ALLOCATE kr=0 port=19
  NOTIFYD_N2_MACH_DIRECT_TARGET_MAKE_SEND kr=0
  NOTIFYD_N2_MACH_DIRECT_NOTIFY_ALLOCATE kr=0 port=20
  NOTIFYD_N2_MACH_DIRECT_PORTSET_ALLOCATE kr=0 portset=21
  NOTIFYD_N2_MACH_DIRECT_NOTIFY_MOVE_MEMBER kr=0
  NOTIFYD_N2_MACH_DIRECT_KQUEUE fd=3
  NOTIFYD_N2_MACH_DIRECT_KEVENT_ARM ret=0
  NOTIFYD_N2_MACH_DIRECT_REQUEST kr=0 previous=0
  NOTIFYD_N2_MACH_DIRECT_EARLY_KEVENT ret=0 count=0
  NOTIFYD_N2_MACH_DIRECT_RECEIVE_DESTROY kr=0 owner=same_task
  NOTIFYD_N2_MACH_DIRECT_KEVENT_RECEIVE ret=1 filter=-16 ident=21 fflags=0 data=0 size=120 id=72 local=20 not_port=19
  NOTIFYD_N2_MACH_DIRECT_KEVENT_REARM ret=0
  NOTIFYD_N2_MACH_DIRECT_DUPLICATE_KEVENT ret=0 duplicate=0
  NOTIFYD_N2_MACH_DIRECT_TERMINAL status=0
  phase07_mach_direct_kevent_exit=0
  """

  @notify_trace_timeout_serial """
  mach_module=loaded
  NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_SMOKE_START status=0
  NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_TARGET_ALLOCATE kr=0 port=20
  NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_TARGET_MAKE_SEND kr=0
  NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_QUEUE_CREATE status=0
  NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_SOURCE_CREATE status=0
  NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_PRIVATE_NOTIFY_UPDATE_ENTER port=20 new=1 del=0 mask=13 prev=0 fflags=1
  NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_PRIVATE_NOTIFY_SOURCE_RESUME status=0 port=23
  NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_PRIVATE_NOTIFY_UPDATE_REQUEST kr=0 previous=0 msgid=72 sync=1 notify_port=23
  NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_REGISTRATION count=1
  NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_EARLY_EVENT count=0
  NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_RECEIVE_DESTROY kr=0 owner=same_task
  NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_PRIVATE_MSG_DRAIN_ENTER fflags=0 data=0 ext0=4096 ext1=16384
  NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_PRIVATE_MSG_DRAIN_FAST id=72 local=23 size=36
  NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_PRIVATE_MSG_RECV_ENTER id=72 local=23 size=36
  NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_PRIVATE_SOURCE_MERGE_MSG notify_source=1 id=72 local=23 size=36
  NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_PRIVATE_SOURCE_INVOKE id=72 local=23 size=36
  NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_PRIVATE_DEAD_NAME name=0
  NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_PRIVATE_NOTIFY_MERGE_ENTER name=0 flag=1 final=1
  NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_PRIVATE_NOTIFY_MERGE_FIND found=0 name=0
  NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_PRIVATE_SOURCE_INVOKE_RESULT success=1 ret=0
  NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_USER_EVENT_TIMEOUT count=0
  NOTIFYD_N2_DISPATCH_NOTIFY_TRACE_TERMINAL status=0 diagnostic=user_event_timeout
  phase07_dispatch_notify_trace_exit=0
  """

  @concurrency_serial """
  WARNING: WITNESS option enabled, expect reduced performance.
  KDB: debugger backends: ddb
  KDB: current backend: ddb
  NOTIFYD_N2_LAUNCHD_CHECKIN_REQUEST kr=0 result=dict
  NOTIFYD_N2_LAUNCHD_MACH_SERVICES_DICT present=1 type=dict
  NOTIFYD_N2_LAUNCHD_SERVICE_ENTRY service=com.apple.system.notification_center present=1 type=machport
  NOTIFYD_N2_LAUNCHD_RECEIVE_RIGHT service=com.apple.system.notification_center port=21 right=receive
  NOTIFYD_N2_LAUNCHD_CHECKIN_TERMINAL status=0
  NOTIFYD_N2_CONCURRENCY_START status=0 clients=2
  NOTIFYD_N2_TWQ_COUNTERS_BEFORE workers=4 source=kern.smp.cpus
  NOTIFYD_N2_KERNEL_MACH_MSG_RECEIVE msgid=78945669 local_port=21 size=56 trailer_type=0
  NOTIFYD_N2_KERNEL_AUDIT_TRAILER msgid=78945669 client_pid=1056 auid=0 euid=0 egid=0 trailer_size=52
  NOTIFYD_N2_PROC_SOURCE_CREATE pid=1056 source_created=1
  NOTIFYD_N2_CONCURRENCY_REGISTER client=1 name=org.rmxos.notifyd.n2.concurrency.client_a token=0 status=0
  NOTIFYD_N2_CONCURRENCY_REGISTER client=2 name=org.rmxos.notifyd.n2.concurrency.client_b token=1 status=0
  NOTIFYD_N2_CONCURRENCY_CHECK client=1 token=0 phase=baseline expected=1 observed=1 status=0 attempts=1
  NOTIFYD_N2_CONCURRENCY_CHECK client=2 token=1 phase=baseline expected=1 observed=1 status=0 attempts=1
  NOTIFYD_N2_TWQ_PROGRESS point=registered status=0
  NOTIFYD_N2_CONCURRENCY_CLIENT_SPAWN client=dead pid=1057 status=0
  NOTIFYD_N2_CONCURRENCY_DEAD_CLIENT_PORT kr=0 port=20
  NOTIFYD_N2_CONCURRENCY_DEAD_CLIENT_MAKE_SEND kr=0
  NOTIFYD_N2_CONCURRENCY_REGISTER client=dead name=org.rmxos.notifyd.n2.concurrency.dead_client token=0 status=0
  NOTIFYD_N2_MACH_SEND_SOURCE_CREATE notify_port=21 registered_name=26 source_created=1
  NOTIFYD_N2_CONCURRENCY_POST client=2 name=org.rmxos.notifyd.n2.concurrency.client_a status=0
  NOTIFYD_N2_CONCURRENCY_CHECK client=1 token=0 phase=target expected=1 observed=1 status=0 attempts=2
  NOTIFYD_N2_CONCURRENCY_CHECK_SAMPLE client=2 token=1 reason=nontarget observed=0 status=0 allowed_false_positive=1
  NOTIFYD_N2_CONCURRENCY_POST client=2 name=org.rmxos.notifyd.n2.concurrency.client_b status=0
  NOTIFYD_N2_CONCURRENCY_CHECK client=2 token=1 phase=target expected=1 observed=1 status=0 attempts=2
  NOTIFYD_N2_CONCURRENCY_CHECK_SAMPLE client=1 token=0 reason=nontarget observed=1 status=0 allowed_false_positive=1
  NOTIFYD_N2_CONCURRENCY_POST client=1 name=org.rmxos.notifyd.n2.concurrency.client_a status=0
  NOTIFYD_N2_CONCURRENCY_CHECK client=1 token=0 phase=target expected=1 observed=1 status=0 attempts=2
  NOTIFYD_N2_CONCURRENCY_CHECK_SAMPLE client=2 token=1 reason=nontarget observed=0 status=0 allowed_false_positive=1
  NOTIFYD_N2_CONCURRENCY_CANCEL client=1 token=0 status=0
  NOTIFYD_N2_CONCURRENCY_CLIENT_EXIT client=dead pid=1057 status=0
  NOTIFYD_N2_TWQ_COUNTERS_AFTER workers=4 source=kern.smp.cpus
  NOTIFYD_N2_TWQ_PROGRESS point=final status=0
  NOTIFYD_N2_CONCURRENCY_FINAL_COUNTS clients=2 posts=3 baseline_checks=2 target_checks=3 samples=3 checks=8 cancels=1 dead_clients=1 status=0
  NOTIFYD_N2_CONCURRENCY_TERMINAL status=0
  phase095a_notifyd_n2_concurrency_exit=0
  === phase095a notifyd n2 concurrency end rc=0 ===
  """

  @n2c2b_serial """
  WARNING: WITNESS option enabled, expect reduced performance.
  KDB: debugger backends: ddb
  KDB: current backend: ddb
  === phase095b notifyd n2c2b client-death start ===
  mach_module=loaded
  NOTIFYD_N2_LAUNCHD_CHECKIN_REQUEST kr=0 result=dict
  NOTIFYD_N2_LAUNCHD_MACH_SERVICES_DICT present=1 type=dict
  NOTIFYD_N2_LAUNCHD_SERVICE_ENTRY service=com.apple.system.notification_center present=1 type=machport
  NOTIFYD_N2_LAUNCHD_RECEIVE_RIGHT service=com.apple.system.notification_center port=21 right=receive
  NOTIFYD_N2_LAUNCHD_CHECKIN_TERMINAL status=0
  NOTIFYD_N2C2B_SMOKE_START status=0 clients=1
  NOTIFYD_N2C2B_CLIENT_SPAWN pid=1062 status=0
  NOTIFYD_N2C2B_CLIENT_PORT kr=0 port=20
  NOTIFYD_N2C2B_CLIENT_MAKE_SEND kr=0
  NOTIFYD_N2_KERNEL_MACH_MSG_RECEIVE msgid=78945669 local_port=21 size=56 trailer_type=0
  NOTIFYD_N2_KERNEL_AUDIT_TRAILER msgid=78945669 client_pid=1062 auid=0 euid=0 egid=0 trailer_size=52
  NOTIFYD_N2_PROC_SOURCE_CREATE pid=1062 source_created=1
  NOTIFYD_N2C2B_PROC_SOURCE_CREATE pid=1062 source_created=1
  NOTIFYD_N2C2B_PROC_SOURCE_RESUME pid=1062 resumed=1
  NOTIFYD_N2_KERNEL_MACH_MSG_RECEIVE msgid=78945681 local_port=21 size=40 trailer_type=0
  NOTIFYD_N2_KERNEL_AUDIT_TRAILER msgid=78945681 client_pid=1062 auid=0 euid=0 egid=0 trailer_size=52
  NOTIFYD_N2_KERNEL_MACH_MSG_RECEIVE msgid=78945679 local_port=21 size=40 trailer_type=0
  NOTIFYD_N2_KERNEL_AUDIT_TRAILER msgid=78945679 client_pid=1062 auid=0 euid=0 egid=0 trailer_size=52
  NOTIFYD_N2C2B_CLIENT_REGISTER name=org.rmxos.notifyd.n2c2b.dead_client token=0 status=0
  NOTIFYD_N2_KERNEL_MACH_MSG_RECEIVE msgid=78945698 local_port=21 size=72 trailer_type=0
  NOTIFYD_N2_KERNEL_AUDIT_TRAILER msgid=78945698 client_pid=1062 auid=0 euid=0 egid=0 trailer_size=52
  NOTIFYD_N2_PROC_SOURCE_CREATE pid=1062 source_created=1
  NOTIFYD_N2C2B_PROC_SOURCE_CREATE pid=1062 source_created=1
  NOTIFYD_N2C2B_PROC_SOURCE_RESUME pid=1062 resumed=1
  NOTIFYD_N2C2B_PORTPROC_LOOKUP registered_name=26 site=register found=0
  NOTIFYD_N2_MACH_SEND_SOURCE_CREATE notify_port=21 registered_name=26 source_created=1
  NOTIFYD_N2C2B_MACH_SEND_SOURCE_CREATE registered_name=26 source_created=1
  NOTIFYD_N2C2B_SEND_RIGHT_RETAIN registered_name=26 kr=0
  NOTIFYD_N2C2B_PORTPROC_INSERT registered_name=26 state=suspended
  NOTIFYD_N2C2B_MACH_SEND_SOURCE_RESUME registered_name=26 resumed=1
  NOTIFYD_N2C2B_PRIVATE_NOTIFY_UPDATE_ENTER registered_name=26 new=9 del=0 mask=13 prev=0 fflags=9
  NOTIFYD_N2C2B_PRIVATE_NOTIFY_UPDATE_REQUEST kr=0 previous=0 msgid=72 sync=1 registered_name=26 notify_port=28
  NOTIFYD_N2C2B_PRIVATE_MSG_DRAIN_ENTER fflags=0 data=0 ext0=4096 ext1=16384
  NOTIFYD_N2C2B_PRIVATE_MSG_DRAIN_FAST id=72 local=28 size=36
  NOTIFYD_N2C2B_PRIVATE_DEAD_NAME name=26
  NOTIFYD_N2C2B_CLIENT_EXIT pid=1062 status=0
  NOTIFYD_N2C2B_PRIVATE_NOTIFY_MERGE_ENTER name=26 flag=1 final=1
  NOTIFYD_N2C2B_PRIVATE_NOTIFY_MERGE_FIND found=1 name=26 fflags=9 data=9
  NOTIFYD_N2C2B_PRIVATE_SOURCE_MERGE_KEVENT filter=-20 fflags=1 data=0 mask=9
  NOTIFYD_N2C2B_PRIVATE_NOTIFY_UPDATE_ENTER registered_name=26 new=0 del=9 mask=13 prev=0 fflags=9
  NOTIFYD_N2C2B_PORTPROC_LOOKUP registered_name=26 site=event found=1
  NOTIFYD_N2C2B_PORT_EVENT_ENTER registered_name=26 data=1
  NOTIFYD_N2_MACH_SEND_DEAD_EVENT registered_name=26 data=1
  NOTIFYD_N2C2B_TERMINAL status=0
  phase095b_notifyd_n2c2b_exit=0
  === phase095b notifyd n2c2b client-death end rc=1 ===
  """

  test "validates accepted MACH_SEND contract with corrected rc normalization" do
    serial = String.replace(@mach_send_serial, "\n", "\r\n")
    result = NotifydN2Series.validate_serial(:mach_send, serial, run_guest_rc: "1")

    assert result["passed"]
    assert result["ordered_marker_count"] == 11
    assert result["terminal_contract"]["run_guest_rc_accepted"]
    assert result["hard_stop_matches"] == []
  end

  test "validates accepted supporting split evidence families" do
    for {family, serial} <- [
          mach_raw: @mach_raw_serial,
          mach_direct: @mach_direct_serial,
          dispatch_notify_trace_timeout: @notify_trace_timeout_serial
        ] do
      assert NotifydN2Series.validate_serial(family, serial, run_guest_rc: "1")["passed"]
      assert NotifydN2Series.marker_coverage(family, serial)["passed"]
      assert NotifydN2Series.negative_controls(family, serial, "1")["passed"]
    end
  end

  test "validates accepted narrowed N2 concurrency contract" do
    result = NotifydN2Series.validate_serial(:concurrency, @concurrency_serial, run_guest_rc: "1")

    assert result["passed"]
    assert result["terminal_contract"]["run_guest_rc_accepted"]
    assert NotifydN2Series.marker_coverage(:concurrency, @concurrency_serial)["passed"]
    assert NotifydN2Series.negative_controls(:concurrency, @concurrency_serial, "1")["passed"]
  end

  test "validates narrowed N2C-2b client-death contract as distinct family" do
    result =
      NotifydN2Series.validate_serial(:n2c2b_client_death, @n2c2b_serial, run_guest_rc: "1")

    assert result["passed"]
    assert result["terminal_contract"]["run_guest_rc_accepted"]
    assert NotifydN2Series.marker_coverage(:n2c2b_client_death, @n2c2b_serial)["passed"]

    assert NotifydN2Series.negative_controls(:n2c2b_client_death, @n2c2b_serial, "1")[
             "passed"
           ]

    assert MarkerManifest.spec!(:n2c2b_mach_send_dead_event).family == :n2c2b_client_death

    assert MarkerManifest.spec!(:n2c2b_mach_send_dead_event).fields == %{
             registered_name: :positive_integer,
             data: :positive_integer
           }

    assert MarkerManifest.spec!(:mach_send_dead_event).fields == %{
             count: {:eq, "1"},
             duplicate: {:eq, "0"},
             data: :positive_integer
           }
  end

  test "authority records validate-only reclassification and closes the N2 series" do
    closeout = MarkerManifest.closeout()

    assert closeout.accepted_claim == MarkerManifest.accepted_claim()
    assert closeout.accepted_claims.concurrency == MarkerManifest.narrowed_concurrency_claim()

    assert closeout.accepted_claims.n2c2b_client_death ==
             MarkerManifest.n2c2b_client_death_claim()

    assert closeout.governing_record_commit == MarkerManifest.governing_record_commit()

    assert closeout.concurrency_governing_record_commit ==
             MarkerManifest.concurrency_governing_record_commit()

    assert closeout.source_pins.validator_correction == MarkerManifest.validator_correction_pin()

    assert closeout.source_pins.concurrency_validator ==
             MarkerManifest.concurrency_validator_pin()

    assert closeout.source_pins.n2c2b_validator == MarkerManifest.n2c2b_validator_pin()
    assert closeout.source_pins.donor_decode_fix == MarkerManifest.donor_decode_fix_pin()
    assert closeout.coordinator_acceptance =~ "narrowed N2C-1/N2C-2a/N2C-3"
    assert closeout.coordinator_acceptance =~ "narrowed N2C-2b"
    assert "direct_launchd_notifyd_facts_for_n2c_1" in closeout.satisfied_obligations
    assert "direct_kernel_receive_facts_for_n2c_2a" in closeout.satisfied_obligations

    assert "n2c_2b_cross_process_client_death_observation:satisfied-via-narrowed-contract" in closeout.satisfied_obligations

    refute "n2c_2b_cross_process_client_death_observation" in closeout.open_obligations
    refute "notifyd_n2_series_closeout_after_n2c_2b" in closeout.open_obligations

    assert "proc_path_independent_validation_non_port_client_or_non_racing_death" in closeout.open_obligations

    assert "NOTIFYD_N2_PROC_SOURCE_EVENT" in closeout.deferred_marker_families.n2c_2b_proc_path_independent_validation

    assert closeout.accepted_marker_families.n2c2b_client_death.field_policy == %{
             registered_name: :positive_integer,
             data: :positive_integer
           }

    assert closeout.new_guest_run_for_authority_extraction == false
    assert closeout.closeout_triggered == "notifyd_n2_series_closed_after_n2c_2b"
  end

  test "producer model separates donor harness kernel and launchd facts" do
    producers =
      MarkerManifest.specs()
      |> Enum.map(& &1.producer)
      |> Enum.uniq()
      |> Enum.sort()

    assert producers == [:donor, :harness, :kernel, :launchd]
    assert MarkerManifest.producer_breakdown()[:donor] > 0
    assert MarkerManifest.producer_breakdown()[:harness] > 0
    assert MarkerManifest.producer_breakdown()[:kernel] > 0
    assert MarkerManifest.producer_breakdown()[:launchd] == 10
  end

  test "coverage maps every accepted family key to authority" do
    for {family, serial} <- [
          mach_send: @mach_send_serial,
          mach_raw: @mach_raw_serial,
          mach_direct: @mach_direct_serial,
          dispatch_notify_trace_timeout: @notify_trace_timeout_serial,
          concurrency: @concurrency_serial,
          n2c2b_client_death: @n2c2b_serial
        ] do
      coverage = NotifydN2Series.marker_coverage(family, serial)

      assert coverage["passed"]
      assert coverage["unmapped_serial_keys"] == []
      assert coverage["authority_keys_missing_from_serial"] == []
      assert coverage["authority_specs_missing_from_serial"] == []
    end
  end

  test "MACH_SEND negative controls fail for intended classes" do
    controls = NotifydN2Series.negative_controls(:mach_send, @mach_send_serial, "1")

    concurrency_controls =
      NotifydN2Series.negative_controls(:concurrency, @concurrency_serial, "1")

    assert controls["passed"]
    assert concurrency_controls["passed"]

    classes =
      controls["controls"]
      |> Enum.map(& &1["class"])
      |> Enum.sort()
      |> Enum.uniq()

    assert classes == ~w(hard_stop order rc receipt terminal value)
  end

  test "hard-stop policy allows normal WITNESS banner and rejects diagnostics" do
    assert NotifydN2Series.hard_stop_scan(
             "WARNING: WITNESS option enabled, expect reduced performance.\n"
           )["passed"]

    refute NotifydN2Series.hard_stop_scan("WITNESS: lock diagnostic\n")["passed"]
    refute NotifydN2Series.hard_stop_scan("lock order reversal\n")["passed"]
    refute NotifydN2Series.hard_stop_scan("KASSERT(fake)\n")["passed"]
    refute NotifydN2Series.hard_stop_scan("KDB: stack backtrace\n")["passed"]
    refute NotifydN2Series.hard_stop_scan("dispatch assertion failed\n")["passed"]
  end

  test "rc=1 fails without terminal and phase07 exit markers" do
    missing_terminal =
      String.replace(@mach_send_serial, "NOTIFYD_N2_MACH_SEND_TERMINAL status=0", "")

    missing_exit = String.replace(@mach_send_serial, "phase07_dispatch_mach_send_exit=0", "")

    refute NotifydN2Series.validate_serial(:mach_send, missing_terminal, run_guest_rc: "1")[
             "passed"
           ]

    refute NotifydN2Series.validate_serial(:mach_send, missing_exit, run_guest_rc: "1")[
             "passed"
           ]
  end

  test "static no-copy cross-series and Phase07 whitelist checks pass" do
    report = NotifydN2Series.static_authority_contract_checks(File.cwd!())

    assert report["passed"]
    assert report["no_copy"]["passed"]
    assert report["cross_series"]["passed"]
    assert report["phase07_exit_whitelist"]["passed"]

    assert MarkerManifest.phase07_exit_whitelist()["phase07_dispatch_mach_send_exit"] == [
             :mach_send
           ]
  end

  test "seeded no-copy check catches copied N2 literals outside authority" do
    seeded =
      ContractCheck.no_copy_check(%{
        "lib/rmx_os_oracle/migration/seeded_notifyd_n2_copy.ex" =>
          ~s|def copied, do: "NOTIFYD_N2_MACH_SEND_DEAD_EVENT"|
      })

    refute seeded["passed"]
    assert [%{"literal" => "NOTIFYD_N2_MACH_SEND_DEAD_EVENT"}] = seeded["matches"]
  end

  test "accepted evidence hashes match recorded serial hashes when paths exist" do
    report = ContractCheck.accepted_evidence_hash_check(File.cwd!())

    assert report["passed"]

    mach_send =
      Enum.find(report["results"], &(&1["family"] == "mach_send")) ||
        flunk("mach_send evidence hash result missing")

    assert mach_send["expected_sha256"] ==
             "0e2a1b5d0fe24a1859e7e9124353dc62d10dc563a95227ae7ea819ddb7beb1bf"

    assert mach_send["passed"]

    concurrency =
      Enum.find(report["results"], &(&1["family"] == "concurrency")) ||
        flunk("concurrency evidence hash result missing")

    assert concurrency["expected_sha256"] ==
             "af1a56ee8d9b81def49babf3b6c211700416658253a83152b253f94146711500"

    assert concurrency["passed"]

    n2c2b =
      Enum.find(report["results"], &(&1["family"] == "n2c2b_client_death")) ||
        flunk("n2c2b_client_death evidence hash result missing")

    assert n2c2b["expected_sha256"] ==
             "eb28d75767826183374b5f18dca32dffad78e2491d88c1f8c2e5f1b21c293333"

    assert n2c2b["passed"]
  end

  test "preserved accepted MACH_SEND evidence revalidates when present" do
    evidence_path = Path.join(File.cwd!(), MarkerManifest.evidence(:mach_send).path)

    if File.exists?(evidence_path) do
      report = NotifydN2Series.revalidate_accepted_family(:mach_send, File.cwd!())

      assert report["passed"]
      assert report["accepted_claim"] == MarkerManifest.accepted_claim()
      assert report["serial_sha256"] == MarkerManifest.evidence(:mach_send).serial_sha256
      assert report["raw_evidence_mutated"] == false
    end
  end

  test "preserved accepted narrowed concurrency evidence revalidates when present" do
    evidence_path = Path.join(File.cwd!(), MarkerManifest.evidence(:concurrency).path)

    if File.exists?(evidence_path) do
      report = NotifydN2Series.revalidate_accepted_family(:concurrency, File.cwd!())

      assert report["passed"]
      assert report["accepted_claim"] == MarkerManifest.narrowed_concurrency_claim()
      assert report["serial_sha256"] == MarkerManifest.evidence(:concurrency).serial_sha256
      assert report["raw_evidence_mutated"] == false
    end
  end

  test "preserved narrowed N2C-2b evidence revalidates when present" do
    evidence_path = Path.join(File.cwd!(), MarkerManifest.evidence(:n2c2b_client_death).path)

    if File.exists?(evidence_path) do
      report = NotifydN2Series.revalidate_accepted_family(:n2c2b_client_death, File.cwd!())

      assert report["passed"]
      assert report["accepted_claim"] == MarkerManifest.n2c2b_client_death_claim()

      assert report["serial_sha256"] ==
               MarkerManifest.evidence(:n2c2b_client_death).serial_sha256

      assert report["raw_evidence_mutated"] == false
    end
  end
end
