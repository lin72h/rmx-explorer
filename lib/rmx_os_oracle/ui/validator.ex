defmodule RmxOSOracle.UI.Validator do
  @moduledoc false

  @schemas %{
    "rmxos_oracle.ui.overview.v1" =>
      ~w(phase m1_acceptance source_freeze m0_manifest checks hard_stops),
    "rmxos_oracle.ui.migration.v1" =>
      ~w(milestones imported_files manifest_drift dependency_audit fixture_import_status)
  }
  @surface_by_schema %{
    "rmxos_oracle.ui.overview.v1" => "overview",
    "rmxos_oracle.ui.migration.v1" => "migration"
  }

  @catalog "rmxos_oracle.ui.catalog.v1"
  @components ~w(
    Page
    Section
    ProvenanceBanner
    WarningBanner
    StatusSummary
    StatusList
    StatusBadge
    KeyValueList
    DataTable
    ArtifactRefList
    EvidenceLadder
    TextBlock
    LinkList
  )
  @required_bindings %{
    "ProvenanceBanner" => ~w(generated_at repo_sha dirty source_refs),
    "WarningBanner" => ~w(warnings),
    "StatusSummary" => ~w(items),
    "StatusList" => ~w(items),
    "StatusBadge" => ~w(status),
    "KeyValueList" => ~w(items),
    "DataTable" => ~w(rows),
    "ArtifactRefList" => ~w(refs),
    "EvidenceLadder" => ~w(levels),
    "TextBlock" => ~w(text),
    "LinkList" => ~w(links)
  }
  @statuses ~w(pass fail blocked warning unknown not_available parser_missing not_applicable)
  @severities ~w(info warning error hard_stop)
  @hard_stop_states ~w(active inactive unknown not_detectable)
  @envelope_keys ~w(schema generated_at generator repo source_refs warnings ui data)

  def validate(snapshot) do
    errors =
      []
      |> Kernel.++(json_errors(snapshot, ""))
      |> Kernel.++(envelope_errors(snapshot))
      |> Kernel.++(enum_errors(snapshot, ""))
      |> Kernel.++(ui_errors(snapshot))

    if errors == [], do: :ok, else: {:error, Enum.uniq(errors)}
  end

  def validate!(snapshot) do
    case validate(snapshot) do
      :ok -> snapshot
      {:error, errors} -> raise ArgumentError, "invalid UI snapshot: #{Enum.join(errors, "; ")}"
    end
  end

  defp envelope_errors(snapshot) when is_map(snapshot) do
    missing = missing_keys(snapshot, @envelope_keys, "")
    schema = snapshot["schema"]
    data = snapshot["data"]

    schema_errors =
      case Map.fetch(@schemas, schema) do
        {:ok, required} when is_map(data) ->
          missing_keys(data, required, "/data") ++ data_shape_errors(schema, data)

        {:ok, _required} ->
          ["/data must be an object"]

        :error ->
          ["/schema is not an approved page schema"]
      end

    generated_at_errors =
      if utc_iso8601?(snapshot["generated_at"]),
        do: [],
        else: ["/generated_at must be a UTC ISO-8601 timestamp"]

    generator_errors =
      case snapshot["generator"] do
        %{"name" => name, "version" => version} when is_binary(name) and is_binary(version) -> []
        _ -> ["/generator must contain name:string and version:string"]
      end

    repo_errors =
      case snapshot["repo"] do
        %{"path" => path, "sha" => sha, "dirty" => dirty}
        when is_binary(path) and (is_binary(sha) or is_nil(sha)) and is_boolean(dirty) ->
          if Path.type(path) == :absolute, do: [], else: ["/repo/path must be absolute"]

        _ ->
          ["/repo must contain path:string, sha:string|null, and dirty:boolean"]
      end

    source_ref_errors =
      if string_list?(snapshot["source_refs"]),
        do: [],
        else: ["/source_refs must be an array of strings"]

    warning_errors =
      case snapshot["warnings"] do
        warnings when is_list(warnings) ->
          ids = Enum.map(warnings, &warning_id/1)

          duplicate_errors =
            if length(ids) == MapSet.size(MapSet.new(ids)),
              do: [],
              else: ["/warnings has duplicate ids"]

          duplicate_errors ++ Enum.flat_map(warnings, &warning_errors/1)

        _ ->
          ["/warnings must be an array"]
      end

    missing ++
      schema_errors ++
      generated_at_errors ++
      generator_errors ++ repo_errors ++ source_ref_errors ++ warning_errors
  end

  defp envelope_errors(_), do: ["snapshot must be an object"]

  defp warning_errors(%{
         "id" => id,
         "severity" => severity,
         "message" => message,
         "source_refs" => refs
       })
       when is_binary(id) and is_binary(severity) and is_binary(message) do
    if string_list?(refs), do: [], else: ["/warnings contains non-string source_refs"]
  end

  defp warning_errors(_warning) do
    ["/warnings contains an invalid warning object"]
  end

  defp warning_id(%{"id" => id}) when is_binary(id) do
    id
  end

  defp warning_id(_warning) do
    nil
  end

  defp utc_iso8601?(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, %DateTime{utc_offset: 0, std_offset: 0}, 0} -> true
      _ -> false
    end
  end

  defp utc_iso8601?(_value) do
    false
  end

  defp ui_errors(snapshot) do
    case snapshot["ui"] do
      %{
        "semantics" => "a2ui-inspired",
        "compatibility" => "semantic_only_not_wire_compatible",
        "surface_id" => surface_id,
        "catalog_id" => @catalog,
        "root_component_id" => root_id,
        "components" => components
      }
      when is_binary(surface_id) and is_binary(root_id) and is_list(components) ->
        surface_errors =
          case Map.get(@surface_by_schema, snapshot["schema"]) do
            nil -> []
            ^surface_id -> []
            expected -> ["/ui/surface_id must be #{expected} for #{snapshot["schema"]}"]
          end

        surface_errors ++ component_errors(snapshot, root_id, components)

      _ ->
        ["/ui must be a complete approved A2UI-inspired surface"]
    end
  end

  defp component_errors(snapshot, root_id, components) do
    ids = Enum.map(components, &component_id/1)
    id_set = MapSet.new(ids)

    duplicate_errors =
      if length(ids) == MapSet.size(id_set), do: [], else: ["/ui/components has duplicate ids"]

    root_errors =
      case Enum.find(components, &(component_id(&1) == root_id)) do
        %{"component" => "Page"} -> []
        nil -> ["/ui/root_component_id does not resolve"]
        _ -> ["/ui/root_component_id must resolve to a Page component"]
      end

    item_errors =
      components
      |> Enum.with_index()
      |> Enum.flat_map(fn {component, index} ->
        component_item_errors(snapshot, component, index, id_set)
      end)

    duplicate_errors ++ root_errors ++ item_errors
  end

  defp component_item_errors(snapshot, component, index, id_set) when is_map(component) do
    base = "/ui/components/#{index}"
    id = component["id"]
    type = component["component"]
    children = Map.get(component, "children", [])
    bind = Map.get(component, "bind", %{})

    []
    |> maybe_error(not is_binary(id) or id == "", "#{base}/id must be a non-empty string")
    |> maybe_error(type not in @components, "#{base}/component is not in #{@catalog}")
    |> maybe_error(not is_list(children), "#{base}/children must be an array")
    |> maybe_error(not is_map(bind), "#{base}/bind must be an object")
    |> Kernel.++(component_property_errors(component, type, base))
    |> Kernel.++(children_errors(children, id_set, base))
    |> Kernel.++(binding_errors(snapshot, type, bind, base))
  end

  defp component_item_errors(_snapshot, _component, index, _id_set),
    do: ["/ui/components/#{index} must be an object"]

  defp children_errors(children, id_set, base) when is_list(children) do
    Enum.flat_map(children, fn child ->
      cond do
        not is_binary(child) -> ["#{base}/children contains a non-string id"]
        not MapSet.member?(id_set, child) -> ["#{base}/children contains dangling id #{child}"]
        true -> []
      end
    end)
  end

  defp children_errors(_children, _id_set, _base), do: []

  defp binding_errors(snapshot, type, bind, base) when is_map(bind) do
    required = Map.get(@required_bindings, type, [])

    missing =
      required
      |> Enum.reject(&Map.has_key?(bind, &1))
      |> Enum.map(&"#{base}/bind is missing required binding #{&1}")

    invalid =
      Enum.flat_map(bind, fn {name, pointer} ->
        cond do
          not is_binary(name) ->
            ["#{base}/bind contains a non-string binding name"]

          not valid_pointer?(pointer) ->
            ["#{base}/bind/#{name} is not an RFC 6901 JSON Pointer"]

          true ->
            case resolve_pointer(snapshot, pointer) do
              :error ->
                ["#{base}/bind/#{name} does not resolve"]

              {:ok, value} ->
                if binding_shape_valid?(type, name, value),
                  do: [],
                  else: ["#{base}/bind/#{name} resolves to an invalid binding shape"]
            end
        end
      end)

    missing ++ invalid
  end

  defp binding_errors(_snapshot, _type, _bind, _base), do: []

  defp valid_pointer?(""), do: true

  defp valid_pointer?(pointer) when is_binary(pointer) do
    String.starts_with?(pointer, "/") and
      pointer
      |> String.split("/", trim: false)
      |> tl()
      |> Enum.all?(&(not Regex.match?(~r/~(?:[^01]|$)/, &1)))
  end

  defp valid_pointer?(_), do: false

  defp resolve_pointer(value, ""), do: {:ok, value}

  defp resolve_pointer(value, pointer) do
    pointer
    |> String.split("/", trim: false)
    |> tl()
    |> Enum.map(&(&1 |> String.replace("~1", "/") |> String.replace("~0", "~")))
    |> Enum.reduce_while({:ok, value}, fn token, {:ok, current} ->
      case pointer_step(current, token) do
        {:ok, next} -> {:cont, {:ok, next}}
        :error -> {:halt, :error}
      end
    end)
  end

  defp pointer_step(map, token) when is_map(map), do: Map.fetch(map, token)

  defp pointer_step(list, token) when is_list(list) do
    case Integer.parse(token) do
      {index, ""} when index >= 0 -> Enum.fetch(list, index)
      _ -> :error
    end
  end

  defp pointer_step(_value, _token), do: :error

  defp binding_shape_valid?("ProvenanceBanner", "generated_at", value), do: is_binary(value)

  defp binding_shape_valid?("ProvenanceBanner", "repo_sha", value),
    do: is_binary(value) or is_nil(value)

  defp binding_shape_valid?("ProvenanceBanner", "dirty", value), do: is_boolean(value)
  defp binding_shape_valid?("ProvenanceBanner", "source_refs", value), do: string_list?(value)
  defp binding_shape_valid?("WarningBanner", "warnings", value), do: is_list(value)
  defp binding_shape_valid?("StatusSummary", "items", value), do: is_list(value)
  defp binding_shape_valid?("StatusList", "items", value), do: is_list(value)
  defp binding_shape_valid?("StatusBadge", "status", value), do: value in @statuses
  defp binding_shape_valid?("StatusBadge", "severity", value), do: value in @severities
  defp binding_shape_valid?("KeyValueList", "items", value), do: is_list(value)
  defp binding_shape_valid?("DataTable", "rows", value), do: is_list(value)
  defp binding_shape_valid?("ArtifactRefList", "refs", value), do: is_list(value)
  defp binding_shape_valid?("EvidenceLadder", "levels", value), do: is_list(value)
  defp binding_shape_valid?("EvidenceLadder", "harness_note", value), do: is_map(value)
  defp binding_shape_valid?("TextBlock", "text", value), do: is_binary(value)
  defp binding_shape_valid?("LinkList", "links", value), do: is_list(value)
  defp binding_shape_valid?(_type, _name, _value), do: true

  defp component_property_errors(component, type, base) do
    allowed =
      case type do
        "DataTable" -> ~w(id component children bind columns)
        "Section" -> ~w(id component children bind title)
        _ -> ~w(id component children bind)
      end

    unknown =
      component
      |> Map.keys()
      |> Enum.reject(&(&1 in allowed))
      |> Enum.map(&"#{base} contains unsupported property #{&1}")

    columns_errors =
      case Map.fetch(component, "columns") do
        {:ok, columns} when type == "DataTable" ->
          if string_list?(columns), do: [], else: ["#{base}/columns must be an array of strings"]

        {:ok, _columns} ->
          ["#{base}/columns is only allowed for DataTable"]

        :error ->
          []
      end

    title_errors =
      case Map.fetch(component, "title") do
        {:ok, title} when type == "Section" and is_binary(title) -> []
        {:ok, _title} -> ["#{base}/title is only allowed as a string on Section"]
        :error -> []
      end

    unknown ++ columns_errors ++ title_errors
  end

  defp enum_errors(value, path) when is_map(value) do
    own =
      []
      |> enum_error(value, "status", @statuses, path)
      |> enum_error(value, "severity", @severities, path)
      |> enum_error(value, "state", @hard_stop_states, path)

    own ++
      Enum.flat_map(value, fn {key, child} ->
        segment = if(is_binary(key), do: escape_pointer(key), else: "<non-binary-key>")
        enum_errors(child, "#{path}/#{segment}")
      end)
  end

  defp enum_errors(value, path) when is_list(value) do
    value
    |> Enum.with_index()
    |> Enum.flat_map(fn {child, index} -> enum_errors(child, "#{path}/#{index}") end)
  end

  defp enum_errors(_value, _path), do: []

  defp enum_error(errors, map, key, allowed, path) do
    case Map.fetch(map, key) do
      {:ok, value} ->
        if value in allowed,
          do: errors,
          else: errors ++ ["#{path}/#{key} is not in the approved enum"]

      :error ->
        errors
    end
  end

  defp json_errors(value, _path) when is_nil(value) or is_boolean(value) or is_integer(value),
    do: []

  defp json_errors(value, path) when is_float(value) do
    try do
      JSON.encode!(value)
      []
    rescue
      _ -> ["#{path} contains a non-JSON float"]
    end
  end

  defp json_errors(value, path) when is_binary(value) do
    if String.valid?(value), do: [], else: ["#{path} contains invalid UTF-8"]
  end

  defp json_errors(value, path) when is_list(value) do
    value
    |> Enum.with_index()
    |> Enum.flat_map(fn {child, index} -> json_errors(child, "#{path}/#{index}") end)
  end

  defp json_errors(value, path) when is_map(value) do
    Enum.flat_map(value, fn
      {key, child} when is_binary(key) ->
        key_errors =
          if String.valid?(key), do: [], else: ["#{path} contains an invalid UTF-8 key"]

        key_errors ++ json_errors(child, "#{path}/#{escape_pointer(key)}")

      {_key, _child} ->
        ["#{path} contains a non-binary map key"]
    end)
  end

  defp json_errors(_value, path), do: ["#{path} contains a non-JSON value"]

  defp data_shape_errors("rmxos_oracle.ui.overview.v1", data) do
    []
    |> type_error(data, "phase", :map, "/data")
    |> type_error(data, "m1_acceptance", :map, "/data")
    |> type_error(data, "source_freeze", :map, "/data")
    |> type_error(data, "m0_manifest", :map, "/data")
    |> type_error(data, "checks", :list, "/data")
    |> type_error(data, "hard_stops", :list, "/data")
    |> Kernel.++(common_item_errors(data["checks"], "/data/checks"))
    |> Kernel.++(hard_stop_errors(data["hard_stops"]))
  end

  defp data_shape_errors("rmxos_oracle.ui.migration.v1", data) do
    []
    |> type_error(data, "milestones", :map, "/data")
    |> type_error(data, "imported_files", :list, "/data")
    |> type_error(data, "manifest_drift", :map, "/data")
    |> type_error(data, "dependency_audit", :map, "/data")
    |> type_error(data, "fixture_import_status", :map, "/data")
    |> Kernel.++(import_errors(data["imported_files"]))
    |> Kernel.++(migration_group_errors(data))
  end

  defp data_shape_errors(_schema, _data), do: []

  defp common_item_errors(items, path) when is_list(items) do
    items
    |> Enum.with_index()
    |> Enum.flat_map(fn
      {%{
         "id" => id,
         "label" => label,
         "status" => status,
         "severity" => severity,
         "source_refs" => refs
       }, _index}
      when is_binary(id) and is_binary(label) and status in @statuses and severity in @severities and
             is_list(refs) ->
        []

      {_item, index} ->
        ["#{path}/#{index} is not a common status item"]
    end)
  end

  defp common_item_errors(_items, _path), do: []

  defp hard_stop_errors(items) when is_list(items) do
    items
    |> Enum.with_index()
    |> Enum.flat_map(fn
      {%{
         "id" => id,
         "label" => label,
         "state" => state,
         "detectable" => detectable,
         "severity" => severity,
         "message" => message,
         "source_refs" => refs
       }, _index}
      when is_binary(id) and is_binary(label) and state in @hard_stop_states and
             is_boolean(detectable) and severity in @severities and is_binary(message) and
             is_list(refs) ->
        []

      {_item, index} ->
        ["/data/hard_stops/#{index} is not a hard-stop item"]
    end)
  end

  defp hard_stop_errors(_items), do: []

  defp import_errors(items) when is_list(items) do
    items
    |> Enum.with_index()
    |> Enum.flat_map(fn
      {%{
         "source_path" => source_path,
         "target_path" => target_path,
         "category" => category,
         "status" => status,
         "source_refs" => refs
       }, _index}
      when is_binary(source_path) and is_binary(target_path) and is_binary(category) and
             status in @statuses and is_list(refs) ->
        []

      {_item, index} ->
        ["/data/imported_files/#{index} is not an import item"]
    end)
  end

  defp import_errors(_items), do: []

  defp migration_group_errors(data) do
    []
    |> nested_type_error(data["milestones"], "m0", :map, "/data/milestones")
    |> nested_type_error(data["milestones"], "m1", :map, "/data/milestones")
    |> nested_type_error(data["manifest_drift"], "changed_entries", :list, "/data/manifest_drift")
    |> nested_type_error(
      data["dependency_audit"],
      "blocked_edges",
      :list,
      "/data/dependency_audit"
    )
    |> nested_type_error(
      data["dependency_audit"],
      "allowed_edges",
      :list,
      "/data/dependency_audit"
    )
    |> nested_type_error(
      data["fixture_import_status"],
      "imported",
      :list,
      "/data/fixture_import_status"
    )
    |> nested_type_error(
      data["fixture_import_status"],
      "skipped",
      :list,
      "/data/fixture_import_status"
    )
    |> nested_type_error(
      data["fixture_import_status"],
      "blocked",
      :list,
      "/data/fixture_import_status"
    )
  end

  defp type_error(errors, map, key, type, path) do
    nested_type_error(errors, map, key, type, path)
  end

  defp nested_type_error(errors, map, key, type, path) when is_map(map) do
    if valid_type?(Map.get(map, key), type),
      do: errors,
      else: errors ++ ["#{path}/#{key} must be a #{type}"]
  end

  defp nested_type_error(errors, _map, key, type, path),
    do: errors ++ ["#{path}/#{key} must be a #{type}"]

  defp valid_type?(value, :map), do: is_map(value)
  defp valid_type?(value, :list), do: is_list(value)

  defp string_list?(value), do: is_list(value) and Enum.all?(value, &is_binary/1)

  defp missing_keys(map, keys, path) do
    keys
    |> Enum.reject(&Map.has_key?(map, &1))
    |> Enum.map(&"#{path}/#{&1} is required")
  end

  defp component_id(%{"id" => id}) when is_binary(id), do: id
  defp component_id(_), do: nil

  defp maybe_error(errors, true, message), do: errors ++ [message]
  defp maybe_error(errors, false, _message), do: errors

  defp escape_pointer(key) do
    key
    |> String.replace("~", "~0")
    |> String.replace("/", "~1")
  end
end
