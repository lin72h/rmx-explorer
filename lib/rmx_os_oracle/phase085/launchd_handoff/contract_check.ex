defmodule RmxOSOracle.Phase085.LaunchdHandoff.ContractCheck do
  @moduledoc """
  Contract checks for Phase 0.85 generic launchd-handoff consumers.

  The no-copy check is semantic: a consumer may not define a local
  `:launchd`-produced fact with the same common policy as a generic fact under a
  different id. Consumers must import the generic fact id and bind concrete
  consumer markers to it.
  """

  alias RmxOSOracle.Phase085.LaunchdHandoff.MarkerManifest

  def run(consumers) when is_list(consumers) do
    registry = registry_check(consumers)
    bindings = Enum.map(consumers, &binding_check/1)

    %{
      "passed" => registry["passed"] and Enum.all?(bindings, & &1["passed"]),
      "registry" => registry,
      "bindings" => bindings
    }
  end

  def registry_check(consumers) when is_list(consumers) do
    registry = MarkerManifest.consumer_registry()

    results =
      Enum.map(consumers, fn %{consumer: consumer} ->
        entry = Map.get(registry, consumer)

        %{
          "consumer" => Atom.to_string(consumer),
          "registered" => not is_nil(entry),
          "series_prefix" => entry && entry.series_prefix,
          "generic_source" => entry && Atom.to_string(entry.generic_source),
          "passed" => not is_nil(entry) and entry.generic_source == MarkerManifest.authority_id()
        }
      end)

    %{"passed" => Enum.all?(results, & &1["passed"]), "results" => results}
  end

  def binding_check(%{
        consumer: consumer,
        service_name: service_name,
        fixture_form: fixture_form,
        identity_instrument: identity_instrument,
        facts: facts,
        local_specs: local_specs,
        imported_specs: imported_specs
      }) do
    registry_entry = Map.get(MarkerManifest.consumer_registry(), consumer)
    fact_ids = MarkerManifest.fact_ids()

    missing_facts =
      fact_ids
      |> Enum.reject(&Map.has_key?(facts, &1))
      |> Enum.map(&Atom.to_string/1)

    fact_errors =
      fact_ids
      |> Enum.flat_map(fn id ->
        fact = MarkerManifest.fact!(id)
        fact_binding = Map.get(facts, id)
        validate_fact_binding(fact, fact_binding, service_name)
      end)

    semantic_no_copy = semantic_no_copy_check(local_specs)
    imported = imported_specs_check(imported_specs)

    errors =
      []
      |> append_if(is_nil(registry_entry), "consumer missing from Phase 0.85 registry")
      |> append_if(service_name in [nil, ""], "missing service name")
      |> append_if(is_nil(fixture_form), "missing fixture form")
      |> append_if(is_nil(identity_instrument), "missing identity instrument")
      |> Kernel.++(Enum.map(missing_facts, &"missing generic fact #{&1}"))
      |> Kernel.++(fact_errors)
      |> Kernel.++(semantic_no_copy["errors"])
      |> Kernel.++(imported["errors"])

    %{
      "consumer" => Atom.to_string(consumer),
      "passed" => errors == [],
      "service_name" => service_name,
      "fixture_form" => Atom.to_string(fixture_form),
      "identity_instrument" => Atom.to_string(identity_instrument),
      "generic_fact_ids" => Enum.map(fact_ids, &Atom.to_string/1),
      "imported_spec_count" => length(imported_specs),
      "local_spec_count" => length(local_specs),
      "semantic_no_copy" => semantic_no_copy,
      "imported_specs" => imported,
      "errors" => errors
    }
  end

  def semantic_no_copy_check(specs) when is_list(specs) do
    matches =
      specs
      |> Enum.flat_map(fn spec ->
        MarkerManifest.facts()
        |> Enum.flat_map(fn {id, fact} ->
          if semantic_copy?(spec, fact) and not imported_generic?(spec, id) do
            [
              %{
                "id" => to_string(Map.get(spec, :id, "unknown")),
                "key" => to_string(Map.get(spec, :key, "unknown")),
                "generic_fact_id" => Atom.to_string(id),
                "producer" => to_string(Map.get(spec, :producer, "unknown")),
                "reason" => "local semantic equivalent of generic Phase 0.85 fact"
              }
            ]
          else
            []
          end
        end)
      end)

    %{
      "passed" => matches == [],
      "matches" => matches,
      "errors" =>
        Enum.map(matches, fn match ->
          "local semantic copy #{match["id"]} of #{match["generic_fact_id"]}"
        end)
    }
  end

  def imported_specs_check(specs) when is_list(specs) do
    fact_ids = MapSet.new(MarkerManifest.fact_ids())

    errors =
      specs
      |> Enum.flat_map(fn spec ->
        []
        |> append_if(
          Map.get(spec, :generic_source) != MarkerManifest.authority_id(),
          "#{Map.get(spec, :id)} missing Phase 0.85 generic source"
        )
        |> append_if(
          not MapSet.member?(fact_ids, Map.get(spec, :generic_fact_id)),
          "#{Map.get(spec, :id)} imports unknown generic fact"
        )
        |> append_if(
          Map.get(spec, :producer) != :launchd,
          "#{Map.get(spec, :id)} generic binding producer is not :launchd"
        )
      end)

    %{"passed" => errors == [], "errors" => errors}
  end

  def self_test do
    positive = %{
      consumer: :asl_a2,
      service_name: "com.example.service",
      fixture_form: :boolean,
      identity_instrument: :seeded_identity,
      facts: seeded_fact_bindings(:launchd),
      local_specs: [],
      imported_specs: seeded_imported_specs(:launchd)
    }

    negative_controls = [
      harness_fixture_literal_rejected:
        binding_check(%{positive | facts: seeded_fact_bindings(:harness)}),
      wrong_service_name_rejected: binding_check(%{positive | service_name: "com.example.wrong"}),
      missing_machservices_dict_rejected:
        binding_check(%{
          positive
          | facts: Map.delete(positive.facts, :machservices_dictionary_present)
        }),
      missing_selected_entry_rejected:
        binding_check(%{
          positive
          | facts: Map.delete(positive.facts, :selected_service_entry_present)
        }),
      unusable_receive_right_rejected:
        binding_check(%{
          positive
          | facts:
              put_in(positive.facts, [:receive_right_materialized, :markers], [
                %{producer: :launchd, generic_policy: %{receive_right_materialized: false}}
              ])
        }),
      local_copy_rejected:
        binding_check(%{
          positive
          | local_specs: [
              %{
                id: :renamed_checkin_response,
                key: "LOCAL_DIFFERENT_NAME",
                producer: :launchd,
                producer_detail: :renamed_checkin_response,
                generic_policy: MarkerManifest.fact!(:checkin_response_materialized).common_policy
              }
            ]
        }),
      producer_mismatch_rejected:
        binding_check(%{positive | imported_specs: seeded_imported_specs(:harness)})
    ]

    %{
      "passed" =>
        binding_check(positive)["passed"] and
          Enum.all?(negative_controls, fn {_id, result} -> not result["passed"] end),
      "positive" => binding_check(positive),
      "negative_controls" =>
        Map.new(negative_controls, fn {id, result} ->
          {Atom.to_string(id), %{"passed" => not result["passed"], "errors" => result["errors"]}}
        end)
    }
  end

  defp validate_fact_binding(_fact, nil, _service_name), do: ["missing generic fact binding"]

  defp validate_fact_binding(fact, binding, service_name) do
    markers = Map.get(binding, :markers, [])

    []
    |> append_if(markers == [], "generic fact #{fact.id} has no bound markers")
    |> append_if(
      Enum.any?(markers, &(Map.get(&1, :producer) != :launchd)),
      "generic fact #{fact.id} has non-launchd producer"
    )
    |> append_if(
      Enum.any?(fact.required_parameters, &(not Map.has_key?(binding, &1))),
      "generic fact #{fact.id} missing required parameter"
    )
    |> append_if(
      :service_name in fact.required_parameters and binding[:service_name] != service_name,
      "generic fact #{fact.id} service name mismatch"
    )
    |> append_if(
      not policy_satisfied?(fact.id, markers),
      "generic fact #{fact.id} common field policy not satisfied"
    )
  end

  defp policy_satisfied?(:checkin_response_materialized, markers),
    do: Enum.any?(markers, &truthy_policy?(&1, :checkin_response_present))

  defp policy_satisfied?(:machservices_dictionary_present, markers),
    do: Enum.any?(markers, &truthy_policy?(&1, :machservices_dictionary_present))

  defp policy_satisfied?(:selected_service_entry_present, markers),
    do: Enum.any?(markers, &truthy_policy?(&1, :selected_service_entry_present))

  defp policy_satisfied?(:receive_right_materialized, markers),
    do: Enum.any?(markers, &truthy_policy?(&1, :receive_right_materialized))

  defp truthy_policy?(marker, policy_key),
    do: marker |> Map.get(:generic_policy, %{}) |> Map.get(policy_key) == true

  defp semantic_copy?(%{producer: :launchd} = spec, fact) do
    generic_policy = Map.get(spec, :generic_policy)

    cond do
      generic_policy == fact.common_policy ->
        true

      Map.get(spec, :producer_detail) in producer_details_for(fact.id) ->
        true

      true ->
        false
    end
  end

  defp semantic_copy?(_spec, _fact), do: false

  defp imported_generic?(spec, fact_id) do
    Map.get(spec, :generic_source) == MarkerManifest.authority_id() and
      Map.get(spec, :generic_fact_id) == fact_id
  end

  defp producer_details_for(:checkin_response_materialized),
    do: [:checkin_reply, :launch_msg_checkin, :launchd_checkin_request]

  defp producer_details_for(:machservices_dictionary_present),
    do: [:machservices_dictionary, :mach_services_dictionary]

  defp producer_details_for(:selected_service_entry_present),
    do: [:machservice_entry, :mach_services_entry]

  defp producer_details_for(:receive_right_materialized),
    do: [:machservice_receive_right, :receive_right]

  defp seeded_fact_bindings(producer) do
    %{
      checkin_response_materialized: %{
        markers: [
          %{
            producer: producer,
            generic_policy: %{checkin_response_present: true, successful_checkin: true}
          }
        ]
      },
      machservices_dictionary_present: %{
        markers: [
          %{producer: producer, generic_policy: %{machservices_dictionary_present: true}}
        ]
      },
      selected_service_entry_present: %{
        service_name: "com.example.service",
        markers: [
          %{
            producer: producer,
            generic_policy: %{selected_service_entry_present: true, service_name: :parameterized}
          }
        ]
      },
      receive_right_materialized: %{
        service_name: "com.example.service",
        markers: [
          %{
            producer: producer,
            generic_policy: %{
              receive_right_materialized: true,
              receive_port: :positive_integer_or_equivalent_right_handle,
              service_name: :parameterized
            }
          }
        ]
      }
    }
  end

  defp seeded_imported_specs(producer) do
    MarkerManifest.fact_ids()
    |> Enum.map(fn id ->
      %{
        id: :"seeded_#{id}",
        key: "SEEDED_#{String.upcase(Atom.to_string(id))}",
        producer: producer,
        producer_detail: :seeded,
        generic_source: MarkerManifest.authority_id(),
        generic_fact_id: id
      }
    end)
  end

  defp append_if(errors, true, error), do: errors ++ [error]
  defp append_if(errors, false, _error), do: errors
end
