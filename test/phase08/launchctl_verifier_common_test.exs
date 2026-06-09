defmodule Phase08LaunchctlVerifierCommonTest do
  use ExUnit.Case, async: true

  alias Phase08.LaunchctlVerifierCommon
  alias Phase08.LaunchctlVerifierContractCheck
  alias Phase08.MarkerManifest

  @fixture_dir Path.expand("../fixtures/phase08/launchctl", __DIR__)

  @source_d19_order [
    "phase08_dispatch_launchctl_keepalive_restart_start",
    "PHASE08_D19_MANAGEMENT_REQUEST_SENT=1",
    "PHASE08_D19_CALLER_PID_MATCH=1",
    "PHASE08_D19_DONOR_RUNTIME_DEMUX_CALLED=1",
    "PHASE08_D19_START_PENDING_SET=1",
    "PHASE08_D19_JOB_KEEPALIVE_REASON=start_pending",
    "PHASE08_D19_CYCLE1_JOB_START_CALLED=1",
    "PHASE08_D19_POSIX_SPAWN_SETEXEC_BRIDGE=direct_exec",
    "PHASE08_D19_CYCLE1_REAP_PATH=dispatch_proc_source",
    "PHASE08_D19_CYCLE2_JOB_START_CALLED=1",
    "PHASE08_D19_POST_CYCLE1_KEEPALIVE_REASON=keepalive",
    "PHASE08_D19_STOP_AFTER_CYCLE2_ARMED=1",
    "PHASE08_D19_CYCLE2_REAP_PATH=dispatch_proc_source",
    "PHASE08_D19_STOP_RESTART_SUPPRESSED=harness_cycle_limit",
    "PHASE08_D19_KEEPALIVE_RESTART_CONFIRMED=1"
  ]

  @source_d20_order [
    "phase08_dispatch_launchctl_successful_exit_start",
    "PHASE08_D20_MANAGEMENT_REQUEST_SENT=1",
    "PHASE08_D20_CALLER_PID_MATCH=1",
    "PHASE08_D20_DONOR_RUNTIME_DEMUX_CALLED=1",
    "PHASE08_D20_START_PENDING_SET=1",
    "PHASE08_D20_JOB_KEEPALIVE_REASON=start_pending",
    "PHASE08_D20_CYCLE1_JOB_START_CALLED=1",
    "PHASE08_D20_POSIX_SPAWN_SETEXEC_BRIDGE=direct_exec",
    "PHASE08_D20_CYCLE1_REAP_PATH=dispatch_proc_source",
    "PHASE08_D20_POSTREAP_KEEPALIVE_REASON=successful_exit",
    "PHASE08_D20_CYCLE2_JOB_START_CALLED=1",
    "PHASE08_D20_POST_CYCLE1_KEEPALIVE_REASON=successful_exit",
    "PHASE08_D20_CYCLE2_REAP_PATH=dispatch_proc_source",
    "PHASE08_D20_POST_CYCLE2_KEEPALIVE_REASON=successful_exit_mismatch",
    "PHASE08_D20_CONDITIONAL_KEEPALIVE_CONFIRMED=1"
  ]

  test "Oracle D19 order contract matches the transitional source contract" do
    assert LaunchctlVerifierCommon.source_reference().short_commit == "089311cff65b"
    assert LaunchctlVerifierCommon.d19_order_markers() == @source_d19_order

    assert LaunchctlVerifierCommon.d19_order_hash() ==
             "9fd4d8e8605a0d34cfaf9ecaa3cbb4b7edc9b64b5ff42efc61f416025bb24293"
  end

  test "D19 contract carries producer attribution and downstream consumer data" do
    contract = LaunchctlVerifierCommon.d19_order_contract()
    consumers = LaunchctlVerifierCommon.d19_downstream_consumers()
    not_applicable = LaunchctlVerifierCommon.d19_not_applicable_consumers()

    assert Enum.all?(contract, &(&1.producer in [:donor, :harness]))

    assert Enum.all?(
             Enum.reject(contract, &(&1.producer == :harness)),
             &Map.has_key?(&1, :producer_detail)
           )

    assert Enum.find(contract, &(&1.id == :d19_confirmed)).producer == :donor
    assert Enum.find(contract, &(&1.id == :d19_confirmed)).producer_detail == :donor_job
    assert Enum.map(consumers, & &1.id) == [:d19, :d20, :d21, :d22]
    assert Enum.all?(consumers, &(&1.order_ref == :d19_shared_order))
    assert [%{id: :d23, status: :not_applicable, reason: reason}] = not_applicable
    assert reason =~ "D19-D22 only"
  end

  test "Oracle D20 order contract is live and matches the source verifier list" do
    assert LaunchctlVerifierCommon.d20_order_markers() == @source_d20_order

    assert LaunchctlVerifierCommon.d20_order_hash() ==
             "b167826bfd13b6157bb22920e42e64cedf7a7196efff069e5d678f980a15586c"

    assert LaunchctlVerifierCommon.validate_d20(d20_serial()) == :ok
  end

  test "Oracle static contract check accepts shared-order consumers" do
    assert LaunchctlVerifierContractCheck.check_oracle_layout() == :ok
    assert LaunchctlVerifierContractCheck.check_oracle_layout!() == :ok
  end

  test "Oracle static contract check rejects copied D19/D20 ordered marker literals in source text" do
    assert {:error, issues} =
             LaunchctlVerifierContractCheck.check_layout(%{
               contracts: LaunchctlVerifierContractCheck.runtime_contracts(),
               source_texts: [
                 LaunchctlVerifierContractCheck.owner_source_text(),
                 LaunchctlVerifierContractCheck.seeded_copied_order_source_text(:d19),
                 LaunchctlVerifierContractCheck.seeded_copied_order_source_text(:d20)
               ]
             })

    assert Enum.any?(
             issues,
             &match?(
               %{
                 reason: :copied_d19_order_contract,
                 path: "lib/phase08/seeded_bad_d19_consumer.ex"
               },
               &1
             )
           )

    assert Enum.any?(
             issues,
             &match?(
               %{
                 reason: :copied_d20_order_contract,
                 path: "lib/phase08/seeded_bad_d20_consumer.ex"
               },
               &1
             )
           )
  end

  test "Oracle static contract check rejects consumers missing the shared order ref" do
    consumers =
      Enum.map(LaunchctlVerifierCommon.d19_downstream_consumers(), fn
        %{id: :d22} = consumer -> Map.delete(consumer, :order_ref)
        consumer -> consumer
      end)

    assert {:error, issues} =
             LaunchctlVerifierContractCheck.check_layout(%{
               owner_markers: LaunchctlVerifierCommon.d19_order_markers(),
               consumers: consumers,
               not_applicable_consumers: LaunchctlVerifierCommon.d19_not_applicable_consumers(),
               source_texts: [LaunchctlVerifierContractCheck.owner_source_text()]
             })

    assert %{
             reason: :missing_shared_order_ref,
             contract: :d19,
             consumers: [:d22],
             shared_ref: :d19_shared_order
           } in issues
  end

  test "accepted D19 preserved serial validates" do
    assert LaunchctlVerifierCommon.validate_d19(d19_serial()) == :ok
  end

  test "accepted D20 preserved serial validates with inherited D19 and live D20 order" do
    assert LaunchctlVerifierCommon.validate_d20(d20_serial()) == :ok
  end

  test "accepted D21 preserved serial validates with manifest-backed remove markers" do
    assert LaunchctlVerifierCommon.validate_d21(d21_serial()) == :ok
  end

  test "D19 fails when KEEPALIVE_RESTART_CONFIRMED is missing" do
    serial = String.replace(d19_serial(), "PHASE08_D19_KEEPALIVE_RESTART_CONFIRMED=1", "")

    assert {:error, error} = LaunchctlVerifierCommon.validate_d19(serial)
    assert error.consumer == :d19
    assert error.reason == :missing_marker
    assert error.marker == "PHASE08_D19_KEEPALIVE_RESTART_CONFIRMED=1"
  end

  test "D19 fails when cycle2 reap appears before cycle2 start" do
    serial =
      d19_serial()
      |> move_before(
        "PHASE08_D19_CYCLE2_REAP_PATH=dispatch_proc_source",
        "PHASE08_D19_CYCLE2_JOB_START_CALLED=1"
      )

    assert {:error, error} = LaunchctlVerifierCommon.validate_d19(serial)
    assert error.consumer == :d19
    assert error.reason == :out_of_order_marker
    assert error.marker == "PHASE08_D19_CYCLE2_REAP_PATH=dispatch_proc_source"
  end

  test "D19 first-match ordering rejects early duplicate rescue attempts" do
    duplicate_marker = "PHASE08_D19_POSIX_SPAWN_SETEXEC_BRIDGE=direct_exec"
    serial = duplicate_marker <> "\n" <> synthetic_inherited_log()

    assert {:error, error} = LaunchctlVerifierCommon.validate_inherited_d19_order(serial, :d20)
    assert error.consumer == :d20
    assert error.reason == :out_of_order_marker
    assert error.marker == duplicate_marker
  end

  test "D19 fails closed when the terminal harness marker is missing" do
    serial = String.replace(d19_serial(), "=== phase1 launchd harness end rc=0 ===", "")

    assert {:error, error} = LaunchctlVerifierCommon.validate_d19(serial)
    assert error.consumer == :d19
    assert error.reason == :incomplete_serial
    assert error.marker == "=== phase1 launchd harness end rc=0 ==="
  end

  test "D20 fails on D20-specific conditional keepalive falsifier" do
    serial = String.replace(d20_serial(), "PHASE08_D20_CONDITIONAL_KEEPALIVE_CONFIRMED=1", "")

    assert {:error, error} = LaunchctlVerifierCommon.validate_d20(serial)
    assert error.consumer == :d20
    assert error.reason == :missing_marker
    assert error.marker == "PHASE08_D20_CONDITIONAL_KEEPALIVE_CONFIRMED=1"
  end

  test "D20 fails on wrong no-third-start value" do
    serial =
      String.replace(d20_serial(), "PHASE08_D20_NO_THIRD_START=1", "PHASE08_D20_NO_THIRD_START=0")

    assert {:error, error} = LaunchctlVerifierCommon.validate_d20(serial)
    assert error.consumer == :d20
    assert error.reason == :missing_marker
    assert error.marker == "PHASE08_D20_NO_THIRD_START=1"
  end

  test "D20 fails when D20 order is invalid" do
    serial =
      d20_serial()
      |> move_before(
        "PHASE08_D20_CYCLE2_REAP_PATH=dispatch_proc_source",
        "PHASE08_D20_CYCLE2_JOB_START_CALLED=1"
      )

    assert {:error, error} = LaunchctlVerifierCommon.validate_d20(serial)
    assert error.consumer == :d20
    assert error.reason == :out_of_order_marker
    assert error.marker == "PHASE08_D20_CYCLE2_REAP_PATH=dispatch_proc_source"
  end

  test "D20 first-match ordering rejects early duplicate rescue attempts" do
    duplicate_marker = "PHASE08_D20_POSIX_SPAWN_SETEXEC_BRIDGE=direct_exec"
    serial = duplicate_marker <> "\n" <> synthetic_d20_inherited_log()

    assert {:error, error} = LaunchctlVerifierCommon.validate_inherited_d20_order(serial, :d21)
    assert error.consumer == :d21
    assert error.reason == :out_of_order_marker
    assert error.marker == duplicate_marker
  end

  test "D20 truncated serial is incomplete and cannot pass" do
    truncated = binary_part(d20_serial(), 0, 2_000)

    assert {:error, error} = LaunchctlVerifierCommon.validate_d20(truncated)
    assert error.consumer == :d20
    assert error.reason in [:missing_marker, :incomplete_serial]
  end

  test "D21 fails on missing donor remove marker" do
    serial = String.replace(d21_serial(), "PHASE08_D21_REMOVE_HANDLER_CALLED=1", "")

    assert {:error, error} = LaunchctlVerifierCommon.validate_d21(serial)
    assert error.consumer == :d21
    assert error.reason == :missing_marker
    assert error.marker == "PHASE08_D21_REMOVE_HANDLER_CALLED=1"
  end

  test "D21 fails on wrong donor remove state value" do
    serial =
      String.replace(
        d21_serial(),
        "PHASE08_D21_JOB_STRUCT_NO_LEAK=1",
        "PHASE08_D21_JOB_STRUCT_NO_LEAK=0"
      )

    assert {:error, error} = LaunchctlVerifierCommon.validate_d21(serial)
    assert error.consumer == :d21
    assert error.reason == :missing_marker
    assert error.marker == "PHASE08_D21_JOB_STRUCT_NO_LEAK=1"
  end

  test "D21 truncated serial is incomplete and cannot pass" do
    truncated = binary_part(d21_serial(), 0, 2_000)

    assert {:error, error} = LaunchctlVerifierCommon.validate_d21(truncated)
    assert error.consumer == :d21
    assert error.reason in [:missing_marker, :incomplete_serial]
  end

  test "truncated D19 serial is incomplete and cannot pass" do
    truncated = binary_part(d19_serial(), 0, 2_000)

    assert {:error, error} = LaunchctlVerifierCommon.validate_d19(truncated)
    assert error.consumer == :d19
    assert error.reason in [:missing_marker, :incomplete_serial]
  end

  test "D20-D22 consumers fail closed on invalid inherited D19 order" do
    invalid_log =
      synthetic_inherited_log()
      |> move_before(
        "PHASE08_D19_CYCLE2_REAP_PATH=dispatch_proc_source",
        "PHASE08_D19_CYCLE2_JOB_START_CALLED=1"
      )

    for consumer <- [:d20, :d21, :d22] do
      assert {:error, error} =
               LaunchctlVerifierCommon.validate_inherited_d19_order(invalid_log, consumer)

      assert error.consumer == consumer
      assert error.reason == :out_of_order_marker
      assert error.marker == "PHASE08_D19_CYCLE2_REAP_PATH=dispatch_proc_source"
    end
  end

  test "D21-D22 consumers fail closed on invalid inherited D20 order" do
    invalid_log =
      synthetic_d20_inherited_log()
      |> move_before(
        "PHASE08_D20_CYCLE2_REAP_PATH=dispatch_proc_source",
        "PHASE08_D20_CYCLE2_JOB_START_CALLED=1"
      )

    for consumer <- [:d21, :d22] do
      assert {:error, error} =
               LaunchctlVerifierCommon.validate_inherited_d20_order(invalid_log, consumer)

      assert error.consumer == consumer
      assert error.reason == :out_of_order_marker
      assert error.marker == "PHASE08_D20_CYCLE2_REAP_PATH=dispatch_proc_source"
    end
  end

  test "tail declarations are manifest-backed or explicitly tail-only" do
    declared_markers =
      LaunchctlVerifierCommon.required_tail_marker_declarations()
      |> Enum.flat_map(&tail_declaration_markers/1)
      |> MapSet.new()

    required_markers =
      [:d19, :d20, :d21]
      |> Enum.flat_map(&LaunchctlVerifierCommon.required_tail_markers/1)
      |> MapSet.new()

    assert MapSet.subset?(required_markers, declared_markers)

    for declaration <- LaunchctlVerifierCommon.required_tail_marker_declarations() do
      cond do
        declaration.backing == :manifest and is_list(declaration[:ids]) ->
          Enum.each(declaration.ids, &marker_literal!/1)

        declaration.backing == :order_and_manifest ->
          assert marker_literal!(declaration.id) == declaration.marker

        declaration.backing == :manifest ->
          assert marker_literal!(declaration.id) == declaration.marker

        declaration.backing == :tail_only ->
          assert is_binary(declaration.marker)
          assert is_binary(declaration.reason)
      end
    end

    assert Enum.any?(
             LaunchctlVerifierCommon.required_tail_marker_declarations(),
             &match?(
               %{
                 gate: :d19,
                 marker: "PHASE08_D19_CYCLE2_PROC_SOURCE_CANCELLED=1",
                 backing: :tail_only
               },
               &1
             )
           )
  end

  test "D22/D23 reconciliation audit has no must-fix findings" do
    audit = LaunchctlVerifierCommon.d22_d23_reconciliation_audit()
    assert Enum.all?(audit, &(&1.status in [:pass, :deferred, :not_applicable]))
    refute Enum.any?(audit, &(&1.status == :must_fix))

    assert Enum.any?(
             audit,
             &match?(%{item: :d23_inherits_d19_order, status: :not_applicable}, &1)
           )

    assert LaunchctlVerifierCommon.ordering_checkpoint().decision ==
             :option_b_helper_owns_ordering
  end

  test "fixture provenance records accepted source evidence" do
    d19 = decode_json!("d19_keepalive_restart.provenance.json")
    d20 = decode_json!("d20_successful_exit.provenance.json")
    d21 = decode_json!("d21_remove.provenance.json")

    assert d19["source"]["accepted_validator_commit"] ==
             "089311cff65bf116323a1e2e2d5ccf602432a22c"

    assert d20["source"]["accepted_validator_commit"] ==
             "089311cff65bf116323a1e2e2d5ccf602432a22c"

    assert d21["source"]["accepted_validator_commit"] ==
             "089311cff65bf116323a1e2e2d5ccf602432a22c"

    assert d19["source"]["original_run_path"] =~ "priv/runs/"
    assert d20["source"]["original_run_path"] =~ "priv/runs/"
    assert d21["source"]["original_run_path"] =~ "priv/runs/"
    assert File.exists?(Path.join(@fixture_dir, d19["fixture"] |> Path.basename()))
    assert d19["sha256"] == sha256_file!("d19_keepalive_restart.accepted.serial.log")
    assert d20["sha256"] == sha256_file!("d20_successful_exit.accepted.serial.log")
    assert d21["sha256"] == sha256_file!("d21_remove.accepted.serial.log")
  end

  defp d19_serial do
    File.read!(Path.join(@fixture_dir, "d19_keepalive_restart.accepted.serial.log"))
  end

  defp d20_serial do
    File.read!(Path.join(@fixture_dir, "d20_successful_exit.accepted.serial.log"))
  end

  defp d21_serial do
    File.read!(Path.join(@fixture_dir, "d21_remove.accepted.serial.log"))
  end

  defp synthetic_inherited_log do
    Enum.join(LaunchctlVerifierCommon.d19_order_markers(), "\n") <> "\n"
  end

  defp synthetic_d20_inherited_log do
    Enum.join(LaunchctlVerifierCommon.d20_order_markers(), "\n") <> "\n"
  end

  defp marker_literal!(id), do: MarkerManifest.marker_literal(MarkerManifest.spec!(id))

  defp tail_declaration_markers(%{ids: ids}) when is_list(ids),
    do: Enum.map(ids, &marker_literal!/1)

  defp tail_declaration_markers(%{marker: marker}), do: [marker]

  defp move_before(serial, moving_marker, before_marker) do
    serial
    |> remove_line_containing!(moving_marker)
    |> insert_line_before!(moving_marker, before_marker)
  end

  defp remove_line_containing!(serial, marker) do
    lines = String.split(serial, "\n", trim: false)
    {removed, kept} = Enum.split_with(lines, &String.contains?(&1, marker))

    if removed == [] do
      flunk("marker to move not found: #{marker}")
    end

    Enum.join(kept, "\n")
  end

  defp insert_line_before!(serial, moving_marker, before_marker) do
    lines = String.split(serial, "\n", trim: false)
    idx = Enum.find_index(lines, &String.contains?(&1, before_marker))

    if is_nil(idx) do
      flunk("target marker not found: #{before_marker}")
    end

    lines
    |> List.insert_at(idx, moving_marker)
    |> Enum.join("\n")
  end

  defp decode_json!(filename) do
    filename
    |> then(&Path.join(@fixture_dir, &1))
    |> File.read!()
    |> JSON.decode!()
  end

  defp sha256_file!(filename) do
    @fixture_dir
    |> Path.join(filename)
    |> File.read!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
