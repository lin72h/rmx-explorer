defmodule RmxOSOracle.Phase085.LaunchdHandoffTest do
  use ExUnit.Case, async: true

  alias RmxOSOracle.Asl.A2.MarkerManifest, as: AslA2
  alias RmxOSOracle.Notifyd.N2.MarkerManifest, as: NotifydN2
  alias RmxOSOracle.Phase085.LaunchdHandoff.{ContractCheck, MarkerManifest}

  test "generic authority records four shared launchd facts and evidence basis" do
    assert MarkerManifest.fact_ids() == [
             :checkin_response_materialized,
             :machservices_dictionary_present,
             :selected_service_entry_present,
             :receive_right_materialized
           ]

    assert MarkerManifest.fact!(:checkin_response_materialized).producer == :launchd

    assert MarkerManifest.fact!(:selected_service_entry_present).required_parameters == [
             :service_name
           ]

    assert MarkerManifest.fact!(:receive_right_materialized).required_parameters == [
             :service_name
           ]

    closeout = MarkerManifest.closeout()

    assert closeout.design.commit == MarkerManifest.design_commit()
    assert closeout.data_comparison.commit == MarkerManifest.comparison_commit()
    assert closeout.evidence_basis.asl_a2.service_name == "com.apple.system.logger"

    assert closeout.evidence_basis.notifyd_n2.service_name ==
             "com.apple.system.notification_center"

    assert "no_richer_n2_only_field_promotion" in closeout.non_claims
    assert closeout.emission_site_verification_owner == "consumer_authority"
  end

  test "series prefix registry names A2 and N2 consumers" do
    registry = MarkerManifest.consumer_registry()

    assert registry.asl_a2.series_prefix == "ASL_A2_"
    assert registry.asl_a2.generic_source == MarkerManifest.authority_id()
    assert registry.notifyd_n2.series_prefix == "NOTIFYD_N2_LAUNCHD_"
    assert registry.notifyd_n2.generic_source == MarkerManifest.authority_id()
  end

  test "ASL A2 and notifyd N2 bindings consume generic facts" do
    report =
      ContractCheck.run([AslA2.launchd_handoff_binding(), NotifydN2.launchd_handoff_binding()])

    assert report["passed"]

    for binding <- report["bindings"] do
      assert binding["passed"]
      assert binding["generic_fact_ids"] == Enum.map(MarkerManifest.fact_ids(), &Atom.to_string/1)
      assert binding["semantic_no_copy"]["passed"]
      assert binding["imported_specs"]["passed"]
    end
  end

  test "semantic no-copy rejects a differently named local generic fact" do
    seeded =
      ContractCheck.semantic_no_copy_check([
        %{
          id: :local_reimplementation_under_new_name,
          key: "ASL_A2_RENAMED_GENERIC_CHECKIN",
          producer: :launchd,
          producer_detail: :not_the_original_name,
          generic_policy: MarkerManifest.fact!(:checkin_response_materialized).common_policy
        }
      ])

    refute seeded["passed"]

    assert [
             %{
               "generic_fact_id" => "checkin_response_materialized",
               "reason" => "local semantic equivalent of generic Phase 0.85 fact"
             }
           ] = seeded["matches"]
  end

  test "negative controls fail closed" do
    self_test = ContractCheck.self_test()

    assert self_test["passed"]
    assert self_test["positive"]["passed"]

    for {_id, result} <- self_test["negative_controls"] do
      assert result["passed"]
      assert result["errors"] != []
    end
  end

  test "consumers expose imported specs separately from local specs" do
    assert Enum.all?(
             AslA2.imported_generic_specs(),
             &(&1.generic_source == MarkerManifest.authority_id())
           )

    assert Enum.all?(
             NotifydN2.imported_generic_specs(),
             &(&1.generic_source == MarkerManifest.authority_id())
           )

    refute Enum.any?(AslA2.local_specs(), &Map.has_key?(&1, :generic_fact_id))
    refute Enum.any?(NotifydN2.local_specs(), &Map.has_key?(&1, :generic_fact_id))
  end
end
