defmodule RmxOSOracle.MixProject do
  use Mix.Project

  def project do
    [
      app: :rmxos_oracle,
      version: "0.1.0",
      elixir: "~> 1.20.0",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: ["lib"],
      deps: []
    ]
  end

  def application do
    [
      extra_applications: [:crypto, :logger]
    ]
  end
end
