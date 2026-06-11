defmodule RmxOSOracle.UI.SourceInventory do
  @moduledoc """
  Stable source inventory for the first post-M1 UI snapshot slice.

  This records historical provenance and producer scope. It is not a
  certification result and does not replace the underlying source artifacts.
  """

  @accepted_oracle_sha "389e6eb96215b732108832527efe169f7b1ef915"
  @source_freeze_sha "a30ef3f4fff278d6dc7594543f364a880d4b36a4"
  @manifest_path "priv/manifests/m0_legacy_source_test_manifest.json"
  @dependency_path "priv/dependencies/m0_dependency_edges.json"
  @migration_refs ["docs/migration-m0-inventory.md", "docs/migration-m1-design.md"]
  @platform_refs [
    "docs/migration-m2-authority-design.md",
    "catalog/README.md",
    "priv/schemas/catalog_feature_v1.schema.json",
    "priv/schemas/catalog_probe_v1.schema.json",
    "priv/schemas/mismatch_v1.schema.json"
  ]
  @evidence_refs [
    "lib/rmx_os_oracle/evidence.ex",
    "docs/migration-m1-design.md",
    "docs/migration-m2-authority-design.md"
  ]

  @elixir_imports [
    {"scripts/launchd/phase08_marker_manifest.exs", "lib/phase08/marker_manifest.ex",
     "phase08_elixir"},
    {"scripts/launchd/phase08_source_transform.exs", "lib/phase08/source_transform.ex",
     "phase08_elixir"},
    {"test/phase08_source_transform_test.exs", "test/phase08/source_transform_test.exs",
     "phase08_elixir_test"},
    {"test/test_helper.exs", "test/test_helper.exs", "elixir_test_support"}
  ]

  @fixture_paths ~w(
    fixtures/launchd/com.apple.notifyd.plist
    fixtures/launchd/com.apple.syslogd.plist
    fixtures/launchd/org.freebsd.devd.plist
    fixtures/launchd/org.rmxos.phase08.d14.noop.plist
    fixtures/launchd/org.rmxos.phase08.d15.json-rejected.json
    fixtures/launchd/org.rmxos.phase08.d15.malformed.plist
    fixtures/launchd/org.rmxos.phase08.d16.runatload.plist
    fixtures/launchd/org.rmxos.phase08.d17.fast-exit.plist
    fixtures/launchd/org.rmxos.phase08.d18.sigkill.plist
    fixtures/launchd/org.rmxos.phase08.d18.sigterm.plist
    fixtures/launchd/org.rmxos.phase08.d19.keepalive.plist
    fixtures/launchd/org.rmxos.phase08.d20.successful-exit.plist
    fixtures/launchd/org.rmxos.phase08.d21.remove.plist
    fixtures/launchd/org.rmxos.phase08.d22.keepalive-remove.plist
    fixtures/launchd/org.rmxos.phase08.d22.running-remove.plist
    fixtures/launchd/org.rmxos.phase08.d23.inert-reload.plist
    fixtures/launchd/org.rmxos.phase08.d23.keepalive-reload.plist
  )

  @zig_paths [
    "zig/build.zig",
    "zig/README.md",
    "zig/probes/mach",
    "zig/probes/dispatch",
    "zig/probes/launchd",
    "zig/probes/libthr"
  ]

  @canonical_platforms [
    %{"id" => "rx-x64", "label" => "rx-x64", "arch" => "x64", "runner_ids" => []},
    %{"id" => "rx-a64", "label" => "rx-a64", "arch" => "a64", "runner_ids" => []},
    %{"id" => "mx-x64", "label" => "mx-x64", "arch" => "x64", "runner_ids" => ["mx-x64z"]},
    %{"id" => "mx-a64", "label" => "mx-a64", "arch" => "a64", "runner_ids" => ["mx-a64z"]},
    %{"id" => "nx-r64", "label" => "nx-r64", "arch" => "r64", "runner_ids" => ["nx-v64z"]}
  ]

  @historical_runner_ids [
    %{
      "id" => "mx-a64z",
      "canonical_platform_id" => "mx-a64",
      "source_refs" => [
        "docs/migration-m0-inventory.md",
        "docs/migration-m2-authority-design.md",
        "mx-a64z"
      ]
    },
    %{
      "id" => "mx-x64z",
      "canonical_platform_id" => "mx-x64",
      "source_refs" => [
        "docs/migration-m0-inventory.md",
        "docs/migration-m2-authority-design.md",
        "mx-x64z"
      ]
    },
    %{
      "id" => "nx-v64z",
      "canonical_platform_id" => "nx-r64",
      "source_refs" => [
        "docs/migration-m0-inventory.md",
        "docs/migration-m2-authority-design.md",
        "findings/nx-v64z"
      ]
    }
  ]

  @platform_artifact_paths [
    %{"id" => "mx_a64z_runner_dir", "path" => "mx-a64z", "kind" => "historical_runner_dir"},
    %{"id" => "mx_x64z_runner_dir", "path" => "mx-x64z", "kind" => "historical_runner_dir"},
    %{
      "id" => "nx_v64z_findings_dir",
      "path" => "findings/nx-v64z",
      "kind" => "historical_findings_dir"
    },
    %{
      "id" => "mx_a64z_results_dir",
      "path" => "macos-validation/results/mx-a64z",
      "kind" => "historical_results_dir"
    },
    %{
      "id" => "mx_x64z_results_dir",
      "path" => "macos-validation/results/mx-x64z",
      "kind" => "historical_results_dir"
    },
    %{
      "id" => "nx_v64z_validation_findings_dir",
      "path" => "macos-validation/findings/nx-v64z",
      "kind" => "historical_findings_dir"
    }
  ]

  def accepted_oracle_sha, do: @accepted_oracle_sha
  def source_freeze_sha, do: @source_freeze_sha
  def manifest_path, do: @manifest_path
  def dependency_path, do: @dependency_path
  def migration_refs, do: @migration_refs
  def platform_refs, do: @platform_refs
  def evidence_refs, do: @evidence_refs
  def zig_paths, do: @zig_paths
  def canonical_platforms, do: @canonical_platforms
  def historical_runner_ids, do: @historical_runner_ids
  def platform_artifact_paths, do: @platform_artifact_paths

  def inventory do
    %{
      "schema" => "rmxos_oracle.ui.source_inventory.v1",
      "historical_baseline" => historical_baseline(),
      "imports" => imports(),
      "producer_scopes" => producer_scopes(),
      "zig_paths" => @zig_paths,
      "canonical_platforms" => @canonical_platforms,
      "historical_runner_ids" => @historical_runner_ids,
      "platform_artifact_paths" => @platform_artifact_paths
    }
  end

  def historical_baseline do
    %{
      "status" => "pass",
      "acceptance" => "accepted",
      "oracle_sha" => @accepted_oracle_sha,
      "source_freeze_sha" => @source_freeze_sha,
      "source_refs" => @migration_refs
    }
  end

  def imports do
    elixir =
      Enum.map(@elixir_imports, fn {source_path, target_path, category} ->
        import_entry(source_path, target_path, category)
      end)

    fixtures =
      Enum.map(@fixture_paths, fn path ->
        import_entry(path, path, "launchd_fixture")
      end)

    elixir ++ fixtures
  end

  def producer_scopes do
    %{
      "manifest_preflight" => %{
        "scope" => "frozen_m0_copy_roots",
        "source_refs" => [@manifest_path | @migration_refs]
      },
      "dependency_audit" => %{
        "scope" => "original_m1_scan_set",
        "source_refs" => [@dependency_path]
      },
      "fixture_inventory" => %{
        "scope" => "launchd_fixture_presence_only",
        "source_refs" => ["fixtures/launchd/"]
      },
      "env_validation" => %{
        "scope" => "no_persisted_result",
        "source_refs" => ["priv/env/env.example"]
      }
    }
  end

  defp import_entry(source_path, target_path, category) do
    %{
      "source_path" => source_path,
      "target_path" => target_path,
      "category" => category,
      "accepted_oracle_sha" => @accepted_oracle_sha,
      "verification" => "accepted_commit_membership_and_current_presence",
      "source_refs" => [@manifest_path | @migration_refs]
    }
  end
end
