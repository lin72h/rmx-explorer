defmodule RmxOSOracle.Phase085.LaunchdHandoff.MarkerManifest do
  @moduledoc """
  Generic Phase 0.85 launchd MachServices handoff authority.

  This authority is extracted from already accepted ASL A2 and notifyd N2C-1
  evidence only. It owns the four common `:launchd` handoff facts shared by
  both consumers and leaves richer consumer-only fields as extension points.

  Emission-site verification remains the consumer authority's responsibility:
  this module enforces producer class, common field policy, parameter binding,
  registry membership, and semantic no-copy rules. It does not prove that a
  consumer marker was emitted by a particular probe source fragment.
  """

  @authority_id :phase085_launchd_handoff
  @design_path "docs/phase-0.85-handoff-design.md"
  @design_commit "c90c737562b6574bf10c22762c73d7e9b252719c"
  @comparison_commit "9a0339eb2831924deda225adbc754f2bebff2974"
  @comparison_path "findings/handoff-a2-n2-comparison.json"

  @fact_ids [
    :checkin_response_materialized,
    :machservices_dictionary_present,
    :selected_service_entry_present,
    :receive_right_materialized
  ]

  @facts %{
    checkin_response_materialized: %{
      id: :checkin_response_materialized,
      producer: :launchd,
      common_policy: %{
        checkin_response_present: true,
        successful_checkin: true
      },
      required_parameters: [],
      extension_points: [:result_dict]
    },
    machservices_dictionary_present: %{
      id: :machservices_dictionary_present,
      producer: :launchd,
      common_policy: %{
        machservices_dictionary_present: true
      },
      required_parameters: [],
      extension_points: [:type_dict]
    },
    selected_service_entry_present: %{
      id: :selected_service_entry_present,
      producer: :launchd,
      common_policy: %{
        selected_service_entry_present: true,
        service_name: :parameterized
      },
      required_parameters: [:service_name],
      extension_points: [:entry_type_machport]
    },
    receive_right_materialized: %{
      id: :receive_right_materialized,
      producer: :launchd,
      common_policy: %{
        receive_right_materialized: true,
        receive_port: :positive_integer_or_equivalent_right_handle,
        service_name: :parameterized
      },
      required_parameters: [:service_name],
      extension_points: [:right_receive]
    }
  }

  @consumer_registry %{
    asl_a2: %{
      series_prefix: "ASL_A2_",
      consumer_authority: "RmxOSOracle.Asl.A2.MarkerManifest",
      generic_source: @authority_id
    },
    notifyd_n2: %{
      series_prefix: "NOTIFYD_N2_LAUNCHD_",
      consumer_authority: "RmxOSOracle.Notifyd.N2.MarkerManifest",
      generic_source: @authority_id
    }
  }

  @evidence_basis %{
    asl_a2: %{
      accepted_claim: "launchd_handoff_plus_donor_lookup_nonce_identity",
      evidence_path: "priv/runs/asl-a2/20260610T0407195Z-system-logger-handoff",
      serial_sha256: "dd8763f70b6d0db4758a8867b9b9bd8ab7c699cdc8d5679ab30d9343e883fc93",
      service_name: "com.apple.system.logger"
    },
    notifyd_n2: %{
      accepted_claim:
        "n2c_1_launchd_checkin_n2c_2a_kernel_receive_mach_send_source_create_n2c_3_unidirectional_concurrency",
      evidence_path: "priv/runs/notifyd-n2-concurrency/20260616T090236Z-token0-fixed-attempt-a",
      serial_sha256: "af1a56ee8d9b81def49babf3b6c211700416658253a83152b253f94146711500",
      service_name: "com.apple.system.notification_center"
    }
  }

  def authority_id, do: @authority_id
  def design_path, do: @design_path
  def design_commit, do: @design_commit
  def comparison_commit, do: @comparison_commit
  def comparison_path, do: @comparison_path
  def fact_ids, do: @fact_ids
  def facts, do: @facts
  def fact!(id), do: Map.fetch!(@facts, id)
  def consumer_registry, do: @consumer_registry
  def consumer_registry!(consumer), do: Map.fetch!(@consumer_registry, consumer)
  def evidence_basis, do: @evidence_basis

  def extension_points do
    %{
      result_dict: "N2 records result=dict; A2 records reply presence only",
      type_dict: "N2 records MachServices type=dict; A2 records dictionary presence only",
      right_receive: "N2 records right=receive; A2 records positive receive port plus usability",
      n2_checkin_terminal: "N2 check-in terminal has no launchd-produced A2 equivalent",
      emission_site_verification:
        "consumer authorities verify bound marker emission sites; generic authority verifies producer class and field policy only"
    }
  end

  def closeout do
    %{
      authority_id: @authority_id,
      design: %{path: @design_path, commit: @design_commit},
      data_comparison: %{path: @comparison_path, commit: @comparison_commit},
      evidence_basis: @evidence_basis,
      facts: @facts,
      consumer_registry: @consumer_registry,
      non_claims: [
        "no_richer_n2_only_field_promotion",
        "no_n2c_2b_cross_process_client_death_observation",
        "no_cleanup_remove_reload_or_reset_at_close_claim",
        "no_pid_1_launchd_claim",
        "no_d22_d23_launchctl_lifecycle_claim",
        "no_guest_run_for_authority_extraction",
        "no_certification_claim"
      ],
      emission_site_verification_owner: "consumer_authority",
      generic_authority_evidence_count: 2
    }
  end
end
