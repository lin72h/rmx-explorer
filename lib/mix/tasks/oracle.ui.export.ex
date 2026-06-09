defmodule Mix.Tasks.Oracle.Ui.Export do
  use Mix.Task

  alias RmxOSOracle.UI.Export

  @shortdoc "Export read-only JSON snapshots for the post-M1 oracle UI"

  @impl Mix.Task
  def run(args) do
    {opts, _rest, invalid} =
      OptionParser.parse(args,
        strict: [
          source: :string,
          page: :keep
        ]
      )

    if invalid != [], do: Mix.raise("invalid options: #{inspect(invalid)}")

    export_opts =
      []
      |> maybe_put(:source, Keyword.get(opts, :source))
      |> maybe_put(:pages, Keyword.get_values(opts, :page) |> empty_to_nil())

    report = Export.export(export_opts)
    Mix.shell().info(JSON.encode!(report))

    if report["status"] != "pass", do: exit({:shutdown, 1})
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp empty_to_nil([]), do: nil
  defp empty_to_nil(values), do: values
end
