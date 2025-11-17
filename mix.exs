defmodule RaffApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :raff_app,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {RaffApp.Application, []}
    ]
  end

  defp deps do
    [
      {:plug, "~> 1.15"},
      {:plug_cowboy, "~> 2.7"},
      {:jason, "~> 1.4"},
      {:httpoison, "~> 2.1"}
    ]
  end
end
