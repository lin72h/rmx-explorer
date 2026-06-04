defmodule Phase08MarkerManifestTest do
  use ExUnit.Case, async: true

  alias Phase08.MarkerManifest

  test "marker inventory is stable and unique" do
    markers = MarkerManifest.markers()
    ids = Enum.map(markers, & &1.id)
    keys = Enum.map(markers, & &1.key)

    assert length(markers) > 0
    assert ids == Enum.uniq(ids)
    assert keys == Enum.uniq(keys)
    assert :d22_running_donor_sent_signal in ids
    assert :d23_inert_reload_accepted in ids
  end

  test "gate and arm filters expose expected marker ids" do
    assert :d22_running_donor_sent_signal in marker_ids(MarkerManifest.for_gate(:d22))
    assert :d23_inert_reload_accepted in marker_ids(MarkerManifest.for_gate(:d23))

    assert :d22_running_deferred_enter_count in marker_ids(MarkerManifest.for_arm(:d22, :running))

    assert :d22_keepalive_deferred_enter_count in marker_ids(
             MarkerManifest.for_arm(:d22, :keepalive)
           )

    assert :d23_inert_reload_accepted in marker_ids(MarkerManifest.for_arm(:d23, :inert))
    assert :d23_keepalive_reload_accepted in marker_ids(MarkerManifest.for_arm(:d23, :keepalive))
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
end
