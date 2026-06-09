defmodule Phase08MarkerManifestTest do
  use ExUnit.Case, async: true

  alias Phase08.LaunchctlVerifierCommon
  alias Phase08.MarkerManifest

  @fixture_dir Path.expand("../fixtures/phase08/launchctl", __DIR__)

  test "marker inventory is stable and unique" do
    markers = MarkerManifest.markers()
    ids = Enum.map(markers, & &1.id)
    keys = Enum.map(markers, & &1.key)

    assert length(markers) > 0
    assert ids == Enum.uniq(ids)
    assert keys == Enum.uniq(keys)
    assert :d22_running_donor_sent_signal in ids
    assert :d19_confirmed in ids
    assert :d23_inert_reload_accepted in ids
  end

  test "gate and arm filters expose expected marker ids" do
    assert :d22_running_donor_sent_signal in marker_ids(MarkerManifest.for_gate(:d22))
    assert :d19_confirmed in marker_ids(MarkerManifest.for_gate(:d19))
    assert :d23_inert_reload_accepted in marker_ids(MarkerManifest.for_gate(:d23))

    assert :d22_running_deferred_enter_count in marker_ids(MarkerManifest.for_arm(:d22, :running))

    assert :d22_keepalive_deferred_enter_count in marker_ids(
             MarkerManifest.for_arm(:d22, :keepalive)
           )

    assert :d23_inert_reload_accepted in marker_ids(MarkerManifest.for_arm(:d23, :inert))
    assert :d23_keepalive_reload_accepted in marker_ids(MarkerManifest.for_arm(:d23, :keepalive))
  end

  test "D19 manifest literals match the shared launchctl helper contract" do
    manifest_literals =
      :d19
      |> MarkerManifest.for_gate()
      |> Enum.map(&MarkerManifest.marker_literal/1)
      |> MapSet.new()

    helper_literals =
      LaunchctlVerifierCommon.d19_order_markers()
      |> MapSet.new()

    assert manifest_literals == helper_literals
  end

  test "D19 manifest producer attribution is donor or harness only" do
    d19_specs = MarkerManifest.for_gate(:d19)

    assert Enum.all?(d19_specs, &(&1.producer in [:donor, :harness]))
    assert MarkerManifest.spec!(:d19_gate_start).producer == :harness

    behavioral_specs = Enum.reject(d19_specs, &(&1.id == :d19_gate_start))
    assert behavioral_specs != []
    assert Enum.all?(behavioral_specs, &(&1.producer == :donor))
    assert Enum.all?(behavioral_specs, &Map.has_key?(&1, :producer_detail))
  end

  test "D19 manifest validates the accepted preserved serial" do
    assert MarkerManifest.validate_log!(
             fixture!("d19_keepalive_restart.accepted.serial.log"),
             :d19
           ) ==
             :ok
  end

  test "D19 frozen generator anchors match the manifest and have red paths" do
    source = fixture!("d19_frozen_generator_anchors_089311cff65b.source.txt")
    manifest_literals = d19_manifest_literals()

    anchor_literals =
      source
      |> MarkerManifest.d19_frozen_generator_anchors_from_text()
      |> Enum.map(& &1.literal)

    assert MapSet.new(anchor_literals) == MapSet.new(manifest_literals)
    assert length(anchor_literals) == length(Enum.uniq(anchor_literals))
    assert MarkerManifest.validate_d19_frozen_generator_anchor_drift!(source) == :ok

    manifest_drift = List.replace_at(manifest_literals, 0, "PHASE08_D19_DRIFTED=1")

    assert_raise ArgumentError, ~r/D19 manifest\/frozen generator anchor drift/, fn ->
      MarkerManifest.validate_d19_frozen_generator_anchor_drift!(source, manifest_drift)
    end

    source_drift =
      String.replace(
        source,
        "PHASE08_D19_KEEPALIVE_RESTART_CONFIRMED=%d",
        "PHASE08_D19_KEEPALIVE_RESTART_MISSING=%d"
      )

    assert_raise ArgumentError, ~r/D19 manifest\/frozen generator anchor drift/, fn ->
      MarkerManifest.validate_d19_frozen_generator_anchor_drift!(source_drift)
    end

    ref = MarkerManifest.d19_frozen_generator_anchor_source_reference()
    assert ref.short_commit == "089311cff65b"

    assert ref.fixture ==
             "test/fixtures/phase08/launchctl/d19_frozen_generator_anchors_089311cff65b.source.txt"

    assert Enum.map(ref.source_refs, & &1.path) == [
             "scripts/launchd/build-phase08-d15-launchctl-json-hardfail.sh",
             "scripts/launchd/link-launchd-harness.sh"
           ]
  end

  test "D19 frozen generator dynamic cycle and value anchors are explicit" do
    specs = MarkerManifest.d19_frozen_generator_anchor_specs()

    cycle_start = find_anchor!(specs, :d19_cycle_job_start)
    assert cycle_start.kind == :dynamic_cycle
    assert cycle_start.dynamic.cycles == [1, 2]

    assert cycle_start.expands_to == [
             "PHASE08_D19_CYCLE1_JOB_START_CALLED=1",
             "PHASE08_D19_CYCLE2_JOB_START_CALLED=1"
           ]

    cycle_reap = find_anchor!(specs, :d19_cycle_reap_path)
    assert cycle_reap.kind == :dynamic_cycle_value
    assert cycle_reap.dynamic.cycles == [1, 2]
    assert cycle_reap.dynamic.accepted_value == "dispatch_proc_source"

    assert cycle_reap.expands_to == [
             "PHASE08_D19_CYCLE1_REAP_PATH=dispatch_proc_source",
             "PHASE08_D19_CYCLE2_REAP_PATH=dispatch_proc_source"
           ]

    runtime_demux = find_anchor!(specs, :d19_runtime_demux)
    assert runtime_demux.kind == :dynamic_value
    assert runtime_demux.dynamic.accepted_value == "1"

    confirmation = find_anchor!(specs, :d19_confirmation)
    assert confirmation.kind == :dynamic_value
    assert confirmation.dynamic.accepted_value == "1"
  end

  test "lookup and C emission helpers preserve manifest policy" do
    assert MarkerManifest.key!(:d23_inert_reload_accepted) ==
             "PHASE08_D23_INERT_RELOAD_ACCEPTED"

    assert MarkerManifest.spec!(:d23_inert_reload_accepted).policy == {:must_equal, "1"}

    assert MarkerManifest.c_key!(:d23_inert_reload_accepted) ==
             "PHASE08_D23_INERT_RELOAD_ACCEPTED"

    assert MarkerManifest.emit_c(:d23_inert_reload_accepted, "accepted ? 1 : 0", "%d") ==
             ~s|printf("PHASE08_D23_INERT_RELOAD_ACCEPTED=%d\\n", accepted ? 1 : 0);|

    assert MarkerManifest.emit_c(:d23_inert_reload_accepted, "1", fmt: "%d", value: "1") ==
             ~s|printf("PHASE08_D23_INERT_RELOAD_ACCEPTED=%d\\n", 1);|

    assert MarkerManifest.emit_c(:d22_running_deferred_enter_count, "2",
             fmt: "%d",
             value: "2"
           ) ==
             ~s|printf("PHASE08_D22_RUNNING_REMOVE_HANDLER_ENTER_COUNT=%d\\n", 2);|

    assert MarkerManifest.emit_c(:d22_running_donor_sent_signal, "SIGTERM",
             fmt: "%s",
             value: "SIGTERM"
           ) ==
             ~s|printf("PHASE08_D22_RUNNING_DONOR_SENT_SIGNAL=%s\\n", SIGTERM);|

    assert_raise ArgumentError, ~r/presence-only marker cannot be emitted with emit_c/, fn ->
      MarkerManifest.emit_c(:d19_gate_start, "1", "%d", value: "1")
    end
  end

  test "C string escaping handles quotes, backslash, newline, tab, and percent" do
    assert MarkerManifest.c_string_literal("quote\" slash\\ newline\n tab\t percent%") ==
             ~s|"quote\\" slash\\\\ newline\\n tab\\t percent%"|
  end

  test "marker value extraction and positive log validation work for D22 and D23" do
    key = MarkerManifest.key!(:d22_running_deferred_enter_count)
    assert MarkerManifest.marker_values("#{key}=1\n#{key}=2\n", key) == ["1", "2"]

    assert MarkerManifest.validate_log!(synthetic_log(:d22), :d22) == :ok
    assert MarkerManifest.validate_log!(synthetic_log(:d23), :d23) == :ok
  end

  test "negative behavior fails loudly for marker-specific reasons" do
    assert_raise ArgumentError, ~r/unknown Phase 0.8 marker id: :missing_marker/, fn ->
      MarkerManifest.key!(:missing_marker)
    end

    assert_raise ArgumentError, ~r/requires a binary value expression/, fn ->
      MarkerManifest.emit_c(:d23_inert_reload_accepted, nil, "%d")
    end

    assert_raise ArgumentError, ~r/requires a non-empty value expression/, fn ->
      MarkerManifest.emit_c(:d23_inert_reload_accepted, "", "%d")
    end

    assert_raise ArgumentError, ~r/emit_c value "0" != manifest expected "1"/, fn ->
      MarkerManifest.emit_c(:d23_inert_reload_accepted, "0", fmt: "%d", value: "0")
    end

    assert_raise ArgumentError, ~r/missing marker PHASE08_D23_RELOAD_REQUESTED/, fn ->
      MarkerManifest.validate_log!(synthetic_log(:d23, %{}, [:d23_requested]), :d23)
    end

    assert_raise ArgumentError, ~r/expected all values "1"/, fn ->
      MarkerManifest.validate_log!(synthetic_log(:d23, %{d23_requested: "0"}), :d23)
    end
  end

  defp marker_ids(markers), do: Enum.map(markers, & &1.id)

  defp fixture!(name), do: File.read!(Path.join(@fixture_dir, name))

  defp d19_manifest_literals do
    :d19
    |> MarkerManifest.for_gate()
    |> Enum.map(&MarkerManifest.marker_literal/1)
  end

  defp find_anchor!(specs, id), do: Enum.find(specs, &(&1.id == id))

  defp synthetic_log(gate, overrides \\ %{}, skip_ids \\ []) do
    gate
    |> MarkerManifest.for_gate()
    |> Enum.reject(&(&1.id in skip_ids))
    |> Enum.map_join("", fn spec ->
      value = Map.get(overrides, spec.id, policy_value(spec.policy))
      "#{spec.key}=#{value}\n"
    end)
  end

  defp policy_value({:must_equal, expected}), do: to_string(expected)
  defp policy_value({:must_include, expected}), do: to_string(expected)
  defp policy_value({:must_be_one_of, [expected | _rest]}), do: to_string(expected)
  defp policy_value(:must_be_present), do: ""
end
