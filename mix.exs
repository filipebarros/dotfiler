defmodule Dotfiler.Mixfile do
  use Mix.Project

  def project do
    [
      app: :dotfiler,
      version: "1.2.0",
      elixir: "~> 1.19",
      escript: escript(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def escript, do: [main_module: Dotfiler, path: "bin/dotfiler"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:meck, "~> 0.9", only: :test},
      {:toml_elixir, "~> 2.0"}
    ]
  end
end
