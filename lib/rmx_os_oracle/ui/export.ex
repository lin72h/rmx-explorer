defmodule RmxOSOracle.UI.Export do
  @moduledoc """
  Builds, validates, and atomically writes read-only UI snapshots.
  """

  alias RmxOSOracle.Paths
  alias RmxOSOracle.UI.Model
  alias RmxOSOracle.UI.Validator

  @generator %{"name" => "RmxOSOracle.UI.Export", "version" => "first-post-m1-slice"}
  @snapshot_dir "priv/runs/ui-snapshots"
  @pages %{
    "overview" => {"overview.json", "rmxos_oracle.ui.overview.v1"},
    "migration" => {"migration.json", "rmxos_oracle.ui.migration.v1"},
    "canonicalization" => {"canonicalization.json", "rmxos_oracle.ui.canonicalization.v1"},
    "platforms" => {"platforms.json", "rmxos_oracle.ui.platforms.v1"},
    "evidence_ladder" => {"evidence_ladder.json", "rmxos_oracle.ui.evidence_ladder.v1"}
  }

  def snapshot_dir, do: @snapshot_dir
  def page_ids, do: @pages |> Map.keys() |> Enum.sort()

  def export(opts \\ []) do
    repo_root = opts |> Keyword.get(:repo_root, File.cwd!()) |> Path.expand()
    output_dir = output_dir(repo_root, opts)
    pages = Keyword.get(opts, :pages, page_ids())

    ensure_output_dir!(repo_root, output_dir)

    results =
      Enum.map(pages, fn page ->
        case Map.fetch(@pages, page) do
          {:ok, {filename, _schema}} ->
            export_page(page, filename, repo_root, output_dir, opts)

          :error ->
            %{"page" => page, "status" => "fail", "error" => "unknown snapshot page"}
        end
      end)

    %{
      "schema" => "rmxos_oracle.ui.export_result.v1",
      "status" => if(Enum.all?(results, &(&1["status"] == "pass")), do: "pass", else: "fail"),
      "output_dir" => Path.relative_to(output_dir, repo_root),
      "results" => results
    }
  end

  def build_snapshot(page, opts \\ []) do
    repo_root = opts |> Keyword.get(:repo_root, File.cwd!()) |> Path.expand()
    source = Keyword.get(opts, :source)
    model = Keyword.get(opts, :model, Model)
    generated_at = Keyword.get(opts, :generated_at, DateTime.utc_now() |> DateTime.to_iso8601())
    {_, schema} = Map.fetch!(@pages, page)

    model_opts =
      [repo_root: repo_root]
      |> maybe_put(:source, source)

    model_result =
      case page do
        "overview" -> model.overview(model_opts)
        "migration" -> model.migration(model_opts)
        "canonicalization" -> model.canonicalization(model_opts)
        "platforms" -> model.platforms(model_opts)
        "evidence_ladder" -> model.evidence_ladder(model_opts)
      end

    repo = model.repo_status(repo_root)
    warnings = page_warnings(page, repo["warnings"] ++ model_result["warnings"])

    snapshot = %{
      "schema" => schema,
      "generated_at" => generated_at,
      "generator" => @generator,
      "repo" => %{"path" => repo_root, "sha" => repo["sha"], "dirty" => repo["dirty"]},
      "source_refs" => model_result["source_refs"],
      "warnings" => warnings,
      "ui" => ui(page),
      "data" => model_result["data"]
    }

    Validator.validate!(snapshot)
  end

  defp export_page(page, filename, repo_root, output_dir, opts) do
    try do
      snapshot = build_snapshot(page, Keyword.put(opts, :repo_root, repo_root))
      target = Path.join(output_dir, filename)
      # Snapshot bytes are runtime cache, not a canonical or evidence encoding.
      write_atomic!(target, JSON.encode!(snapshot) <> "\n", output_dir)

      %{
        "page" => page,
        "status" => "pass",
        "path" => Path.relative_to(target, repo_root),
        "warning_count" => length(snapshot["warnings"])
      }
    rescue
      error ->
        %{
          "page" => page,
          "status" => "fail",
          "error" => Exception.message(error)
        }
    end
  end

  defp ui("overview") do
    surface("overview", [
      %{
        "id" => "root",
        "component" => "Page",
        "children" => ["provenance", "warnings", "checks", "hard_stops"]
      },
      provenance_component(),
      warning_component(),
      %{
        "id" => "checks",
        "component" => "StatusList",
        "bind" => %{"items" => "/data/checks"}
      },
      %{
        "id" => "hard_stops",
        "component" => "DataTable",
        "columns" => ~w(label state message),
        "bind" => %{"rows" => "/data/hard_stops"}
      }
    ])
  end

  defp ui("migration") do
    surface("migration", [
      %{
        "id" => "root",
        "component" => "Page",
        "children" => ["provenance", "warnings", "imports"]
      },
      provenance_component(),
      warning_component(),
      %{
        "id" => "imports",
        "component" => "DataTable",
        "columns" => ~w(source_path target_path category status),
        "bind" => %{"rows" => "/data/imported_files"}
      }
    ])
  end

  defp ui("canonicalization") do
    surface("canonicalization", [
      %{
        "id" => "root",
        "component" => "Page",
        "children" => ["provenance", "warnings", "summary", "blocked_edges"]
      },
      provenance_component(),
      warning_component(),
      %{
        "id" => "summary",
        "component" => "StatusSummary",
        "bind" => %{"items" => "/data/summary"}
      },
      %{
        "id" => "blocked_edges",
        "component" => "DataTable",
        "columns" => ~w(source target reason),
        "bind" => %{"rows" => "/data/blocked_dependency_edges"}
      }
    ])
  end

  defp ui("platforms") do
    surface("platforms", [
      %{
        "id" => "root",
        "component" => "Page",
        "children" => [
          "provenance",
          "warnings",
          "canonical_platforms",
          "historical_runner_ids",
          "artifact_availability"
        ]
      },
      provenance_component(),
      warning_component(),
      %{
        "id" => "canonical_platforms",
        "component" => "DataTable",
        "columns" => ~w(id arch status evidence_status),
        "bind" => %{"rows" => "/data/canonical_platforms"}
      },
      %{
        "id" => "historical_runner_ids",
        "component" => "DataTable",
        "columns" => ~w(id canonical_platform_id status),
        "bind" => %{"rows" => "/data/historical_runner_ids"}
      },
      %{
        "id" => "artifact_availability",
        "component" => "DataTable",
        "columns" => ~w(path kind exists status),
        "bind" => %{"rows" => "/data/artifact_availability"}
      }
    ])
  end

  defp ui("evidence_ladder") do
    surface("evidence_ladder", [
      %{
        "id" => "root",
        "component" => "Page",
        "children" => ["provenance", "warnings", "levels", "harness_note"]
      },
      provenance_component(),
      warning_component(),
      %{
        "id" => "levels",
        "component" => "EvidenceLadder",
        "bind" => %{"levels" => "/data/levels"}
      },
      %{
        "id" => "harness_note",
        "component" => "TextBlock",
        "bind" => %{"text" => "/data/harness_note/text"}
      }
    ])
  end

  defp surface(id, components) do
    %{
      "semantics" => "a2ui-inspired",
      "compatibility" => "semantic_only_not_wire_compatible",
      "surface_id" => id,
      "catalog_id" => "rmxos_oracle.ui.catalog.v1",
      "root_component_id" => "root",
      "components" => components
    }
  end

  defp provenance_component do
    %{
      "id" => "provenance",
      "component" => "ProvenanceBanner",
      "bind" => %{
        "generated_at" => "/generated_at",
        "repo_sha" => "/repo/sha",
        "dirty" => "/repo/dirty",
        "source_refs" => "/source_refs"
      }
    }
  end

  defp warning_component do
    %{
      "id" => "warnings",
      "component" => "WarningBanner",
      "bind" => %{"warnings" => "/warnings"}
    }
  end

  defp output_dir(repo_root, opts) do
    designated = Path.join(repo_root, @snapshot_dir)

    case Keyword.get(opts, :snapshot_subdir) do
      nil -> designated
      subdir when is_binary(subdir) -> Path.join(designated, subdir)
    end
  end

  defp ensure_output_dir!(repo_root, output_dir) do
    designated = Path.join(repo_root, @snapshot_dir) |> Path.expand()
    output_dir = Path.expand(output_dir)

    unless Paths.under?(output_dir, designated) do
      raise ArgumentError, "snapshot output escapes #{designated}"
    end

    reject_symlink_components!(output_dir)
    File.mkdir_p!(output_dir)
    reject_symlink_components!(output_dir)
  end

  defp write_atomic!(target, contents, output_dir) do
    target = Path.expand(target)

    unless Paths.under?(target, output_dir) do
      raise ArgumentError, "snapshot target escapes output directory"
    end

    reject_symlink_components!(target)

    temp =
      Path.join(
        output_dir,
        ".#{Path.basename(target)}.tmp-#{System.unique_integer([:positive, :monotonic])}"
      )

    unless Paths.under?(temp, output_dir) do
      raise ArgumentError, "snapshot temporary path escapes output directory"
    end

    reject_symlink_components!(temp)

    try do
      File.write!(temp, contents, [:exclusive])
      File.rename!(temp, target)
    after
      File.rm(temp)
    end
  end

  defp reject_symlink_components!(path) do
    path
    |> Path.expand()
    |> Path.split()
    |> Enum.scan(fn part, acc -> Path.join(acc, part) end)
    |> Enum.each(fn component ->
      if Paths.symlink?(component) do
        raise ArgumentError, "snapshot path contains symlink component: #{component}"
      end
    end)
  end

  defp page_warnings(page, warnings) do
    Enum.map(warnings, fn warning ->
      id = warning["id"] || "#{page}.unknown_warning"

      if String.starts_with?(id, page <> ".") do
        warning
      else
        Map.put(warning, "id", "#{page}.#{id}")
      end
    end)
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
