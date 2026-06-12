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

  test "authority records validate-only reclassification and open N2 obligations" do
    closeout = MarkerManifest.closeout()

    assert closeout.accepted_claim == MarkerManifest.accepted_claim()
    assert closeout.governing_record_commit == MarkerManifest.governing_record_commit()
    assert closeout.source_pins.validator_correction == MarkerManifest.validator_correction_pin()
    assert closeout.source_pins.donor_decode_fix == MarkerManifest.donor_decode_fix_pin()
    assert closeout.maestro_acceptance =~ "validate-only reclassification"
    assert "direct_launchd_notifyd_facts" in closeout.open_obligations
    assert "direct_kernel_notifyd_facts" in closeout.open_obligations
    assert closeout.new_guest_run_for_authority_extraction == false
  end

  test "producer model separates donor harness and kernel facts" do
    producers =
      MarkerManifest.specs()
      |> Enum.map(& &1.producer)
      |> Enum.uniq()
      |> Enum.sort()

    assert producers == [:donor, :harness, :kernel]
    assert MarkerManifest.producer_breakdown()[:donor] > 0
    assert MarkerManifest.producer_breakdown()[:harness] > 0
    assert MarkerManifest.producer_breakdown()[:kernel] > 0
  end

  test "coverage maps every accepted family key to authority" do
    for {family, serial} <- [
          mach_send: @mach_send_serial,
          mach_raw: @mach_raw_serial,
          mach_direct: @mach_direct_serial,
          dispatch_notify_trace_timeout: @notify_trace_timeout_serial
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

    assert controls["passed"]

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
end
